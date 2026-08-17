import 'package:college_level/core/common/widgets/video_preview.dart';
import 'package:flutter_test/flutter_test.dart';

/// `VideoSource.parse` is a direct port of `parseVideoUrl` in the web app's
/// `video-preview.tsx`. A silent mis-parse here shows the student "preview not
/// available" for a perfectly good link, so every branch is pinned.
void main() {
  group('YouTube', () {
    test('watch links become embed links', () {
      final source = VideoSource.parse(
        'https://www.youtube.com/watch?v=QZwneRb-zqA',
      );
      expect(source.kind, VideoKind.embed);
      expect(source.src, 'https://www.youtube.com/embed/QZwneRb-zqA');
    });

    test('keeps the id when other query params are present', () {
      final source = VideoSource.parse(
        'https://youtube.com/watch?list=PL123&v=abc-DEF_9&t=42',
      );
      expect(source.src, 'https://www.youtube.com/embed/abc-DEF_9');
    });

    test('handles the mobile host', () {
      expect(
        VideoSource.parse('https://m.youtube.com/watch?v=abc123').src,
        'https://www.youtube.com/embed/abc123',
      );
    });

    test('handles youtu.be short links', () {
      final source = VideoSource.parse('https://youtu.be/abc123');
      expect(source.kind, VideoKind.embed);
      expect(source.src, 'https://www.youtube.com/embed/abc123');
    });

    test('handles /shorts/ and already-embedded links', () {
      expect(
        VideoSource.parse('https://www.youtube.com/shorts/xyz789').src,
        'https://www.youtube.com/embed/xyz789',
      );
      expect(
        VideoSource.parse('https://www.youtube.com/embed/xyz789').src,
        'https://www.youtube.com/embed/xyz789',
      );
    });
  });

  group('Vimeo', () {
    test('numeric ids become player links', () {
      final source = VideoSource.parse('https://vimeo.com/123456789');
      expect(source.kind, VideoKind.embed);
      expect(source.src, 'https://player.vimeo.com/video/123456789');
    });

    test('a non-numeric path is not a video', () {
      // e.g. https://vimeo.com/channels/staffpicks
      expect(
        VideoSource.parse('https://vimeo.com/channels').kind,
        VideoKind.invalid,
      );
    });

    test('an existing player link passes through', () {
      const url = 'https://player.vimeo.com/video/123456789';
      expect(VideoSource.parse(url).src, url);
    });
  });

  group('Direct files', () {
    test('recognises the supported extensions', () {
      for (final ext in ['mp4', 'webm', 'ogg', 'mov', 'm4v']) {
        final url = 'https://cdn.example.com/lecture.$ext';
        expect(
          VideoSource.parse(url).kind,
          VideoKind.file,
          reason: '.$ext should play as a file',
        );
        expect(VideoSource.parse(url).src, url);
      }
    });

    test('matches on the path, ignoring a query string', () {
      expect(
        VideoSource.parse('https://cdn.example.com/a.mp4?token=xyz').kind,
        VideoKind.file,
      );
    });
  });

  /// The id is what `YouTubeVideoPlayer` hands to the IFrame API, so a wrong or
  /// missing one is the difference between the video and an error card. It is
  /// derived from the same parse as `src`, which is why every shape above is
  /// re-checked here rather than trusted.
  group('youtubeId', () {
    test('comes back from every link shape the parser accepts', () {
      const cases = {
        'https://www.youtube.com/watch?v=QZwneRb-zqA': 'QZwneRb-zqA',
        'https://youtube.com/watch?list=PL123&v=abc-DEF_9&t=42': 'abc-DEF_9',
        'https://m.youtube.com/watch?v=abc123': 'abc123',
        'https://youtu.be/QZwneRb-zqA': 'QZwneRb-zqA',
        'https://www.youtube.com/embed/QZwneRb-zqA': 'QZwneRb-zqA',
        'https://www.youtube.com/shorts/QZwneRb-zqA': 'QZwneRb-zqA',
      };

      cases.forEach((url, id) {
        expect(VideoSource.parse(url).youtubeId, id, reason: url);
      });
    });

    test('is null for everything that is not YouTube', () {
      // Vimeo parses to an embed too, so `kind` alone cannot be the test —
      // handing a Vimeo id to the YouTube player would load someone else's
      // video, or nothing at all.
      expect(
        VideoSource.parse('https://vimeo.com/123456789').youtubeId,
        isNull,
      );
      expect(
        VideoSource.parse('https://player.vimeo.com/video/123').youtubeId,
        isNull,
      );
      expect(
        VideoSource.parse('https://cdn.example.com/lecture.mp4').youtubeId,
        isNull,
      );
    });

    test('is null when there is nothing to parse', () {
      expect(VideoSource.parse(null).youtubeId, isNull);
      expect(VideoSource.parse('').youtubeId, isNull);
      expect(VideoSource.parse('not a url').youtubeId, isNull);
      expect(VideoSource.parse('https://example.com/watch').youtubeId, isNull);
    });
  });

  group('Unsupported input', () {
    test('empty, null, and malformed values are invalid', () {
      expect(VideoSource.parse(null).kind, VideoKind.invalid);
      expect(VideoSource.parse('').kind, VideoKind.invalid);
      expect(VideoSource.parse('   ').kind, VideoKind.invalid);
      expect(VideoSource.parse('not a url').kind, VideoKind.invalid);
    });

    test('an arbitrary page is not previewable', () {
      expect(
        VideoSource.parse('https://example.com/some/article').kind,
        VideoKind.invalid,
      );
    });
  });
}
