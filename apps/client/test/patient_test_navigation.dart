import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:queueb_client/src/patient.dart';
import 'package:queueb_client/src/features/patient/application/patient_overview_cubit.dart';

/// Exercise the retained ticket deep link, which is no longer a bottom item.
/// Use the router rather than manipulating the feature's state or controllers.
Future<void> openPatientTickets(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(NavigationBar)))
      .go('/patient/tickets');
  await tester.pumpAndSettle();
}

Future<void> openPatientAgenda(WidgetTester tester) async {
  GoRouter.of(tester.element(find.byType(NavigationBar)))
      .go('/patient/appointments');
  await tester.pumpAndSettle();
}

/// Exercise a supported clinic deep link using the current server catalog.
/// The retired duplicate catalog is no longer a public navigation destination.
Future<void> openPatientCatalog(
  WidgetTester tester, {
  bool walkIn = false,
}) async {
  final context = tester.element(find.byType(PatientBranchView).first);
  final services = context.read<PatientOverviewCubit>().state.snapshot.services;
  final clinic = services.firstWhere(
    (s) =>
        s['aktif'] != false &&
        (!walkIn ||
            const {'ANTREAN_HARIAN', 'HIBRIDA'}.contains(s['modeReservasi'])),
  );
  GoRouter.of(context).go(
    Uri(
      path: '/patient/reservations/new',
      queryParameters: {'clinic': clinic['id'] as String},
    ).toString(),
  );
  await tester.pumpAndSettle();
  if (walkIn && find.text('Walk-in').evaluate().isNotEmpty) {
    await tester.tap(find.text('Walk-in'));
    await tester.pumpAndSettle();
  }
}
