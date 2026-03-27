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

/// Detail screen showing a prospect's info and event history.
class ProspectDetailScreen extends StatefulWidget {
  final Prospect prospect;

  const ProspectDetailScreen({super.key, required this.prospect});

  @override
  State<ProspectDetailScreen> createState() => _ProspectDetailScreenState();
}

class _ProspectDetailScreenState extends State<ProspectDetailScreen> {
  final _dateFormat = DateFormat('MMM dd, yyyy');

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
        content: Text('Are you sure you want to delete "${widget.prospect.name}" and all their events?'),
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
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prospect = widget.prospect;

    return Scaffold(
      appBar: AppBar(
        title: Text(prospect.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProspectFormScreen(prospect: prospect),
                ),
              );
              // Refresh prospect data after editing
              if (mounted) {
                context.read<ProspectProvider>().loadProspects();
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            tooltip: 'Delete',
            onPressed: _deleteProspect,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Prospect info card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ID badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      prospect.id,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _infoRow(Icons.person, 'Name', prospect.name),
                  _infoRow(Icons.link, 'Connection', prospect.connectionType),
                  _infoRow(Icons.place, 'Place', prospect.place),
                  _infoRow(Icons.work, 'Status', prospect.currentStatus),
                  _infoRow(Icons.phone, 'Phone', prospect.contactNumber),
                  if (prospect.relationship != null && prospect.relationship!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Icon(Icons.favorite_border, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 12),
                          Text('Relationship: ', style: const TextStyle(fontWeight: FontWeight.w500)),
                          _RelationshipChip(relationship: prospect.relationship!),
                        ],
                      ),
                    ),

                  // Social links
                  if (prospect.instagramLink != null && prospect.instagramLink!.isNotEmpty)
                    _socialLink(Icons.camera_alt, 'Instagram', prospect.instagramLink!),
                  if (prospect.linkedinLink != null && prospect.linkedinLink!.isNotEmpty)
                    _socialLink(Icons.work_outline, 'LinkedIn', prospect.linkedinLink!),
                  if (prospect.facebookLink != null && prospect.facebookLink!.isNotEmpty)
                    _socialLink(Icons.facebook, 'Facebook', prospect.facebookLink!),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Events section header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Interaction History',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => EventFormScreen(prospectId: prospect.id),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Record Event'),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Events list
          Consumer<EventProvider>(
            builder: (context, eventProvider, _) {
              if (eventProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              if (eventProvider.events.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        Icon(Icons.event_note, size: 48, color: Colors.grey[400]),
                        const SizedBox(height: 8),
                        Text(
                          'No events recorded yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: eventProvider.events.map((event) {
                  return _EventCard(
                    event: event,
                    dateFormat: _dateFormat,
                    onEdit: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EventFormScreen(
                          prospectId: prospect.id,
                          event: event,
                        ),
                      ),
                    ),
                    onDelete: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Event'),
                          content: const Text('Delete this event?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) {
                        eventProvider.deleteEvent(event.eventId, prospect.id);
                      }
                    },
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w500)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _socialLink(IconData icon, String label, String url) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        onTap: () => _launchUrl(url),
        child: Row(
          children: [
            Icon(icon, size: 18, color: Colors.blue),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

/// Coloured chip for the 4-value relationship field.
class _RelationshipChip extends StatelessWidget {
  final String relationship;
  const _RelationshipChip({required this.relationship});

  static Color _bgColor(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFFFE0E0);
      case 'Warm': return const Color(0xFFFFEDD5);
      case 'Cold': return const Color(0xFFDDEEFF);
      case 'DKD':  return const Color(0xFFEEEEEE);
      default:     return const Color(0xFFEEEEEE);
    }
  }

  static Color _fgColor(String r) {
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
        color: _bgColor(relationship),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        relationship,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: _fgColor(relationship),
        ),
      ),
    );
  }
}

/// Card widget for displaying an individual event.
class _EventCard extends StatelessWidget {
  final ProspectEvent event;
  final DateFormat dateFormat;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _EventCard({
    required this.event,
    required this.dateFormat,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with date and actions
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  dateFormat.format(event.dateOfInteraction),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 18),
                      onPressed: onEdit,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                      onPressed: onDelete,
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(),
            _eventField('Action', event.lastActionTaken),
            _eventField('Remarks', event.remarks),
            _eventField('Conversation', event.lastInteractionConvo),
            _eventField('Next Action', event.nextPlanOfAction),
            _eventField('Next Date', dateFormat.format(event.nextEngagementDate)),
          ],
        ),
      ),
    );
  }

  Widget _eventField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700], fontSize: 13),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
