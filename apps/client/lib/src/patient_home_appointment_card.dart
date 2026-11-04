import 'package:flutter/material.dart';

import 'config.dart';
import 'doctor_professional.dart';
import 'patient_design.dart';
import 'patient_home.dart';
import 'patient_ui.dart';

/// Home-only doctor preview. Slot totals are shown only when the caller has an
/// authoritative availability label; a practice schedule alone is not a quota.
class PatientHomeAppointmentCard extends StatelessWidget {
  const PatientHomeAppointmentCard({
    super.key,
    required this.preview,
    required this.config,
    this.onTap,
    this.scheduleUnavailable = false,
    this.availabilityLabel,
  });

  final HomeDoctorPreview preview;
  final AppConfig config;
  final VoidCallback? onTap;
  final bool scheduleUnavailable;
  final String? availabilityLabel;

  String get _zone => switch (config.serviceTimeZone) {
    'Asia/Jakarta' => 'WIB',
    'Asia/Makassar' => 'WITA',
    'Asia/Jayapura' => 'WIT',
    _ => config.serviceTimeZone,
  };

  String get _schedule {
    if (scheduleUnavailable) return 'Jadwal belum dapat dimuat';
    final session = preview.session;
    if (session == null) return 'Jadwal belum tersedia';
    final day = dateOnly(session['tanggal']);
    final date = day == config.today ? 'Hari ini' : patientCompactDate(day);
    final start = DateTime.tryParse('${session['mulaiPada']}');
    final end = DateTime.tryParse('${session['selesaiPada']}');
    return start == null || end == null
        ? '$date · Jam belum tersedia'
        : '$date: ${patientTime(session, config)} $_zone';
  }

  String? get _room {
    if (scheduleUnavailable) return null;
    final room = object(preview.session?['loket']);
    final code = '${room['kode'] ?? ''}'.trim();
    final name = '${room['nama'] ?? ''}'.trim();
    final parts = [
      if (code.isNotEmpty) code,
      if (name.isNotEmpty && name != code) name,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final doctorName = label(preview.doctor);
    final specialty = '${preview.doctor['spesialisasi'] ?? ''}'.trim();
    final clinicName = label(preview.clinic);
    final availability = scheduleUnavailable
        ? ''
        : availabilityLabel?.trim() ?? '';
    return Material(
      color: PatientDesign.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PatientDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalDoctorAvatar(
                  config: config,
                  photo: preview.doctor['fotoProfil'],
                  radius: 20,
                  borderRadius: BorderRadius.circular(8),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: PatientDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (specialty.isNotEmpty &&
                              specialty.toLowerCase() !=
                                  clinicName.toLowerCase())
                            specialty,
                          clinicName,
                        ].join(' · '),
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: PatientDesign.muted,
                        ),
                      ),
                      if (availability.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          decoration: BoxDecoration(
                            color: PatientDesign.soft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          child: Text(
                            availability,
                            style: const TextStyle(
                              fontSize: 11,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                              color: PatientDesign.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                color: PatientDesign.soft,
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(8),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final facts = Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AppointmentFact(
                        icon: Icons.schedule_outlined,
                        text: _schedule,
                        color: scheduleUnavailable
                            ? PatientDesign.muted
                            : PatientDesign.primary,
                      ),
                      if (_room case final room?) ...[
                        const SizedBox(height: 4),
                        _AppointmentFact(
                          icon: Icons.meeting_room_outlined,
                          text: room,
                        ),
                      ],
                    ],
                  );
                  final action = FilledButton.icon(
                    onPressed: onTap,
                    style: FilledButton.styleFrom(
                      backgroundColor: PatientDesign.primary,
                      foregroundColor: PatientDesign.paper,
                      minimumSize: const Size(44, 44),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    iconAlignment: IconAlignment.end,
                    label: const Text('Detail & Jadwal'),
                  );
                  if (constraints.maxWidth < 280 ||
                      MediaQuery.textScalerOf(context).scale(13) > 17) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        facts,
                        const SizedBox(height: 6),
                        Align(alignment: Alignment.centerRight, child: action),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: facts),
                      const SizedBox(width: 8),
                      action,
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentFact extends StatelessWidget {
  const _AppointmentFact({
    required this.icon,
    required this.text,
    this.color = PatientDesign.muted,
  });
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Icon(icon, size: 16, color: color),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ],
  );
}
