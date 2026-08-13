import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/common/bloc/remote_cubit.dart';
import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/injection_modules/service_locator.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../files/presentation/widgets/attachment_tile.dart';
import '../../../notes/domain/entities/note.dart';
import '../../../notes/presentation/bloc/material_notes_cubit.dart';
import '../../../notes/presentation/widgets/material_notes_tab.dart';
import '../../domain/entities/course_tree.dart';
import '../bloc/course_tabs_cubit.dart';
import '../bloc/courses_cubit.dart';
import '../bloc/material_comments_cubit.dart';
import '../widgets/material_assignments_tab.dart';
import '../widgets/material_comments_tab.dart';

/// Port of `student/courses/detail/learning-plan/components/topic-content.tsx`
/// and its `MaterialTabs`.
///
/// The web renders a material in the right-hand pane of a split view; on a
/// phone it is a pushed page, so the interactive blocks in the Content tab —
/// quiz, tabs, playground, pdf — get the full width.
///
/// Tabs, in the web's order: Content · Video · Attachments · Assignments ·
/// Notes · Comments. Video only exists when the material has one, and the
/// Attachments tab carries the file count as a badge.
class MaterialDetailPage extends StatelessWidget {
  const MaterialDetailPage({
    super.key,
    required this.courseId,
    required this.materialId,
  });

  final String courseId;
  final String materialId;

  /// Pushes the page above the shell, carrying the caller's [CourseTreeCubit]
  /// so completion toggles and the tree stay one source of truth.
  static Future<void> push(
    BuildContext context, {
    required String courseId,
    required String materialId,
  }) {
    final tree = context.read<CourseTreeCubit>();

    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider.value(
          value: tree,
          child: MaterialDetailPage(
            courseId: courseId,
            materialId: materialId,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Re-derived from the tree on every build: after a completion toggle the
    // cubit reloads, and the page picks the new state up with nothing to sync.
    return BlocBuilder<CourseTreeCubit, RemoteState<CourseTree>>(
      builder: (context, state) {
        final located = state.data?.locate(materialId);

        if (located == null) {
          return Scaffold(
            appBar: const AdaptiveAppBar(title: 'Material'),
            body: state.isInitialLoading
                ? const AppLoader()
                : const AppEmptyState(
                    title: 'Material unavailable',
                    description:
                        'It may have been removed from this course.',
                    icon: Icons.description_outlined,
                  ),
          );
        }

        return _MaterialScaffold(
          courseId: courseId,
          location: located,
        );
      },
    );
  }
}

class _MaterialScaffold extends StatelessWidget {
  const _MaterialScaffold({required this.courseId, required this.location});

  final String courseId;
  final MaterialLocation location;

  @override
  Widget build(BuildContext context) {
    final material = location.material;
    final hasVideo = (material.videoUrl ?? '').trim().isNotEmpty;
    final attachmentCount = material.attachments.length;

    // Video is conditional, exactly as on the web, so the tab list and the view
    // list are built together to stay in step.
    final tabs = <Tab>[
      const Tab(text: 'Content'),
      if (hasVideo) const Tab(text: 'Video'),
      Tab(child: _AttachmentsLabel(count: attachmentCount)),
      const Tab(text: 'Assignments'),
      const Tab(text: 'Notes'),
      const Tab(text: 'Comments'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: material.name,
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: tabs,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              _Header(location: location),
              Expanded(
                child: TabBarView(
                  children: [
                    _ContentTab(content: material.content),
                    if (hasVideo) _VideoTab(url: material.videoUrl!),
                    _AttachmentsTab(fileIds: material.attachments),

                    // The last three fetch their own data, each lazily on the
                    // first build of its tab.
                    BlocProvider(
                      create: (_) => CourseAssessmentsCubit(
                        listAssessments: sl(),
                        courseId: courseId,
                        // No category → the backend excludes quizzes, matching
                        // the web tab.
                        category: null,
                        courseMaterialId: material.id,
                      ),
                      child: const MaterialAssignmentsTab(),
                    ),
                    BlocProvider(
                      create: (_) => MaterialNotesCubit(
                        list: sl(),
                        create: sl(),
                        link: NoteLinkContext(
                          courseId: courseId,
                          materialId: material.id,
                        ),
                      ),
                      child: const MaterialNotesTab(),
                    ),
                    BlocProvider(
                      create: (_) => MaterialCommentsCubit(
                        list: sl(),
                        create: sl(),
                        reply: sl(),
                        update: sl(),
                        remove: sl(),
                        materialId: material.id,
                      ),
                      child: const MaterialCommentsTab(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `Attachments 3` — the count badge that is the material tab strip's one piece
/// of live data.
class _AttachmentsLabel extends StatelessWidget {
  const _AttachmentsLabel({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Attachments'),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Breadcrumb and completion toggle on one line, with the description tucked
/// behind a tap.
///
/// This strip sits above the tab content on every tab, so every pixel it takes
/// is a pixel the material itself doesn't get. The web solves the same squeeze
/// by hiding the description below the `sm` breakpoint and shrinking the toggle
/// into a mobile action bar; here the description stays reachable rather than
/// being dropped, but it stays collapsed until asked for.
class _Header extends StatefulWidget {
  const _Header({required this.location});

  final MaterialLocation location;

  @override
  State<_Header> createState() => _HeaderState();
}

class _HeaderState extends State<_Header> {
  bool _showDescription = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = context.scheme;
    final material = widget.location.material;
    final description = (material.description ?? '').trim();
    final hasDescription = description.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(bottom: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${widget.location.module.name}  ›  '
                  '${widget.location.topic.name}',
                  style: theme.textTheme.labelSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (hasDescription)
                InkWell(
                  onTap: () =>
                      setState(() => _showDescription = !_showDescription),
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      _showDescription
                          ? Icons.info_rounded
                          : Icons.info_outline_rounded,
                      size: 16,
                      color: _showDescription
                          ? scheme.primary
                          : scheme.mutedForeground,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
              _CompleteToggle(material: material),
            ],
          ),
          if (hasDescription && _showDescription)
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 4),
              child: Text(description, style: theme.textTheme.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// The completion toggle as a pill rather than a full-height button — it shares
/// its line with the breadcrumb, so it has to fit inside one.
class _CompleteToggle extends StatelessWidget {
  const _CompleteToggle({required this.material});

  final CourseMaterial material;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final scheme = tokens.scheme;
    final done = material.completed;

    final background = done ? tokens.success.background : scheme.primary;
    final foreground =
        done ? tokens.success.foreground : scheme.primaryForeground;

    return InkWell(
      onTap: () => context.read<CourseTreeCubit>().toggleMaterial(material),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.check_rounded,
              size: 14,
              color: foreground,
            ),
            const SizedBox(width: 5),
            Text(
              done ? 'Completed' : 'Mark complete',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: foreground,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContentTab extends StatelessWidget {
  const _ContentTab({required this.content});

  final String? content;

  @override
  Widget build(BuildContext context) {
    if ((content ?? '').trim().isEmpty) {
      return const AppEmptyState(
        title: 'No content yet',
        description: 'This material has no written content.',
        icon: Icons.menu_book_outlined,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      child: AppMarkdown(content),
    );
  }
}

class _VideoTab extends StatelessWidget {
  const _VideoTab({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          VideoPreview(url: url),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final uri = Uri.tryParse(url);
                if (uri == null) return;
                final launched = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!launched && context.mounted) {
                  AppToast.error(context, 'Could not open this video.');
                }
              },
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text('Open in app'),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentsTab extends StatelessWidget {
  const _AttachmentsTab({required this.fileIds});

  final List<String> fileIds;

  @override
  Widget build(BuildContext context) {
    if (fileIds.isEmpty) {
      return const AppEmptyState(
        title: 'No attachments',
        description: 'No files have been attached to this material.',
        icon: Icons.attach_file_rounded,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      children: [
        // Each tile resolves its own uuid through `GET /files/:id`, so the row
        // can show a real name and open through a presigned URL.
        for (final fileId in fileIds) AttachmentTile(fileId: fileId),
      ],
    );
  }
}
