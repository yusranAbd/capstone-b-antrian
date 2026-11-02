import 'dart:convert';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:queueb_client/src/api.dart';
import 'package:queueb_client/src/app.dart';
import 'package:queueb_client/src/config.dart';
import 'package:queueb_client/src/admin.dart';
import 'package:queueb_client/src/admin_ui.dart';
import 'package:queueb_client/src/admin_service_setup.dart';
import 'package:queueb_client/src/features/admin/data/admin_catalog_repository.dart';
import 'package:queueb_client/src/features/patient/application/patient_booking_cubit.dart';
import 'package:queueb_client/src/patient_ui.dart';
import 'package:queueb_client/src/patient_reservations.dart';

import 'patient_reservations_test.dart' show ReservationBackend;
import 'admin_slot_cubit_test.dart' show SlotFixture;

void main() {
  setUpAll(tz.initializeTimeZones);
  Future<AdminCatalogRepository> repo() async {
    final api =
        QueueApi(
            config: AppConfig(
              apiBaseUrl: 'http://localhost/api/v1',
              realtime: false,
            ),
            client: MockClient(
              (r) async => http.Response(
                jsonEncode(
                  r.url.path.endsWith('/layanan')
                      ? [
                          {
                            'id': 'service',
                            'nama': 'Layanan',
                            'kode': 'S',
                            'aktif': true,
                          },
                        ]
                      : r.url.path.endsWith('/dokter')
                      ? [
                          for (var i = 0; i < 13; i++)
                            {
                              'id': 'd-$i',
                              'nama': 'Dokter $i',
                              'aktif': true,
                              'dokterLayanan': [],
                            },
                        ]
                      : r.url.path.endsWith('/jadwal-praktik')
                      ? [
                          for (var i = 0; i < 13; i++)
                            {
                              'id': 'p-$i',
                              'tanggal': '2026-11-03',
                              'aktif': true,
                              'dokterLayanan': {'layananId': 'service'},
                              'loket': {'nama': 'Ruang $i'},
                            },
                        ]
                      : [],
                ),
                200,
              ),
            ),
          )
          ..accessToken = 'test'
          ..user = {'id': 'admin', 'peran': 'ADMIN'};
    final repo = AdminCatalogRepository(api);
    addTearDown(() {
      repo.dispose();
      api.dispose();
    });
    await repo.refresh(['/layanan', '/dokter', '/jadwal-praktik']);
    return repo;
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('service setup retains controls at 320px scale $scale', (
      t,
    ) async {
      t.view.physicalSize = const Size(320, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final r = (await t.runAsync(repo))!;
      await t.pumpWidget(
        MaterialApp(
          theme: AdminStyle.theme,
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: AdminServiceSetup(
                repository: r,
                onAction: (_, _, _) async {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      for (final text in ['Tutup', 'Sebelumnya', 'Selanjutnya']) {
        expect(t.getRect(find.text(text).last).right, lessThanOrEqualTo(320));
      }
    });
  }
  testWidgets('service setup reaches every doctor and practice session', (
    t,
  ) async {
    final r = (await t.runAsync(repo))!;
    await t.pumpWidget(
      MaterialApp(
        theme: AdminStyle.theme,
        home: Scaffold(
          body: AdminServiceSetup(repository: r, onAction: (_, _, _) async {}),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>));
    await t.pumpAndSettle();
    await t.tap(find.text('Layanan · S').last);
    await t.pumpAndSettle();
    await t.tap(find.text('3. Dokter'));
    await t.pumpAndSettle();
    expect(find.text('Dokter 12'), findsOneWidget);
    await t.tap(find.text('4. Jadwal & Slot'));
    await t.pumpAndSettle();
    expect(find.text('Ruang: Ruang 12'), findsOneWidget);
    expect(find.text('Tambah slot'), findsNWidgets(13));
  });
  testWidgets('home mouse swipe retains controller and selected tab', (
    t,
  ) async {
    bool selected = true;
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => PatientNativeHomeTabs(
              walkInSelected: selected,
              onChanged: (v) => setState(() => selected = v),
              headerSlivers: const [],
              walkInSlivers: const [
                SliverToBoxAdapter(
                  child: SizedBox(height: 800, child: Text('Walk-in')),
                ),
              ],
              appointmentSlivers: const [
                SliverToBoxAdapter(
                  child: SizedBox(height: 800, child: Text('Appointments')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    final controller = t.widget<TabBar>(find.byType(TabBar)).controller;
    final g = await t.startGesture(
      t.getCenter(find.byType(TabBarView)),
      kind: PointerDeviceKind.mouse,
    );
    await g.moveBy(const Offset(-500, 0));
    await g.up();
    await t.pumpAndSettle();
    expect(selected, isFalse);
    expect(t.widget<TabBar>(find.byType(TabBar)).controller, same(controller));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'nearest reloads after return and follows subsequent slot changes',
    (t) async {
      t.view.physicalSize = const Size(900, 1100);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final b = ReservationBackend();
      final api =
          QueueApi(
              config: AppConfig(
                apiBaseUrl: 'http://localhost/api/v1',
                realtime: false,
              ),
              client: MockClient(b.handle),
            )
            ..accessToken = 'test'
            ..user = b.user;
      addTearDown(api.dispose);
      await t.pumpWidget(QueueBApp(api: api));
      await t.pumpAndSettle();
      await t.tap(find.widgetWithText(NavigationDestination, 'Reservasi'));
      await t.pumpAndSettle();
      await t.tap(find.byType(FloatingActionButton));
      await t.pumpAndSettle();
      await t.tap(find.text('Jadwal Terdekat'));
      await t.pumpAndSettle();
      expect(find.byType(ReservationDoctorChoice), findsOneWidget);
      await t.tap(find.text('Pilih Jadwal'));
      await t.pumpAndSettle();
      final cubit = t
          .element(find.byType(PatientHeading).last)
          .read<PatientBookingCubit>();
      await t.ensureVisible(find.byTooltip('Kembali').last);
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Kembali').last);
      await t.pumpAndSettle();
      expect(find.text('Jadwal Terdekat'), findsOneWidget);
      expect(cubit.state.values['nearestActive'], isTrue);
      b.slotsAvailable = false;
      await t.runAsync(cubit.refreshSelection);
      await t.pumpAndSettle();
      expect(find.byType(ReservationDoctorChoice), findsNothing);
      expect(b.requests.where((r) => r.$1 == 'POST'), isEmpty);
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('wizard slot save uses the session selected by the form', (
    t,
  ) async {
    final f = SlotFixture();
    addTearDown(f.dispose);
    await t.pumpWidget(
      MaterialApp(
        theme: AdminStyle.theme,
        home: Scaffold(body: AdminPage(api: f.api)),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Kelola Layanan Terpadu'));
    await t.pumpAndSettle();
    final setup = t.widget<AdminServiceSetup>(find.byType(AdminServiceSetup));
    final operation = setup.onAction(AdminSetupAction.addSlot, 'clinic', 'a');
    await t.pumpAndSettle();
    final form = t.widget(
      find.byWidgetPredicate((w) => w.runtimeType.toString() == '_AdminEditor'),
    ) as dynamic;
    await t.runAsync(() async {
      await form.onSave(<String, dynamic>{
        'jadwalPraktikId': 'b',
        'mulaiPada': '2026-10-28T17:15:00Z',
        'selesaiPada': '2026-10-28T17:30:00Z',
        'kapasitas': 2,
      });
    });
    expect(f.data['b'], hasLength(2));
    expect(f.data['a'], hasLength(1));
    expect(f.reads['b'], 1);
    expect(f.reads['a'], isNull);
    await t.tap(find.text('Kembali').last);
    await t.pumpAndSettle();
    await operation;
    await t.pumpWidget(const SizedBox());
  });
}
