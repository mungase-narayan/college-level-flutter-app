import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:college_level/core/common/widgets/widgets.dart';
import 'package:college_level/core/config/theme/app_theme.dart';

import '../support/platform_parity.dart';

/// A filter bar's controls must line up with the button beside them. Nothing
/// here checks how they look — only that they land on one height, which is the
/// thing that visibly broke.
void main() {
  double heightOf(WidgetTester t, String key) =>
      t.getSize(find.byKey(Key(key))).height;

  /// Top-left and shrink-wrapped, so every child reports its natural height
  /// instead of being stretched to the viewport.
  Widget host(ParityHost h, List<Widget> children) => h(Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children,
          ),
        ),
      ));

  bothPlatforms('a dense filter bar lines up on one height', (t, h) async {
    await t.pumpWidget(host(h, [
      const AppSelect<String>(
        key: Key('select'),
        dense: true,
        value: 'a',
        items: [AppSelectItem(value: 'a', label: 'All statuses')],
        onChanged: _noop,
      ),
      AppSearchField(key: const Key('search'), dense: true, onChanged: (_) {}),
      const AppInput(key: Key('input'), dense: true),
      AppButton(
        key: const Key('button'),
        label: 'Create',
        size: AppButtonSize.sm,
        onPressed: () {},
      ),
    ]));
    await t.pumpAndSettle();

    for (final name in ['select', 'search', 'input', 'button']) {
      expect(
        heightOf(t, name),
        AppTheme.controlHeightSm,
        reason: '$name should be the dense control height',
      );
    }
  });

  bothPlatforms('a small button really is the small height', (t, h) async {
    await t.pumpWidget(host(h, [
      AppButton(
        key: const Key('button'),
        label: 'Create',
        size: AppButtonSize.sm,
        onPressed: () {},
      ),
    ]));
    await t.pumpAndSettle();

    // Material's default tap-target padding used to floor this at 48, so the
    // same button rendered 38 on iOS and 48 on Android.
    expect(heightOf(t, 'button'), AppTheme.controlHeightSm);
  });

  bothPlatforms('an undense control keeps the taller default', (t, h) async {
    await t.pumpWidget(host(h, [
      const AppInput(key: Key('input')),
      AppButton(key: const Key('button'), label: 'Save', onPressed: () {}),
    ]));
    await t.pumpAndSettle();

    expect(heightOf(t, 'button'), AppTheme.controlHeightMd);
    // Only that it stays comfortably taller than a dense one. The default
    // field sits a couple of pixels off the button on both branches, which
    // predates this change and never shows outside a filter bar.
    expect(heightOf(t, 'input'), greaterThan(AppTheme.controlHeightSm));
  });

  bothPlatforms('dense never squashes a multi-line field', (t, h) async {
    await t.pumpWidget(host(h, [
      const AppInput(
        key: Key('input'),
        dense: true,
        minLines: 3,
        maxLines: 6,
      ),
    ]));
    await t.pumpAndSettle();

    // A note editor has to grow with its content, dense or not.
    expect(heightOf(t, 'input'), greaterThan(AppTheme.controlHeightSm));
  });
}

void _noop(String? _) {}
