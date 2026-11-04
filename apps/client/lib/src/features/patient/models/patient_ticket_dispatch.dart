import '../../../api.dart';
import '../../../config.dart';
import 'patient_queue_models.dart';

/// Explicit owned-ticket projection. Extra response fields are not retained.
class PatientTicketDispatch {
  PatientTicketDispatch({
    required this.ticketId,
    required this.status,
    required this.date,
    required this.serviceId,
    required this.serviceCode,
    required this.serviceName,
    required this.reservationMode,
    required this.observedAt,
    required this.checkedInAt,
    required Json? destination,
    required this.position,
    required this.ahead,
    required this.reason,
    required List<PatientServingNumber> serving,
  }) : destination = destination == null ? null : Map.unmodifiable(destination),
       serving = List.unmodifiable(serving);

  final String ticketId, status, date;
  final String serviceId, serviceCode, serviceName, reservationMode;
  final DateTime observedAt;
  final DateTime? checkedInAt;
  final Json? destination;
  final int? position, ahead;
  final String? reason;
  final List<PatientServingNumber> serving;

  bool matches(Json ticket) =>
      ticket['id'] == ticketId &&
      ticket['status'] == status &&
      dateOnly(ticket['tanggalPelayanan'] ?? ticket['tanggalAntrean']) ==
          date &&
      (object(ticket['layanan'])['id'] ?? ticket['layananId']) == serviceId;

  bool freshAt(DateTime now) {
    final age = now.difference(observedAt);
    return age >= const Duration(seconds: -30) &&
        age <= const Duration(minutes: 3);
  }

  static PatientTicketDispatch parse(Object? raw, String ticketId) {
    Never invalid() =>
        throw const ApiException(0, 'Status antrean belum terverifikasi.');
    String text(Object? value) {
      if (value is! String || value.trim().isEmpty) invalid();
      return value;
    }

    DateTime instant(Object? value) {
      final parsed = value is String && value.contains('T')
          ? DateTime.tryParse(value)
          : null;
      if (parsed == null || !parsed.isUtc) invalid();
      return parsed;
    }

    int? count(Object? value) {
      if (value == null) return null;
      if (value is! int || value < 0) invalid();
      return value;
    }

    if (raw is! Map || raw['versiSkema'] != 1 || raw['tiketId'] != ticketId) {
      invalid();
    }
    for (final key in const [
      'checkInPada',
      'loketTujuan',
      'posisiAntrean',
      'jumlahDiDepan',
      'alasanPosisi',
      'sedangDilayani',
    ]) {
      if (!raw.containsKey(key)) invalid();
    }
    final date = text(raw['tanggalPelayanan']);
    final status = text(raw['status']);
    if (!validPatientQueueDate(date) ||
        !const {
          'DIPESAN',
          'CHECK_IN',
          'MENUNGGU',
          'DIPANGGIL',
          'DILAYANI',
          'DILEWATI',
          'SELESAI',
          'DIBATALKAN',
        }.contains(status)) {
      invalid();
    }
    final service = raw['layanan'];
    if (service is! Map) invalid();
    final checkedInAt = raw['checkInPada'] == null
        ? null
        : instant(raw['checkInPada']);
    final position = count(raw['posisiAntrean']);
    final ahead = count(raw['jumlahDiDepan']);
    final reason = raw['alasanPosisi'] == null
        ? null
        : text(raw['alasanPosisi']);
    if ((position == null) != (ahead == null) ||
        (position != null &&
            (position < 1 ||
                ahead != position - 1 ||
                status != 'MENUNGGU' ||
                checkedInAt == null ||
                reason != null))) {
      invalid();
    }
    Json? destination;
    if (raw['loketTujuan'] case final Map room) {
      destination = {
        'id': text(room['id']),
        'kode': text(room['kode']),
        'nama': text(room['nama']),
      };
    } else if (raw['loketTujuan'] != null) {
      invalid();
    }
    final active = raw['sedangDilayani'];
    if (active is! List) invalid();
    final serving = <PatientServingNumber>[];
    final seen = <(String, String)>{};
    for (final item in active) {
      if (item is! Map) invalid();
      final room = text(item['loketId']);
      final number = text(item['nomorAntrean']);
      if (!seen.add((room, number))) invalid();
      serving.add(PatientServingNumber(room, text(item['kodeLoket']), number));
    }
    return PatientTicketDispatch(
      ticketId: ticketId,
      status: status,
      date: date,
      serviceId: text(service['id']),
      serviceCode: text(service['kode']),
      serviceName: text(service['nama']),
      reservationMode: text(service['modeReservasi']),
      observedAt: instant(raw['diperolehPada']),
      checkedInAt: checkedInAt,
      destination: destination,
      position: position,
      ahead: ahead,
      reason: reason,
      serving: serving,
    );
  }
}
