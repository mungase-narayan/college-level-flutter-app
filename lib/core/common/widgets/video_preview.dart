import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Imported for the inline-playback params; WKWebView blocks in-place video
// without them.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../config/theme/app_theme.dart';

/// How a video URL should be played.
enum VideoKind {
  /// A provider embed (YouTube, Vimeo) — what the web app puts in an `iframe`.
  embed,

  /// A direct video file, played by the platform's own `<video>` element.
  file,

  /// Not something we can preview.
  invalid,
}

/// The result of parsing a course material's `videoUrl`.
class VideoSource {
  const VideoSource(this.kind, [this.src]);

  final VideoKind kind;
  final String? src;

  static const _invalid = VideoSource(VideoKind.invalid);

  /// Port of `parseVideoUrl` in `src/components/shared/video-preview.tsx`.
  ///
  /// Normalises watch/short/embed links to the provider's embed URL so the
  /// player loads directly instead of the surrounding site chrome.
  factory VideoSource.parse(String? raw) {
    final url = (raw ?? '').trim();
    if (url.isEmpty) return _invalid;

    final parsed = Uri.tryParse(url);
    if (parsed == null || !parsed.hasScheme) return _invalid;

    final host = parsed.host.replaceFirst(RegExp(r'^www\.'), '');

    // ── YouTube ───────────────────────────────────────────────────────────
    if (host == 'youtube.com' || host == 'm.youtube.com') {
      final v = parsed.queryParameters['v'];
      if (v != null && v.isNotEmpty) {
        return VideoSource(VideoKind.embed, 'https://www.youtube.com/embed/$v');
      }
      final match =
          RegExp(r'/(embed|shorts)/([\w-]+)').firstMatch(parsed.path);
      if (match != null) {
        return VideoSource(
          VideoKind.embed,
          'https://www.youtube.com/embed/${match.group(2)}',
        );
      }
    }
    if (host == 'youtu.be') {
      final id = parsed.path.replaceFirst('/', '');
      if (id.isNotEmpty) {
        return VideoSource(VideoKind.embed, 'https://www.youtube.com/embed/$id');
      }
    }

    // ── Vimeo ─────────────────────────────────────────────────────────────
    if (host == 'vimeo.com') {
      final segments = parsed.pathSegments.where((s) => s.isNotEmpty).toList();
      if (segments.isNotEmpty && RegExp(r'^\d+$').hasMatch(segments.first)) {
        return VideoSource(
          VideoKind.embed,
          'https://player.vimeo.com/video/${segments.first}',
        );
      }
    }
    if (host == 'player.vimeo.com') return VideoSource(VideoKind.embed, url);

    // ── Direct file ───────────────────────────────────────────────────────
    if (RegExp(r'\.(mp4|webm|ogg|mov|m4v)$', caseSensitive: false)
        .hasMatch(parsed.path)) {
      return VideoSource(VideoKind.file, url);
    }

    return _invalid;
  }
}

/// Port of the shared `VideoPreview` — plays a course material's video inline.
///
/// Provider links load their embed player; a direct file is wrapped in a
/// minimal HTML document so the platform supplies native controls. Anything we
/// can't preview falls back to the same message the web app shows.
class VideoPreview extends StatefulWidget {
  const VideoPreview({super.key, required this.url});

  final String? url;

  @override
  State<VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<VideoPreview> {
  WebViewController? _controller;
  late VideoSource _source;

  @override
  void initState() {
    super.initState();
    _source = VideoSource.parse(widget.url);
    _prepare();
  }

  @override
  void didUpdateWidget(VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _source = VideoSource.parse(widget.url);
      _prepare();
    }
  }

  void _prepare() {
    if (_source.kind == VideoKind.invalid) {
      setState(() => _controller = null);
      return;
    }

    // Play inline. Without this, WKWebView refuses to render video in place and
    // iOS takes over the whole screen the moment playback starts.
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black);

    if (_source.kind == VideoKind.embed) {
      final src = _playerUri(_source.src!);
      // Loaded as a document with a `baseUrl` on the provider's own origin, NOT
      // via loadRequest. A bare request has no origin, so YouTube's embed
      // rejects it with "Error 153 — video player configuration error".
      controller.loadHtmlString(
        _embedHtml(src.toString()),
        baseUrl: src.origin,
      );
    } else {
      controller.loadHtmlString(_fileHtml(_source.src!));
    }

    setState(() => _controller = controller);
  }

  /// Adds the player flags the web `iframe` relies on, preserving any query the
  /// provider link already carries.
  Uri _playerUri(String src) {
    final uri = Uri.parse(src);
    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        // Keep playback in the frame and drop unrelated end-cards.
        'playsinline': '1',
        'rel': '0',
      },
    );
  }

  /// `&` must be escaped inside an HTML attribute or the query silently
  /// truncates at the first parameter.
  String _attr(String value) => value.replaceAll('&', '&amp;');

  String _embedHtml(String src) => '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
    <style>
      html, body { margin: 0; height: 100%; background: #000; overflow: hidden; }
      iframe { border: 0; width: 100%; height: 100%; }
    </style>
  </head>
  <body>
    <iframe src="${_attr(src)}"
      allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
      allowfullscreen></iframe>
  </body>
</html>
''';

  /// A minimal page whose only job is to hand the file to the platform player.
  String _fileHtml(String src) => '''
<!doctype html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1, user-scalable=no">
    <style>
      html, body { margin: 0; height: 100%; background: #000; }
      video { width: 100%; height: 100%; object-fit: contain; }
    </style>
  </head>
  <body>
    <video src="${_attr(src)}" controls playsinline></video>
  </body>
</html>
''';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    if (_source.kind == VideoKind.invalid || _controller == null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.muted.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(
            color: scheme.border,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 15, color: scheme.mutedForeground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Preview not available for this link.',
                style: theme.textTheme.labelSmall,
              ),
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: ColoredBox(
          color: Colors.black,
          child: WebViewWidget(controller: _controller!),
        ),
      ),
    );
  }
}
