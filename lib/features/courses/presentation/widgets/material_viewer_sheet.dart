import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_colors.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/constants/api_urls.dart';
import '../../domain/entities/course_tree.dart';

/// The mobile form of the React material viewer.
///
/// The web version renders video, PDF, and link materials inline in a resizable
/// pane. Here the markdown body renders in-sheet, and video/attachments open in
/// the platform's own player or viewer via `url_launcher` — which also gets the
/// presigned-URL redirect for private files handled by the OS.
class MaterialViewerSheet extends StatelessWidget {
  const MaterialViewerSheet({
    super.key,
    required this.material,
    required this.onToggleComplete,
  });

  final CourseMaterial material;
  final VoidCallback onToggleComplete;

  static Future<void> show(
    BuildContext context, {
    required CourseMaterial material,
    required VoidCallback onToggleComplete,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => MaterialViewerSheet(
        material: material,
        onToggleComplete: onToggleComplete,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final hasBody = (material.content ?? '').trim().isNotEmpty;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title and status share one line; the description gets the
                // full width beneath rather than being squeezed beside a badge.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        material.name,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                    if (material.completed) ...[
                      const SizedBox(width: 10),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AppBadge(
                          'Completed',
                          icon: Icons.check_rounded,
                          shade: TwColors.emerald,
                          dense: true,
                        ),
                      ),
                    ],
                  ],
                ),
                if ((material.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    material.description!,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Plays inline — the port of the web app's `VideoPreview`
                  // iframe rather than punting the student to a browser.
                  if ((material.videoUrl ?? '').isNotEmpty) ...[
                    VideoPreview(url: material.videoUrl),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _open(context, material.videoUrl!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 15),
                        label: const Text('Open in app'),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (material.attachments.isNotEmpty) ...[
                    Text('Attachments', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 8),
                    for (final fileId in material.attachments) ...[
                      _LinkTile(
                        icon: Icons.description_outlined,
                        label: 'Open attachment',
                        description: fileId,
                        onTap: () => _open(
                          context,
                          // Streams through the API so private-bucket files get
                          // their presigned redirect.
                          '${ApiUrls.baseUrl}${ApiUrls.file(fileId)}/download',
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    const SizedBox(height: 4),
                  ],
                  if (hasBody)
                    AppMarkdown(material.content)
                  else if ((material.videoUrl ?? '').isEmpty &&
                      material.attachments.isEmpty)
                    Text(
                      'This material has no content yet.',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              12 + MediaQuery.of(context).padding.bottom,
            ),
            child: AppButton(
              label: material.completed ? 'Mark as incomplete' : 'Mark as complete',
              icon: material.completed
                  ? Icons.remove_done_rounded
                  : Icons.check_rounded,
              expand: true,
              variant: material.completed
                  ? AppButtonVariant.outline
                  : AppButtonVariant.primary,
              onPressed: () {
                Navigator.of(context).pop();
                onToggleComplete();
              },
            ),
          ),
        ],
      ),
    ).withBackground(scheme.popover);
  }

  Future<void> _open(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppToast.error(context, 'Could not open this material.');
    }
  }
}

class _LinkTile extends StatelessWidget {
  const _LinkTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.description,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.muted,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: theme.textTheme.bodyMedium),
                  if (description != null)
                    Text(
                      description!,
                      style: theme.textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 16, color: scheme.mutedForeground),
          ],
        ),
      ),
    );
  }
}

extension on Widget {
  /// The sheet's own surface colour, applied after the constraints so the
  /// rounded corners of `bottomSheetTheme` still clip correctly.
  Widget withBackground(Color color) => DecoratedBox(
        decoration: BoxDecoration(color: color),
        child: this,
      );
}
