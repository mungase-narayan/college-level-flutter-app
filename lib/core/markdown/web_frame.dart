import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
// Imported for the inline-playback params; WKWebView blocks in-place media
// without them. Same reason `VideoPreview` reaches for it.
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../config/theme/app_theme.dart';

/// A fixed-height WebView pane for the blocks that have no native Flutter
/// equivalent — the code playground, inline PDFs, and mermaid diagrams.
///
/// The web app puts each of these in an `iframe`; this is the closest mobile
/// analogue, and it reuses the same platform plumbing `VideoPreview` already
/// relies on so there is one place where inline-media behaviour is configured.
class WebFrame extends StatefulWidget {
  const WebFrame({
    super.key,
    this.url,
    this.html,
    this.baseUrl,
    required this.height,
    this.background = Colors.transparent,
    this.onMessage,
    this.channels = const {},
  }) : assert(url != null || html != null, 'WebFrame needs a url or html');

  /// Loaded with `loadRequest`. Mutually exclusive with [html].
  final String? url;

  /// Loaded with `loadHtmlString`. Mutually exclusive with [url].
  final String? html;

  /// Origin the [html] document is treated as belonging to. Providers that
  /// check the embedding origin need this — see the note in `VideoPreview`.
  final String? baseUrl;

  final double height;
  final Color background;

  /// Called with `(channelName, message)` for any of [channels] that fires.
  final void Function(String channel, String message)? onMessage;

  /// JavaScript channel names to expose on `window`.
  final Set<String> channels;

  @override
  State<WebFrame> createState() => _WebFrameState();
}

class _WebFrameState extends State<WebFrame> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  @override
  void didUpdateWidget(WebFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.html != widget.html) {
      _prepare();
    }
  }

  void _prepare() {
    final params = WebViewPlatform.instance is WebKitWebViewPlatform
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(widget.background);

    for (final name in widget.channels) {
      controller.addJavaScriptChannel(
        name,
        onMessageReceived: (message) =>
            widget.onMessage?.call(name, message.message),
      );
    }

    if (widget.html != null) {
      controller.loadHtmlString(
        widget.html!,
        baseUrl: widget.baseUrl,
      );
    } else {
      final uri = Uri.tryParse(widget.url!);
      if (uri != null) controller.loadRequest(uri);
    }

    setState(() => _controller = controller);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return SizedBox(height: widget.height);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: SizedBox(
        height: widget.height,
        child: WebViewWidget(controller: controller),
      ),
    );
  }
}

/// Android's system WebView cannot render a PDF, so the document is routed
/// through Google's viewer there. iOS renders PDFs natively in WKWebView.
///
/// The viewer can only reach a publicly readable URL, which is why every PDF
/// pane keeps an "Open externally" action alongside it.
String pdfFrameUrl(String src) {
  if (defaultTargetPlatform == TargetPlatform.android) {
    return 'https://docs.google.com/gview?embedded=true&url='
        '${Uri.encodeComponent(src)}';
  }
  return src;
}
