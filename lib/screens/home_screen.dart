import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/prospect_provider.dart';
import '../providers/profile_provider.dart';
import '../models/prospect.dart';
import 'prospect_form_screen.dart';
import 'prospect_detail_screen.dart';

/// Home screen — prospect list with greeting header and search bar.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProspectProvider>().loadProspects();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Greeting header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${context.watch<ProfileProvider>().name} 👋',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Manage your prospects',
                          style: TextStyle(
                            color: colors.onSurfaceVariant,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Add prospect button (top-right)
                  FilledButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProspectFormScreen()),
                      );
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Add'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      textStyle: const TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Search bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onTap: () => setState(() => _isSearching = true),
                onChanged: (query) {
                  context.read<ProspectProvider>().searchProspects(query);
                },
                decoration: InputDecoration(
                  hintText: 'Search prospects...',
                  hintStyle:
                      TextStyle(color: colors.onSurfaceVariant, fontSize: 14),
                  prefixIcon:
                      Icon(Icons.search, color: colors.onSurfaceVariant),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _isSearching = false);
                            context.read<ProspectProvider>().loadProspects();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerHighest,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide:
                        BorderSide(color: colors.primary, width: 1.5),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ── Section label + count ──
            Consumer<ProspectProvider>(
              builder: (context, provider, _) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _isSearching && _searchController.text.isNotEmpty
                          ? 'Search results'
                          : 'All prospects',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${provider.prospects.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colors.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // ── Prospect list ──
            Expanded(
              child: Consumer<ProspectProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.prospects.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.people_outline,
                              size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 16),
                          Text(
                            _isSearching
                                ? 'No results found'
                                : 'No prospects yet',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 6),
                          if (!_isSearching)
                            Text(
                              'Tap Add to get started',
                              style: TextStyle(
                                  color: Colors.grey[400], fontSize: 13),
                            ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: provider.prospects.length,
                    itemBuilder: (context, index) {
                      return _ProspectCard(
                          prospect: provider.prospects[index]);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card widget for a single prospect.
class _ProspectCard extends StatelessWidget {
  final Prospect prospect;

  const _ProspectCard({required this.prospect});

  // Consistent avatar colour per prospect based on name initial
  Color _avatarColor(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
      Theme.of(context).colorScheme.tertiaryContainer,
    ];
    final idx = prospect.name.codeUnitAt(0) % colors.length;
    return colors[idx];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProspectDetailScreen(prospect: prospect)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.outlineVariant.withOpacity(0.5)),
        ),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: _avatarColor(context),
              child: Text(
                prospect.name.isNotEmpty
                    ? prospect.name[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Name + subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prospect.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${prospect.connectionType} · ${prospect.place}',
                    style: TextStyle(
                        fontSize: 12, color: colors.onSurfaceVariant),
                  ),
                ],
              ),
            ),

            // Status chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: colors.secondaryContainer,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                prospect.currentStatus,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: colors.onSecondaryContainer,
                ),
              ),
            ),

            // Relationship badge
            if (prospect.relationship != null &&
                prospect.relationship!.isNotEmpty) ...[
              const SizedBox(width: 6),
              _RelationshipBadge(relationship: prospect.relationship!),
            ],

            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                size: 18, color: colors.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Tiny coloured badge showing the relationship tag on prospect cards.
class _RelationshipBadge extends StatelessWidget {
  final String relationship;
  const _RelationshipBadge({required this.relationship});

  static Color _bg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFFFCDD2);
      case 'Warm': return const Color(0xFFFFE0B2);
      case 'Cold': return const Color(0xFFBBDEFB);
      case 'DKD':  return const Color(0xFFE0E0E0);
      default:     return const Color(0xFFE0E0E0);
    }
  }

  static Color _fg(String r) {
    switch (r) {
      case 'Hot':  return const Color(0xFFC62828);
      case 'Warm': return const Color(0xFFE65100);
      case 'Cold': return const Color(0xFF1565C0);
      case 'DKD':  return const Color(0xFF757575);
      default:     return const Color(0xFF757575);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: _bg(relationship),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        relationship,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: _fg(relationship),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
