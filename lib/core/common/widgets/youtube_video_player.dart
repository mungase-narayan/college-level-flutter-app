import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../../config/theme/app_theme.dart';
import 'app_states.dart';
import 'app_toast.dart';
import 'video_source.dart';

/// Plays a YouTube link with the official IFrame player.
///
/// ### Why not the WebView
///
/// [VideoPreview] used to hand YouTube an `<iframe>` inside a hand-written HTML
/// document. YouTube rejects that embed — the player comes back with "This video
/// is unavailable, error 152" rather than the video — because the frame has no
/// legitimate embedding origin to report. This widget talks to the same IFrame
/// API through the package that maintains that contract, so there is nothing to
/// keep in step by hand.
///
/// ### Fullscreen
///
/// Split between the package and this widget, and it is worth knowing which half
/// does what. The player renders into an [OverlayPortal], so fullscreen expands
/// the video over the whole app rather than over this widget's box, keeps its
/// controls, and comes back to exactly the frame it left — nothing is re-created,
/// so the playback position survives with no seeking. It also takes the back
/// button (via [PopScope]) while it is fullscreen, so Android's back exits
/// fullscreen before it leaves the page.
///
/// What it does *not* do is turn the device: `enterFullScreen` raises a flag and
/// nothing else. The rotation and the system bars are handled here, in
/// [_YouTubeVideoPlayerState._applyFullscreenChrome].
///
/// Because the overlay is the player's own, this widget can be dropped anywhere —
/// a tab, a markdown block — without the host page having to know about it.
class YouTubeVideoPlayer extends StatefulWidget {
  const YouTubeVideoPlayer({super.key, required this.videoUrl});

  /// Any YouTube link: `watch?v=`, `youtu.be/`, `/embed/`, `/shorts/`. Parsed by
  /// [VideoSource], the same parser the rest of the app's video handling uses.
  final String? videoUrl;

  @override
  State<YouTubeVideoPlayer> createState() => _YouTubeVideoPlayerState();
}

class _YouTubeVideoPlayerState extends State<YouTubeVideoPlayer>
    with WidgetsBindingObserver {
  YoutubePlayerController? _controller;
  StreamSubscription<YoutubePlayerValue>? _subscription;

  /// The last error the IFrame API reported, or [YoutubeError.none].
  YoutubeError _error = YoutubeError.none;

  /// False until the player has told us it is ready for input, which is what the
  /// loading state waits on.
  bool _ready = false;

  /// Mirrors the player's own fullscreen flag, so the app-side chrome changes
  /// fire once per transition however it was triggered — the button, a vertical
  /// swipe, or the back gesture.
  bool _fullscreen = false;

  /// Holds the portrait lock just long enough for the device to turn back.
  Timer? _releaseOrientation;

  String? get _videoId => VideoSource.parse(widget.videoUrl).youtubeId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _create();
  }

  @override
  void didUpdateWidget(YouTubeVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeController();
      _create();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Leaving the screen from inside fullscreen — a back gesture, a deep link,
    // a logout — would otherwise strand the whole app in landscape with its
    // system bars hidden, on a screen that has nothing to do with video.
    if (_fullscreen) _applyFullscreenChrome(false);
    _disposeController();
    super.dispose();
  }

  /// Stops playback when the app leaves the foreground.
  ///
  /// The player lives in a WebView, which happily keeps the audio running once
  /// the app is backgrounded — the single most common complaint about embedded
  /// video, and not something the user can stop from outside the app.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      unawaited(_controller?.pauseVideo());
    }
  }

  void _create() {
    final id = _videoId;
    if (id == null) return;

    final controller = YoutubePlayerController.fromVideoId(
      videoId: id,
      // Never on open: a video that starts talking the moment a student taps a
      // material is the behaviour every platform guideline asks you not to ship.
      autoPlay: false,
      params: const YoutubePlayerParams(
        mute: false,
        showFullscreenButton: true,
        // Keeps playback in the frame rather than handing the whole screen to
        // the platform's own player, which is what makes the inline layout and
        // the fullscreen transition ours to control.
        playsInline: true,
        // End cards from unrelated channels have no place in coursework.
        strictRelatedVideos: true,
      ),
    );

    _subscription = controller.stream.listen(_onValue);
    setState(() {
      _controller = controller;
      _error = YoutubeError.none;
      _ready = false;
    });
  }

  void _onValue(YoutubePlayerValue value) {
    if (!mounted) return;

    if (value.fullScreenOption.enabled != _fullscreen) {
      _fullscreen = value.fullScreenOption.enabled;
      _applyFullscreenChrome(_fullscreen);
    }

    // `unknown` is the initial state, before the IFrame API has answered at all.
    final ready = value.playerState != PlayerState.unknown;
    if (ready == _ready && value.error == _error) return;

    if (value.error != YoutubeError.none) {
      // The code is the only part worth keeping; the student gets plain copy.
      debugPrint(
        'YouTubeVideoPlayer: ${value.error.name} (${value.error.code}) '
        'for ${widget.videoUrl}',
      );
    }

    setState(() {
      _ready = ready;
      _error = value.error;
    });
  }

  /// Rotates the device and hides the system bars for fullscreen, and puts both
  /// back on the way out.
  ///
  /// The player does **not** do this. `enterFullScreen` only raises a flag and
  /// expands the video into an overlay — it makes no `SystemChrome` calls at all,
  /// so on its own the fullscreen button gives you a letterboxed portrait video
  /// on a phone. The rotation is the app's job, and so is undoing it.
  ///
  /// Landscape is *locked* while fullscreen and released afterwards rather than
  /// simply set: leaving a preference in place is how an app ends up stuck in
  /// landscape on the next screen the student opens.
  void _applyFullscreenChrome(bool fullscreen) {
    if (fullscreen) {
      SystemChrome.setPreferredOrientations(const [
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      // Sticky rather than plain immersive: a stray tap near the edge should
      // not permanently bring the bars back over the video.
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      return;
    }

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);

    // Held only long enough to carry the device through the rotation, then
    // dropped so the rest of the app keeps whatever orientation freedom it had.
    // Without the delay the release lands before the device has turned and the
    // screen stays in landscape.
    _releaseOrientation?.cancel();
    _releaseOrientation = Timer(const Duration(milliseconds: 700), () {
      SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    });
  }

  void _disposeController() {
    _subscription?.cancel();
    _subscription = null;
    // `close` tears down the WebView as well as the controller. Skipping it
    // leaves the video playing to itself after the screen is gone.
    unawaited(_controller?.close());
    _controller = null;
  }

  void _retry() {
    _disposeController();
    _create();
  }

  Future<void> _openInYouTube() async {
    final url = widget.videoUrl;
    final uri = url == null ? null : Uri.tryParse(url);
    if (uri == null) return;

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppToast.error(context, 'Could not open this video.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (controller == null) {
      return const _VideoMessage(
        icon: Icons.link_off_rounded,
        title: 'Unable to load video',
        description: 'Please check the YouTube URL.',
      );
    }

    if (_error != YoutubeError.none) return _errorSurface();

    return _Frame(
      child: Stack(
        fit: StackFit.expand,
        children: [
          YoutubePlayer(
            controller: controller,
            // Explicit rather than inherited: this widget's whole contract is a
            // 16:9 frame, and a mismatch here would letterbox inside a box that
            // is already the right shape.
            aspectRatio: 16 / 9,
            backgroundColor: Colors.black,
            // Off, because this widget drives the rotation itself. Left on, the
            // two fight: exiting fullscreen forces portrait, the device turns,
            // and the player — seeing landscape one frame earlier — puts itself
            // straight back into fullscreen.
            autoFullScreen: false,
          ),
          // Sits above the player only until the IFrame API answers. The player
          // paints its background immediately, so without this the student
          // watches a black rectangle with no sign that anything is happening.
          if (!_ready)
            const IgnorePointer(
              child: ColoredBox(
                color: Colors.black,
                child: AppLoader(message: 'Loading video…'),
              ),
            ),
        ],
      ),
    );
  }

  /// The error surface, split by whether retrying could possibly help.
  Widget _errorSurface() {
    // 101/150/152 all mean the same thing: the channel has switched embedding
    // off. No player can play it, so offering "Try again" would be a lie — the
    // only route left is YouTube itself.
    final blocked = _error == YoutubeError.notEmbeddable ||
        _error == YoutubeError.sameAsNotEmbeddable ||
        _error.code == 152;

    if (blocked) {
      return _VideoMessage(
        icon: Icons.lock_outline_rounded,
        title: 'Not available here',
        description: 'The channel does not allow this video to play inside '
            'other apps.',
        action: FilledButton.icon(
          onPressed: _openInYouTube,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('Watch on YouTube'),
        ),
      );
    }

    final gone = _error == YoutubeError.videoNotFound ||
        _error == YoutubeError.cannotFindVideo;

    return _VideoMessage(
      icon: Icons.error_outline_rounded,
      title: 'Video unavailable',
      description: gone
          ? 'This video has been removed or made private.'
          : 'The video could not be loaded.',
      action: gone
          ? null
          : OutlinedButton.icon(
              onPressed: _retry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}

/// The 16:9 rounded surface every state of the player is drawn on, so loading,
/// error and playback all occupy exactly the same box and the page never jumps.
class _Frame extends StatelessWidget {
  const _Frame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(color: Colors.black, child: child),
      ),
    );
  }
}

class _VideoMessage extends StatelessWidget {
  const _VideoMessage({
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.muted.withValues(alpha: 0.4),
            border: Border.all(color: scheme.border),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 26, color: scheme.mutedForeground),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: theme.textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  if (action != null) ...[const SizedBox(height: 14), action!],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
