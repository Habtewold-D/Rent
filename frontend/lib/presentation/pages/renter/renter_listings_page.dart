import 'package:flutter/material.dart';

import '../../../data/models/room.dart';
import '../../../data/models/room_image.dart';
import '../../../data/services/room_service.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../data/services/matching_service.dart';
import '../../../core/constants/api_constants.dart';
import 'rent_with_others_page.dart';
// Removed local notifications imports; Home AppBar hosts the bell globally

class RenterListingsPage extends StatefulWidget {
  const RenterListingsPage({super.key});

  @override
  State<RenterListingsPage> createState() => _RenterListingsPageState();
}

class _RenterListingsPageState extends State<RenterListingsPage> {
  final _service = RoomService();
  bool _loading = false;
  String? _error;
  List<Room> _rooms = [];
  int _page = 1;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      if (reset) {
        _error = null;
        _page = 1;
        _rooms = [];
      }
    });
    try {
      final result = await _service.getPublicRooms(page: _page, limit: 10);
      final rooms = (result['rooms'] as List<Room>);
      final pagination = (result['pagination'] as Map<String, dynamic>);
      setState(() {
        _rooms = [..._rooms, ...rooms];
        _totalPages = (pagination['totalPages'] is int)
            ? pagination['totalPages'] as int
            : int.tryParse(pagination['totalPages']?.toString() ?? '1') ?? 1;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    await _load(reset: true);
  }

  void _loadMore() {
    if (_page < _totalPages && !_loading) {
      setState(() => _page += 1);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: _error != null
            ? ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                ],
              )
            : (_loading && _rooms.isEmpty)
                ? const Center(child: CircularProgressIndicator())
                : (_rooms.isEmpty)
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('No rooms found')),
                        ],
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _rooms.length + 1,
                        itemBuilder: (context, index) {
                          if (index == _rooms.length) {
                            final hasMore = _page < _totalPages;
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12.0),
                              child: Center(
                                child: hasMore
                                    ? OutlinedButton(
                                        onPressed: _loading ? null : _loadMore,
                                        child: _loading
                                            ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                            : const Text('Load more'),
                                      )
                                    : const Text('No more results'),
                              ),
                            );
                          }
                          final r = _rooms[index];
                          return _RoomCard(room: r);
                        },
                      ),
      ),
    );
  }
}

void _openGroupSheet(BuildContext context, Room room) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _GroupMatchSheet(room: room),
  );
}

class _GroupMatchSheet extends StatefulWidget {
  final Room room;
  const _GroupMatchSheet({required this.room});

  @override
  State<_GroupMatchSheet> createState() => _GroupMatchSheetState();
}

class _GroupMatchSheetState extends State<_GroupMatchSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _ageCtrl;
  int _desiredSize = 2;
  String _religion = 'any';
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result; // data from joinRoom

  @override
  void initState() {
    super.initState();
    _ageCtrl = TextEditingController();
    try {
      final auth = context.read<AuthViewModel>();
      if (auth.userAge != null) {
        _ageCtrl.text = auth.userAge!.toString();
      }
      // religion defaults to user's if available
      if ((auth.userReligion ?? '').isNotEmpty) {
        _religion = auth.userReligion!;
      }
    } catch (_) {
      // If provider not found, keep defaults and continue
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchGroups() async {
    if (!_formKey.currentState!.validate()) return;
    String? token;
    try {
      final auth = context.read<AuthViewModel>();
      token = auth.token;
    } catch (_) {
      token = null;
    }
    if (token == null) {
      setState(() => _error = 'You must be logged in');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = MatchingService();
      final data = await svc.joinRoom(
        token,
        widget.room.id,
        userAge: int.parse(_ageCtrl.text.trim()),
        desiredGroupSize: _desiredSize,
        religionPreference: _religion,
      );
      setState(() => _result = data);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    String? token;
    try {
      final auth = context.read<AuthViewModel>();
      token = auth.token;
    } catch (_) {
      token = null;
    }
    if (token == null) {
      setState(() => _error = 'You must be logged in');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = MatchingService();
      final data = await svc.createGroup(
        token,
        widget.room.id,
        userAge: int.parse(_ageCtrl.text.trim()),
        desiredGroupSize: _desiredSize,
        religionPreference: _religion,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group created. Spots left: ${data['spotsLeft']}')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinGroup(String groupId) async {
    String? token;
    try {
      final auth = context.read<AuthViewModel>();
      token = auth.token;
    } catch (_) {
      token = null;
    }
    if (token == null) {
      setState(() => _error = 'You must be logged in');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = MatchingService();
      await svc.joinGroup(token, groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Joined group successfully')),
      );
      Navigator.pop(context);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets;
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Rent with others', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                Form(
                  key: _formKey,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _ageCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Your age'),
                          validator: (v) {
                            final n = int.tryParse(v?.trim() ?? '');
                            if (n == null || n < 18 || n > 65) return '18-65';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: _desiredSize,
                        items: const [
                          DropdownMenuItem(value: 2, child: Text('Group of 2')),
                          DropdownMenuItem(value: 3, child: Text('Group of 3')),
                        ],
                        onChanged: (v) => setState(() => _desiredSize = v ?? 2),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _religion,
                        items: const [
                          DropdownMenuItem(value: 'any', child: Text('Any religion')),
                          DropdownMenuItem(value: 'orthodox', child: Text('Orthodox')),
                          DropdownMenuItem(value: 'muslim', child: Text('Muslim')),
                          DropdownMenuItem(value: 'protestant', child: Text('Protestant')),
                          DropdownMenuItem(value: 'catholic', child: Text('Catholic')),
                          DropdownMenuItem(value: 'other_christian', child: Text('Other Christian')),
                          DropdownMenuItem(value: 'other', child: Text('Other')),
                        ],
                        onChanged: (v) => setState(() => _religion = v ?? 'any'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _loading ? null : _fetchGroups,
                      icon: _loading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.search),
                      label: const Text('Find groups'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _createGroup,
                      icon: const Icon(Icons.group_add),
                      label: const Text('Create new group'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                ],
                const SizedBox(height: 12),
                if (_result != null) ...[
                  Text('Recommended groups', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _GroupsList(
                    groups: _extractList(_result!, ['recommendedGroups', 'groups', 'matches', 'availableGroups']),
                    onJoin: _joinGroup,
                  ),
                  const SizedBox(height: 12),
                  Text('Other groups', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  _GroupsList(
                    groups: _extractList(_result!, ['otherGroups']),
                    onJoin: _joinGroup,
                  ),
                  const SizedBox(height: 12),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _extractList(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final v = map[k];
      final coerced = _coerceMaps(v);
      if (coerced.isNotEmpty) return coerced;
    }
    return const [];
  }

  List<Map<String, dynamic>> _coerceMaps(dynamic v) {
    if (v is List) {
      return v
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    }
    return const [];
  }
}

class _GroupsList extends StatelessWidget {
  final List<Map<String, dynamic>> groups;
  final void Function(String groupId) onJoin;
  const _GroupsList({required this.groups, required this.onJoin});

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return const Text('No groups found');
    }
    final theme = Theme.of(context);
    return Column(
      children: groups.map((g) {
        final currentSize = g['currentSize'] ?? 0;
        final targetSize = g['targetSize'] ?? 0;
        final ageRange = (g['ageRange'] ?? '').toString();
        final cost = g['costPerPerson'];
        final religion = (g['religionPreference'] ?? 'any').toString();
        final spotsLeft = g['spotsLeft'] ?? (targetSize - currentSize);
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.groups_2_outlined, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Group ${currentSize}/${targetSize}', style: theme.textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.event_seat, size: 16),
                          const SizedBox(width: 4),
                          Text('Spots: $spotsLeft'),
                        ],
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.cake_outlined, size: 16),
                      label: Text(ageRange.isEmpty ? 'Age: —' : 'Age: $ageRange'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.attach_money, size: 16),
                      label: Text(cost == null ? 'Per person: —' : 'Per person: $cost ETB'),
                    ),
                    Chip(
                      avatar: const Icon(Icons.self_improvement_outlined, size: 16),
                      label: Text('Religion: ${religion == 'any' ? 'Any' : religion}'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => onJoin(g['id'].toString()),
                    icon: const Icon(Icons.group_add),
                    label: const Text('Join this group'),
                  ),
                )
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final Room room;
  const _RoomCard({required this.room});

  @override
  Widget build(BuildContext context) {
    String typeLabel;
    switch (room.roomType) {
      case 'apartment':
        typeLabel = 'Apartment';
        break;
      case 'studio':
        typeLabel = 'Studio';
        break;
      case 'single':
        typeLabel = 'Single room';
        break;
      case 'shared':
        typeLabel = 'Shared room';
        break;
      default:
        typeLabel = room.roomType;
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              _ImageCarousel(images: room.images),
              Positioned(
                left: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.home_work_outlined, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(typeLabel, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'ETB ${room.monthlyRent.toStringAsFixed(0)}/mo',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${room.city} • ${room.address}',
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.group_outlined, size: 16),
                    const SizedBox(width: 4),
                    Text('Max ${room.maxOccupants}'),
                    const SizedBox(width: 12),
                    const Icon(Icons.wc, size: 16),
                    const SizedBox(width: 4),
                    Text(room.genderPreference),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        icon: const Icon(Icons.person),
                        label: const Text('Rent alone'),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Rent-alone booking coming soon')), // TODO: wire booking when backend ready
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(44)),
                        icon: const Icon(Icons.group_add),
                        label: const Text('With others'),
                        onPressed: () {
                          // Prefer full-screen page flow
                          String? token;
                          int? age;
                          String? religion;
                          try {
                            final auth = context.read<AuthViewModel>();
                            token = auth.token;
                            age = auth.userAge;
                            religion = auth.userReligion;
                          } catch (_) {
                            token = null;
                          }
                          if (token == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please log in to continue')),
                            );
                            return;
                          }
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RentWithOthersPage(
                                token: token!,
                                roomId: room.id,
                                initialAge: age,
                                initialDesiredGroupSize: 2,
                                initialReligionPreference: (religion == null || religion.isEmpty) ? 'any' : religion,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCarousel extends StatefulWidget {
  final List<RoomImage> images;
  const _ImageCarousel({required this.images});

  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
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
    final images = widget.images;
    if (images.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        alignment: Alignment.center,
        child: const Icon(Icons.image_not_supported_outlined, size: 48, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 200,
          width: double.infinity,
          child: PageView.builder(
            controller: _controller,
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) {
              final url = _normalizeUrl(images[i].imageUrl);
              // Debug: log original vs normalized URL
              // ignore: avoid_print
              debugPrint('Renter IMG => original: ${images[i].imageUrl} | normalized: $url');
              return Image.network(
                url,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      height: 28,
                      width: 28,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
                errorBuilder: (context, error, stack) {
                  // Debug: log network image error
                  debugPrint('Renter IMG ERROR for $url => $error');
                  return Container(
                    color: Colors.grey.shade200,
                    alignment: Alignment.center,
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined, size: 36, color: Colors.grey),
                        SizedBox(height: 6),
                        Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (images.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(images.length, (i) {
                final active = i == _index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: active ? 16 : 6,
                  decoration: BoxDecoration(
                    color: active ? Colors.white : Colors.white70,
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }

  String _normalizeUrl(String url) {
    var s = url.trim();
    if (s.isEmpty) return s;
    // Fix common Cloudinary host typo
    s = s.replaceAll('res.cloudinaru.com', 'res.cloudinary.com');
    // Prepend https if protocol-relative
    if (s.startsWith('//')) s = 'https:$s';
    // Prefix backend base URL for relative paths
    if (!s.startsWith('http://') && !s.startsWith('https://')) {
      if (!s.startsWith('/')) s = '/$s';
      s = '${ApiConstants.baseUrl}$s';
    }
    // Replace localhost/127.0.0.1 with emulator-friendly base origin
    try {
      final uri = Uri.tryParse(s);
      final base = Uri.parse(ApiConstants.baseUrl);
      if (uri != null && uri.hasAuthority) {
        if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
          final replaced = uri.replace(scheme: base.scheme, host: base.host, port: base.hasPort ? base.port : null);
          s = replaced.toString();
        }
        // Only force https for Cloudinary
        if (uri.host.contains('cloudinary.com') && uri.scheme != 'https') {
          final replaced = uri.replace(scheme: 'https', port: null);
          s = replaced.toString();
        }
      }
    } catch (_) {}
    return s;
  }
}
