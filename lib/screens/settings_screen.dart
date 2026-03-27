import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/enum_provider.dart';
import '../providers/profile_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EnumProvider>().loadEnums();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Profile section ──
          _SectionHeader(icon: Icons.person_outline, label: 'My Profile'),
          const SizedBox(height: 8),
          const _ProfileCard(),
          const SizedBox(height: 28),

          // ── Custom Options section ──
          _SectionHeader(icon: Icons.tune, label: 'Custom Dropdown Options'),
          const SizedBox(height: 4),
          Text(
            'Manage the options that appear in your forms',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          Consumer<EnumProvider>(
            builder: (context, enumProvider, _) {
              if (enumProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              return Column(
                children: EnumProvider.categories.map((category) {
                  final label =
                      EnumProvider.categoryLabels[category] ?? category;
                  final values = enumProvider.getValues(category);
                  return _EnumCategoryCard(
                    category: category,
                    label: label,
                    values: values,
                    enumProvider: enumProvider,
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Profile card
// ─────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard();

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final colors  = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 30,
              backgroundColor: colors.primaryContainer,
              child: Text(
                profile.initials,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: colors.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name & role
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    profile.role,
                    style: TextStyle(
                        fontSize: 13, color: colors.onSurfaceVariant),
                  ),
                  if (profile.phone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      profile.phone,
                      style: TextStyle(
                          fontSize: 12, color: colors.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),

            // Edit button
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
              onPressed: () => _showEditDialog(context, profile),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ProfileProvider profile) {
    final nameCtrl  = TextEditingController(text: profile.name == 'Your Name' ? '' : profile.name);
    final roleCtrl  = TextEditingController(text: profile.role == 'Sales Executive' ? '' : profile.role);
    final phoneCtrl = TextEditingController(text: profile.phone);
    final formKey   = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Profile'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: roleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Role / Title',
                  prefixIcon: Icon(Icons.work_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await context.read<ProfileProvider>().update(
                    name:  nameCtrl.text.trim(),
                    role:  roleCtrl.text.trim(),
                    phone: phoneCtrl.text.trim(),
                  );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Enum category card
// ─────────────────────────────────────────────

class _EnumCategoryCard extends StatelessWidget {
  final String category;
  final String label;
  final List<String> values;
  final EnumProvider enumProvider;

  const _EnumCategoryCard({
    required this.category,
    required this.label,
    required this.values,
    required this.enumProvider,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: colors.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${values.length}',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colors.onSecondaryContainer),
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.add_circle_outline,
                      color: colors.primary, size: 22),
                  tooltip: 'Add option',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _showAddDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Options as chips
            if (values.isEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 4),
                child: Text('No options yet',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[400])),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: values.map((value) {
                  return Chip(
                    label: Text(value,
                        style: const TextStyle(fontSize: 12)),
                    deleteIcon:
                        const Icon(Icons.close, size: 14),
                    deleteIconColor: Colors.red[300],
                    onDeleted: () => _confirmDelete(context, value),
                    materialTapTargetSize:
                        MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 0),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $label Option'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new option...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(ctx, controller),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _save(ctx, controller),
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _save(BuildContext ctx, TextEditingController controller) {
    final value = controller.text.trim();
    if (value.isNotEmpty) {
      enumProvider.addValue(category, value);
      Navigator.pop(ctx);
    }
  }

  void _confirmDelete(BuildContext context, String value) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Option'),
        content: Text('Remove "$value" from $label?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              enumProvider.deleteValue(category, value);
              Navigator.pop(ctx);
            },
            style:
                TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
