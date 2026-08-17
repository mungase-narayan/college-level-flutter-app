import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../domain/entities/announcement.dart';

/// The announcement's files.
///
/// Deliberately not `AttachmentTile`: that one exists to turn a bare file uuid
/// into a presigned URL through two use cases, and the announcement payload
/// already arrives with `attachmentFiles` fully resolved. Reusing it would fire
/// two requests per row to learn what is already in hand.
class AnnouncementAttachments extends StatelessWidget {
  const AnnouncementAttachments({super.key, required this.files});

  final List<AnnouncementFileRef> files;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (files.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Attachments (${files.length})',
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        for (final file in files)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AttachmentRow(file: file),
          ),
      ],
    );
  }
}

class _AttachmentRow extends StatefulWidget {
  const _AttachmentRow({required this.file});

  final AnnouncementFileRef file;

  @override
  State<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends State<_AttachmentRow> {
  bool _opening = false;

  Future<void> _open() async {
    if (_opening) return;
    setState(() => _opening = true);

    final uri = Uri.tryParse(widget.file.url);
    var launched = false;
    if (uri != null) {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    if (!mounted) return;
    setState(() => _opening = false);
    if (!launched) {
      AppToast.error(context, 'Could not open this attachment.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return AppCard(
      onTap: _open,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.muted,
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: Icon(
              Icons.insert_drive_file_outlined,
              size: 17,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.file.name.isEmpty ? 'Attachment' : widget.file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          if (_opening)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            Icon(
              Icons.download_rounded,
              size: 18,
              color: scheme.mutedForeground,
            ),
        ],
      ),
    );
  }
}
