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
///
/// Lives apart from the widgets that consume it because two of them now do:
/// `VideoPreview` plays Vimeo and direct files in a WebView, `YouTubeVideoPlayer`
/// plays YouTube through the IFrame API, and the first has to parse a link to
/// know which of them owns it. Keeping the parser here is what stops those two
/// files from importing each other in a circle.
class VideoSource {
  const VideoSource(this.kind, [this.src]);

  final VideoKind kind;
  final String? src;

  static const _invalid = VideoSource(VideoKind.invalid);

  /// The YouTube id, or null when this is not a YouTube source.
  ///
  /// Read off the normalised [src] rather than the original link, so every shape
  /// [parse] already understands — `watch?v=`, `youtu.be`, `/embed/`, `/shorts/`,
  /// the mobile host — resolves through one code path. The player needs the bare
  /// id; the WebView needs the embed URL; both come out of the same parse.
  String? get youtubeId {
    final url = src;
    if (kind != VideoKind.embed || url == null) return null;

    final match = RegExp(
      r'^https://www\.youtube\.com/embed/([A-Za-z0-9_-]+)$',
    ).firstMatch(url);
    return match?.group(1);
  }

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
