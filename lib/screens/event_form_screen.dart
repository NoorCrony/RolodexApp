import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
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
  final _formKey               = GlobalKey<FormState>();
  final _remarksController     = TextEditingController();
  final _convoController       = TextEditingController();
  final _dateFormat            = DateFormat('MMM dd, yyyy');

  // Speech-to-text
  final _speech    = SpeechToText();
  bool _speechReady = false;
  // Which field is currently recording: 'remarks' | 'convo' | null
  String? _activeField;

  String? _lastActionTaken;
  String? _nextPlanOfAction;
  DateTime _dateOfInteraction  = DateTime.now();
  DateTime _nextEngagementDate = DateTime.now().add(const Duration(days: 7));

  bool get _isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
    final e = widget.event;
    if (e != null) {
      _remarksController.text  = e.remarks;
      _convoController.text    = e.lastInteractionConvo;
      _lastActionTaken         = e.lastActionTaken;
      _nextPlanOfAction        = e.nextPlanOfAction;
      _dateOfInteraction       = e.dateOfInteraction;
      _nextEngagementDate      = e.nextEngagementDate;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnumProvider>().loadEnums();
      _initSpeech();
    });
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onError: (_) => setState(() => _activeField = null),
      onStatus: (status) {
        // Auto-stop UI when recognition finishes naturally
        if (status == 'done' || status == 'notListening') {
          setState(() => _activeField = null);
        }
      },
    );
    if (mounted) setState(() => _speechReady = available);
  }

  /// Start / stop recording for a given field key.
  Future<void> _toggleVoice(String fieldKey, TextEditingController ctrl) async {
    if (!_speechReady) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available on this device.')),
      );
      return;
    }

    // If already recording this field → stop
    if (_activeField == fieldKey) {
      await _speech.stop();
      setState(() => _activeField = null);
      return;
    }

    // If recording a different field → stop that first
    if (_activeField != null) await _speech.stop();

    // Capture the existing text so we can append to it
    final existingText = ctrl.text.trimRight();

    setState(() => _activeField = fieldKey);

    await _speech.listen(
      onResult: (result) {
        final words = result.recognizedWords;
        if (words.isEmpty) return;
        final separator = existingText.isEmpty ? '' : ' ';
        ctrl.text = '$existingText$separator$words';
        // Move cursor to end
        ctrl.selection = TextSelection.fromPosition(
          TextPosition(offset: ctrl.text.length),
        );
      },
      listenFor: const Duration(minutes: 2),
      pauseFor: const Duration(seconds: 4),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  @override
  void dispose() {
    _speech.stop();
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
    if (_activeField != null) await _speech.stop();

    final event = ProspectEvent(
      eventId:              widget.event?.eventId ?? IdGenerator.eventId(),
      prospectId:           widget.prospectId,
      lastActionTaken:      _lastActionTaken ?? '',
      remarks:              _remarksController.text.trim(),
      dateOfInteraction:    _dateOfInteraction,
      lastInteractionConvo: _convoController.text.trim(),
      nextPlanOfAction:     _nextPlanOfAction ?? '',
      nextEngagementDate:   _nextEngagementDate,
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

                // Remarks — voice-enabled
                _VoiceTextField(
                  controller: _remarksController,
                  label: 'Remarks *',
                  maxLines: 3,
                  isRecording: _activeField == 'remarks',
                  speechReady: _speechReady,
                  onMicTap: () => _toggleVoice('remarks', _remarksController),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Remarks are required' : null,
                ),
                const SizedBox(height: 16),

                // Conversation Notes — voice-enabled
                _VoiceTextField(
                  controller: _convoController,
                  label: 'Conversation Notes *',
                  hint: 'Summary of what was discussed...',
                  maxLines: 4,
                  isRecording: _activeField == 'convo',
                  speechReady: _speechReady,
                  onMicTap: () => _toggleVoice('convo', _convoController),
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
      items: items
          .map((item) => DropdownMenuItem(value: item, child: Text(item)))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reusable voice-enabled text field
// ─────────────────────────────────────────────────────────────────────────────

class _VoiceTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final int maxLines;
  final bool isRecording;
  final bool speechReady;
  final VoidCallback onMicTap;
  final FormFieldValidator<String>? validator;

  const _VoiceTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.maxLines = 3,
    required this.isRecording,
    required this.speechReady,
    required this.onMicTap,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
            // Recording indicator border
            enabledBorder: isRecording
                ? OutlineInputBorder(
                    borderSide: BorderSide(color: Colors.red.shade400, width: 2),
                  )
                : null,
            // Mic button in the top-right corner of the field
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 4, top: 4),
              child: _MicButton(
                isRecording: isRecording,
                enabled: speechReady,
                onTap: onMicTap,
              ),
            ),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
          maxLines: maxLines,
          validator: validator,
        ),

        // Live recording hint
        if (isRecording)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Row(
              children: [
                Icon(Icons.fiber_manual_record,
                    size: 10, color: Colors.red.shade400),
                const SizedBox(width: 4),
                Text(
                  'Listening… tap mic to stop',
                  style: TextStyle(
                      fontSize: 11, color: Colors.red.shade400),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Mic button with pulse animation while recording ───────────────────────────

class _MicButton extends StatefulWidget {
  final bool isRecording;
  final bool enabled;
  final VoidCallback onTap;

  const _MicButton({
    required this.isRecording,
    required this.enabled,
    required this.onTap,
  });

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _scale = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    if (widget.isRecording) {
      return ScaleTransition(
        scale: _scale,
        child: IconButton(
          icon: const Icon(Icons.mic, color: Colors.red),
          tooltip: 'Stop recording',
          onPressed: widget.onTap,
        ),
      );
    }

    return IconButton(
      icon: Icon(
        Icons.mic_none,
        color: widget.enabled ? colors.primary : colors.onSurfaceVariant,
      ),
      tooltip: widget.enabled ? 'Tap to dictate' : 'Speech unavailable',
      onPressed: widget.enabled ? widget.onTap : null,
    );
  }
}
