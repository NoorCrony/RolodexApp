import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../database/database_helper.dart';
import '../providers/enum_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/prospect_provider.dart';
import '../providers/auth_provider.dart';

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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surfaceContainerLowest,
      body: CustomScrollView(
        slivers: [
          // ── Large collapsing app bar with profile ──
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: colors.surface,
            flexibleSpace: FlexibleSpaceBar(
              background: _ProfileHeader(),
            ),
            title: const Text(
              'Settings',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Google Account group (optional) ──
                  _GroupLabel(label: 'GOOGLE DRIVE BACKUP  •  OPTIONAL'),
                  const SizedBox(height: 6),
                  const _GoogleAccountCard(),
                  const SizedBox(height: 28),

                  // ── Customisation group ──
                  _GroupLabel(label: 'CUSTOMISATION'),
                  const SizedBox(height: 6),
                  _SettingsGroup(
                    children: EnumProvider.categories.map((category) {
                      final label =
                          EnumProvider.categoryLabels[category] ?? category;
                      return _EnumTile(category: category, label: label);
                    }).toList(),
                  ),

                  const SizedBox(height: 28),

                  // ── Data & Backup group ──
                  _GroupLabel(label: 'DATA & BACKUP'),
                  const SizedBox(height: 6),
                  _SettingsGroup(
                    children: [
                      _ActionTile(
                        icon: Icons.upload_rounded,
                        iconColor: Colors.blue,
                        title: 'Export Backup',
                        subtitle: 'Share your .db file via any app',
                        onTap: () => _exportBackup(context),
                      ),
                      _ActionTile(
                        icon: Icons.download_rounded,
                        iconColor: Colors.orange,
                        title: 'Restore Backup',
                        subtitle: 'Import a .db file — replaces all data',
                        onTap: () => _importBackup(context),
                        showDivider: false,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 13, color: colors.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Restoring replaces all current data. Export first!',
                            style: TextStyle(
                                fontSize: 11, color: colors.onSurfaceVariant),
                          ),
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
    );
  }

  // ── Backup helpers ──────────────────────────────────────────────────────

  Future<void> _exportBackup(BuildContext context) async {
    try {
      final dbPath = await DatabaseHelper.instance.getDatabasePath();
      await Share.shareXFiles(
        [XFile(dbPath)],
        subject: 'Rolodex Backup',
        text: 'Rolodex database backup',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup shared!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Backup'),
        content: const Text(
          'This will replace ALL current data with the backup file. '
          'This cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) return;
      final filePath = result.files.single.path!;

      if (!filePath.endsWith('.db')) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select a valid .db backup file.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      await DatabaseHelper.instance.restoreDatabase(filePath);

      if (context.mounted) {
        await context.read<ProspectProvider>().loadProspects();
        await context.read<EnumProvider>().loadEnums();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup restored!')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Restore failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Profile header — sits inside the SliverAppBar's flexible space
// ─────────────────────────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final colors  = Theme.of(context).colorScheme;

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
          padding: const EdgeInsets.fromLTRB(20, 48, 20, 16),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 38,
                backgroundColor: colors.primary,
                child: Text(
                  profile.initials,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Name / role / phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      profile.name,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.role,
                      style: TextStyle(
                          fontSize: 13, color: colors.onSurfaceVariant),
                    ),
                    if (profile.phone.isNotEmpty) ...[
                      const SizedBox(height: 1),
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
              IconButton.filledTonal(
                icon: const Icon(Icons.edit_outlined, size: 18),
                tooltip: 'Edit profile',
                onPressed: () => _showEditDialog(context, profile),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, ProfileProvider profile) {
    final nameCtrl = TextEditingController(
        text: profile.name == 'Your Name' ? '' : profile.name);
    final roleCtrl = TextEditingController(
        text: profile.role == 'Sales Executive' ? '' : profile.role);
    final phoneCtrl = TextEditingController(text: profile.phone);
    final formKey = GlobalKey<FormState>();

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
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              await context.read<ProfileProvider>().update(
                    name: nameCtrl.text.trim(),
                    role: roleCtrl.text.trim(),
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

// ─────────────────────────────────────────────────────────────────────────────
// Google Account card
// ─────────────────────────────────────────────────────────────────────────────

class _GoogleAccountCard extends StatelessWidget {
  const _GoogleAccountCard();

  static final _dateFmt = DateFormat('MMM d, yyyy • h:mm a');

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final colors = Theme.of(context).colorScheme;

    if (auth.isLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (!auth.isSignedIn) {
      return Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(Icons.cloud_off_outlined,
                  size: 40, color: colors.onSurfaceVariant),
              const SizedBox(height: 12),
              Text(
                'Optionally link your Google account to enable automatic daily backups to Drive.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  final success = await context.read<AuthProvider>().signIn();
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(success
                        ? 'Signed in! Daily backup scheduled for 6:00 AM.'
                        : 'Sign-in cancelled.'),
                  ));
                },
                icon: Image.asset('assets/google_logo.png',
                    width: 18, height: 18,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.login, size: 18)),
                label: const Text('Sign in with Google'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Signed in state
    final user       = auth.currentUser!;
    final lastBackup = auth.lastBackupAt;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          // Account row
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: user.photoUrl != null
                  ? NetworkImage(user.photoUrl!)
                  : null,
              backgroundColor: colors.primaryContainer,
              child: user.photoUrl == null
                  ? Text(
                      (user.displayName ?? user.email)[0].toUpperCase(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer),
                    )
                  : null,
            ),
            title: Text(user.displayName ?? user.email,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(user.email,
                style: TextStyle(
                    fontSize: 12, color: colors.onSurfaceVariant)),
            trailing: TextButton(
              onPressed: () async {
                await context.read<AuthProvider>().signOut();
              },
              child: const Text('Sign Out',
                  style: TextStyle(color: Colors.red)),
            ),
          ),

          Divider(height: 1, indent: 16, color: colors.outlineVariant),

          // Backup row
          ListTile(
            leading: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: auth.isBackingUp
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.backup_rounded,
                      color: Colors.blue, size: 18),
            ),
            title: const Text('Backup Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            subtitle: Text(
              lastBackup != null
                  ? 'Last backup: ${_dateFmt.format(lastBackup)}'
                  : 'Never backed up',
              style: TextStyle(
                  fontSize: 12, color: colors.onSurfaceVariant),
            ),
            trailing: Icon(Icons.chevron_right,
                color: colors.onSurfaceVariant, size: 18),
            onTap: auth.isBackingUp
                ? null
                : () async {
                    try {
                      await context.read<AuthProvider>().backupNow();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Backed up to Google Drive!')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Backup failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
          ),

          Divider(height: 1, indent: 16, color: colors.outlineVariant),

          // Schedule info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 14, color: colors.onSurfaceVariant),
                const SizedBox(width: 6),
                Text(
                  'Auto-backup runs daily at 6:00 AM',
                  style: TextStyle(
                      fontSize: 12, color: colors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout helpers
// ─────────────────────────────────────────────────────────────────────────────

/// Grey uppercase section label (iOS-style)
class _GroupLabel extends StatelessWidget {
  final String label;
  const _GroupLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Rounded white card that groups a list of tiles
class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Column(children: children),
    );
  }
}

/// A tappable row that navigates to the enum management sheet
class _EnumTile extends StatelessWidget {
  final String category;
  final String label;
  const _EnumTile({required this.category, required this.label});

  // Consistent accent colour per category
  static final _colors = [
    Colors.indigo,
    Colors.teal,
    Colors.orange,
    Colors.purple,
    Colors.green,
  ];

  @override
  Widget build(BuildContext context) {
    final idx = EnumProvider.categories.indexOf(category);
    final accent = _colors[idx % _colors.length];
    final values = context.watch<EnumProvider>().getValues(category);

    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.list_alt_rounded, color: accent, size: 18),
          ),
          title: Text(label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${values.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 18),
            ],
          ),
          onTap: () => _showEnumSheet(context, category, label, values),
        ),
        if (category != EnumProvider.categories.last)
          Divider(
              height: 1,
              indent: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
      ],
    );
  }

  void _showEnumSheet(
      BuildContext context, String category, String label, List<String> values) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EnumManageSheet(
        category: category,
        label: label,
      ),
    );
  }
}

/// A simple tappable action row (for export / import)
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDivider;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          title: Text(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text(subtitle,
              style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
          trailing: Icon(Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant, size: 18),
          onTap: onTap,
        ),
        if (showDivider)
          Divider(
              height: 1,
              indent: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Enum management bottom sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EnumManageSheet extends StatelessWidget {
  final String category;
  final String label;
  const _EnumManageSheet({required this.category, required this.label});

  @override
  Widget build(BuildContext context) {
    final enumProvider = context.watch<EnumProvider>();
    final values = enumProvider.getValues(category);
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add'),
                  onPressed: () => _showAddDialog(context, enumProvider),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Options
          if (values.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 40, color: colors.outline),
                  const SizedBox(height: 8),
                  Text('No options yet',
                      style: TextStyle(color: colors.onSurfaceVariant)),
                ],
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: values.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: colors.outlineVariant),
                itemBuilder: (ctx, i) {
                  final v = values[i];
                  return ListTile(
                    dense: true,
                    title: Text(v),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Colors.red),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmDelete(context, enumProvider, v),
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _showAddDialog(BuildContext context, EnumProvider enumProvider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add $label'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new option...',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _save(ctx, ctrl, enumProvider),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => _save(ctx, ctrl, enumProvider),
              child: const Text('Add')),
        ],
      ),
    );
  }

  void _save(BuildContext ctx, TextEditingController ctrl,
      EnumProvider enumProvider) {
    final v = ctrl.text.trim();
    if (v.isNotEmpty) {
      enumProvider.addValue(category, v);
      Navigator.pop(ctx);
    }
  }

  void _confirmDelete(
      BuildContext context, EnumProvider enumProvider, String value) {
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
