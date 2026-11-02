import 'config.dart';

const serviceCategoryLabels = {
  'POLIKLINIK': 'Poliklinik',
  'PENDAFTARAN': 'Pendaftaran',
  'APOTEK': 'Apotek',
  'LABORATORIUM': 'Laboratorium',
  'RADIOLOGI': 'Radiologi',
  'KASIR': 'Kasir',
  'REKAM_MEDIS': 'Rekam medis',
  'LAINNYA': 'Layanan lainnya',
};

/// Explicit API category wins, even when the service code is renamed.
/// Code inference is only for responses from a backend predating the field.
String serviceCategory(Json service) {
  final category = '${service['kategori'] ?? ''}'.trim().toUpperCase();
  if (category.isNotEmpty) return category;
  return switch ('${service['kode'] ?? ''}'.trim().toUpperCase()) {
    'PENDAFTARAN' ||
    'DAFTAR' ||
    'REGISTRASI' ||
    'ADMINISTRASI' => 'PENDAFTARAN',
    'APOTEK' || 'APOTIK' => 'APOTEK',
    'LABORATORIUM' => 'LABORATORIUM',
    'RADIOLOGI' => 'RADIOLOGI',
    'KASIR' => 'KASIR',
    'REKAM_MEDIS' => 'REKAM_MEDIS',
    _ => 'POLIKLINIK',
  };
}

String serviceCategoryLabel(Json service) =>
    serviceCategoryLabels[serviceCategory(service)] ??
    'Kategori belum dikenali';
