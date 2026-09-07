import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Shown to a Regional Admin. Reads the snapshots that the
/// `generateWeeklyReports` Cloud Function writes every Monday — this
/// screen never computes stats itself, it just visualizes them.
///
/// Usage:
///   RegionalAdminReportsScreen(
///     regionId: 'region_south',
///     regionName: 'Southern Region',
///     cities: ['Karachi', 'Hyderabad', 'Sukkur'],
///   )
enum _Metric { users, gigs, payments }

class RegionalAdminReportsScreen extends StatefulWidget {
  final String regionId;
  final String regionName;
  final List<String> cities;

  const RegionalAdminReportsScreen({
    super.key,
    required this.regionId,
    required this.regionName,
    required this.cities,
  });

  @override
  State<RegionalAdminReportsScreen> createState() =>
      _RegionalAdminReportsScreenState();
}

class _RegionalAdminReportsScreenState
    extends State<RegionalAdminReportsScreen> {
  static const Color _navy = Color(0xFF0E3B2E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _bg = Color(0xFFF7F5EF);
  static const Color _blue = Color(0xFF1A5C46);
  static const Color _green = Color(0xFF10B981);
  static const Color _amber = Color(0xFFC9A227);

  late String _selectedCity;
  _Metric _metric = _Metric.users;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.cities.isNotEmpty ? widget.cities.first : '';
  }

  Color get _metricColor {
    switch (_metric) {
      case _Metric.users:
        return _blue;
      case _Metric.gigs:
        return _green;
      case _Metric.payments:
        return _amber;
    }
  }

  String get _metricLabel {
    switch (_metric) {
      case _Metric.users:
        return 'New users / week';
      case _Metric.gigs:
        return 'New gigs / week';
      case _Metric.payments:
        return 'Payments resolved / week';
    }
  }

  int _metricValue(Map<String, dynamic> data) {
    switch (_metric) {
      case _Metric.users:
        return (data['newUsersThisWeek'] ?? 0) as int;
      case _Metric.gigs:
        return (data['newGigsThisWeek'] ?? 0) as int;
      case _Metric.payments:
        return (data['paymentsResolvedThisWeek'] ?? 0) as int;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _navy,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: _white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('${widget.regionName} · Weekly Reports',
            style: const TextStyle(
                color: _white, fontSize: 16, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: widget.cities.isEmpty
          ? const Center(
              child: Text('No cities assigned to this region.',
                  style: TextStyle(color: Color(0xFFA6B2AB))))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _CityChips(
                  cities: widget.cities,
                  selected: _selectedCity,
                  onSelect: (c) => setState(() => _selectedCity = c),
                ),
                const SizedBox(height: 20),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('weeklyReports')
                      .where('regionId', isEqualTo: widget.regionId)
                      .where('city', isEqualTo: _selectedCity)
                      .orderBy('weekStart', descending: true)
                      .limit(8)
                      .snapshots(),
                  builder: (context, snap) {
                    if (snap.hasError) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                            'Could not load reports. If this is the first '
                            'run, Firestore may still be building the index.',
                            style: TextStyle(
                                color: Color(0xFFA6B2AB), fontSize: 13)),
                      );
                    }
                    if (!snap.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child:
                                CircularProgressIndicator(color: _navy)),
                      );
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                            'No weekly reports yet for this city. '
                            'The first one lands next Monday.',
                            style: TextStyle(
                                color: Color(0xFFA6B2AB), fontSize: 13)),
                      );
                    }

                    final reports = docs
                        .map((d) => d.data() as Map<String, dynamic>)
                        .toList();
                    final latest = reports.first;
                    final previous =
                        reports.length > 1 ? reports[1] : null;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            'Week ${latest['weekId'] ?? '—'} · auto-generated',
                            style: const TextStyle(
                                fontSize: 11.5,
                                color: Color(0xFFA6B2AB),
                                fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        _TrendStatsRow(latest: latest, previous: previous),
                        const SizedBox(height: 24),
                        const _SectionTitle('Trend'),
                        const SizedBox(height: 10),
                        _MetricToggle(
                          metric: _metric,
                          onChanged: (m) => setState(() => _metric = m),
                        ),
                        const SizedBox(height: 14),
                        _InteractiveChartCard(
                          reports: reports.reversed.toList(),
                          color: _metricColor,
                          label: _metricLabel,
                          valueOf: _metricValue,
                        ),
                        const SizedBox(height: 24),
                        const _SectionTitle('Report History'),
                        const SizedBox(height: 10),
                        ...reports.map((r) => _HistoryTile(report: r)),
                      ],
                    );
                  },
                ),
              ],
            ),
    );
  }
}

class _CityChips extends StatelessWidget {
  final List<String> cities;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CityChips(
      {required this.cities, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cities.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final city = cities[i];
          final isSel = city == selected;
          return GestureDetector(
            onTap: () => onSelect(city),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFF0E3B2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color:
                        isSel ? const Color(0xFF0E3B2E) : const Color(0xFFE3E0D5)),
              ),
              child: Center(
                child: Text(city,
                    style: TextStyle(
                        color: isSel ? Colors.white : const Color(0xFF5D6B64),
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrendStatsRow extends StatelessWidget {
  final Map<String, dynamic> latest;
  final Map<String, dynamic>? previous;
  const _TrendStatsRow({required this.latest, required this.previous});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TrendCard(
            label: 'Total users',
            value: (latest['totalUsers'] ?? 0) as int,
            prevValue:
                previous != null ? (previous!['totalUsers'] ?? 0) as int : null,
            color: const Color(0xFF1A5C46),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TrendCard(
            label: 'New gigs',
            value: (latest['newGigsThisWeek'] ?? 0) as int,
            prevValue: previous != null
                ? (previous!['newGigsThisWeek'] ?? 0) as int
                : null,
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _TrendCard(
            label: 'Payments resolved',
            value: (latest['paymentsResolvedThisWeek'] ?? 0) as int,
            prevValue: previous != null
                ? (previous!['paymentsResolvedThisWeek'] ?? 0) as int
                : null,
            color: const Color(0xFFC9A227),
          ),
        ),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final String label;
  final int value;
  final int? prevValue;
  final Color color;
  const _TrendCard(
      {required this.label,
      required this.value,
      required this.prevValue,
      required this.color});

  @override
  Widget build(BuildContext context) {
    double? pct;
    bool up = true;
    if (prevValue != null && prevValue! > 0) {
      pct = ((value - prevValue!) / prevValue!) * 100;
      up = pct >= 0;
    } else if (prevValue == 0 && value > 0) {
      pct = 100;
      up = true;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value',
              style:
                  TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(color: Color(0xFFA6B2AB), fontSize: 11)),
          if (pct != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(
                    up
                        ? Icons.arrow_upward_rounded
                        : Icons.arrow_downward_rounded,
                    size: 12,
                    color: up ? const Color(0xFF10B981) : const Color(0xFFDC2626)),
                const SizedBox(width: 2),
                Text('${pct.abs().toStringAsFixed(0)}%',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color:
                            up ? const Color(0xFF10B981) : const Color(0xFFDC2626))),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricToggle extends StatelessWidget {
  final _Metric metric;
  final ValueChanged<_Metric> onChanged;
  const _MetricToggle({required this.metric, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget seg(String label, _Metric m) {
      final isSel = metric == m;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(m),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: isSel ? const Color(0xFF0E3B2E) : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : const Color(0xFF5D6B64))),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      child: Row(
        children: [
          seg('Users', _Metric.users),
          seg('Gigs', _Metric.gigs),
          seg('Payments', _Metric.payments),
        ],
      ),
    );
  }
}

/// A small, dependency-free line chart. Tap or drag across it to see the
/// exact value for each week — no charting package required.
class _InteractiveChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> reports; // chronological (oldest -> newest)
  final Color color;
  final String label;
  final int Function(Map<String, dynamic>) valueOf;
  const _InteractiveChartCard({
    required this.reports,
    required this.color,
    required this.label,
    required this.valueOf,
  });

  @override
  State<_InteractiveChartCard> createState() => _InteractiveChartCardState();
}

class _InteractiveChartCardState extends State<_InteractiveChartCard> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.reports.map(widget.valueOf).toList();
    final rawMax = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    final maxVal = rawMax < 1 ? 1 : rawMax;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE3E0D5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2A26))),
          const SizedBox(height: 4),
          if (_touchedIndex != null && _touchedIndex! < widget.reports.length)
            Text(
              'Week ${widget.reports[_touchedIndex!]['weekId'] ?? ''}  ·  ${values[_touchedIndex!]}',
              style: TextStyle(
                  fontSize: 11.5, color: widget.color, fontWeight: FontWeight.w700),
            )
          else
            const Text('Tap or drag across the chart to see weekly values',
                style: TextStyle(fontSize: 11, color: Color(0xFFA6B2AB))),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (d) =>
                      _handleTouch(d.localPosition, constraints.maxWidth, values.length),
                  onPanUpdate: (d) =>
                      _handleTouch(d.localPosition, constraints.maxWidth, values.length),
                  onPanEnd: (_) => setState(() => _touchedIndex = null),
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, 140),
                    painter: _LineChartPainter(
                      values: values.map((v) => v.toDouble()).toList(),
                      maxVal: maxVal.toDouble(),
                      color: widget.color,
                      touchedIndex: _touchedIndex,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: widget.reports
                .map((r) => Text(
                    '${r['weekId'] ?? ''}'.replaceFirst(RegExp(r'^\d{4}-'), ''),
                    style: const TextStyle(fontSize: 9, color: Color(0xFFA9B5AE))))
                .toList(),
          ),
        ],
      ),
    );
  }

  void _handleTouch(Offset pos, double width, int count) {
    if (count == 0) return;
    final step = width / (count == 1 ? 1 : count - 1);
    final idx = (pos.dx / step).round().clamp(0, count - 1);
    setState(() => _touchedIndex = idx);
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final double maxVal;
  final Color color;
  final int? touchedIndex;

  _LineChartPainter({
    required this.values,
    required this.maxVal,
    required this.color,
    required this.touchedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final step = values.length > 1 ? size.width / (values.length - 1) : 0.0;

    Offset pointAt(int i) {
      final x = step * i;
      final y = size.height - (values[i] / maxVal) * (size.height - 10) - 5;
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFFF7F5EF)
      ..strokeWidth = 1;
    for (int g = 0; g <= 3; g++) {
      final y = size.height * g / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final areaPath = Path()..moveTo(0, size.height);
    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      areaPath.lineTo(p.dx, p.dy);
    }
    areaPath.lineTo(size.width, size.height);
    areaPath.close();
    canvas.drawPath(areaPath, Paint()..color = color.withValues(alpha: 0.08));

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      if (i == 0) {
        linePath.moveTo(p.dx, p.dy);
      } else {
        linePath.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(linePath, linePaint);

    for (int i = 0; i < values.length; i++) {
      final p = pointAt(i);
      final isTouched = touchedIndex == i;
      canvas.drawCircle(p, isTouched ? 6 : 3, Paint()..color = color);
      if (isTouched) {
        canvas.drawCircle(p, 9, Paint()..color = color.withValues(alpha: 0.25));
        canvas.drawLine(
          Offset(p.dx, 0),
          Offset(p.dx, size.height),
          Paint()
            ..color = color.withValues(alpha: 0.2)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) =>
      oldDelegate.touchedIndex != touchedIndex || oldDelegate.values != values;
}

class _HistoryTile extends StatefulWidget {
  final Map<String, dynamic> report;
  const _HistoryTile({required this.report});

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final weekId = r['weekId'] ?? '—';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE3E0D5)),
        ),
        child: Column(
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('Week $weekId',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1F2A26))),
                    ),
                    Icon(
                        _expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        size: 18,
                        color: const Color(0xFFA6B2AB)),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  children: [
                    _row('Total users', r['totalUsers']),
                    _row('New users this week', r['newUsersThisWeek']),
                    _row('Active gigs', r['activeGigs']),
                    _row('New gigs this week', r['newGigsThisWeek']),
                    _row('Pending payments', r['pendingPayments']),
                    _row('Payments resolved this week',
                        r['paymentsResolvedThisWeek']),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF5D6B64))),
          Text('${value ?? 0}',
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF1F2A26))),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: Color(0xFF1F2A26), fontSize: 14, fontWeight: FontWeight.w700));
}