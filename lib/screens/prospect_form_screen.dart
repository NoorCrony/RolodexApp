import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../models/prospect.dart';
import '../providers/prospect_provider.dart';
import '../providers/enum_provider.dart';
import '../utils/id_generator.dart';
import '../utils/csv_importer.dart';

/// Screen for adding a new prospect or editing an existing one.
/// Also provides CSV import functionality.
class ProspectFormScreen extends StatefulWidget {
  final Prospect? prospect; // Null = add mode, non-null = edit mode

  const ProspectFormScreen({super.key, this.prospect});

  @override
  State<ProspectFormScreen> createState() => _ProspectFormScreenState();
}

class _ProspectFormScreenState extends State<ProspectFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _contactController;
  late final TextEditingController _instagramController;
  late final TextEditingController _linkedinController;
  late final TextEditingController _facebookController;

  String? _connectionType;
  String? _place;
  String? _currentStatus;
  String? _relationship;

  bool get _isEditing => widget.prospect != null;

  @override
  void initState() {
    super.initState();
    final p = widget.prospect;
    _nameController = TextEditingController(text: p?.name ?? '');
    _contactController = TextEditingController(text: p?.contactNumber ?? '');
    _instagramController = TextEditingController(text: p?.instagramLink ?? '');
    _linkedinController = TextEditingController(text: p?.linkedinLink ?? '');
    _facebookController = TextEditingController(text: p?.facebookLink ?? '');
    _connectionType = p?.connectionType;
    _place = p?.place;
    _currentStatus = p?.currentStatus;
    _relationship = p?.relationship;

    // Load enum values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnumProvider>().loadEnums();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    _facebookController.dispose();
    super.dispose();
  }

  Future<void> _saveProspect() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ProspectProvider>();
    final prospect = Prospect(
      id: widget.prospect?.id ?? IdGenerator.prospectId(),
      name: _nameController.text.trim(),
      connectionType: _connectionType ?? '',
      place: _place ?? '',
      currentStatus: _currentStatus ?? '',
      relationship: _relationship,
      contactNumber: _contactController.text.trim(),
      instagramLink: _instagramController.text.trim().isEmpty
          ? null
          : _instagramController.text.trim(),
      linkedinLink: _linkedinController.text.trim().isEmpty
          ? null
          : _linkedinController.text.trim(),
      facebookLink: _facebookController.text.trim().isEmpty
          ? null
          : _facebookController.text.trim(),
    );

    if (_isEditing) {
      await provider.updateProspect(prospect);
    } else {
      await provider.addProspect(prospect);
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _importCsv() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) return;

      final prospects = await CsvImporter.importFromFile(result.files.single.path!);

      if (!mounted) return;

      final importResult = await context.read<ProspectProvider>().bulkAddProspects(prospects);

      // Reload enums so any new values from the CSV are immediately available
      if (mounted) {
        await context.read<EnumProvider>().loadEnums();
      }

      if (mounted) {
        final prospectCount = importResult['prospects'] ?? 0;
        final enumCount     = importResult['newEnums']   ?? 0;
        final enumNote = enumCount > 0
            ? ' ($enumCount new dropdown option${enumCount == 1 ? '' : 's'} added)'
            : '';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Imported $prospectCount prospects$enumNote'),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Prospect' : 'Add Prospect'),
        actions: [
          if (!_isEditing)
            TextButton.icon(
              onPressed: _importCsv,
              icon: const Icon(Icons.upload_file),
              label: const Text('Import CSV'),
            ),
        ],
      ),
      body: Consumer<EnumProvider>(
        builder: (context, enumProvider, _) {
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Name
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full Name *',
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 16),

                // Connection Type dropdown
                _buildDropdown(
                  label: 'Connection Type *',
                  value: _connectionType,
                  items: enumProvider.getValues('connection_type'),
                  onChanged: (v) => setState(() => _connectionType = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Place dropdown
                _buildDropdown(
                  label: 'Place *',
                  value: _place,
                  items: enumProvider.getValues('place'),
                  onChanged: (v) => setState(() => _place = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Current Status dropdown
                _buildDropdown(
                  label: 'Current Status *',
                  value: _currentStatus,
                  items: enumProvider.getValues('current_status'),
                  onChanged: (v) => setState(() => _currentStatus = v),
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: 16),

                // Relationship dropdown (fixed options)
                DropdownButtonFormField<String>(
                  value: _relationship,
                  decoration: const InputDecoration(
                    labelText: 'Relationship',
                    border: OutlineInputBorder(),
                  ),
                  items: Prospect.relationshipOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
                  onChanged: (v) => setState(() => _relationship = v),
                ),
                const SizedBox(height: 16),

                // Contact Number
                TextFormField(
                  controller: _contactController,
                  decoration: const InputDecoration(
                    labelText: 'Contact Number *',
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Contact number is required' : null,
                ),
                const SizedBox(height: 24),

                // Social Links section header
                Text(
                  'Social Links (Optional)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.grey[700],
                      ),
                ),
                const SizedBox(height: 12),

                // Instagram
                TextFormField(
                  controller: _instagramController,
                  decoration: const InputDecoration(
                    labelText: 'Instagram Link',
                    prefixIcon: Icon(Icons.camera_alt),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // LinkedIn
                TextFormField(
                  controller: _linkedinController,
                  decoration: const InputDecoration(
                    labelText: 'LinkedIn Link',
                    prefixIcon: Icon(Icons.work),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),

                // Facebook
                TextFormField(
                  controller: _facebookController,
                  decoration: const InputDecoration(
                    labelText: 'Facebook Link',
                    prefixIcon: Icon(Icons.facebook),
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 32),

                // Save button
                FilledButton.icon(
                  onPressed: _saveProspect,
                  icon: Icon(_isEditing ? Icons.save : Icons.person_add),
                  label: Text(_isEditing ? 'Save Changes' : 'Add Prospect'),
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

  /// Helper to build a dropdown with validation.
  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    FormFieldValidator<String>? validator,
  }) {
    // Reset value if it's not in the items list
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
