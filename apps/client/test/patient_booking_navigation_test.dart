import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueb_client/src/patient_navigation.dart';
import 'package:queueb_client/src/patient_reservations.dart';

void main() {
  test('duplicate catalog URLs return to Reservasi', () {
    for (final uri in [
      Uri.parse('/patient/reservations/new'),
      Uri.parse('/patient/reservations/new?mode=clinics'),
      Uri.parse('/patient/reservations/new?mode=legacy'),
    ]) {
      expect(patientBookingRedirect(uri), '/patient/reservations');
    }
  });

  test('service, doctor search and nearest URLs remain accessible', () {
    for (final uri in [
      Uri.parse('/patient/reservations/new?clinic=example-id'),
      Uri.parse('/patient/reservations/new?mode=doctors'),
      Uri.parse('/patient/reservations/new?mode=nearest'),
    ]) {
      expect(patientBookingRedirect(uri), isNull);
    }
  });

  testWidgets('Buat Reservasi offers only doctor and nearest routes', (
    tester,
  ) async {
    String? method;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                method = await chooseReservationMethod(context);
              },
              child: const Text('Buat Reservasi'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buat Reservasi'));
    await tester.pumpAndSettle();
    expect(find.text('Cari Dokter'), findsOneWidget);
    expect(find.text('Jadwal Terdekat'), findsOneWidget);
    expect(find.text('Pilih Poliklinik'), findsNothing);
    await tester.tap(find.text('Cari Dokter'));
    await tester.pumpAndSettle();
    expect(method, 'doctors');
  });
}
