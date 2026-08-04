import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../core/common/widgets/widgets.dart';
import '../../../../core/config/theme/app_theme.dart';
import '../../../../core/design/extensions/glass_context.dart';

/// Open-source attribution, on-design.
///
/// Replaces Flutter's built-in `showLicensePage`, which rendered badly here for two
/// reasons: it pushed onto the *shell's* navigator, so the shell's own app bar and
/// floating nav capsule stayed on top of it, and it builds a plain Material
/// `AppBar` that `LiquidGlassTheme` deliberately makes transparent — leaving its
/// title floating in a dead band with no surface behind it.
///
/// It is not optional. Flutter's engine and Dart ship under BSD-3, and most of the
/// packages here are MIT or BSD; all of those require the copyright notice be
/// reproduced in binary distributions. This screen is how the app satisfies that,
/// which is why it was redesigned rather than deleted.
///
/// The licence *text* still comes from [LicenseRegistry], the same source Flutter's
/// own page reads. Enumerating it by hand would risk silently omitting a package —
/// exactly the failure that would make the attribution incomplete.
class LicensesPage extends StatefulWidget {
  const LicensesPage({super.key});

  @override
  State<LicensesPage> createState() => _LicensesPageState();
}

class _LicensesPageState extends State<LicensesPage> {
  late final Future<List<_PackageLicenses>> _licenses = _collect();

  /// Groups every registered licence by package.
  ///
  /// One [LicenseEntry] can apply to several packages (a shared notice), so each is
  /// filed under all of them — which is why the counts add up to more than the
  /// number of entries.
  static Future<List<_PackageLicenses>> _collect() async {
    final byPackage = <String, List<LicenseEntry>>{};

    await for (final entry in LicenseRegistry.licenses) {
      for (final package in entry.packages) {
        byPackage.putIfAbsent(package, () => []).add(entry);
      }
    }

    final packages = byPackage.keys.toList()..sort(_byDisplayName);

    return [
      for (final package in packages)
        _PackageLicenses(name: package, entries: byPackage[package]!),
    ];
  }

  /// Alphabetical the way a reader expects, which is not what a raw string
  /// comparison gives.
  ///
  /// Two adjustments: case-insensitive, so `Flutter` and `args` interleave rather
  /// than all capitals coming first; and leading punctuation ignored, so
  /// `_fe_analyzer_shared` files under "f" instead of jumping to the top of the
  /// list. Flutter's built-in page does the latter and it reads like a glitch.
  static int _byDisplayName(String a, String b) {
    final byKey = _sortKey(a).compareTo(_sortKey(b));
    // Ties (`_foo` vs `foo`) fall back to the raw name so the order is stable.
    return byKey != 0 ? byKey : a.compareTo(b);
  }

  static final _leadingPunctuation = RegExp(r'^[^a-zA-Z0-9]+');

  static String _sortKey(String name) =>
      name.toLowerCase().replaceFirst(_leadingPunctuation, '');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = context.glassContentInsets;

    return Scaffold(
      appBar: const AdaptiveAppBar(title: 'Open source licences'),
      body: SafeArea(
        top: false,
        child: FutureBuilder<List<_PackageLicenses>>(
          future: _licenses,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AppLoader(message: 'Gathering licences…');
            }
            final packages = snapshot.data ?? const [];
            if (packages.isEmpty) {
              return const AppEmptyState(
                title: 'No licences registered',
                icon: Icons.description_outlined,
              );
            }

            return ListView.separated(
              padding: EdgeInsets.fromLTRB(
                16,
                12 + insets.top,
                16,
                24 + insets.bottom,
              ),
              itemCount: packages.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      'College Level 1.0.0 is built with the open source '
                      'packages below. Tap one to read its licence.',
                      style: theme.textTheme.bodySmall,
                    ),
                  );
                }

                final package = packages[index - 1];
                return AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => _LicenseDetailPage(package: package),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(package.name, style: theme.textTheme.titleSmall),
                            const SizedBox(height: 2),
                            Text(package.subtitle,
                                style: theme.textTheme.labelSmall),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: context.scheme.mutedForeground,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// One package's licence text.
class _LicenseDetailPage extends StatelessWidget {
  const _LicenseDetailPage({required this.package});

  final _PackageLicenses package;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final insets = context.glassContentInsets;

    return Scaffold(
      appBar: AdaptiveAppBar(title: package.name),
      body: SafeArea(
        top: false,
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            16,
            12 + insets.top,
            16,
            24 + insets.bottom,
          ),
          itemCount: package.entries.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) => AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final paragraph in package.entries[index].paragraphs)
                  Padding(
                    padding: EdgeInsets.only(
                      top: paragraph.indent == LicenseParagraph.centeredIndent
                          ? 12
                          : 8,
                      // The registry expresses structure as an indent level; each
                      // level is a nesting step, and centred text uses a sentinel.
                      left: paragraph.indent ==
                              LicenseParagraph.centeredIndent
                          ? 0
                          : paragraph.indent * 12.0,
                    ),
                    child: Text(
                      paragraph.text,
                      textAlign: paragraph.indent ==
                              LicenseParagraph.centeredIndent
                          ? TextAlign.center
                          : TextAlign.start,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

@immutable
class _PackageLicenses {
  const _PackageLicenses({required this.name, required this.entries});

  final String name;
  final List<LicenseEntry> entries;

  String get subtitle =>
      entries.length == 1 ? '1 licence' : '${entries.length} licences';
}
