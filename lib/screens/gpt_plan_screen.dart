import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/weekly_plan.dart';
import '../models/prospect.dart';
import '../providers/weekly_plan_provider.dart';
import '../providers/prospect_provider.dart';
import '../providers/enum_provider.dart';
import '../database/database_helper.dart';
import 'event_form_screen.dart';
import 'prospect_detail_screen.dart';

/// Goal Planning Tracker — pick prospects, assign actions, track the week.
class GptPlanScreen extends StatefulWidget {
  const GptPlanScreen({super.key});

  @override
  State<GptPlanScreen> createState() => _GptPlanScreenState();
}

class _GptPlanScreenState extends State<GptPlanScreen> {
  static final _dayFmt  = DateFormat('MMM d');
  static final _dateFmt = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WeeklyPlanProvider>().load();
      context.read<ProspectProvider>().loadProspects();
      context.read<EnumProvider>().loadEnums();
    });
  }

  String _weekLabel(WeeklyPlanProvider p) =>
      '${_dayFmt.format(p.weekStart)} – ${_dayFmt.format(p.weekEnd)}';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: Consumer<WeeklyPlanProvider>(
        builder: (context, planner, _) {
          return CustomScrollView(
            slivers: [
              // ── App bar ──────────────────────────────────────────────────
              SliverAppBar(
                pinned: true,
                expandedHeight: 140,
                backgroundColor: colors.surface,
                flexibleSpace: FlexibleSpaceBar(
                  background: _PlannerHeader(planner: planner),
                ),
                title: const Text(
                  'Goal Planner',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.today_outlined),
                    tooltip: 'Jump to this week',
                    onPressed: () {
                      context.read<WeeklyPlanProvider>()
                          .jumpToWeek(WeeklyPlanProvider.currentWeekSat());
                    },
                  ),
                ],
              ),

              // ── Week navigation bar ──────────────────────────────────────
              SliverToBoxAdapter(
                child: _WeekNavBar(
                  label: _weekLabel(planner),
                  onPrev: () => context.read<WeeklyPlanProvider>().goToPreviousWeek(),
                  onNext: () => context.read<WeeklyPlanProvider>().goToNextWeek(),
                  onPick: () => _pickWeek(context, planner),
                ),
              ),

              // ── Action count summary ─────────────────────────────────────
              SliverToBoxAdapter(
                child: _ActionSummaryBar(planner: planner),
              ),

              if (planner.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                // ── From Your Records ────────────────────────────────────
                if (planner.suggested.isNotEmpty) ...[
                  _sectionHeader(context, Icons.history_outlined,
                      'From Your Records', Colors.teal,
                      subtitle: 'Prospects whose next follow-up falls this week'),
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => _SuggestedCard(
                        item: planner.suggested[i],
                        alreadyAdded: planner.isAlreadyPlanned(
                            planner.suggested[i].prospectId),
                        onAdd: () => _addSuggested(
                            ctx, planner, planner.suggested[i]),
                        onRecord: () => _showEditNextPlanSheet(
                            ctx,
                            planner.suggested[i].prospectId,
                            planner.suggested[i].prospectName),
                        onTap: () => _openProspect(
                            ctx, planner.suggested[i].prospectId),
                      ),
                      childCount: planner.suggested.length,
                    ),
                  ),
                ],

                // ── My Plan ──────────────────────────────────────────────
                _sectionHeader(context, Icons.checklist_rounded,
                    'My Plan', colors.primary,
                    subtitle: '${planner.totalDone}/${planner.plans.length} done'),

                if (planner.plans.isEmpty)
                  SliverToBoxAdapter(
                    child: _EmptyPlan(
                      onAdd: () => _showAddProspectSheet(context, planner),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final plan = planner.plans[i];
                        return _PlanCard(
                          plan: plan,
                          onToggle: () =>
                              context.read<WeeklyPlanProvider>().toggleDone(plan),
                          onDelete: () =>
                              context.read<WeeklyPlanProvider>().deletePlan(plan.id),
                          onSubmit: () => _submitActivity(ctx, plan),
                          onEditNextPlan: (name) => _showEditNextPlanSheet(
                              ctx, plan.prospectId, name),
                          onTap: () => _openProspect(ctx, plan.prospectId),
                        );
                      },
                      childCount: planner.plans.length,
                    ),
                  ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ],
          );
        },
      ),

      // FAB to add a prospect to the plan
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddProspectSheet(
            context, context.read<WeeklyPlanProvider>()),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Add to Plan'),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, IconData icon, String title,
      Color color, {String? subtitle}) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: color),
            ),
            if (subtitle != null) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickWeek(BuildContext context, WeeklyPlanProvider planner) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: planner.weekStart,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      helpText: 'Select any day in the week',
    );
    if (picked == null) return;
    // Snap to the Saturday of the picked week
    final daysSinceSat = (picked.weekday + 1) % 7;
    final sat = picked.subtract(Duration(days: daysSinceSat));
    if (context.mounted) {
      context.read<WeeklyPlanProvider>().jumpToWeek(sat);
    }
  }

  Future<void> _addSuggested(BuildContext context, WeeklyPlanProvider planner,
      SuggestedPlan s) async {
    await planner.addPlan(
      prospectId: s.prospectId,
      plannedAction: s.plannedAction,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${s.prospectName} added to your plan!')),
      );
    }
  }

  void _showEditNextPlanSheet(BuildContext context, String prospectId,
      String prospectName) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditNextPlanSheet(
        prospectId: prospectId,
        prospectName: prospectName,
        onSaved: () => context.read<WeeklyPlanProvider>().load(),
      ),
    );
  }

  void _openProspect(BuildContext context, String prospectId) {
    final prospects = context.read<ProspectProvider>().prospects;
    final prospect = prospects.where((p) => p.id == prospectId).firstOrNull;
    if (prospect == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => ProspectDetailScreen(prospect: prospect)),
    ).then((_) => context.read<WeeklyPlanProvider>().load());
  }

  /// Opens the event form and marks the plan item as done on return.
  void _submitActivity(BuildContext context, WeeklyPlan plan) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EventFormScreen(prospectId: plan.prospectId),
      ),
    ).then((_) async {
      if (!context.mounted) return;
      final planner = context.read<WeeklyPlanProvider>();
      // Mark as done only if not already done
      if (!plan.isDone) await planner.toggleDone(plan);
      await planner.load();
    });
  }

  void _showAddProspectSheet(BuildContext context, WeeklyPlanProvider planner) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddProspectSheet(planner: planner),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _PlannerHeader extends StatelessWidget {
  final WeeklyPlanProvider planner;
  const _PlannerHeader({required this.planner});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final done    = planner.totalDone;
    final total   = planner.plans.length;
    final pct     = total == 0 ? 0.0 : done / total;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colors.primaryContainer, colors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 12),
          child: Row(
            children: [
              // Progress ring
              _ProgressCircle(pct: pct, done: done, total: total),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Goal Planning Tracker',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${planner.suggested.length} follow-ups due  •  ${planner.plans.length} planned',
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  final double pct;
  final int done;
  final int total;
  const _ProgressCircle(
      {required this.pct, required this.done, required this.total});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: pct,
            strokeWidth: 6,
            backgroundColor: colors.outlineVariant,
            color: colors.primary,
          ),
          Text(
            total == 0 ? '–' : '$done/$total',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: colors.primary),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action count summary bar
// ─────────────────────────────────────────────────────────────────────────────

class _ActionSummaryBar extends StatelessWidget {
  final WeeklyPlanProvider planner;
  const _ActionSummaryBar({required this.planner});

  static Map<String, int> _toCounts(Iterable<String> actions) {
    final counts = <String, int>{};
    for (final a in actions) {
      counts[a] = (counts[a] ?? 0) + 1;
    }
    return counts;
  }

  @override
  Widget build(BuildContext context) {
    final planCounts    = _toCounts(planner.plans.map((p) => p.plannedAction));
    final recordCounts  = _toCounts(planner.suggested.map((s) => s.plannedAction));

    final bothEmpty = planCounts.isEmpty && recordCounts.isEmpty;
    if (bothEmpty) return const SizedBox.shrink();

    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (planCounts.isNotEmpty) ...[
            _SummarySection(
              label: 'MY PLAN',
              counts: planCounts,
              chipColor: Theme.of(context).colorScheme.primaryContainer,
              badgeColor: Theme.of(context).colorScheme.primary,
              textColor: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ],
          if (planCounts.isNotEmpty && recordCounts.isNotEmpty)
            const SizedBox(height: 10),
          if (recordCounts.isNotEmpty) ...[
            _SummarySection(
              label: 'FROM YOUR RECORDS',
              counts: recordCounts,
              chipColor: Colors.teal.shade50,
              badgeColor: Colors.teal.shade600,
              textColor: Colors.teal.shade900,
            ),
          ],
        ],
      ),
    );
  }
}

class _SummarySection extends StatelessWidget {
  final String label;
  final Map<String, int> counts;
  final Color chipColor;
  final Color badgeColor;
  final Color textColor;

  const _SummarySection({
    required this.label,
    required this.counts,
    required this.chipColor,
    required this.badgeColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: sorted.map((entry) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: chipColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.key,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: badgeColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${entry.value}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Week nav bar
// ─────────────────────────────────────────────────────────────────────────────

class _WeekNavBar extends StatelessWidget {
  final String label;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onPick;
  const _WeekNavBar(
      {required this.label,
      required this.onPrev,
      required this.onNext,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left),
              visualDensity: VisualDensity.compact),
          GestureDetector(
            onTap: onPick,
            child: Row(
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(width: 4),
                Icon(Icons.arrow_drop_down,
                    size: 18, color: colors.onSurfaceVariant),
              ],
            ),
          ),
          IconButton(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
              visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Suggested plan card (from events)
// ─────────────────────────────────────────────────────────────────────────────

class _SuggestedCard extends StatelessWidget {
  final SuggestedPlan item;
  final bool alreadyAdded;
  final VoidCallback onAdd;
  final VoidCallback onRecord;
  final VoidCallback onTap;
  const _SuggestedCard(
      {required this.item,
      required this.alreadyAdded,
      required this.onAdd,
      required this.onRecord,
      required this.onTap});

  static final _fmt = DateFormat('MMM d');

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.teal.withOpacity(0.3)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          radius: 20,
          backgroundColor: Colors.teal.withOpacity(0.12),
          child: Text(
            item.prospectName[0].toUpperCase(),
            style: const TextStyle(
                color: Colors.teal, fontWeight: FontWeight.w700),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(item.prospectName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (item.relationship != null)
              _RelBadge(rel: item.relationship!),
          ],
        ),
        subtitle: Text(
          '${item.plannedAction}  •  Due ${_fmt.format(item.nextEngagementDate)}',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
        trailing: alreadyAdded
            ? Icon(Icons.check_circle, color: colors.primary, size: 20)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.teal, size: 22),
                    tooltip: 'Add to plan',
                    visualDensity: VisualDensity.compact,
                    onPressed: onAdd,
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_calendar_outlined,
                        color: colors.primary, size: 22),
                    tooltip: 'Update next plan',
                    visualDensity: VisualDensity.compact,
                    onPressed: onRecord,
                  ),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Plan card (manually added)
// ─────────────────────────────────────────────────────────────────────────────

class _PlanCard extends StatelessWidget {
  final WeeklyPlan plan;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  final VoidCallback onTap;
  final void Function(String prospectName) onEditNextPlan;
  const _PlanCard(
      {required this.plan,
      required this.onToggle,
      required this.onDelete,
      required this.onSubmit,
      required this.onTap,
      required this.onEditNextPlan});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Consumer<ProspectProvider>(
      builder: (context, pp, _) {
        final prospect = pp.prospects
            .where((p) => p.id == plan.prospectId)
            .firstOrNull;
        final name = prospect?.name ?? plan.prospectId;
        final rel  = prospect?.relationship;

        return Dismissible(
          key: Key(plan.id),
          direction: DismissDirection.endToStart,
          background: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete_outline, color: Colors.red),
          ),
          onDismissed: (_) => onDelete(),
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: plan.isDone
                    ? colors.primary.withOpacity(0.4)
                    : colors.outlineVariant,
              ),
            ),
            child: ListTile(
              onTap: onTap,
              leading: GestureDetector(
                onTap: onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: plan.isDone
                        ? colors.primary
                        : colors.surfaceContainerHighest,
                    border: plan.isDone
                        ? null
                        : Border.all(color: colors.outline),
                  ),
                  child: plan.isDone
                      ? const Icon(Icons.check,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: plan.isDone
                            ? TextDecoration.lineThrough
                            : null,
                        color: plan.isDone
                            ? colors.onSurfaceVariant
                            : colors.onSurface,
                      ),
                    ),
                  ),
                  if (rel != null) _RelBadge(rel: rel),
                ],
              ),
              subtitle: Text(
                plan.plannedAction,
                style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                    decoration:
                        plan.isDone ? TextDecoration.lineThrough : null),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Remove from plan (always visible)
                  IconButton(
                    icon: Icon(Icons.remove_circle_outline,
                        color: Colors.red.shade400, size: 22),
                    tooltip: 'Remove from plan',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDelete,
                  ),
                  if (!plan.isDone) ...[
                    // Submit final activity → opens event form
                    IconButton(
                      icon: Icon(Icons.task_alt,
                          color: Colors.green.shade600, size: 22),
                      tooltip: 'Submit activity',
                      visualDensity: VisualDensity.compact,
                      onPressed: onSubmit,
                    ),
                    // Update next plan date / action
                    IconButton(
                      icon: Icon(Icons.edit_calendar_outlined,
                          color: colors.primary, size: 22),
                      tooltip: 'Update next plan',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => onEditNextPlan(name),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyPlan extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyPlan({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.calendar_today_outlined,
              size: 48, color: colors.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(
            'No prospects planned yet',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap "Add to Plan" to select prospects and actions for this week.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 13, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Prospect to Plan'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Add prospect bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _AddProspectSheet extends StatefulWidget {
  final WeeklyPlanProvider planner;
  const _AddProspectSheet({required this.planner});

  @override
  State<_AddProspectSheet> createState() => _AddProspectSheetState();
}

class _AddProspectSheetState extends State<_AddProspectSheet> {
  Prospect? _selectedProspect;
  String? _selectedAction;
  final _searchCtrl = TextEditingController();
  final _notesCtrl  = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors   = Theme.of(context).colorScheme;
    final prospects = context.watch<ProspectProvider>().prospects
        .where((p) =>
            p.name.toLowerCase().contains(_query.toLowerCase()))
        .toList();
    final actions = context.watch<EnumProvider>().getValues('next_plan_of_action');

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text('Add to This Week\'s Plan',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                hintText: 'Search prospect...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),

          // Prospect list
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: prospects.length,
              itemBuilder: (ctx, i) {
                final p = prospects[i];
                final alreadyAdded = widget.planner.isAlreadyPlanned(p.id);
                return ListTile(
                  dense: true,
                  selected: _selectedProspect?.id == p.id,
                  selectedTileColor: colors.primaryContainer.withOpacity(0.3),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: alreadyAdded
                        ? colors.primary.withOpacity(0.15)
                        : colors.surfaceContainerHighest,
                    child: alreadyAdded
                        ? Icon(Icons.check, size: 14, color: colors.primary)
                        : Text(p.name[0],
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  title: Text(p.name,
                      style: const TextStyle(fontSize: 13)),
                  subtitle: p.relationship != null
                      ? Text(p.relationship!,
                          style: TextStyle(
                              fontSize: 11,
                              color: colors.onSurfaceVariant))
                      : null,
                  trailing: alreadyAdded
                      ? Text('Added',
                          style: TextStyle(
                              fontSize: 11, color: colors.primary))
                      : null,
                  onTap: alreadyAdded
                      ? null
                      : () => setState(
                          () => _selectedProspect = p),
                );
              },
            ),
          ),

          // Action picker
          if (_selectedProspect != null) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: DropdownButtonFormField<String>(
                value: _selectedAction,
                decoration: const InputDecoration(
                  labelText: 'Planned Action *',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: actions
                    .map((a) =>
                        DropdownMenuItem(value: a, child: Text(a)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedAction = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: (_selectedProspect != null &&
                            _selectedAction != null)
                        ? () async {
                            await widget.planner.addPlan(
                              prospectId: _selectedProspect!.id,
                              plannedAction: _selectedAction!,
                              notes: _notesCtrl.text.trim().isEmpty
                                  ? null
                                  : _notesCtrl.text.trim(),
                            );
                            if (context.mounted) Navigator.pop(context);
                          }
                        : null,
                    child: const Text('Add to Plan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit Next Plan bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditNextPlanSheet extends StatefulWidget {
  final String prospectId;
  final String prospectName;
  final VoidCallback onSaved;

  const _EditNextPlanSheet({
    required this.prospectId,
    required this.prospectName,
    required this.onSaved,
  });

  @override
  State<_EditNextPlanSheet> createState() => _EditNextPlanSheetState();
}

class _EditNextPlanSheetState extends State<_EditNextPlanSheet> {
  static final _dateFmt = DateFormat('MMM d, yyyy');

  bool _loading = true;
  bool _saving = false;
  bool _noEvents = false;

  String? _selectedAction;
  DateTime? _selectedDate;
  String? _eventId;

  @override
  void initState() {
    super.initState();
    _loadLatestEvent();
  }

  Future<void> _loadLatestEvent() async {
    final event = await DatabaseHelper.instance
        .getLatestEventForProspect(widget.prospectId);
    if (!mounted) return;
    if (event == null) {
      setState(() { _loading = false; _noEvents = true; });
      return;
    }
    setState(() {
      _loading = false;
      _eventId = event.eventId;
      _selectedAction = event.nextPlanOfAction;
      _selectedDate = event.nextEngagementDate;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (_eventId == null || _selectedAction == null || _selectedDate == null) return;
    setState(() => _saving = true);

    // Load the full event so we can copyWith safely
    final latest = await DatabaseHelper.instance
        .getLatestEventForProspect(widget.prospectId);
    if (latest == null || !mounted) { setState(() => _saving = false); return; }

    final updated = latest.copyWith(
      nextPlanOfAction: _selectedAction,
      nextEngagementDate: _selectedDate,
    );
    await DatabaseHelper.instance.updateEvent(updated);

    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final actions =
        context.watch<EnumProvider>().getValues('next_plan_of_action');

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                    color: colors.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Update Next Plan',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: colors.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.prospectName,
                    style: TextStyle(
                        fontSize: 13, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_noEvents)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Text(
                  'No events recorded yet for this prospect.\nRecord an event first to set a next plan.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else ...[
              // Next Plan of Action dropdown
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: DropdownButtonFormField<String>(
                  value: actions.contains(_selectedAction)
                      ? _selectedAction
                      : null,
                  decoration: const InputDecoration(
                    labelText: 'Next Plan of Action',
                    border: OutlineInputBorder(),
                  ),
                  items: actions
                      .map((a) => DropdownMenuItem(value: a, child: Text(a)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedAction = v),
                ),
              ),
              const SizedBox(height: 14),

              // Action Date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(8),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Action Date',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                    child: Text(
                      _selectedDate != null
                          ? _dateFmt.format(_selectedDate!)
                          : 'Tap to pick a date',
                      style: TextStyle(
                        fontSize: 15,
                        color: _selectedDate != null
                            ? colors.onSurface
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: (_selectedAction != null &&
                                _selectedDate != null &&
                                !_saving)
                            ? _save
                            : null,
                        child: _saving
                            ? const SizedBox(
                                width: 18, height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white),
                              )
                            : const Text('Save'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relationship badge
// ─────────────────────────────────────────────────────────────────────────────

class _RelBadge extends StatelessWidget {
  final String rel;
  const _RelBadge({required this.rel});

  static Color _bg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFFFCDD2);
      case 'Warm': return const Color(0xFFFFE0B2);
      case 'Cold': return const Color(0xFFBBDEFB);
      default:     return const Color(0xFFE0E0E0);
    }
  }

  static Color _fg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFC62828);
      case 'Warm': return const Color(0xFFE65100);
      case 'Cold': return const Color(0xFF1565C0);
      default:     return const Color(0xFF757575);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: _bg(rel),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(rel,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: _fg(rel))),
    );
  }
}
