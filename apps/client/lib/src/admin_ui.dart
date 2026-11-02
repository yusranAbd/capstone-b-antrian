import 'package:flutter/material.dart';

import 'config.dart';
import 'mobile_ui.dart';
import 'queueb_palette.dart';
import 'queueb_value_motion.dart';

abstract final class AdminStyle {
  static const radius = 16.0;
  static const pagePadding = 16.0;
  static EdgeInsets pageInsets(BuildContext context) => EdgeInsets.all(
    MediaQuery.sizeOf(context).width < 360
        ? 12
        : MediaQuery.sizeOf(context).width < 960
        ? 16
        : 24,
  );
  static const canvas = QueueBPalette.background;
  static const sky = QueueBPalette.soft;
  static const blue = QueueBPalette.cyan;
  static const rule = QueueBPalette.border;
  static const shadow = Color(0x08172544);
  static BoxDecoration get panel => BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: rule),
  );
  static final ThemeData theme = QueueBStyle.theme.copyWith(
    scaffoldBackgroundColor: canvas,
    textTheme: QueueBStyle.operationalTextTheme.copyWith(
      headlineSmall: const TextStyle(
        fontSize: 22,
        height: 1.25,
        fontWeight: FontWeight.w700,
        letterSpacing: -.4,
        color: QueueBStyle.navy,
      ),
      titleLarge: const TextStyle(
        fontSize: 17,
        height: 1.35,
        fontWeight: FontWeight.w600,
        letterSpacing: -.15,
        color: QueueBStyle.navy,
      ),
      titleMedium: const TextStyle(
        fontSize: 15,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: QueueBStyle.navy,
      ),
      bodyMedium: const TextStyle(
        fontSize: 13,
        height: 1.45,
        color: QueueBStyle.navy,
      ),
      bodySmall: const TextStyle(
        fontSize: 12,
        height: 1.4,
        color: QueueBStyle.muted,
      ),
    ),
    cardTheme: const CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.symmetric(vertical: 3),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: QueueBStyle.navy,
      elevation: 0,
      toolbarHeight: QueueBStyle.operationalToolbarHeight,
      scrolledUnderElevation: 0,
      shape: Border(bottom: BorderSide(color: rule)),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(QueueBStyle.background),
      headingTextStyle: TextStyle(
        fontWeight: FontWeight.w600,
        color: QueueBStyle.muted,
        fontSize: 12,
      ),
      dataTextStyle: TextStyle(color: QueueBStyle.navy, fontSize: 13),
      horizontalMargin: 12,
      columnSpacing: 16,
      dividerThickness: .5,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 40),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        textStyle: const TextStyle(fontSize: 13),
        side: const BorderSide(color: rule),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 36),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        textStyle: const TextStyle(fontSize: 13),
      ),
    ),
    inputDecorationTheme: QueueBStyle.theme.inputDecorationTheme.copyWith(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      fillColor: Colors.white,
      labelStyle: const TextStyle(fontSize: 13, color: QueueBStyle.muted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rule),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: rule),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: QueueBStyle.darkTeal, width: 1.5),
      ),
    ),
  );
}

class AdminPageHeading extends StatelessWidget {
  const AdminPageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title, subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 5),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      );
      if (box.maxWidth < 640 ||
          MediaQuery.textScalerOf(context).scale(13) > 19) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (trailing != null) ...[const SizedBox(height: 12), trailing!],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: heading),
          if (trailing != null) ...[const SizedBox(width: 20), trailing!],
        ],
      );
    },
  );
}

/// Session identity only; the existing profile and logout actions remain in app.dart.
class AdminIdentity extends StatelessWidget {
  const AdminIdentity({super.key, required this.name});
  final String name;
  @override
  Widget build(BuildContext context) {
    final displayName = name.trim().isEmpty ? 'Administrator' : name.trim();
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => String.fromCharCode(s.runes.first).toUpperCase())
        .join();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AdminStyle.sky,
            foregroundColor: QueueBStyle.darkTeal,
            child: Text(
              initials,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 220,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: QueueBStyle.navy,
                    fontSize: 14,
                  ),
                ),
                const Text(
                  'Administrator',
                  style: TextStyle(color: QueueBStyle.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AdminColumn {
  const AdminColumn(
    this.title,
    this.value, {
    this.cell,
    this.numeric = false,
    this.icon,
  });
  final String title;
  final Object? Function(Json) value;
  final Widget Function(Json)? cell;
  final bool numeric;
  final IconData? icon;
}

/// Client pagination for existing REST arrays. Only one page creates row widgets.
class AdminTable extends StatefulWidget {
  const AdminTable({
    super.key,
    required this.rows,
    required this.columns,
    this.title,
    this.pageSize = 10,
    this.compact = true,
    this.decorated = true,
    this.rowHeight,
    this.minimumWidth,
    this.numberedPagination = false,
    this.hideFooterWhenSinglePage = false,
    this.paginationLabel = 'data',
  });
  final List<Json> rows;
  final List<AdminColumn> columns;
  final String? title;
  final int pageSize;
  final bool compact, decorated;

  /// Opt-in numbered footer. Other ADMIN tables keep native pagination.
  final bool numberedPagination;

  /// Suppress the redundant pagination strip in small, grouped tables.
  final bool hideFooterWhenSinglePage;

  /// Item noun for the numbered footer, e.g. dokter or poliklinik.
  final String paginationLabel;
  final double? rowHeight;

  /// Optional lower bound for dense dashboard tables; other tables keep theirs.
  final double? minimumWidth;
  @override
  State<AdminTable> createState() => _AdminTableState();
}

class _AdminTableState extends State<AdminTable> {
  late final _AdminTableSource source;
  int sort = 0, size = 10;
  bool ascending = true;
  int firstRow = 0, epoch = 0;
  @override
  void initState() {
    super.initState();
    size = widget.pageSize;
    source = _AdminTableSource(this);
    reorder();
  }

  @override
  void didUpdateWidget(covariant AdminTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.numberedPagination && oldWidget.pageSize != widget.pageSize) {
      size = widget.pageSize;
      firstRow = (firstRow ~/ size) * size;
      epoch++;
    }
    if (firstRow > 0 && firstRow >= widget.rows.length) {
      firstRow = widget.numberedPagination && widget.rows.isNotEmpty
          ? ((widget.rows.length - 1) ~/ size) * size
          : 0;
      epoch++;
    }
    reorder();
  }

  void reorder() {
    final column = widget.columns[sort.clamp(0, widget.columns.length - 1)];
    source.rows = [...widget.rows]
      ..sort((a, b) {
        final av = column.value(a), bv = column.value(b);
        final result = av is num && bv is num
            ? av.compareTo(bv)
            : '$av'.toLowerCase().compareTo('$bv'.toLowerCase());
        final stable = result == 0
            ? '${a['id']}'.compareTo('${b['id']}')
            : result;
        return ascending ? stable : -stable;
      });
    source.refresh();
  }

  @override
  void dispose() {
    source.dispose();
    super.dispose();
  }

  void goToPage(int page) {
    final pages = (source.rowCount + size - 1) ~/ size;
    if (page < 0 || page >= pages || page == firstRow ~/ size) return;
    setState(() => firstRow = page * size);
  }

  List<DataColumn> tableColumns() => [
    for (var i = 0; i < widget.columns.length; i++)
      DataColumn(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.columns[i].icon != null) ...[
              Icon(widget.columns[i].icon, size: 18, color: QueueBStyle.muted),
              const SizedBox(width: 8),
            ],
            Text(widget.columns[i].title),
          ],
        ),
        numeric: widget.columns[i].numeric,
        onSort: widget.columns[i].title == 'Aksi'
            ? null
            : (index, order) => setState(() {
                sort = index;
                ascending = order;
                if (widget.numberedPagination) firstRow = 0;
                reorder();
              }),
      ),
  ];

  /// Only explicitly opted-in tables render numbered pagination.
  /// Render precisely one page of rows and
  /// keep the footer outside the horizontally scrollable table on mobile.
  Widget numberedTable(
    BuildContext context,
    double availableWidth,
    double tableWidth,
  ) {
    final end = (firstRow + size).clamp(0, source.rowCount);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: tableWidth),
            child: ListenableBuilder(
              listenable: source,
              builder: (context, _) => DataTable(
                showCheckboxColumn: false,
                dataRowMinHeight: widget.rowHeight ?? 42,
                dataRowMaxHeight: widget.rowHeight == null
                    ? (MediaQuery.textScalerOf(context).scale(40) + 14).clamp(
                        58,
                        double.infinity,
                      )
                    : MediaQuery.textScalerOf(context)
                          .scale(widget.rowHeight!)
                          .clamp(widget.rowHeight!, double.infinity),
                headingRowHeight: widget.compact ? 40 : 56,
                sortColumnIndex: sort,
                sortAscending: ascending,
                columns: tableColumns(),
                rows: [for (var i = firstRow; i < end; i++) source.getRow(i)!],
              ),
            ),
          ),
        ),
        if (!widget.hideFooterWhenSinglePage || source.rowCount > size) ...[
          const Divider(height: 1, color: QueueBStyle.border),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            child: numberedFooter(context, availableWidth),
          ),
        ],
      ],
    );
  }

  Widget numberedFooter(BuildContext context, double availableWidth) {
    final total = source.rowCount;
    final pages = (total + size - 1) ~/ size;
    final current = firstRow ~/ size;
    final firstPage = (current - 2).clamp(0, (pages - 5).clamp(0, pages));
    final lastPage = (firstPage + 5).clamp(0, pages);
    final firstVisible = total == 0 ? 0 : firstRow + 1;
    final lastVisible = (firstRow + size).clamp(0, total);
    final primary = Theme.of(context).colorScheme.primary;

    Widget arrow(IconData icon, String tooltip, int? page) => IconButton(
      icon: Icon(icon, size: 19),
      tooltip: tooltip,
      onPressed: page == null ? null : () => goToPage(page),
    );

    Widget number(int index) => Semantics(
      selected: index == current,
      child: SizedBox(
        width: 38,
        height: 36,
        child: TextButton(
          onPressed: index == current ? null : () => goToPage(index),
          style: TextButton.styleFrom(
            disabledForegroundColor: primary,
            foregroundColor: QueueBStyle.navy,
            backgroundColor: index == current
                ? primary.withValues(alpha: 0.10)
                : Colors.transparent,
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          child: Text(
            '${index + 1}',
            style: TextStyle(
              fontWeight: index == current ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );

    final controls = Wrap(
      alignment: WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      children: [
        if (availableWidth >= 520)
          arrow(Icons.first_page, 'Halaman pertama', current > 0 ? 0 : null),
        arrow(
          Icons.chevron_left,
          'Halaman sebelumnya',
          current > 0 ? current - 1 : null,
        ),
        for (var page = firstPage; page < lastPage; page++) number(page),
        arrow(
          Icons.chevron_right,
          'Halaman berikutnya',
          current + 1 < pages ? current + 1 : null,
        ),
        if (availableWidth >= 520)
          arrow(
            Icons.last_page,
            'Halaman terakhir',
            current + 1 < pages ? pages - 1 : null,
          ),
      ],
    );
    final summary = Text(
      'Menampilkan $firstVisible–$lastVisible dari $total ${widget.paginationLabel}',
      style: const TextStyle(fontSize: 12, color: QueueBStyle.muted),
    );
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 4,
      spacing: 12,
      children: [controls, summary],
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final tableWidth =
          (widget.minimumWidth ??
                  (widget.numberedPagination
                      ? (widget.columns.length >= 7 ? 980.0 : 880.0)
                      : widget.columns.length * 135.0))
              .clamp(box.maxWidth, double.infinity)
              .toDouble();
      return Container(
        decoration: !widget.decorated
            ? null
            : BoxDecoration(
                color: Colors.white,
                border: Border.all(color: QueueBStyle.border),
                borderRadius: BorderRadius.circular(16),
              ),
        clipBehavior: widget.numberedPagination && widget.decorated
            ? Clip.antiAlias
            : Clip.none,
        child: widget.numberedPagination
            ? numberedTable(context, box.maxWidth, tableWidth)
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: tableWidth,
                  child: PaginatedDataTable(
                    key: ValueKey(epoch),
                    onPageChanged: (value) => firstRow = value,
                    header: widget.title == null
                        ? null
                        : Text(
                            widget.title!,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                    showCheckboxColumn: false,
                    showEmptyRows: false,
                    dataRowMinHeight:
                        widget.rowHeight ?? (widget.compact ? 42 : 58),
                    dataRowMaxHeight: widget.rowHeight != null
                        ? MediaQuery.textScalerOf(context)
                              .scale(widget.rowHeight!)
                              .clamp(widget.rowHeight!, double.infinity)
                        : widget.compact
                        ? (MediaQuery.textScalerOf(context).scale(32) + 12)
                              .clamp(46, double.infinity)
                        : 112,
                    headingRowHeight: widget.compact ? 40 : 56,
                    rowsPerPage: widget.rows.length.clamp(1, size),
                    availableRowsPerPage: {
                      if (widget.rows.length < 10)
                        widget.rows.length.clamp(1, 10),
                      widget.pageSize,
                      10,
                      20,
                      50,
                    }.toList()..sort(),
                    onRowsPerPageChanged: (value) =>
                        setState(() => size = value ?? 10),
                    sortColumnIndex: sort,
                    sortAscending: ascending,
                    columns: tableColumns(),
                    source: source,
                  ),
                ),
              ),
      );
    },
  );
}

class _AdminTableSource extends DataTableSource {
  _AdminTableSource(this.owner);
  final _AdminTableState owner;
  List<Json> rows = [];
  int? hoveredRow;
  void hover(int? index) {
    if (hoveredRow == index) return;
    hoveredRow = index;
    notifyListeners();
  }

  void refresh() => notifyListeners();
  @override
  DataRow? getRow(int index) {
    if (index >= rows.length) return null;
    final row = rows[index];
    return DataRow.byIndex(
      index: index,
      color: owner.widget.compact && hoveredRow == index
          ? const WidgetStatePropertyAll(QueueBStyle.mint)
          : null,
      cells: [
        for (final col in owner.widget.columns)
          DataCell(
            MouseRegion(
              onEnter: owner.widget.compact ? (_) => hover(index) : null,
              onExit: owner.widget.compact ? (_) => hover(null) : null,
              child: _cell(row, col),
            ),
          ),
      ],
    );
  }

  @override
  int get rowCount => rows.length;
  Widget _cell(Json row, AdminColumn col) {
    final child =
        col.cell?.call(row) ??
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 220),
          child: Tooltip(
            message: '${col.value(row) ?? '—'}',
            child: Text(
              '${col.value(row) ?? '—'}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        );
    if (row['id'] == null || !col.title.toLowerCase().startsWith('status')) {
      return child;
    }
    return QueueBValueMotion(
      key: ValueKey<Object>((row['id'], col.title)),
      scope: row['id'],
      value: col.value(row),
      animateChild: false,
      highlight: true,
      borderOnly: true,
      highlightColor: AdminStyle.blue,
      child: child,
    );
  }

  @override
  bool get isRowCountApproximate => false;
  @override
  int get selectedRowCount => 0;
}

class AdminSearchChoice extends StatefulWidget {
  const AdminSearchChoice({
    super.key,
    required this.label,
    required this.choices,
    required this.value,
    required this.onChanged,
    this.required = true,
  });
  final String label;
  final List<(String, String)> choices;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final bool required;
  @override
  State<AdminSearchChoice> createState() => _AdminSearchChoiceState();
}

class _AdminSearchChoiceState extends State<AdminSearchChoice> {
  final text = TextEditingController();
  String? selected;
  @override
  void initState() {
    super.initState();
    reset();
  }

  void reset() {
    selected = widget.value;
    text.text =
        widget.choices.where((c) => c.$1 == selected).firstOrNull?.$2 ?? '';
  }

  @override
  void didUpdateWidget(covariant AdminSearchChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) reset();
  }

  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => DropdownMenuFormField<String>(
    key: ValueKey(widget.value),
    controller: text,
    initialSelection: selected,
    expandedInsets: EdgeInsets.zero,
    menuHeight: 280,
    enabled: widget.onChanged != null,
    enableFilter: true,
    enableSearch: true,
    requestFocusOnTap: true,
    label: Text(widget.label),
    dropdownMenuEntries: [
      for (final c in widget.choices)
        DropdownMenuEntry(value: c.$1, label: c.$2),
    ],
    onSelected: (value) {
      selected = value;
      widget.onChanged?.call(value);
    },
    validator: (_) =>
        (widget.required || selected != null || text.text.isNotEmpty) &&
            !widget.choices.any((c) => c.$1 == selected && c.$2 == text.text)
        ? 'Pilih ${widget.label.toLowerCase()} dari daftar.'
        : null,
  );
}

/// One contextual popup for all ADMIN rows. Existing owners keep confirmations,
/// API mutation, RBAC errors, reload and filter state.
class AdminRowAction {
  const AdminRowAction(
    this.label,
    this.icon,
    this.onSelect, {
    this.danger = false,
    this.enabled = true,
  });
  final String label;
  final IconData icon;
  final VoidCallback onSelect;
  final bool danger, enabled;
}

class AdminRowActions extends StatelessWidget {
  const AdminRowActions({
    super.key,
    required this.actions,
    this.busy = false,
    required this.tooltip,
    this.iconOnly = false,
  });
  final List<AdminRowAction> actions;
  final bool busy;
  final bool iconOnly;
  final String tooltip;
  @override
  Widget build(BuildContext context) => PopupMenuButton<AdminRowAction>(
    tooltip: tooltip,
    enabled: !busy && actions.any((a) => a.enabled),
    position: PopupMenuPosition.under,
    onSelected: (action) {
      if (!busy && action.enabled) action.onSelect();
    },
    itemBuilder: (_) => [
      for (var i = 0; i < actions.length; i++)
        PopupMenuItem<AdminRowAction>(
          value: actions[i],
          enabled: actions[i].enabled,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                actions[i].icon,
                size: 18,
                color: actions[i].danger
                    ? const Color(0xffb3261e)
                    : QueueBStyle.muted,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  actions[i].label,
                  style: TextStyle(
                    fontSize: 13,
                    color: actions[i].danger ? const Color(0xffb3261e) : null,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
    child: Semantics(
      button: true,
      label: tooltip,
      excludeSemantics: true,
      child: SizedBox(
        width: iconOnly
            ? 44
            : 88 +
                  (MediaQuery.textScalerOf(context).scale(13) - 13).clamp(
                        0,
                        double.infinity,
                      ) *
                      4,
        height: (MediaQuery.textScalerOf(context).scale(20) + 12).clamp(
          40,
          double.infinity,
        ),
        child: iconOnly
            ? const Icon(Icons.more_horiz, size: 22)
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Aksi',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.expand_more, size: 18),
                ],
              ),
      ),
    ),
  );
}
