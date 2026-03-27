import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../models/prospect.dart';
import '../models/event.dart';
import 'prospect_detail_screen.dart';

// ─────────────────────────────────────────────
// Top-level screen
// ─────────────────────────────────────────────

enum _ViewMode { week, month }

class WeeklyStatsScreen extends StatefulWidget {
  const WeeklyStatsScreen({super.key});

  @override
  State<WeeklyStatsScreen> createState() => _WeeklyStatsScreenState();
}

class _WeeklyStatsScreenState extends State<WeeklyStatsScreen>
    with SingleTickerProviderStateMixin {
  _ViewMode _mode = _ViewMode.week;

  // ── Week state ──
  late DateTime _weekStart;

  // ── Month state ──
  late int _monthYear;
  late int _monthIndex; // 1-12

  // ── Shared loaded data ──
  int _prospectCount = 0;
  int _activityCount = 0;
  List<Prospect> _newProspects = [];
  List<ProspectEvent> _activities = [];
  Map<String, int> _dailyCounts = {};
  List<Map<String, dynamic>> _weeklyCountsForMonth = [];
  List<Map<String, dynamic>> _actionBreakdown = [];
  bool _isLoading = true;

  late TabController _tabController;

  final _headerFormat = DateFormat('MMM dd');
  final _monthLabelFormat = DateFormat('MMMM yyyy');
  final _fullFormat = DateFormat('EEE, MMM dd');
  final _dayFormat = DateFormat('EEE\ndd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _weekStart = _currentWeekStart();
    final now = DateTime.now();
    _monthYear = now.year;
    _monthIndex = now.month;
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Date helpers
  // ─────────────────────────────────────────────

  DateTime _currentWeekStart() {
    final now = DateTime.now();
    final daysSinceSat = (now.weekday + 1) % 7;
    return DateTime(now.year, now.month, now.day - daysSinceSat);
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  DateTime get _monthStart => DateTime(_monthYear, _monthIndex);
  DateTime get _monthEnd => DateTime(_monthYear, _monthIndex + 1);

  bool get _isCurrentWeek => _weekStart == _currentWeekStart();
  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _monthYear == now.year && _monthIndex == now.month;
  }

  DateTime get _from => _mode == _ViewMode.week ? _weekStart : _monthStart;
  DateTime get _to => _mode == _ViewMode.week ? _weekEnd : _monthEnd;

  // ─────────────────────────────────────────────
  // Data loading
  // ─────────────────────────────────────────────

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    final results = await Future.wait([
      DatabaseHelper.instance.countNewProspects(_from, _to),
      DatabaseHelper.instance.countActivities(_from, _to),
      DatabaseHelper.instance.getNewProspects(_from, _to),
      DatabaseHelper.instance.getActivities(_from, _to),
      DatabaseHelper.instance.countActivitiesPerDay(_from, _to),
      DatabaseHelper.instance.getActionBreakdown(_from, _to),
      DatabaseHelper.instance.countActivitiesPerWeek(_from, _to),
    ]);

    setState(() {
      _prospectCount = results[0] as int;
      _activityCount = results[1] as int;
      _newProspects = results[2] as List<Prospect>;
      _activities = results[3] as List<ProspectEvent>;
      _dailyCounts = results[4] as Map<String, int>;
      _actionBreakdown = results[5] as List<Map<String, dynamic>>;
      _weeklyCountsForMonth = results[6] as List<Map<String, dynamic>>;
      _isLoading = false;
    });
  }

  // ─────────────────────────────────────────────
  // Navigation
  // ─────────────────────────────────────────────

  void _prevPeriod() {
    if (_mode == _ViewMode.week) {
      setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7)));
    } else {
      setState(() {
        if (_monthIndex == 1) {
          _monthIndex = 12;
          _monthYear--;
        } else {
          _monthIndex--;
        }
      });
    }
    _loadData();
  }

  void _nextPeriod() {
    if (_mode == _ViewMode.week) {
      if (_isCurrentWeek) return;
      setState(() => _weekStart = _weekStart.add(const Duration(days: 7)));
    } else {
      if (_isCurrentMonth) return;
      setState(() {
        if (_monthIndex == 12) {
          _monthIndex = 1;
          _monthYear++;
        } else {
          _monthIndex++;
        }
      });
    }
    _loadData();
  }

  Future<void> _pickPeriod() async {
    final initial = _mode == _ViewMode.week ? _weekStart : _monthStart;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: _mode == _ViewMode.week
          ? 'Pick any day in the week'
          : 'Pick any day in the month',
    );
    if (picked == null) return;
    setState(() {
      if (_mode == _ViewMode.week) {
        final daysSinceSat = (picked.weekday + 1) % 7;
        _weekStart =
            DateTime(picked.year, picked.month, picked.day - daysSinceSat);
      } else {
        _monthYear = picked.year;
        _monthIndex = picked.month;
      }
    });
    _loadData();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  String get _periodLabel {
    if (_mode == _ViewMode.week) {
      return '${_headerFormat.format(_weekStart)} – ${_headerFormat.format(_weekEnd.subtract(const Duration(seconds: 1)))}';
    } else {
      return _monthLabelFormat.format(_monthStart);
    }
  }

  String get _periodSubLabel {
    if (_mode == _ViewMode.week) {
      return _isCurrentWeek ? 'This Week' : 'Selected Week';
    } else {
      return _isCurrentMonth ? 'This Month' : 'Selected Month';
    }
  }

  bool get _canGoForward =>
      _mode == _ViewMode.week ? !_isCurrentWeek : !_isCurrentMonth;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Summary'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Actions'),
            Tab(text: 'Details'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Week / Month toggle ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<_ViewMode>(
              segments: const [
                ButtonSegment(
                    value: _ViewMode.week,
                    label: Text('Weekly'),
                    icon: Icon(Icons.view_week_outlined, size: 16)),
                ButtonSegment(
                    value: _ViewMode.month,
                    label: Text('Monthly'),
                    icon: Icon(Icons.calendar_month_outlined, size: 16)),
              ],
              selected: {_mode},
              onSelectionChanged: (sel) {
                setState(() => _mode = sel.first);
                _loadData();
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // ── Period selector bar ──
          Container(
            color: colors.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _prevPeriod,
                  tooltip: 'Previous',
                ),
                Expanded(
                  child: InkWell(
                    onTap: _pickPeriod,
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        children: [
                          Text(
                            _periodSubLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: colors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _periodLabel,
                                style: const TextStyle(
                                    fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.calendar_today,
                                  size: 14, color: colors.primary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: _canGoForward ? _nextPeriod : null,
                  tooltip: 'Next',
                ),
              ],
            ),
          ),

          // ── Tab content ──
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      // Overview tab
                      _OverviewTab(
                        mode: _mode,
                        periodStart: _from,
                        periodEnd: _to,
                        prospectCount: _prospectCount,
                        activityCount: _activityCount,
                        dailyCounts: _dailyCounts,
                        weeklyCountsForMonth: _weeklyCountsForMonth,
                        dayFormat: _dayFormat,
                        fullFormat: _fullFormat,
                      ),
                      // Actions tab
                      _ActionsTab(
                        actionBreakdown: _actionBreakdown,
                        mode: _mode,
                        periodLabel: _periodLabel,
                      ),
                      // Details tab
                      _DetailsTab(
                        newProspects: _newProspects,
                        activities: _activities,
                        fullFormat: _fullFormat,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Overview Tab
// ─────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final _ViewMode mode;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int prospectCount;
  final int activityCount;
  final Map<String, int> dailyCounts;
  final List<Map<String, dynamic>> weeklyCountsForMonth;
  final DateFormat dayFormat;
  final DateFormat fullFormat;

  const _OverviewTab({
    required this.mode,
    required this.periodStart,
    required this.periodEnd,
    required this.prospectCount,
    required this.activityCount,
    required this.dailyCounts,
    required this.weeklyCountsForMonth,
    required this.dayFormat,
    required this.fullFormat,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Stat cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                icon: Icons.person_add,
                label: 'New Prospects',
                count: prospectCount,
                color: colors.primary,
                bgColor: colors.primaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                icon: Icons.event_note,
                label: 'Activities',
                count: activityCount,
                color: colors.secondary,
                bgColor: colors.secondaryContainer,
              ),
            ),
          ],
        ),

        const SizedBox(height: 24),

        Text(
          mode == _ViewMode.week
              ? 'Daily Activity Breakdown'
              : 'Weekly Activity Breakdown',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),

        // Chart: daily for week, weekly for month
        if (mode == _ViewMode.week)
          _DailyBarChart(
            weekStart: periodStart,
            dailyCounts: dailyCounts,
            dayFormat: dayFormat,
          )
        else
          _WeeklyBarChart(weeklyCounts: weeklyCountsForMonth),

        const SizedBox(height: 24),

        // Day-by-day list only for weekly view
        if (mode == _ViewMode.week) ...[
          Text('Day by Day', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildDayList(context),
        ] else ...[
          Text('Week by Week', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildWeekList(context),
        ],
      ],
    );
  }

  List<Widget> _buildDayList(BuildContext context) {
    return List.generate(7, (i) {
      final day = periodStart.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      final count = dailyCounts[key] ?? 0;
      final isToday = day.year == DateTime.now().year &&
          day.month == DateTime.now().month &&
          day.day == DateTime.now().day;
      return _DayRow(
          label: fullFormat.format(day), count: count, highlight: isToday);
    });
  }

  List<Widget> _buildWeekList(BuildContext context) {
    return weeklyCountsForMonth.map((w) {
      return _DayRow(
          label: w['label'] as String, count: w['count'] as int, highlight: false);
    }).toList();
  }
}

class _DayRow extends StatelessWidget {
  final String label;
  final int count;
  final bool highlight;
  const _DayRow(
      {required this.label, required this.count, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      color: highlight
          ? colors.primaryContainer.withOpacity(0.4)
          : null,
      child: ListTile(
        dense: true,
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: highlight ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: count > 0 ? colors.secondary : Colors.grey[300],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '$count ${count == 1 ? 'activity' : 'activities'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: count > 0 ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Daily Bar Chart (week view)
// ─────────────────────────────────────────────

class _DailyBarChart extends StatelessWidget {
  final DateTime weekStart;
  final Map<String, int> dailyCounts;
  final DateFormat dayFormat;

  const _DailyBarChart({
    required this.weekStart,
    required this.dailyCounts,
    required this.dayFormat,
  });

  @override
  Widget build(BuildContext context) {
    final counts = List.generate(7, (i) {
      final day = weekStart.add(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      return dailyCounts[key] ?? 0;
    });

    final maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final count = counts[i];
          final barHeight = maxCount > 0 ? (count / maxCount) * 80.0 : 0.0;
          final isToday = day.year == DateTime.now().year &&
              day.month == DateTime.now().month &&
              day.day == DateTime.now().day;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text('$count',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.secondary)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: barHeight.clamp(4.0, 80.0),
                    decoration: BoxDecoration(
                      color: isToday
                          ? colors.primary
                          : colors.secondaryContainer,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dayFormat.format(day),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight:
                          isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday ? colors.primary : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Weekly Bar Chart (month view)
// ─────────────────────────────────────────────

class _WeeklyBarChart extends StatelessWidget {
  final List<Map<String, dynamic>> weeklyCounts;

  const _WeeklyBarChart({required this.weeklyCounts});

  @override
  Widget build(BuildContext context) {
    if (weeklyCounts.isEmpty) return const SizedBox.shrink();

    final counts =
        weeklyCounts.map((w) => w['count'] as int).toList();
    final maxCount = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(weeklyCounts.length, (i) {
          final label = weeklyCounts[i]['label'] as String;
          final count = counts[i];
          final barHeight = maxCount > 0 ? (count / maxCount) * 80.0 : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (count > 0)
                    Text('$count',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.secondary)),
                  const SizedBox(height: 2),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOut,
                    height: barHeight.clamp(4.0, 80.0),
                    decoration: BoxDecoration(
                      color: colors.secondaryContainer,
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Actions Tab
// ─────────────────────────────────────────────

class _ActionsTab extends StatelessWidget {
  final List<Map<String, dynamic>> actionBreakdown;
  final _ViewMode mode;
  final String periodLabel;

  const _ActionsTab({
    required this.actionBreakdown,
    required this.mode,
    required this.periodLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (actionBreakdown.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.touch_app_outlined, size: 56, color: Colors.grey[350]),
            const SizedBox(height: 12),
            Text(
              'No actions recorded for\n$periodLabel',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 15),
            ),
          ],
        ),
      );
    }

    final maxTotal = actionBreakdown
        .map((e) => e['total'] as int)
        .reduce((a, b) => a > b ? a : b);

    // Grand totals for the period
    final grandTotal =
        actionBreakdown.fold<int>(0, (sum, e) => sum + (e['total'] as int));
    final grandNew =
        actionBreakdown.fold<int>(0, (sum, e) => sum + (e['newCount'] as int));
    final grandContinued = grandTotal - grandNew;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Period label
        Text(
          '${mode == _ViewMode.week ? 'Week' : 'Month'}: $periodLabel',
          style: TextStyle(
              fontSize: 12,
              color: colors.onSurfaceVariant,
              fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),

        // Grand total summary card
        Card(
          color: colors.primaryContainer,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SummaryFigure(
                    value: grandTotal,
                    label: 'Total',
                    color: colors.onPrimaryContainer),
                _VerticalDivider(),
                _SummaryFigure(
                    value: grandNew,
                    label: 'New Prospects',
                    color: colors.primary),
                _VerticalDivider(),
                _SummaryFigure(
                    value: grandContinued,
                    label: 'Continued',
                    color: colors.onPrimaryContainer),
              ],
            ),
          ),
        ),

        // Legend
        Row(
          children: [
            _LegendDot(color: colors.primary, label: 'New prospect'),
            const SizedBox(width: 16),
            _LegendDot(
                color: colors.secondaryContainer, label: 'Continued'),
          ],
        ),
        const SizedBox(height: 12),

        // Per-action cards
        ...actionBreakdown.map((entry) {
          final action = entry['action'] as String;
          final total = entry['total'] as int;
          final newCount = entry['newCount'] as int;
          final continued = entry['continued'] as int;
          final newFraction = total > 0 ? newCount / total : 0.0;
          final shareOfTotal = grandTotal > 0 ? total / grandTotal : 0.0;

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(action,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$total total',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: colors.onSurfaceVariant),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${(shareOfTotal * 100).round()}%',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Stacked bar: new | continued
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: SizedBox(
                      height: 10,
                      child: Row(
                        children: [
                          Flexible(
                            flex: (newFraction * 1000).round(),
                            child: Container(color: colors.primary),
                          ),
                          Flexible(
                            flex: ((1 - newFraction) * 1000).round(),
                            child: Container(color: colors.secondaryContainer),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),

                  Row(
                    children: [
                      _CountChip(
                        label: 'New',
                        count: newCount,
                        color: colors.primary,
                        textColor: colors.onPrimary,
                      ),
                      const SizedBox(width: 8),
                      _CountChip(
                        label: 'Continued',
                        count: continued,
                        color: colors.secondaryContainer,
                        textColor: colors.onSecondaryContainer,
                      ),
                    ],
                  ),

                  // Relative width bar vs busiest action
                  if (maxTotal > 1) ...[
                    const SizedBox(height: 8),
                    LayoutBuilder(builder: (ctx, constraints) {
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: (total / maxTotal) * constraints.maxWidth,
                          height: 4,
                          decoration: BoxDecoration(
                            color: colors.primary.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Details Tab
// ─────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final List<Prospect> newProspects;
  final List<ProspectEvent> activities;
  final DateFormat fullFormat;

  const _DetailsTab({
    required this.newProspects,
    required this.activities,
    required this.fullFormat,
  });

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(text: 'New Prospects (${newProspects.length})'),
              Tab(text: 'Activities (${activities.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                newProspects.isEmpty
                    ? _emptyState(
                        context, Icons.person_search, 'No new prospects')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: newProspects.length,
                        itemBuilder: (ctx, i) {
                          final p = newProspects[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                  child: Text(p.name[0].toUpperCase())),
                              title: Text(p.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle:
                                  Text('${p.connectionType} • ${p.place}'),
                              trailing: Text(
                                fullFormat.format(p.createdAt),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                              onTap: () => Navigator.push(
                                ctx,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProspectDetailScreen(prospect: p),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                activities.isEmpty
                    ? _emptyState(
                        context, Icons.event_busy, 'No activities')
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: activities.length,
                        itemBuilder: (ctx, i) {
                          final e = activities[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(ctx)
                                    .colorScheme
                                    .secondaryContainer,
                                child: Icon(Icons.event_note,
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .secondary,
                                    size: 20),
                              ),
                              title: Text(e.lastActionTaken,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(e.remarks,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              trailing: Text(
                                fullFormat.format(e.dateOfInteraction),
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey),
                              ),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey[350]),
          const SizedBox(height: 12),
          Text(message,
              style: TextStyle(color: Colors.grey[500], fontSize: 15)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────

class _SummaryFigure extends StatelessWidget {
  final int value;
  final String label;
  final Color color;
  const _SummaryFigure(
      {required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value',
            style: TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(fontSize: 11, color: color.withOpacity(0.8))),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 36, color: Colors.black12);
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _CountChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final Color textColor;
  const _CountChip(
      {required this.label,
      required this.count,
      required this.color,
      required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(20)),
      child: Text('$count $label',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final Color bgColor;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: bgColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text('$count',
                style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: color,
                    height: 1.0)),
            const SizedBox(height: 4),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          ],
        ),
      ),
    );
  }
}
