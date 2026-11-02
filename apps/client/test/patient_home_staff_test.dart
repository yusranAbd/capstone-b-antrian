import 'package:flutter_test/flutter_test.dart';
import 'package:queueb_client/src/patient_home_v8.dart';

void main() {
  final services = <Map<String, dynamic>>[
    {'id': 'apotek-link', 'aktif': true, 'layananId': 'apotek'},
  ];
  final provider = <String, dynamic>{
    'id': 'savira',
    'nama': 'Savira Julia, S.Farm',
    'aktif': true,
    'dokterLayanan': services,
  };
  final schedule = <String, dynamic>{
    'tanggal': '2026-11-01',
    'aktif': true,
    'dokterLayananId': 'apotek-link',
    'dokterLayanan': {
      'id': 'apotek-link',
      'dokterId': 'savira',
      'layananId': 'apotek',
    },
  };

  test('menampilkan nama pertama penyedia layanan yang terjadwal', () {
    expect(
      patientServiceScheduledProviderName(
        doctors: [provider],
        sessions: [schedule],
        serviceId: 'apotek',
        date: '2026-11-01',
      ),
      'Savira',
    );
  });
  test('tidak mencampur jadwal layanan atau tanggal lain', () {
    expect(
      patientServiceScheduledProviderName(
        doctors: [provider],
        sessions: [schedule],
        serviceId: 'radiologi',
        date: '2026-11-01',
      ),
      isNull,
    );
    expect(
      patientServiceScheduledProviderName(
        doctors: [provider],
        sessions: [schedule],
        serviceId: 'apotek',
        date: '2026-11-02',
      ),
      isNull,
    );
  });
  test(
    'fallback menampilkan nama dari dokter terkait tanpa jadwal hari itu',
    () {
      expect(
        patientServiceProviderLabel(
          doctors: [provider],
          sessions: const [],
          serviceId: 'apotek',
          date: '2026-11-01',
        ),
        'Savira',
      );
    },
  );
  test('jadwal sesuai tanggal lebih diutamakan daripada fallback', () {
    expect(
      patientServiceProviderLabel(
        doctors: [provider],
        sessions: [schedule],
        serviceId: 'apotek',
        date: '2026-11-01',
      ),
      'Savira',
    );
  });
  test('tidak menampilkan dokter layanan lain', () {
    expect(
      patientServiceProviderLabel(
        doctors: [provider],
        sessions: const [],
        serviceId: 'radiologi',
        date: '2026-11-01',
      ),
      '',
    );
  });
  test('dokter nonaktif tidak muncul pada fallback', () {
    expect(
      patientServiceProviderLabel(
        doctors: [
          {...provider, 'aktif': false},
        ],
        sessions: const [],
        serviceId: 'apotek',
        date: '2026-11-01',
      ),
      '',
    );
  });
  test('fallback menerima relasi aktif tanpa tanggal sesi', () {
    final radiologi = <String, dynamic>{
      'id': 'radiologi-doctor',
      'nama': 'Radiologi',
      'aktif': true,
      'dokterLayanan': [
        {'id': 'link-radio', 'aktif': true, 'layananId': 'radiologi'},
      ],
    };
    final yusril = <String, dynamic>{
      'id': 'yusril',
      'nama': 'Yusril',
      'aktif': true,
      'dokterLayanan': [
        {'id': 'link-lab', 'aktif': true, 'layananId': 'laboratorium'},
      ],
    };
    expect(
      patientServiceProviderLabel(
        doctors: [radiologi, yusril],
        sessions: const [],
        serviceId: 'radiologi',
        date: '2026-11-01',
      ),
      'Radiologi',
    );
    expect(
      patientServiceProviderLabel(
        doctors: [radiologi, yusril],
        sessions: const [],
        serviceId: 'laboratorium',
        date: '2026-11-01',
      ),
      'Yusril',
    );
  });
  test('mengabaikan jadwal nonaktif', () {
    expect(
      patientServiceScheduledProviderName(
        doctors: [provider],
        sessions: [
          {...schedule, 'aktif': false},
        ],
        serviceId: 'apotek',
        date: '2026-11-01',
      ),
      isNull,
    );
  });
}
