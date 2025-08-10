import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/models/room.dart';
import '../../../data/services/room_service.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../data/models/room_image.dart';
import '../../../main.dart';
import 'landlord_edit_listing_page.dart';
import '../../../core/constants/api_constants.dart';
import '../notifications/notifications_page.dart';

class LandlordListingsPage extends StatefulWidget {
  const LandlordListingsPage({super.key});

  @override
  State<LandlordListingsPage> createState() => _LandlordListingsPageState();
}

class _LandlordListingsPageState extends State<LandlordListingsPage> with RouteAware {
  final _service = RoomService();
  bool _loading = false;
  String? _error;
  List<Room> _rooms = [];
  int _page = 1;
  int _totalPages = 1;
  final int _limit = 10;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to route changes
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  // Called when coming back to this page (e.g., after creating or editing)
  @override
  void didPopNext() {
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    if (reset) _page = 1;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getMyListings(token, page: _page, limit: _limit);
      final rooms = (data['rooms'] as List<Room>);
      final pg = (data['pagination'] as Map<String, dynamic>);
      setState(() {
        _rooms = rooms;
        _totalPages = _asInt(pg['totalPages']) ?? 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_error ?? 'Failed to load listings')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delete(String id) async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete listing'),
        content: const Text('Are you sure you want to delete this room? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteRoom(token, id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Room deleted')));
        _load();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('My Listings', style: theme.textTheme.titleLarge),
              const Spacer(),
              FilledButton.icon(
                onPressed: () {
                  // Open the app drawer where the New Listing page lives
                  final scaffold = Scaffold.maybeOf(context);
                  scaffold?.openDrawer();
                },
                icon: const Icon(Icons.add),
                label: const Text('New Listing'),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _loading ? null : () => _load(reset: true),
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh',
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NotificationsPage()),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _rooms.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        itemCount: _rooms.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final r = _rooms[index];
                          final img = r.images.isNotEmpty ? r.images.first.imageUrl : null;
                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  // Top: horizontal image scroller; Bottom: details and actions
                                  final images = r.images;
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _ImagePager(images: images),
                                      const SizedBox(height: 10),
                                      Text('${r.city} • ${r.roomType}', style: theme.textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 4),
                                      Text(r.address, style: theme.textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _Chip(text: 'ETB ${r.monthlyRent.toStringAsFixed(2)}', icon: Icons.payments_outlined),
                                          _Chip(text: 'Max ${r.maxOccupants}', icon: Icons.group_outlined),
                                          _Chip(text: r.genderPreference, icon: Icons.person_outline),
                                          _Chip(text: r.isAvailable ? 'Available' : 'Unavailable', icon: r.isAvailable ? Icons.check_circle_outline : Icons.cancel_outlined),
                                        ],
                                      ),
                                      const SizedBox(height: 10),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              OutlinedButton.icon(
                                                onPressed: () async {
                                                  final result = await Navigator.of(context).push<bool>(
                                                    MaterialPageRoute(builder: (_) => LandlordEditListingPage(room: r)),
                                                  );
                                                  if (result == true && mounted) {
                                                    _load(reset: true);
                                                  }
                                                },
                                                icon: const Icon(Icons.edit_outlined, size: 18),
                                                label: const Text('Edit'),
                                              ),
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(foregroundColor: theme.colorScheme.error),
                                                onPressed: () => _delete(r.id),
                                                icon: const Icon(Icons.delete_outline, size: 18),
                                                label: const Text('Delete'),
                                              ),
                                              Tooltip(
                                                message: 'View bookings/reservations for this room',
                                                child: OutlinedButton.icon(
                                                  onPressed: () {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Bookings shows reservations for this room. To be implemented.')),
                                                    );
                                                  },
                                                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                                                  label: const Text('Bookings'),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          _Pagination(
            page: _page,
            totalPages: _totalPages,
            onPrev: _page > 1 && !_loading
                ? () {
                    setState(() => _page -= 1);
                    _load();
                  }
                : null,
            onNext: _page < _totalPages && !_loading
                ? () {
                    setState(() => _page += 1);
                    _load();
                  }
                : null,
          )
        ],
      ),
    );
  }

  int? _asInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    return null;
  }
}

String _normalizeUrl(String url) {
  var s = url.trim();
  if (s.isEmpty) return s;
  s = s.replaceAll('res.cloudinaru.com', 'res.cloudinary.com');
  if (s.startsWith('//')) s = 'https:$s';
  // Prefix backend base URL for relative paths
  if (!s.startsWith('http://') && !s.startsWith('https://')) {
    if (!s.startsWith('/')) s = '/$s';
    s = '${ApiConstants.baseUrl}$s';
  }
  // Replace localhost/127.0.0.1 with emulator-friendly base origin and only force https for Cloudinary
  try {
    final uri = Uri.tryParse(s);
    final base = Uri.parse(ApiConstants.baseUrl);
    if (uri != null && uri.hasAuthority) {
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        final replaced = uri.replace(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);
        s = replaced.toString();
      }
      if (uri.host.contains('cloudinary.com') && uri.scheme != 'https') {
        final replaced = uri.replace(scheme: 'https', port: null);
        s = replaced.toString();
      }
    }
  } catch (_) {}
  return s;
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.meeting_room_outlined, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 8),
          Text('No listings found', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text('Create your first room listing to get started.', style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final IconData icon;
  const _Chip({required this.text, required this.icon});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Chip(
      visualDensity: VisualDensity.compact,
      labelPadding: const EdgeInsets.symmetric(horizontal: 6),
      avatar: Icon(icon, size: 16, color: theme.colorScheme.primary),
      label: Text(text),
      side: BorderSide(color: theme.colorScheme.outlineVariant),
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}

class _StatusFilter extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _StatusFilter({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

class _Pagination extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  const _Pagination({required this.page, required this.totalPages, this.onPrev, this.onNext});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(onPressed: onPrev, icon: const Icon(Icons.chevron_left)),
        Text('$page / $totalPages'),
        IconButton(onPressed: onNext, icon: const Icon(Icons.chevron_right)),
      ],
    );
  }
}

class _ImagePager extends StatefulWidget {
  final List<RoomImage> images;
  const _ImagePager({required this.images});

  @override
  State<_ImagePager> createState() => _ImagePagerState();
}

class _ImagePagerState extends State<_ImagePager> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = widget.images.length;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 180,
        width: double.infinity,
        child: Stack(
          children: [
            if (total == 0)
              Container(
                color: theme.colorScheme.surfaceVariant,
                child: const Center(child: Icon(Icons.image, size: 36)),
              )
            else
              PageView.builder(
                controller: _controller,
                itemCount: total,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) {
                  final original = widget.images[i].imageUrl;
                  final url = _normalizeUrl(original);
                  // Debug: log original vs normalized URL
                  debugPrint('Landlord IMG => original: $original | normalized: $url');
                  return Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stack) {
                      // Debug: log network image error
                      debugPrint('Landlord IMG ERROR for $url => $error');
                      return Container(
                        color: theme.colorScheme.surfaceVariant,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.broken_image_outlined, size: 32, color: Colors.grey),
                            SizedBox(height: 6),
                            Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            if (total > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.scrim.withOpacity(0.55),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '${_index + 1}/$total',
                    style: theme.textTheme.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
