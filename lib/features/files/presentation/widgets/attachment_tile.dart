import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/injection_modules/service_locator.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/markdown/web_frame.dart';
import '../../../../core/usecases/usecase.dart';
import '../../domain/entities/uploaded_file.dart';
import '../../domain/usecases/file_usecases.dart';

/// One row in the Attachments tab — the port of `AttachmentItem`.
///
/// A material stores attachments as bare file uuids, so the row resolves the
/// file first and only then knows its name, size, and category. Images and PDFs
/// preview in place; everything else opens in the platform's own viewer.
class AttachmentTile extends StatefulWidget {
  const AttachmentTile({super.key, required this.fileId});

  final String fileId;

  @override
  State<AttachmentTile> createState() => _AttachmentTileState();
}

class _AttachmentTileState extends State<AttachmentTile> {
  UploadedFile? _file;
  String? _error;
  bool _loading = true;
  bool _opening = false;
  bool _expanded = false;

  /// Cached so a preview that is opened and closed twice doesn't burn two
  /// presigned-URL requests.
  String? _openUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final result = await sl<GetFileUseCase>()(IdParams(widget.fileId));
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _error = failure.message;
        _loading = false;
      }),
      (file) => setState(() {
        _file = file;
        _loading = false;
      }),
    );
  }

  /// Resolves — and remembers — the URL this file can be reached at.
  Future<String?> _url() async {
    if (_openUrl != null) return _openUrl;
    final file = _file;
    if (file == null) return null;

    final result = await sl<ResolveFileUrlUseCase>()(file);
    return result.fold((_) => null, (url) {
      _openUrl = url;
      return url;
    });
  }

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);

    final url = await _url();
    if (!mounted) return;
    setState(() => _opening = false);

    if (url == null || url.isEmpty) {
      AppToast.error(context, 'Could not open this attachment.');
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      AppToast.error(context, 'Could not open this attachment.');
    }
  }

  Future<void> _togglePreview() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }
    setState(() => _opening = true);
    await _url();
    if (!mounted) return;
    setState(() {
      _opening = false;
      _expanded = _openUrl != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8),
        child: AppSkeleton(height: 56, radius: AppTheme.radiusMd),
      );
    }

    final file = _file;
    if (file == null) {
      // The uuid is still worth showing — it is the only handle anyone has on a
      // file the server would not describe.
      return _Shell(
        child: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: scheme.destructive,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attachment unavailable',
                    style: theme.textTheme.bodyMedium,
                  ),
                  Text(
                    _error ?? widget.fileId,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final previewable =
        file.category == FileCategory.image || file.isPdf;

    return _Shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(_iconFor(file), size: 20, color: scheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.displayName,
                      style: theme.textTheme.bodyMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      [
                        file.fileExtension?.toUpperCase(),
                        file.readableSize,
                      ].whereType<String>().join(' · '),
                      style: theme.textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
              if (_opening)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else ...[
                if (previewable)
                  IconButton(
                    onPressed: _togglePreview,
                    visualDensity: VisualDensity.compact,
                    tooltip: _expanded ? 'Hide preview' : 'Preview',
                    icon: Icon(
                      _expanded
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 18,
                      color: scheme.mutedForeground,
                    ),
                  ),
                IconButton(
                  onPressed: _open,
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Open',
                  icon: Icon(
                    Icons.download_rounded,
                    size: 18,
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
            ],
          ),
          if (_expanded && _openUrl != null) ...[
            const SizedBox(height: 12),
            if (file.category == FileCategory.image)
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: CachedNetworkImage(
                  imageUrl: _openUrl!,
                  fit: BoxFit.contain,
                  errorWidget: (_, _, _) => Text(
                    'Preview unavailable.',
                    style: theme.textTheme.labelSmall,
                  ),
                ),
              )
            else
              WebFrame(url: pdfFrameUrl(_openUrl!), height: 420),
          ],
        ],
      ),
    );
  }

  /// The same category→icon mapping `rowIconFor()` makes on the web.
  IconData _iconFor(UploadedFile file) {
    if (file.isPdf) return Icons.picture_as_pdf_outlined;
    return switch (file.category) {
      FileCategory.image => Icons.image_outlined,
      FileCategory.video => Icons.movie_outlined,
      FileCategory.audio => Icons.audiotrack_outlined,
      FileCategory.document => Icons.description_outlined,
      FileCategory.other => Icons.insert_drive_file_outlined,
    };
  }
}

class _Shell extends StatelessWidget {
  const _Shell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.muted.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border),
        ),
        child: child,
      ),
    );
  }
}
