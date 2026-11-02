import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void expectUnknownMasterMetrics(List<String> paths) {
  for (final path in paths) {
    final metric = find.byKey(ValueKey('admin-metric-$path'));
    expect(metric, findsOneWidget);
    expect(find.descendant(of: metric, matching: find.text('—')), findsWidgets);
    expect(find.descendant(of: metric, matching: find.text('0')), findsNothing);
    expect(
      find.descendant(of: metric, matching: find.text('0 aktif')),
      findsNothing,
    );
  }
}
