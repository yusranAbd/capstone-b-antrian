import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'config.dart';

String reportMinutes(Object? seconds) =>
    seconds is num && seconds.isFinite && seconds >= 0
    ? (seconds / 60).toStringAsFixed(2)
    : '—';
const reportStatusColumns = {
  'totalTiket': 'Tiket',
  'pasienUnik': 'Pasien unik',
  'dipesan': 'Dipesan',
  'checkIn': 'Check-in',
  'menunggu': 'Menunggu',
  'dipanggil': 'Dipanggil',
  'dilayani': 'Dilayani',
  'selesai': 'Selesai',
  'dibatalkan': 'Dibatalkan',
  'dilewati': 'Dilewati',
};
bool get reportCsvSupported =>
    kIsWeb ||
    const {
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    }.contains(defaultTargetPlatform);
String _filename(Json report, String extension) {
  final period = object(report['periode']);
  String safe(Object? v) => '$v'.replaceAll(RegExp('[^a-zA-Z0-9_-]'), '_');
  return 'QueueB_Laporan_${safe(period['mulai'])}_${safe(period['selesai'])}.$extension';
}

/// Quote every string and neutralize spreadsheet formula prefixes, including whitespace.
String reportCsvCell(Object? value) {
  if (value is num) return value.isFinite ? '$value' : '';
  var text = value == null ? '' : '$value';
  if (RegExp(r'^[\s\x00-\x1F]*[=+@\-]').hasMatch(text) ||
      text.startsWith('\t') ||
      text.startsWith('\r')) {
    text = "'$text";
  }
  return '"${text.replaceAll('"', '""')}"';
}

Uint8List operationalReportCsv(Json report) {
  final period = object(report['periode']);
  final header = [
    'Periode mulai',
    'Periode selesai',
    'Diperoleh pada',
    'Zona waktu',
    'Tanggal',
    'Kode layanan',
    'Layanan',
    ...reportStatusColumns.values,
    'Sampel tunggu',
    'Rata-rata tunggu (menit)',
    'Sampel pelayanan',
    'Rata-rata pelayanan (menit)',
  ];
  final all = [
    ...rows(report['baris']),
    {
      ...object(report['ringkasan']),
      'tanggal': 'TOTAL PERIODE',
      'namaLayanan': 'Ringkasan filter',
    },
  ];
  final lines = [
    header.map(reportCsvCell).join(','),
    for (final row in all)
      [
        period['mulai'],
        period['selesai'],
        report['diperolehPada'],
        period['zonaWaktu'],
        row['tanggal'],
        row['kodeLayanan'],
        row['namaLayanan'],
        for (final key in reportStatusColumns.keys) row[key],
        row['sampelTunggu'],
        reportMinutes(row['rataTungguDetik']),
        row['sampelPelayanan'],
        reportMinutes(row['rataPelayananDetik']),
      ].map(reportCsvCell).join(','),
  ];
  return Uint8List.fromList(utf8.encode('\uFEFF${lines.join('\r\n')}\r\n'));
}

Future<bool> saveOperationalCsv(Json report, {bool Function()? current}) async {
  if (current?.call() == false) return false;
  if (!reportCsvSupported) {
    throw UnsupportedError('Ekspor CSV tersedia pada Web dan desktop.');
  }
  final name = _filename(report, 'csv');
  final file = XFile.fromData(
    operationalReportCsv(report),
    mimeType: 'text/csv',
    name: name,
  );
  if (kIsWeb) {
    await file.saveTo(name);
    return true;
  }
  final target = await getSaveLocation(
    suggestedName: name,
    acceptedTypeGroups: [
      const XTypeGroup(label: 'CSV', extensions: ['csv']),
    ],
  );
  if (target == null) return false;
  if (current?.call() == false) return false;
  await file.saveTo(target.path);
  return true;
}

Future<Uint8List> operationalReportPdf(Json report) async {
  final data = rows(report['baris']),
      summary = object(report['ringkasan']),
      period = object(report['periode']);
  if (data.length > 500) {
    throw const FormatException(
      'Persempit filter hingga maksimal 500 baris untuk PDF; CSV dapat memuat seluruh laporan.',
    );
  }
  final document = pw.Document(
    title: 'Laporan Operasional QueueB Hospital',
    author: 'QueueB Hospital',
  );
  String value(Object? v) => v == null ? '-' : '$v';
  pw.Widget table(List<String> headers, List<List<String>> values) =>
      pw.TableHelper.fromTextArray(
        headers: headers,
        data: values,
        headerDecoration: const pw.BoxDecoration(color: PdfColors.blue50),
        headerStyle: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 7),
        cellPadding: const pw.EdgeInsets.all(4),
      );
  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
      maxPages: 100,
      margin: const pw.EdgeInsets.all(24),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'QueueB Hospital | ${context.pageNumber}/${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ),
      build: (_) => [
        pw.Text(
          'QueueB Hospital - Laporan Operasional',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          '${period['mulai']} s.d. ${period['selesai']} | ${period['zonaWaktu']} | Layanan: ${period['layananId'] == null ? 'Semua' : data.firstOrNull?['namaLayanan'] ?? 'Filter layanan'}',
        ),
        pw.Text(
          'Diperoleh: ${report['diperolehPada']}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 12),
        table(reportStatusColumns.values.toList(), [
          [for (final key in reportStatusColumns.keys) value(summary[key])],
        ]),
        pw.SizedBox(height: 10),
        pw.Text(
          'Status merupakan kondisi tiket saat laporan diambil. Pasien unik periode dihitung langsung, bukan dijumlahkan antarhari/layanan. Tunggu: check-in sampai pelayanan dimulai. Pelayanan: mulai sampai selesai. Hanya timestamp lengkap dan durasi nonnegatif dihitung. Tanda - berarti tidak ada sampel.',
          style: const pw.TextStyle(fontSize: 8),
        ),
        pw.SizedBox(height: 10),
        table(
          ['Ringkasan durasi', 'Rata-rata (menit)', 'Sampel'],
          [
            [
              'Tunggu',
              reportMinutes(summary['rataTungguDetik']).replaceAll('—', '-'),
              value(summary['sampelTunggu']),
            ],
            [
              'Pelayanan',
              reportMinutes(summary['rataPelayananDetik']).replaceAll('—', '-'),
              value(summary['sampelPelayanan']),
            ],
          ],
        ),
        pw.SizedBox(height: 12),
        if (data.isEmpty)
          pw.Text('Tidak ada tiket pada periode/filter ini.')
        else ...[
          pw.Text('Status per tanggal dan layanan'),
          table(
            ['Tanggal', 'Layanan', ...reportStatusColumns.values],
            [
              for (final row in data)
                [
                  value(row['tanggal']),
                  value(row['namaLayanan']),
                  for (final key in reportStatusColumns.keys) value(row[key]),
                ],
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Text('Durasi per tanggal dan layanan'),
          table(
            [
              'Tanggal',
              'Layanan',
              'Tunggu (menit)',
              'Sampel tunggu',
              'Pelayanan (menit)',
              'Sampel pelayanan',
            ],
            [
              for (final row in data)
                [
                  value(row['tanggal']),
                  value(row['namaLayanan']),
                  reportMinutes(row['rataTungguDetik']).replaceAll('—', '-'),
                  value(row['sampelTunggu']),
                  reportMinutes(row['rataPelayananDetik']).replaceAll('—', '-'),
                  value(row['sampelPelayanan']),
                ],
            ],
          ),
        ],
      ],
    ),
  );
  return document.save();
}

Future<bool> shareOperationalPdf(
  Json report, {
  bool Function()? current,
}) async {
  final bytes = await operationalReportPdf(report);
  if (current?.call() == false) return false;
  return Printing.sharePdf(bytes: bytes, filename: _filename(report, 'pdf'));
}
