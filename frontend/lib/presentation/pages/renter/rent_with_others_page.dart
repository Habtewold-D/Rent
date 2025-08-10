import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../../../data/services/matching_service.dart';
import '../../../core/constants/api_constants.dart';
import '../notifications/notifications_page.dart';
import '../../widgets/notification_bell.dart';

class RentWithOthersPage extends StatefulWidget {
  final String token;
  final String roomId;
  // Optional initial values to auto-fill from profile
  final int? initialAge;
  final int? initialDesiredGroupSize;
  final String? initialReligionPreference; // e.g. 'any'

  const RentWithOthersPage({
    super.key,
    required this.token,
    required this.roomId,
    this.initialAge,
    this.initialDesiredGroupSize,
    this.initialReligionPreference,
  });

  @override
  State<RentWithOthersPage> createState() => _RentWithOthersPageState();
}

class _RentWithOthersPageState extends State<RentWithOthersPage> {
  final _formKey = GlobalKey<FormState>();
  final _ageCtrl = TextEditingController();
  final _sizeCtrl = TextEditingController();
  String _religionPref = 'any';
  String _genderPref = 'any';

  final _service = MatchingService();

  bool _loading = false;
  String? _error;
  List<dynamic> _suggestedGroups = [];
  List<dynamic> _recommendedGroups = [];
  List<dynamic> _otherGroups = [];
  List<dynamic> _myGroups = [];

  @override
  void initState() {
    super.initState();
    if (widget.initialAge != null) _ageCtrl.text = widget.initialAge.toString();
    if (widget.initialDesiredGroupSize != null) {
      _sizeCtrl.text = widget.initialDesiredGroupSize.toString();
    }
    if (widget.initialReligionPreference != null && widget.initialReligionPreference!.isNotEmpty) {
      final v = widget.initialReligionPreference!;
      const allowed = {
        'any',
        'orthodox',
        'muslim',
        'protestant',
        'catholic',
        'other_christian',
        'other'
      };
      _religionPref = allowed.contains(v) ? v : 'any';
    }
    // Fallback: fetch profile to prefill age/religion if missing
    _loadProfileIfNeeded();
    _loadMyGroups();
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _sizeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMyGroups() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final groups = await _service.getMyGroups(widget.token);
      setState(() => _myGroups = groups);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool _validateAndSave() {
    final ok = _formKey.currentState?.validate() ?? false;
    return ok;
  }

  Future<void> _findGroups() async {
    if (!_validateAndSave()) return;
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final size = int.tryParse(_sizeCtrl.text.trim()) ?? 2;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // Using joinRoom as a discovery endpoint to retrieve compatible groups from backend
      final Map<String, dynamic> data = await _service.joinRoom(
        widget.token,
        widget.roomId,
        userAge: age,
        desiredGroupSize: size,
        religionPreference: _religionPref,
        genderPreference: _genderPref,
      );
      // Parse both recommended and other groups
      List<dynamic> rec = [];
      List<dynamic> oth = [];
      if (data['groups'] is List) {
        rec = List<dynamic>.from(data['groups'] as List);
      }
      if (data['availableGroups'] is List) {
        oth = List<dynamic>.from(data['availableGroups'] as List);
      }
      if (data['matches'] is List) {
        rec = List<dynamic>.from(data['matches'] as List);
      }
      if (data['recommendedGroups'] is List) {
        rec = List<dynamic>.from(data['recommendedGroups'] as List);
      }
      if (data['otherGroups'] is List) {
        oth = List<dynamic>.from(data['otherGroups'] as List);
      }
      setState(() {
        _recommendedGroups = rec;
        _otherGroups = oth;
        // keep _suggestedGroups for backward compatibility (union)
        _suggestedGroups = [...rec, ...oth];
      });
      // Debug counts
      // ignore: avoid_print
      print('joinRoom -> rec: ${rec.length}, other: ${oth.length}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createGroup() async {
    if (!_validateAndSave()) return;
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 0;
    final size = int.tryParse(_sizeCtrl.text.trim()) ?? 2;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.createGroup(
        widget.token,
        widget.roomId,
        userAge: age,
        desiredGroupSize: size,
        religionPreference: _religionPref,
      );
      await _loadMyGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group created successfully')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _joinGroup(String groupId) async {
    final age = int.tryParse(_ageCtrl.text.trim());
    if (age == null || age <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your age before joining')),
      );
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.joinGroup(
        widget.token,
        groupId,
        userAge: age,
        religionPreference: _religionPref,
      );
      await _loadMyGroups();
      // Refresh suggestions so the joined group disappears from joinable lists
      // Use current form inputs if valid
      final desired = int.tryParse(_sizeCtrl.text.trim());
      if (desired != null && desired > 0) {
        await _findGroups();
      }
      if (mounted) {
        // Show a clear success dialog
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Success'),
            content: const Text('You have joined the group successfully.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              )
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to join group: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _leaveGroup(String groupId) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.leaveGroup(widget.token, groupId);
      await _loadMyGroups();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Left group')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadProfileIfNeeded() async {
    if (_ageCtrl.text.trim().isNotEmpty) return;
    try {
      final res = await http.get(
        Uri.parse('${ApiConstants.baseUrl}${ApiConstants.profile}'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Accept': 'application/json',
        },
      );
      if (res.statusCode >= 200 && res.statusCode < 300 && res.body.isNotEmpty) {
        dynamic parsed;
        try {
          parsed = jsonDecode(res.body);
        } catch (_) {
          parsed = {};
        }
        Map<String, dynamic> user = {};
        if (parsed is Map<String, dynamic>) {
          final data = parsed['data'];
          if (data is Map<String, dynamic>) {
            if (data['user'] is Map<String, dynamic>) {
              user = Map<String, dynamic>.from(data['user'] as Map);
            } else {
              user = Map<String, dynamic>.from(data);
            }
          } else if (parsed['user'] is Map<String, dynamic>) {
            user = Map<String, dynamic>.from(parsed['user'] as Map);
          }
        }
        if (user.isNotEmpty) {
          final dynAge = user['age'];
          int? age;
          if (dynAge is int) {
            age = dynAge;
          } else if (dynAge is String) {
            age = int.tryParse(dynAge);
          }
          final rel = user['religion']?.toString();
          if ((_ageCtrl.text.isEmpty) && age != null && age > 0) {
            setState(() => _ageCtrl.text = age!.toString());
          }
          if (rel != null && rel.isNotEmpty) {
            const allowed = {
              'any',
              'orthodox',
              'muslim',
              'protestant',
              'catholic',
              'other_christian',
              'other'
            };
            if (allowed.contains(rel)) {
              setState(() => _religionPref = rel);
            }
          }
        }
      }
    } catch (_) {
      // Silent failure: leave form manual if profile fetch fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rent with others'),
        actions: const [NotificationBell()],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_error != null)
              MaterialBanner(
                content: Text(_error!),
                actions: [
                  TextButton(onPressed: () => setState(() => _error = null), child: const Text('Dismiss')),
                ],
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildForm(theme),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _loading ? null : _findGroups,
                            icon: const Icon(Icons.search),
                            label: const Text('Find groups'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _loading ? null : _createGroup,
                            icon: const Icon(Icons.group_add),
                            label: const Text('Create new group'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    if (_recommendedGroups.isNotEmpty) ...[
                      Text('Recommended for you', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildGroupsList(_recommendedGroups, joinable: true),
                      if (_otherGroups.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Text('Other groups for this room', style: theme.textTheme.titleMedium),
                        const SizedBox(height: 8),
                        _buildGroupsList(_otherGroups, joinable: true),
                      ],
                    ] else if (_otherGroups.isNotEmpty) ...[
                      Text('Groups for this room', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      _buildGroupsList(_otherGroups, joinable: true),
                    ] else ...[
                      Text('No compatible groups found yet', style: theme.textTheme.bodyMedium),
                    ],
                    const SizedBox(height: 24),
                    Text('My groups', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _buildGroupsList(_myGroups, joinable: false),
                  ],
                ),
              ),
            ),
            if (_loading)
              const LinearProgressIndicator(minHeight: 3),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(ThemeData theme) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _ageCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Your age'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n <= 0) return 'Enter a valid age';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _sizeCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Desired group size'),
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null || n < 2) return 'Must be at least 2';
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _religionPref,
            items: const [
              DropdownMenuItem(value: 'any', child: Text('Any')),
              DropdownMenuItem(value: 'orthodox', child: Text('Orthodox')),
              DropdownMenuItem(value: 'muslim', child: Text('Muslim')),
              DropdownMenuItem(value: 'protestant', child: Text('Protestant')),
              DropdownMenuItem(value: 'catholic', child: Text('Catholic')),
              DropdownMenuItem(value: 'other_christian', child: Text('Other Christian')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _religionPref = v ?? 'any'),
            decoration: const InputDecoration(labelText: 'Religion preference'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _genderPref,
            items: const [
              DropdownMenuItem(value: 'any', child: Text('Any')),
              DropdownMenuItem(value: 'male', child: Text('Male only rooms')),
              DropdownMenuItem(value: 'female', child: Text('Female only rooms')),
              DropdownMenuItem(value: 'mixed', child: Text('Mixed rooms')),
            ],
            onChanged: (v) => setState(() => _genderPref = v ?? 'any'),
            decoration: const InputDecoration(labelText: 'Room gender preference (optional)'),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupsList(List<dynamic> groups, {required bool joinable}) {
    if (groups.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          joinable ? 'No matching groups yet. Try creating a new one.' : 'You are not in any groups yet.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.separated(
      itemCount: groups.length,
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final g = groups[i];
        final id = _readId(g, ['id', '_id', 'groupId']) ?? 'unknown';
        final title = _readString(g, ['name', 'title']) ?? 'Roommate group';
        final members = _readInt(g, ['currentSize', 'memberCount', 'size', 'membersCount']) ?? _readListLen(g, ['members']);
        final maxSize = _readInt(g, ['targetSize', 'maxSize', 'desiredGroupSize', 'capacity']);
        final religion = _readString(g, ['religionPreference']);
        final landlordReq = _readString(g, ['landlordRequirement', 'landlordReq']) ?? '';
        final ageRange = _readString(g, ['ageRange']);
        final cost = _readNum(g, ['costPerPerson']);
        final isCreator = _readBool(g, ['isCreator']) ?? false;

        final isMember = _isMemberOf(id);

        // Optional room info
        final room = (g is Map && g['room'] is Map) ? (g['room'] as Map) : const {};
        final city = ((room['city'] ?? '') as String).toString();
        final address = ((room['address'] ?? '') as String).toString();
        final location = [address, city].where((s) => s.isNotEmpty).join(', ');

        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      child: Text((maxSize ?? '-').toString()),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.group, size: 16),
                              const SizedBox(width: 4),
                              Text(maxSize != null && members != null ? '$members/$maxSize members' : 'Group'),
                              if (location.isNotEmpty) ...[
                                const SizedBox(width: 12),
                                const Icon(Icons.place, size: 16),
                                const SizedBox(width: 4),
                                Flexible(child: Text(location, overflow: TextOverflow.ellipsis)),
                              ]
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        if (joinable && !isMember)
                          FilledButton(
                            onPressed: _loading ? null : () => _joinGroup(id),
                            child: const Text('Join'),
                          )
                        else if (!joinable && isMember)
                          FilledButton.tonal(
                            onPressed: _loading ? null : () => _leaveGroup(id),
                            child: const Text('Leave'),
                          ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 8),
                // Members chips
                Builder(builder: (context) {
                  final membersList = (g is Map && g['members'] is List)
                      ? List<Map<String, dynamic>>.from(g['members'] as List)
                      : const <Map<String, dynamic>>[];
                  if (membersList.isEmpty) return const SizedBox.shrink();
                  final names = membersList
                      .map((m) => (m['firstName'] ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toList();
                  if (names.isEmpty) return const SizedBox.shrink();
                  return Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text('Members:'),
                      ),
                      ...names.map((n) => Chip(
                            label: Text(n),
                            visualDensity: VisualDensity.compact,
                          )),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                // Attributes chips
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (isCreator)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('Creator'),
                        avatar: Icon(Icons.star, size: 16),
                      ),
                    if (ageRange != null && ageRange.isNotEmpty)
                      Chip(visualDensity: VisualDensity.compact, label: Text('Age: $ageRange')),
                    if (religion != null && religion.isNotEmpty)
                      Chip(visualDensity: VisualDensity.compact, label: Text('Religion: $religion')),
                    if (cost != null)
                      Chip(visualDensity: VisualDensity.compact, label: Text('ETB ${cost.toString()} /person')),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _isMemberOf(String groupId) {
    for (final g in _myGroups) {
      final id = _readId(g, ['id', '_id', 'groupId']);
      if (id == groupId) return true;
    }
    return false;
  }

  String? _readId(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
        if (v is int) return v.toString();
        if (v != null) {
          final s = v.toString();
          if (s.isNotEmpty) return s;
        }
      }
    }
    return null;
  }

  String? _readString(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.isNotEmpty) return v;
      }
    }
    return null;
  }

  int? _readInt(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is int) return v;
        if (v is String) {
          final n = int.tryParse(v);
          if (n != null) return n;
        }
      }
    }
    return null;
  }

  int? _readListLen(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is List) return v.length;
      }
    }
    return null;
  }

  num? _readNum(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is num) return v;
        if (v is String) {
          final d = double.tryParse(v);
          if (d != null) return d;
        }
      }
    }
    return null;
  }

  bool? _readBool(dynamic m, List<String> keys) {
    if (m is Map) {
      for (final k in keys) {
        final v = m[k];
        if (v is bool) return v;
        if (v is String) {
          if (v.toLowerCase() == 'true') return true;
          if (v.toLowerCase() == 'false') return false;
        }
        if (v is int) {
          if (v == 1) return true;
          if (v == 0) return false;
        }
      }
    }
    return null;
  }
}
