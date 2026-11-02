import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueb_client/src/config.dart';
import 'package:queueb_client/src/doctor_dashboard.dart';
import 'package:queueb_client/src/doctor_visual.dart';
import 'package:queueb_client/src/doctor_professional.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  tz.initializeTimeZones();
  final config = AppConfig(
    apiBaseUrl: 'http://qa.invalid/api/v1',
    realtime: false,
  );
  for (final width in [
    320.0,
    375.0,
    414.0,
    768.0,
    1024.0,
    1200.0,
    1366.0,
    1440.0,
  ]) {
    testWidgets(
      'Doctor composition at $width keeps all panels and unavailable queue count',
      (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final status = ValueNotifier('Menghubungkan realtime');
        addTearDown(status.dispose);
        var refreshes = 0, dates = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: DoctorStyle.theme,
            home: Scaffold(
              body: DoctorDashboard(
                config: config,
                date: config.today,
                profile: const {
                  'nama': 'Dokter Pengujian',
                  'spesialisasi': 'Penyakit Dalam',
                },
                schedules: const [],
                appointments: const [],
                snapshots: const [],
                loading: false,
                available: true,
                status: status,
                onRefresh: () async {
                  refreshes++;
                },
                onPickDate: () {
                  dates++;
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProfessionalDoctorAvatar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(Drawer), findsNothing);
        expect(find.text('Menunggu (0)'), findsOneWidget);
        expect(find.text('Semua (0)'), findsOneWidget);
        await tester.tap(find.byTooltip('Muat ulang portal dokter'));
        await tester.tap(find.byKey(const ValueKey('doctor-date-picker')));
        expect(refreshes, 1);
        expect(dates, 1);
        if (width >= 1200) {
          final queue = tester.getTopLeft(find.byType(DoctorQueuePanel));
          final live = tester.getTopLeft(find.byType(DoctorLivePanel));
          expect(live.dy, closeTo(queue.dy, 1));
          expect(live.dx, greaterThan(queue.dx));
          final profile = tester.getTopLeft(
            find.byType(ProfessionalDoctorAvatar),
          );
          expect(queue.dy, greaterThan(profile.dy));
        }
        await tester.scrollUntilVisible(
          find.text('Belum ada antrean yang sesuai.'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Belum ada antrean yang sesuai.'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Antrean Aktif'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        status.value = 'Realtime terputus';
        await tester.pumpAndSettle();
        expect(find.byTooltip('Realtime terputus'), findsWidgets);
        status.value = 'Realtime terhubung';
        await tester.pumpAndSettle();
        expect(find.byTooltip('Realtime terhubung'), findsWidgets);
        await tester.scrollUntilVisible(
          find.text('Jadwal Praktik Hari Ini'),
          250,
          scrollable: find.byType(Scrollable).first,
        );
        expect(
          find.text('Tidak ada jadwal pada tanggal pilihan.'),
          findsOneWidget,
        );
        expect(find.text('Catatan Klinis Dokter'), findsNothing);
        expect(find.text('Mulai Konsultasi'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'Compact empty laptop dashboard reveals lower sections without scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(1366, 768);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final status = ValueNotifier('Realtime terhubung');
      addTearDown(status.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: DoctorStyle.theme,
          home: Scaffold(
            appBar: AppBar(
              toolbarHeight: 64,
              title: const Text('QueueB Hospital'),
            ),
            body: DoctorDashboard(
              config: config,
              date: config.today,
              profile: const {
                'nama': 'Dokter Pengujian',
                'spesialisasi': 'Penyakit Dalam',
                'poliklinik': [
                  {'nama': 'Poli Penyakit Dalam'},
                ],
              },
              schedules: const [],
              appointments: const [],
              snapshots: const [],
              loading: false,
              available: true,
              status: status,
              onRefresh: () async {},
              onPickDate: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getBottomLeft(find.byType(DoctorQueuePanel)).dy,
        lessThanOrEqualTo(768),
      );
      expect(
        tester.getSize(find.byType(DoctorLivePanel)).height,
        lessThan(360),
      );
      expect(
        tester.getTopLeft(find.text('Jadwal Praktik Hari Ini')).dy,
        lessThan(768),
      );
      expect(
        tester
            .widget<ProfessionalDoctorAvatar>(
              find.byType(ProfessionalDoctorAvatar),
            )
            .radius,
        20,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Generic avatar provides a local fallback when image is unavailable',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: DoctorAvatar(asset: 'missing-qa-avatar.png')),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.medical_services_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
