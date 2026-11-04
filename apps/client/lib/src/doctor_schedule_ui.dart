import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'patient_design.dart';
import 'doctor_professional.dart';
import 'queueb_content_motion.dart';
import 'queueb_motion.dart';

// QueueB existing tokens and navigation; reference: doctor profile + calendar.
class DoctorProfileCard extends StatelessWidget {
  const DoctorProfileCard({
    super.key,
    required this.doctor,
    required this.config,
    required this.clinics,
    this.availability,
    this.onSchedule,
    this.detail = false,
  });
  final Json doctor;
  final AppConfig config;
  final String clinics;
  final String? availability;
  final VoidCallback? onSchedule;
  final bool detail;

  Widget _detailProfile(BuildContext context) {
    final specialty = '${doctor['spesialisasi'] ?? ''}'.trim();
    final clinicNames = clinics.trim();
    final actualAvailability = availability?.trim() ?? '';
    return Material(
      color: PatientDesign.paper,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: PatientDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProfessionalDoctorAvatar(
                  config: config,
                  photo: doctor['fotoProfil'],
                  radius: 28,
                  borderRadius: BorderRadius.circular(10),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label(doctor),
                        style: const TextStyle(
                          fontSize: 18,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: PatientDesign.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty.isEmpty
                            ? 'Spesialisasi belum dicantumkan'
                            : specialty,
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          color: PatientDesign.primary,
                        ),
                      ),
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.local_hospital_outlined,
                    color: PatientDesign.primary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      clinicNames.isEmpty
                          ? 'Poliklinik belum dicantumkan'
                          : clinicNames,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: PatientDesign.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (actualAvailability.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.event_available_outlined,
                    size: 16,
                    color: PatientDesign.muted,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      actualAvailability,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: PatientDesign.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => detail
      ? _detailProfile(context)
      : AppCard(
          color: detail ? PatientDesign.mint : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProfessionalDoctorAvatar(
                    config: config,
                    photo: doctor['fotoProfil'],
                    radius: detail ? 36 : 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label(doctor),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: detail ? 20 : 16,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${doctor['spesialisasi'] ?? 'Spesialisasi belum dicantumkan'}',
                          style: const TextStyle(color: PatientDesign.muted),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          clinics,
                          style: const TextStyle(color: PatientDesign.darkTeal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (availability != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.event_available_outlined,
                      size: 18,
                      color: PatientDesign.muted,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        availability!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: PatientDesign.muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              if (!detail) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onSchedule,
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('Lihat Jadwal'),
                ),
              ],
            ],
          ),
        );
}

/// Values are calendar DATE strings from the API, never derived practice days.
class PracticeDateStrip extends StatefulWidget {
  const PracticeDateStrip({
    super.key,
    required this.dates,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final List<String> dates;
  final String value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  State<PracticeDateStrip> createState() => _PracticeDateStripState();
}

class _PracticeDateStripState extends State<PracticeDateStrip> {
  late final ScrollController controller = ScrollController();

  @override
  void initState() {
    super.initState();
    revealDate();
  }

  @override
  void didUpdateWidget(PracticeDateStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value || oldWidget.dates != widget.dates) {
      revealDate();
    }
  }

  void revealDate() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !controller.hasClients) return;
    final index = widget.dates.indexOf(widget.value);
    controller.jumpTo(
      (index * 80.0).clamp(0.0, controller.position.maxScrollExtent),
    );
  });

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 104 * MediaQuery.textScalerOf(context).scale(1),
    child: ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: widget.dates.length,
      controller: controller,
      separatorBuilder: (_, index) => const SizedBox(width: 8),
      itemBuilder: (context, index) {
        final text = widget.dates[index], day = DateTime.parse(text);
        final selected = text == widget.value;
        return Semantics(
          selected: selected,
          child: SizedBox(
            width: 72,
            child: QueueBSelectionMotion(
              key: ValueKey(text),
              selected: selected,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  animationDuration: QueueBMotion.duration(
                    context,
                    QueueBMotion.micro,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 8,
                  ),
                  backgroundColor: selected
                      ? PatientDesign.darkTeal
                      : Colors.white,
                  foregroundColor: selected ? Colors.white : PatientDesign.navy,
                  side: BorderSide(
                    color: selected ? PatientDesign.teal : PatientDesign.border,
                  ),
                ),
                onPressed: widget.enabled ? () => widget.onChanged(text) : null,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      const [
                        'Sen',
                        'Sel',
                        'Rab',
                        'Kam',
                        'Jum',
                        'Sab',
                        'Min',
                      ][day.weekday - 1],
                    ),
                    Text(
                      '${day.day}/${day.month}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    Text('${day.year}', style: const TextStyle(fontSize: 10)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ),
  );
}

String consultationSlotStatus(Json slot) {
  if (slot['aktif'] == false) return 'Tidak aktif';
  if (slot['sisaKapasitas'] is num && slot['sisaKapasitas'] <= 0) {
    return 'Penuh';
  }
  return slot['tersedia'] == true ? 'Tersedia' : 'Tidak tersedia';
}

class ConsultationSlotGrid extends StatelessWidget {
  const ConsultationSlotGrid({
    super.key,
    required this.slots,
    required this.config,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });
  final List<Json> slots;
  final AppConfig config;
  final String? value;
  final ValueChanged<String> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
      final columns = box.maxWidth >= 296 && scale <= 1.15
          ? 3
          : box.maxWidth >= 220 * scale
          ? 2
          : 1;
      final width = (box.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [for (final slot in slots) _slot(slot, width)],
      );
    },
  );

  Widget _slot(Json slot, double width) {
    final remaining = slot['sisaKapasitas'];
    final available =
        slot['tersedia'] == true &&
        slot['aktif'] != false &&
        !(remaining is num && remaining <= 0);
    final selected = value == slot['id'] && available;
    final canSelect = enabled && available;
    final status = consultationSlotStatus(slot);
    final start = config.localInput(slot['mulaiPada']).split('T').last;
    final end = config.localInput(slot['selesaiPada']).split('T').last;
    final ink = selected
        ? PatientDesign.paper
        : available
        ? PatientDesign.ink
        : PatientDesign.muted;
    final surface = selected
        ? PatientDesign.primary
        : available
        ? PatientDesign.soft
        : const Color(0xfff5f6fa);
    final slotLabel =
        '$start–$end · $status'
        '${remaining is num ? ' · Sisa slot $remaining' : ''}';
    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        child: Tooltip(
          message: slotLabel,
          child: OutlinedButton(
            key: ValueKey('consultation-slot-${slot['id']}'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(48, 78),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              backgroundColor: surface,
              disabledBackgroundColor: surface,
              foregroundColor: ink,
              disabledForegroundColor: ink,
              side: BorderSide(
                color: selected ? PatientDesign.primary : PatientDesign.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: canSelect ? () => onChanged('${slot['id']}') : null,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        start,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.15,
                          fontWeight: FontWeight.w700,
                          color: ink,
                          decoration: available
                              ? TextDecoration.none
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: PatientDesign.paper,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$start–$end',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.2, color: ink),
                ),
                const SizedBox(height: 3),
                Text(
                  selected ? 'Terpilih' : status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? PatientDesign.paper
                        : available
                        ? PatientDesign.success
                        : PatientDesign.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
