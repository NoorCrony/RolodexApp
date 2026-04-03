import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/prospect.dart';
import '../models/event.dart';
import '../providers/prospect_provider.dart';
import '../providers/event_provider.dart';
import 'prospect_form_screen.dart';
import 'event_form_screen.dart';

class ProspectDetailScreen extends StatefulWidget {
  final Prospect prospect;
  const ProspectDetailScreen({super.key, required this.prospect});

  @override
  State<ProspectDetailScreen> createState() => _ProspectDetailScreenState();
}

class _ProspectDetailScreenState extends State<ProspectDetailScreen> {
  static final _dateFmt  = DateFormat('MMM d, yyyy');
  static final _shortFmt = DateFormat('MMM d');

  // ── Relationship colours ─────────────────────────────────────────────────
  static Color _relBg(String? r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFFFCDD2);
      case 'Warm': return const Color(0xFFFFE0B2);
      case 'Cold': return const Color(0xFFBBDEFB);
      case 'DKD':  return const Color(0xFFE0E0E0);
      default:     return const Color(0xFFE8EAF6);
    }
  }

  static Color _relFg(String? r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFC62828);
      case 'Warm': return const Color(0xFFE65100);
      case 'Cold': return const Color(0xFF1565C0);
      case 'DKD':  return const Color(0xFF616161);
      default:     return const Color(0xFF3949AB);
    }
  }

  // ── Action colours & icons ───────────────────────────────────────────────
  static Color _actionColor(String action) {
    final a = action.toLowerCase();
    if (a.contains('call'))    return const Color(0xFF43A047);
    if (a.contains('message')) return const Color(0xFF1E88E5);
    if (a.contains('met') || a.contains('person')) return const Color(0xFF8E24AA);
    if (a.contains('email'))   return const Color(0xFFFB8C00);
    if (a.contains('present')) return const Color(0xFF00ACC1);
    return const Color(0xFF78909C);
  }

  static IconData _actionIcon(String action) {
    final a = action.toLowerCase();
    if (a.contains('call'))    return Icons.phone_in_talk;
    if (a.contains('message')) return Icons.chat_bubble_outline;
    if (a.contains('met') || a.contains('person')) return Icons.people_outline;
    if (a.contains('email'))   return Icons.mail_outline;
    if (a.contains('present')) return Icons.present_to_all;
    return Icons.event_note;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EventProvider>().loadEvents(widget.prospect.id);
    });
  }

  Future<void> _deleteProspect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prospect'),
        content: Text('Delete "${widget.prospect.name}" and all their events?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ProspectProvider>().deleteProspect(widget.prospect.id);
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _launchUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url.startsWith('http') ? url : 'https://$url');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final p      = widget.prospect;
    final colors = Theme.of(context).colorScheme;
    final rel    = p.relationship;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [

          // ── Collapsing profile header ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colors.surface,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit',
                onPressed: () async {
                  await Navigator.push(context, MaterialPageRoute(
                    builder: (_) => ProspectFormScreen(prospect: p),
                  ));
                  if (mounted) context.read<ProspectProvider>().loadProspects();
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Delete',
                onPressed: _deleteProspect,
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _ProspectHeader(
                prospect: p,
                relBg: _relBg(rel),
                relFg: _relFg(rel),
                onLaunch: _launchUrl,
              ),
            ),
          ),

          // ── Info chips row ─────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _InfoChipsRow(prospect: p),
          ),

          // ── Social links row ───────────────────────────────────────────
          if ((p.instagramLink?.isNotEmpty == true) ||
              (p.linkedinLink?.isNotEmpty == true) ||
              (p.facebookLink?.isNotEmpty == true))
            SliverToBoxAdapter(
              child: _SocialLinksRow(prospect: p, onLaunch: _launchUrl),
            ),

          // ── Interaction History header ─────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer<EventProvider>(
                    builder: (_, ep, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Interaction History',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w700)),
                        Text(
                          '${ep.events.length} event${ep.events.length == 1 ? '' : 's'}',
                          style: TextStyle(
                              fontSize: 12, color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventFormScreen(prospectId: p.id),
                      ),
                    ).then((_) {
                      if (mounted) context.read<EventProvider>().loadEvents(p.id);
                    }),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Record'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Timeline list ──────────────────────────────────────────────
          Consumer<EventProvider>(
            builder: (context, ep, _) {
              if (ep.isLoading) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (ep.events.isEmpty) {
                return SliverToBoxAdapter(child: _EmptyHistory());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final event   = ep.events[i];
                    final isFirst = i == 0;
                    final isLast  = i == ep.events.length - 1;

                    return _TimelineEventCard(
                      event: event,
                      isFirst: isFirst,
                      isLast: isLast,
                      dateFmt: _dateFmt,
                      shortFmt: _shortFmt,
                      actionColor: _actionColor(event.lastActionTaken),
                      actionIcon: _actionIcon(event.lastActionTaken),
                      onEdit: () => Navigator.push(
                        ctx,
                        MaterialPageRoute(
                          builder: (_) => EventFormScreen(
                            prospectId: p.id,
                            event: event,
                          ),
                        ),
                      ).then((_) {
                        if (mounted) ep.loadEvents(p.id);
                      }),
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
                          context: ctx,
                          builder: (d) => AlertDialog(
                            title: const Text('Delete Event'),
                            content: const Text('Delete this interaction?'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(d, false),
                                  child: const Text('Cancel')),
                              TextButton(
                                onPressed: () => Navigator.pop(d, true),
                                style: TextButton.styleFrom(
                                    foregroundColor: Colors.red),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) ep.deleteEvent(event.eventId, p.id);
                      },
                    );
                  },
                  childCount: ep.events.length,
                ),
              );
            },
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Prospect profile header (inside FlexibleSpaceBar)
// ─────────────────────────────────────────────────────────────────────────────

class _ProspectHeader extends StatelessWidget {
  final Prospect prospect;
  final Color relBg;
  final Color relFg;
  final Future<void> Function(String?) onLaunch;

  const _ProspectHeader({
    required this.prospect,
    required this.relBg,
    required this.relFg,
    required this.onLaunch,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = prospect;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [relBg, colors.surface],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Avatar
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: relBg,
                  shape: BoxShape.circle,
                  border: Border.all(color: relFg.withOpacity(0.4), width: 2),
                ),
                child: Center(
                  child: Text(
                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: relFg,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // Name
                    Text(
                      p.name,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    // Phone
                    Row(
                      children: [
                        Icon(Icons.phone_outlined,
                            size: 13, color: colors.onSurfaceVariant),
                        const SizedBox(width: 4),
                        Text(
                          p.contactNumber,
                          style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Relationship badge
                    if (p.relationship != null && p.relationship!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: relFg,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          p.relationship!,
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
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

class _SocialBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _SocialBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.7),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 16, color: Colors.grey[700]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Social links row
// ─────────────────────────────────────────────────────────────────────────────

class _SocialLinksRow extends StatelessWidget {
  final Prospect prospect;
  final Future<void> Function(String?) onLaunch;
  const _SocialLinksRow({required this.prospect, required this.onLaunch});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final p = prospect;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          if (p.instagramLink?.isNotEmpty == true)
            _SocialButton(
              icon: Icons.camera_alt_outlined,
              label: 'Instagram',
              color: const Color(0xFFE1306C),
              bgColor: const Color(0xFFFCE4EC),
              onTap: () => onLaunch(p.instagramLink),
            ),
          if (p.instagramLink?.isNotEmpty == true &&
              (p.linkedinLink?.isNotEmpty == true ||
                  p.facebookLink?.isNotEmpty == true))
            const SizedBox(width: 10),
          if (p.linkedinLink?.isNotEmpty == true)
            _SocialButton(
              icon: Icons.work_outline,
              label: 'LinkedIn',
              color: const Color(0xFF0077B5),
              bgColor: const Color(0xFFE3F2FD),
              onTap: () => onLaunch(p.linkedinLink),
            ),
          if (p.linkedinLink?.isNotEmpty == true &&
              p.facebookLink?.isNotEmpty == true)
            const SizedBox(width: 10),
          if (p.facebookLink?.isNotEmpty == true)
            _SocialButton(
              icon: Icons.facebook,
              label: 'Facebook',
              color: const Color(0xFF1877F2),
              bgColor: const Color(0xFFE8F0FE),
              onTap: () => onLaunch(p.facebookLink),
            ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info chips row (connection · place · status)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoChipsRow extends StatelessWidget {
  final Prospect prospect;
  const _InfoChipsRow({required this.prospect});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _InfoChip(
              icon: Icons.link,
              label: prospect.connectionType,
              colors: colors),
          _InfoChip(
              icon: Icons.place_outlined,
              label: prospect.place,
              colors: colors),
          _InfoChip(
              icon: Icons.work_outline,
              label: prospect.currentStatus,
              colors: colors),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final ColorScheme colors;
  const _InfoChip(
      {required this.icon, required this.label, required this.colors});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: colors.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: colors.onSurface),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty history state
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyHistory extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Icon(Icons.timeline, size: 56, color: colors.outlineVariant),
          const SizedBox(height: 12),
          Text('No interactions yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text('Tap Record to log the first one.',
              style: TextStyle(fontSize: 13, color: colors.outlineVariant)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Timeline event card — collapsible, colour-coded
// ─────────────────────────────────────────────────────────────────────────────

class _TimelineEventCard extends StatefulWidget {
  final ProspectEvent event;
  final bool isFirst;
  final bool isLast;
  final DateFormat dateFmt;
  final DateFormat shortFmt;
  final Color actionColor;
  final IconData actionIcon;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TimelineEventCard({
    required this.event,
    required this.isFirst,
    required this.isLast,
    required this.dateFmt,
    required this.shortFmt,
    required this.actionColor,
    required this.actionIcon,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_TimelineEventCard> createState() => _TimelineEventCardState();
}

class _TimelineEventCardState extends State<_TimelineEventCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _ctrl;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _expanded = widget.isFirst;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 220));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    if (_expanded) _ctrl.value = 1.0;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    _expanded ? _ctrl.forward() : _ctrl.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final e      = widget.event;
    final color  = widget.actionColor;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 16, bottom: 0),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ── Timeline spine ─────────────────────────────────────────
            SizedBox(
              width: 32,
              child: Column(
                children: [
                  // Dot
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 18),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.35),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  // Vertical line
                  if (!widget.isLast)
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 2,
                          color: colors.outlineVariant.withOpacity(0.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(width: 10),

            // ── Card ───────────────────────────────────────────────────
            Expanded(
              child: GestureDetector(
                onTap: _toggle,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: widget.isFirst
                          ? color.withOpacity(0.5)
                          : colors.outlineVariant.withOpacity(0.4),
                      width: widget.isFirst ? 1.5 : 1,
                    ),
                    boxShadow: widget.isFirst
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      // ── Card header ──────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 8, 8),
                        child: Row(
                          children: [
                            // Action icon chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(widget.actionIcon,
                                      size: 13, color: color),
                                  const SizedBox(width: 4),
                                  Text(
                                    e.lastActionTaken,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Date
                            Text(
                              widget.shortFmt.format(e.dateOfInteraction),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Expand/collapse chevron
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              size: 18,
                              color: colors.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),

                      // ── Collapsed preview ────────────────────────────
                      if (!_expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                          child: Text(
                            e.remarks.isNotEmpty ? e.remarks : e.lastInteractionConvo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ),

                      // ── Expanded body ────────────────────────────────
                      FadeTransition(
                        opacity: _fade,
                        child: SizeTransition(
                          sizeFactor: _fade,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1, indent: 12, endIndent: 12),
                              const SizedBox(height: 8),
                              if (e.remarks.isNotEmpty)
                                _Field(
                                    icon: Icons.notes,
                                    label: 'Remarks',
                                    value: e.remarks,
                                    color: colors),
                              if (e.lastInteractionConvo.isNotEmpty)
                                _Field(
                                    icon: Icons.chat_outlined,
                                    label: 'Conversation',
                                    value: e.lastInteractionConvo,
                                    color: colors),

                              // Next plan pill
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 7),
                                  decoration: BoxDecoration(
                                    color: colors.secondaryContainer
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.arrow_forward,
                                          size: 14,
                                          color: colors.secondary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${e.nextPlanOfAction}  ·  ${widget.dateFmt.format(e.nextEngagementDate)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: colors.onSecondaryContainer,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // Edit / Delete actions
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(8, 0, 8, 6),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    TextButton.icon(
                                      onPressed: widget.onEdit,
                                      icon: const Icon(
                                          Icons.edit_outlined,
                                          size: 15),
                                      label: const Text('Edit',
                                          style: TextStyle(fontSize: 12)),
                                      style: TextButton.styleFrom(
                                          visualDensity:
                                              VisualDensity.compact),
                                    ),
                                    TextButton.icon(
                                      onPressed: widget.onDelete,
                                      icon: const Icon(
                                          Icons.delete_outline,
                                          size: 15,
                                          color: Colors.red),
                                      label: const Text('Delete',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.red)),
                                      style: TextButton.styleFrom(
                                          visualDensity:
                                              VisualDensity.compact),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Single field row inside expanded card ──────────────────────────────────

class _Field extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ColorScheme color;

  const _Field({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color.onSurfaceVariant),
          const SizedBox(width: 6),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Relationship chip (kept for backward compat with other widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _RelationshipChip extends StatelessWidget {
  final String relationship;
  const _RelationshipChip({required this.relationship});

  static Color _bg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFFFE0E0);
      case 'Warm': return const Color(0xFFFFEDD5);
      case 'Cold': return const Color(0xFFDDEEFF);
      case 'DKD':  return const Color(0xFFEEEEEE);
      default:     return const Color(0xFFEEEEEE);
    }
  }

  static Color _fg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFB71C1C);
      case 'Warm': return const Color(0xFFE65100);
      case 'Cold': return const Color(0xFF1565C0);
      case 'DKD':  return const Color(0xFF616161);
      default:     return const Color(0xFF616161);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
          color: _bg(relationship),
          borderRadius: BorderRadius.circular(12)),
      child: Text(
        relationship,
        style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _fg(relationship)),
      ),
    );
  }
}
