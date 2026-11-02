import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Finder operationalProfileButton() => find.byWidgetPredicate(
  (widget) =>
      widget is Tooltip && widget.message?.startsWith('Buka profil ') == true,
);

Future<void> logoutOperationalPortal(WidgetTester tester) async {
  final profile = operationalProfileButton();
  expect(profile, findsOneWidget);
  await tester.ensureVisible(profile);
  await tester.tap(profile);
  await tester.pumpAndSettle();
  final logout = find.text('Keluar Akun');
  expect(logout, findsOneWidget);
  await tester.ensureVisible(logout);
  await tester.tap(logout);
  await tester.pumpAndSettle();
}

Future<void> dismissFeedback(WidgetTester tester) async {
  final close = find.byTooltip('Tutup pemberitahuan');
  if (close.evaluate().isNotEmpty) {
    await tester.tap(close);
    await tester.pumpAndSettle();
  } else if (find.byType(Scaffold).evaluate().isNotEmpty) {
    ScaffoldMessenger.maybeOf(tester.element(find.byType(Scaffold).first))
        ?.hideCurrentSnackBar();
    await tester.pumpAndSettle();
  }
}

Future<void> selectStaffQueueTab(WidgetTester tester, String title) async {
  final tab = find.textContaining(RegExp('^${RegExp.escape(title)} \\('));
  await tester.ensureVisible(tab);
  await tester.tap(tab);
  await tester.pumpAndSettle();
}
