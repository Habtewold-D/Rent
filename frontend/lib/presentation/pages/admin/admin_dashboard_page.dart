import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/services/admin_dashboard_service.dart';
import '../../viewmodels/auth_view_model.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final _service = AdminDashboardService();
  Future<Map<String, dynamic>>? _future;

  Future<void> _reload() async {
    final token = context.read<AuthViewModel>().token;
    if (token != null) {
      final d = await _service.getSummary(token);
      if (!mounted) return;
      setState(() => _future = Future.value(d));
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final token = context.read<AuthViewModel>().token;
      if (token != null) {
        setState(() {
          _future = _service.getSummary(token);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Failed to load dashboard: ${snap.error}'));
          }
          final data = snap.data ?? {};
          return LayoutBuilder(
            builder: (context, constraints) {
              final padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
              final isWide = constraints.maxWidth >= 1100;
              final isMedium = constraints.maxWidth >= 750;
              final crossCount = isWide ? 4 : (isMedium ? 3 : 2);
              final items = <Widget>[
                _StatCard(
                  label: 'Users',
                  value: (data['users']?['total'] ?? 0).toString(),
                  icon: Icons.people_alt_rounded,
                  color: Colors.indigo,
                  footer: 'Renters ${(data['users']?['renters'] ?? 0)}  ·  Landlords ${(data['users']?['landlords'] ?? 0)}',
                ),
                _StatCard(
                  label: 'New (30d)',
                  value: (data['users']?['new30d'] ?? 0).toString(),
                  icon: Icons.trending_up_rounded,
                  color: Colors.teal,
                  footer: 'Last 7d ${(data['users']?['new7d'] ?? 0)}',
                ),
                _StatCard(
                  label: 'Rooms',
                  value: (data['rooms']?['total'] ?? 0).toString(),
                  icon: Icons.meeting_room_rounded,
                  color: Colors.deepPurple,
                  footer: 'Available ${(data['rooms']?['available'] ?? 0)}  ·  New 30d ${(data['rooms']?['new30d'] ?? 0)}',
                ),
                _StatCard(
                  label: 'Landlord Requests',
                  value: (data['landlordRequests']?['total'] ?? 0).toString(),
                  icon: Icons.verified_user_rounded,
                  color: Colors.orange,
                  footer: 'Pending ${(data['landlordRequests']?['pending'] ?? 0)} · Approved ${(data['landlordRequests']?['approved'] ?? 0)}',
                ),
                _StatCard(
                  label: 'Match Groups',
                  value: (data['match']?['groups'] ?? 0).toString(),
                  icon: Icons.groups_2_rounded,
                  color: Colors.blueGrey,
                  footer: 'Members ${(data['match']?['members'] ?? 0)}',
                ),
                _StatCard(
                  label: 'Notifications',
                  value: (data['notifications']?['total'] ?? 0).toString(),
                  icon: Icons.notifications_active_rounded,
                  color: Colors.pinkAccent,
                  footer: 'System total',
                ),
              ];

                const maxContentWidth = 1200.0;
                final contentWidth = constraints.maxWidth > maxContentWidth ? maxContentWidth : constraints.maxWidth;
                final containerHeight = constraints.maxHeight * 0.75;
                final gridWidth = contentWidth - padding.horizontal;
                final gridHeight = containerHeight - padding.vertical - 8; // header space above grid
                final rows = (items.length / crossCount).ceil();
                const hSpacing = 8.0;
                const vSpacing = 8.0;
                final itemWidth = (gridWidth - hSpacing * (crossCount - 1)) / crossCount;
                final itemHeight = (gridHeight - vSpacing * (rows - 1)) / rows;
                final aspectRatio = itemWidth / itemHeight;

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: maxContentWidth),
                    child: Padding(
                      padding: padding,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text('Admin Dashboard', style: Theme.of(context).textTheme.titleMedium),
                              ),
                              IconButton(
                                tooltip: 'Refresh',
                                icon: const Icon(Icons.refresh_rounded),
                                onPressed: _reload,
                              )
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: containerHeight,
                            child: GridView.count(
                              crossAxisCount: crossCount,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: hSpacing,
                              mainAxisSpacing: vSpacing,
                              childAspectRatio: aspectRatio,
                              children: items,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
        },
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? footer;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.08), color.withOpacity(0.14)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: color.withOpacity(0.9), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Flexible(
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 2),
                  Flexible(
                    child: Text(
                      footer!,
                      style: Theme.of(context).textTheme.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.4)),
      ),
      child: Row(
        children: const [
          Icon(Icons.history_rounded),
          SizedBox(width: 6),
          Expanded(child: Text('Recent activity feed coming soon...')),
        ],
      ),
    );
  }
}
