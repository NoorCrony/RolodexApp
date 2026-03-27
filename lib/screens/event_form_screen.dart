import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/event.dart';
import '../providers/event_provider.dart';
import '../providers/enum_provider.dart';
import '../utils/id_generator.dart';

/// Screen for recording a new event or editing an existing one.
class EventFormScreen extends StatefulWidget {
  final String prospectId;
  final ProspectEvent? event; // Null = add mode

  const EventFormScreen({super.key, required this.prospectId, this.event});

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();
  final _convoController = TextEditingController();
  final _dateFormat = DateFormat('MMM dd, yyyy');

  String? _lastActionTaken;
  String? _nextPlanOfAction;
  DateTime _dateOfInteraction = DateTime.now();
  DateTime _nextEngagementDate = DateTime.now().add(const Duration(days: 7));

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _remarksController.text = e.remarks;
      _convoController.text = e.lastInteractionConvo;
      _lastActionTaken = e.lastActionTaken;
      _nextPlanOfAction = e.nextPlanOfAction;
      _dateOfInteraction = e.dateOfInteraction;
      _nextEngagementDate = e.nextEngagementDate;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnumProvider>().loadEnums();
    });
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _convoController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isInteractionDate) async {
    final current = isInteractionDate ? _dateOfInteraction : _nextEngagementDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isInteractionDate) {
          _dateOfInteraction = picked;
        } else {
          _nextEngagementDate = picked;
        }
      });
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    final event = ProspectEvent(
      eventId: widget.event?.eventId ?? IdGenerator.eventId(),
      prospectId: widget.prospectId,
      lastActionTaken: _lastActionTaken ?? '',
      remarks: _remarksController.text.trim(),
      dateOfInteraction: _dateOfInteraction,
      lastInteractionConvo: _convoController.text.trim(),
      nextPlanOfAction: _nextPlanOfAction ?? '',
      nextEngagementDate: _nextEngagementDate,
    );

    final provider = context.read<EventProvider>();
    if (_isEditing) {
      await provider.updateEvent(event);
    } else {
      await provider.addEvent(event);
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Event' : 'Record Event'),
      ),
      body: Consumer<EnumProvider>(
        builder: (context, enumProvider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Date of Interaction
                _buildDateField(
                  label: 'Date of Interaction',
                  date: _dateOfInteraction,
                  onTap: () => _pickDate(true),
                ),
                const SizedBox(height: 16),

                // Last Action Taken dropdown
                _buildDropdown(
                  label: 'Last Action Taken *',
                  value: _lastActionTaken,
                  items: enumProvider.getValues('last_action_taken'),
                  onChanged: (v) => setState(() => _lastActionTaken = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Remarks
                TextFormField(
                  controller: _remarksController,
                  decoration: const InputDecoration(
                    labelText: 'Remarks *',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 3,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Remarks are required' : null,
                ),
                const SizedBox(height: 16),

                // Last Interaction Conversation
                TextFormField(
                  controller: _convoController,
                  decoration: const InputDecoration(
                    labelText: 'Conversation Notes *',
                    hintText: 'Summary of what was discussed...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Conversation notes are required' : null,
                ),
                const SizedBox(height: 16),

                // Next Plan of Action dropdown
                _buildDropdown(
                  label: 'Next Plan of Action *',
                  value: _nextPlanOfAction,
                  items: enumProvider.getValues('next_plan_of_action'),
                  onChanged: (v) => setState(() => _nextPlanOfAction = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Next Engagement Date
                _buildDateField(
                  label: 'Next Engagement Date',
                  date: _nextEngagementDate,
                  onTap: () => _pickDate(false),
                ),
                const SizedBox(height: 32),

                // Save button
                FilledButton.icon(
                  onPressed: _saveEvent,
                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Save Changes' : 'Record Event'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(_dateFormat.format(date)),
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    FormFieldValidator<String>? validator,
  }) {
    final effectiveValue = (value != null && items.contains(value)) ? value : null;

    return DropdownButtonFormField<String>(
      value: effectiveValue,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      items: items.map((item) {
        return DropdownMenuItem(value: item, child: Text(item));
      }).toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}
