import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:queueb_client/src/admin_dashboard.dart';
import 'package:queueb_client/src/admin_navigation.dart';
import 'package:queueb_client/src/admin_ui.dart';
import 'package:queueb_client/src/config.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  final fontRoot = Platform.environment['QUEUEB_ADMIN_PREVIEW_FONTS'];
  if (fontRoot != null) {
    setUpAll(() async {
      final text = FontLoader('AdminPreview');
      for (final name in [
        'roboto-regular.ttf',
        'roboto-medium.ttf',
        'roboto-bold.ttf',
      ]) {
        text.addFont(
          File('$fontRoot/$name').readAsBytes().then(ByteData.sublistView),
        );
      }
      await text.load();
      await (FontLoader('MaterialIcons')..addFont(
            File('$fontRoot/materialicons-regular.otf')
                .readAsBytes()
                .then(ByteData.sublistView),
          ))
          .load();
    });
  }
  final config = AppConfig(apiBaseUrl: 'http://localhost/api/v1');
  final clinics = <Json>[
    {'id': 'a', 'kode': 'APOTEK', 'nama': 'Apotek', 'aktif': true},
    {'id': 'b', 'kode': 'DAFTAR', 'nama': 'Pendaftaran', 'aktif': true},
    {'id': 'c', 'kode': 'GIGI', 'nama': 'Poli Gigi', 'aktif': true},
    {'id': 'd', 'kode': 'UMUM', 'nama': 'Poli Umum', 'aktif': true},
  ];
  final catalog = <String, List<Json>>{
    '/layanan': clinics,
    '/dokter': [
      {
        'id': 'doctor',
        'aktif': true,
        'dokterLayanan': [
          {'layananId': 'c', 'aktif': true},
        ],
      },
    ],
    '/loket': [
      for (final clinic in clinics) {'layananId': clinic['id'], 'aktif': true},
    ],
    '/jadwal-praktik': [
      {
        'id': 'session',
        'aktif': true,
        'dokterLayanan': {'layananId': 'c'},
      },
    ],
  };
  for (final size in [
    const Size(320, 568),
    const Size(360, 800),
    const Size(390, 844),
    const Size(412, 915),
    const Size(768, 1024),
    const Size(1280, 720),
    const Size(1366, 768),
    const Size(1440, 900),
    const Size(1920, 1080),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Admin modern hierarchy fits $size at scale $scale', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var setup = 0, destination = -1;
        final boundary = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            theme: fontRoot == null
                ? AdminStyle.theme
                : AdminStyle.theme.copyWith(
                    filledButtonTheme: FilledButtonThemeData(
                      style: AdminStyle.theme.filledButtonTheme.style?.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(
                            fontFamily: 'AdminPreview',
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    textButtonTheme: TextButtonThemeData(
                      style: AdminStyle.theme.textButtonTheme.style?.copyWith(
                        textStyle: const WidgetStatePropertyAll(
                          TextStyle(fontFamily: 'AdminPreview', fontSize: 13),
                        ),
                      ),
                    ),
                    textTheme: AdminStyle.theme.textTheme.apply(
                      fontFamily: 'AdminPreview',
                    ),
                  ),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(
                body: RepaintBoundary(
                  key: boundary,
                  child: Material(
                    color: AdminStyle.canvas,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (size.width >= 960) ...[
                          SizedBox(
                            width: 232,
                            child: Material(
                              color: Colors.white,
                              child: AdminNavigation(
                                selected: -1,
                                onSelect: (v) => destination = v,
                              ),
                            ),
                          ),
                          const VerticalDivider(width: 1),
                        ],
                        Expanded(
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: EdgeInsets.all(
                                size.width < 360 ? 12 : 24,
                              ),
                              child: AdminDashboard(
                                catalog: catalog,
                                config: config,
                                loading: false,
                                onSelect: (v) => destination = v,
                                administratorName: 'Administrator QA',
                                onSetup: () => setup++,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.textContaining('Administrator QA!'), findsOneWidget);
        await tester.ensureVisible(find.text('Kelola Layanan Terpadu'));
        await tester.tap(find.text('Kelola Layanan Terpadu'));
        expect(setup, 1);
        await tester.ensureVisible(find.text('Kelola'));
        await tester.tap(find.text('Kelola'));
        expect(destination, 0);
        expect(tester.takeException(), isNull);
        if (fontRoot != null &&
            scale == 1 &&
            (size.width == 1366 || size.width == 390)) {
          await tester.drag(
            find.byType(SingleChildScrollView).first,
            const Offset(0, 2000),
          );
          await tester.pumpAndSettle();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            try {
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final folder = Directory('build/admin-modern-preview')
                ..createSync(recursive: true);
              File('${folder.path}/dashboard-${size.width.toInt()}.png')
                  .writeAsBytesSync(bytes!.buffer.asUint8List());
            } finally {
              image.dispose();
            }
          });
        }
      });
    }
  }
  testWidgets(
    'Dashboard table keeps access to services beyond the first page',
    (tester) async {
      final many = {
        ...catalog,
        '/layanan': [
          for (var i = 0; i < 17; i++)
            {
              'id': 'service-$i',
              'nama': 'Layanan ${i.toString().padLeft(2, '0')}',
              'aktif': true,
            },
        ],
      };
      await tester.pumpWidget(
        MaterialApp(
          theme: AdminStyle.theme,
          home: Scaffold(
            body: SingleChildScrollView(
              child: AdminDashboard(
                catalog: many,
                config: config,
                loading: false,
                onSelect: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Layanan 00'), findsOneWidget);
      final last = find.byTooltip('Halaman terakhir');
      await tester.ensureVisible(last);
      await tester.tap(last);
      await tester.pumpAndSettle();
      expect(find.text('Layanan 16'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
