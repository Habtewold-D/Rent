import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../core/constants/api_constants.dart' as api;
import '../../../data/services/matching_service.dart';

class RenterBookingsPage extends StatefulWidget {
  final String? payUrl;
  final String? payLabel;
  final double? costPerPerson;
  final String? source; // e.g., 'notification'
  final String? expiresAtIso; // ISO string
  final String? groupId;
  final String? roomId;
  final String? groupName;

  const RenterBookingsPage({
    super.key,
    this.payUrl,
    this.payLabel,
    this.costPerPerson,
    this.source,
    this.expiresAtIso,
    this.groupId,
    this.roomId,
    this.groupName,
  });

  @override
  State<RenterBookingsPage> createState() => _RenterBookingsPageState();
}

class _RenterBookingsPageState extends State<RenterBookingsPage> {
  // Direct deeplink payment (single card) support
  Duration? _timeLeft;
  late final DateTime? _expiresAt;
  late final String? _groupName;

  // Notifications-driven lists
  bool _loading = false;
  List<Map<String, dynamic>> _pending = [];
  List<Map<String, dynamic>> _past = [];
  String _filter = 'pending'; // 'pending' | 'past'

  @override
  void initState() {
    super.initState();
    _expiresAt = (widget.expiresAtIso != null && widget.expiresAtIso!.isNotEmpty)
        ? DateTime.tryParse(widget.expiresAtIso!)
        : null;
    _groupName = widget.groupName;
    _tick();
    // Load notifications if no direct pay URL passed
    if (widget.payUrl == null || widget.payUrl!.isEmpty) {
      _loadFromNotifications();
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _tick() {
    if (_expiresAt == null) return;
    void update() {
      final now = DateTime.now();
      final diff = _expiresAt!.difference(now);
      setState(() => _timeLeft = diff.isNegative ? Duration.zero : diff);
      if (diff.isNegative) return;
      Future.delayed(const Duration(seconds: 1), update);
    }
    update();
  }

  String _format(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Future<void> _loadFromNotifications() async {
    setState(() => _loading = true);
    try {
      final auth = context.read<AuthViewModel>();
      final token = auth.token;
      if (token == null || token.isEmpty) {
        setState(() => _loading = false);
        return;
      }
      // Build payment meta from notifications (payUrl, expiresAt, labels) keyed by groupId
      final res = await MatchingService().getNotifications(token);
      final notificationsRaw = res['notifications'];
      final List<Map<String, dynamic>> notifications =
          (notificationsRaw is List)
              ? notificationsRaw.map((e) => (e is Map<String, dynamic>) ? e : <String, dynamic>{}).toList()
              : <Map<String, dynamic>>[];
      final Map<String, Map<String, dynamic>> payMetaByGroup = {};
      for (final n in notifications) {
        Map<String, dynamic> data;
        final rawData = n['data'];
        if (rawData is Map<String, dynamic>) {
          data = rawData;
        } else if (rawData is String && rawData.trim().isNotEmpty) {
          try { data = (jsonDecode(rawData) as Map).cast<String, dynamic>(); } catch (_) { data = <String, dynamic>{}; }
        } else { data = <String, dynamic>{}; }
        final params = (data['params'] is Map<String, dynamic>) ? (data['params'] as Map).cast<String, dynamic>() : <String, dynamic>{};
        final gid = '${params['groupId'] ?? n['groupId'] ?? ''}';
        if (gid.isEmpty) continue;
        payMetaByGroup[gid] = {
          'payUrl': params['payUrl'] ?? n['payUrl'] ?? '',
          'payLabel': params['payLabel'] ?? n['payLabel'] ?? 'Pay now',
          'expiresAt': '${params['expiresAt'] ?? data['expiresAt'] ?? n['expiresAt'] ?? ''}',
          'createdAt': '${n['createdAt'] ?? n['created_at'] ?? n['timestamp'] ?? data['createdAt'] ?? data['created_at'] ?? ''}',
        };
      }

      // Primary source: my groups
      final myGroups = await MatchingService().getMyGroups(token);
      final now = DateTime.now();
      final pending = <Map<String, dynamic>>[];
      final past = <Map<String, dynamic>>[];

      String _gid(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        return '${m['_id'] ?? m['id'] ?? m['groupId'] ?? ''}';
      }

      List<String> _namesFromGroup(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        final members = (m['members'] is List) ? m['members'] as List : const [];
        String _nameOf(dynamic mm) {
          final x = mm is Map ? mm : const {};
          final user = x['user'] is Map ? x['user'] as Map : const {};
          final first = '${user['firstName'] ?? x['firstName'] ?? ''}'.trim();
          final last = '${user['lastName'] ?? x['lastName'] ?? ''}'.trim();
          final full = '${user['fullName'] ?? x['fullName'] ?? ''}'.trim();
          final name = full.isNotEmpty
              ? full
              : ((first.isNotEmpty || last.isNotEmpty) ? ('$first $last').trim() : '${user['name'] ?? x['name'] ?? user['username'] ?? x['username'] ?? ''}');
          return name.toString();
        }
        return members.map(_nameOf).where((s) => s.trim().isNotEmpty).cast<String>().toList();
      }

      List<String> _religionsFromGroup(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        final members = (m['members'] is List) ? m['members'] as List : const [];
        final rels = <String>{};
        for (final mm in members) {
          final x = mm is Map ? mm : const {};
          final user = x['user'] is Map ? x['user'] as Map : const {};
          final r = '${x['religion'] ?? user['religion'] ?? m['religionPreference'] ?? ''}'.trim();
          if (r.isNotEmpty) rels.add(r);
        }
        if (rels.isEmpty) {
          final rp = '${m['religionPreference'] ?? ''}'.trim();
          if (rp.isNotEmpty) rels.add(rp);
        }
        return rels.toList();
      }

      String _locationFromGroup(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        final room = m['room'] is Map ? m['room'] as Map : const {};
        final property = m['property'] is Map ? m['property'] as Map : const {};
        final loc = '${m['location'] ?? room['location'] ?? room['address'] ?? property['location'] ?? property['address'] ?? ''}';
        return loc;
      }

      String _nameFromGroup(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        final room = m['room'] is Map ? m['room'] as Map : const {};
        return '${m['name'] ?? m['groupName'] ?? room['title'] ?? room['name'] ?? ''}';
      }

      num? _priceFromGroup(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        final room = m['room'] is Map ? m['room'] as Map : const {};
        final price = m['costPerPerson'] ?? m['pricePerPerson'] ?? room['pricePerPerson'] ?? room['price'] ?? m['price'];
        if (price is num) return price;
        if (price is String) return num.tryParse(price);
        return null;
      }

      // Extract image candidates for carousel (class-level helper)
      List<String> _imagesFromGroup(dynamic grp) {
        final m = grp is Map<String, dynamic> ? grp : <String, dynamic>{};
        final room = m['room'] is Map ? m['room'] as Map : const {};
        final property = m['property'] is Map ? m['property'] as Map : const {};
        List _asList(dynamic v) {
          if (v is List) return v;
          if (v is String) {
            final s = v.trim();
            if (s.startsWith('[') && s.endsWith(']')) {
              try {
                final parsed = jsonDecode(s);
                if (parsed is List) return parsed;
              } catch (_) {}
            }
            // comma-separated
            if (s.contains(',')) {
              return s.split(',');
            }
          }
          return const [];
        }
        final imgs = _asList(room['images']) + _asList(property['images']) + _asList(m['images']) +
            _asList(room['photos']) + _asList(property['photos']) + _asList(m['photos']) +
            _asList(room['thumbnails']) + _asList(property['thumbnails']);
        String pick(dynamic v) {
          if (v is String) return v;
          if (v is Map) {
            for (final k in ['secure_url', 'url', 'path', 'src', 'image', 'imageUrl']) {
              final val = v[k];
              if (val is String && val.trim().isNotEmpty) return val;
            }
          }
          return '';
        }
        final list = <String>{
          ...imgs.map(pick).where((s) => s.isNotEmpty),
          '${room['imageUrl'] ?? ''}',
          '${property['imageUrl'] ?? ''}',
          '${m['imageUrl'] ?? ''}',
          '${property['coverImage'] ?? ''}',
          '${room['coverImage'] ?? ''}',
          '${room['picture'] ?? ''}',
          '${room['coverPhoto'] ?? ''}',
          '${property['coverPhoto'] ?? ''}',
        }..removeWhere((s) => s.trim().isEmpty || s.toLowerCase() == 'null');
        return list.toList();
      }

      bool _isPaymentRequired(dynamic g) {
        final m = g is Map<String, dynamic> ? g : <String, dynamic>{};
        if (m['paymentRequired'] == true) return true;
        final paymentStatus = '${m['paymentStatus'] ?? ''}'.toLowerCase();
        if (paymentStatus == 'pending') return true;
        final spotsLeftVal = m['spotsLeft'];
        final spotsLeft = (spotsLeftVal is num)
            ? spotsLeftVal.toInt()
            : int.tryParse('${spotsLeftVal ?? ''}') ?? -1;
        if (spotsLeft == 0) return true;
        final status = '${m['status'] ?? ''}'.toLowerCase();
        if (status.contains('payment')) return true;
        if (status == 'complete' || status == 'completed' || status == 'full') return true;
        return false;
      }

      for (final g in (myGroups is List ? myGroups : const [])) {
        final gid = _gid(g);
        if (gid.isEmpty) continue;
        final meta = payMetaByGroup[gid] ?? const <String, dynamic>{};
        // Try multiple fields for expiry on group
        String _expiresFromGroup(dynamic grp) {
          final m = grp is Map<String, dynamic> ? grp : <String, dynamic>{};
          final candidates = [
            m['paymentExpiresAt'],
            m['paymentDeadline'],
            m['expiresAt'],
            m['paymentWindowEndsAt'],
          ];
          for (final c in candidates) {
            final s = '$c';
            if (s.isNotEmpty && s.toLowerCase() != 'null') return s;
          }
          return '';
        }
        // Prefer membership-level paymentDueAt (set when group becomes full)
        String expiresAtIso = '';
        // Some backends may return Date objects serialized; ensure string
        final dynamic paymentDue = g is Map<String, dynamic> ? g['paymentDueAt'] : null;
        if (paymentDue is String && paymentDue.trim().isNotEmpty && paymentDue.toLowerCase() != 'null') {
          expiresAtIso = paymentDue;
        } else if (paymentDue != null) {
          // fall back to toString for Date-like objects
          final s = '$paymentDue';
          if (s.isNotEmpty && s.toLowerCase() != 'null') expiresAtIso = s;
        }
        if (expiresAtIso.isEmpty) {
          final fromMeta = '${meta['expiresAt'] ?? ''}';
          if (fromMeta.isNotEmpty && fromMeta.toLowerCase() != 'null') {
            expiresAtIso = fromMeta;
          } else {
            expiresAtIso = '${_expiresFromGroup(g) ?? ''}';
          }
        }
        // Do not synthesize expiries on the client; rely on backend-provided timestamps only
        DateTime? exp = expiresAtIso.isNotEmpty ? DateTime.tryParse(expiresAtIso) : null;
        if (exp != null && exp.isUtc) exp = exp.toLocal();
        String payUrl = '${meta['payUrl'] ?? ''}';
        if (payUrl.trim().isEmpty) {
          final mg = (g is Map<String, dynamic>) ? g : <String, dynamic>{};
          final room = (mg['room'] is Map<String, dynamic>) ? mg['room'] as Map<String, dynamic> : const <String, dynamic>{};
          final roomId = '${room['id'] ?? room['_id'] ?? mg['roomId'] ?? ''}';
          if (roomId.isNotEmpty && gid.isNotEmpty) {
            payUrl = '/payments/rooms/$roomId/groups/$gid';
          }
        }
        final payLabel = '${meta['payLabel'] ?? 'Pay now'}';

        final hasDue = expiresAtIso.isNotEmpty;
        if (!_isPaymentRequired(g) && !hasDue) {
          // Skip groups that have neither payment requirement nor a deadline
          continue;
        }

        final item = <String, dynamic>{
          'groupId': gid,
          'groupName': _nameFromGroup(g),
          'members': _namesFromGroup(g),
          'location': _locationFromGroup(g),
          'costPerPerson': _priceFromGroup(g)?.toDouble(),
          'payUrl': payUrl,
          'payLabel': payLabel,
          'expiresAt': expiresAtIso,
          'imageUrls': _imagesFromGroup(g),
        };

        // Use parsed exp above for classification
        if (exp == null || exp.isAfter(now)) {
          pending.add(item);
        } else {
          past.add(item);
        }
      }

      // Fallback: If nothing in pending, surface completed/full groups so user sees them
      if (pending.isEmpty && (myGroups is List)) {
        for (final g in myGroups as List) {
          final status = '${(g as Map?)?['status'] ?? ''}'.toLowerCase();
          final spotsLeftVal = (g as Map?)?['spotsLeft'];
          final spotsLeft = (spotsLeftVal is num) ? spotsLeftVal.toInt() : int.tryParse('${spotsLeftVal ?? ''}') ?? -1;
          final isComplete = status == 'complete' || status == 'completed' || status == 'full' || spotsLeft == 0;
          if (!isComplete) continue;
          final gid = _gid(g);
          if (gid.isEmpty) continue;
          final meta = payMetaByGroup[gid] ?? const <String, dynamic>{};
          // compute expiresAt similarly to the main loop
          String fxExpires = '';
          final dynamic fxPaymentDue = (g is Map<String, dynamic>) ? g['paymentDueAt'] : null;
          if (fxPaymentDue is String && fxPaymentDue.trim().isNotEmpty && fxPaymentDue.toLowerCase() != 'null') {
            fxExpires = fxPaymentDue;
          } else if (fxPaymentDue != null) {
            final s = '$fxPaymentDue';
            if (s.isNotEmpty && s.toLowerCase() != 'null') fxExpires = s;
          }
          if (fxExpires.isEmpty) {
            final metaExp = '${meta['expiresAt'] ?? ''}';
            if (metaExp.isNotEmpty && metaExp.toLowerCase() != 'null') {
              fxExpires = metaExp;
            }
          }
          final item = <String, dynamic>{
            'groupId': gid,
            'groupName': _nameFromGroup(g),
            'members': _namesFromGroup(g),
            'location': _locationFromGroup(g),
            'costPerPerson': _priceFromGroup(g)?.toDouble(),
            'payUrl': '${meta['payUrl'] ?? ''}',
            'payLabel': '${meta['payLabel'] ?? 'Pay now'}',
            // Use backend-provided expiry if available
            'expiresAt': fxExpires,
            'imageUrls': _imagesFromGroup(g),
          };
          pending.add(item);
        }
      }

      setState(() {
        _pending = pending;
        _past = past;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load bookings: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final payUrl = widget.payUrl;
    final showPayment = (payUrl != null && payUrl.isNotEmpty);
    if (!showPayment) {
      // Notifications-driven page with filter
      return RefreshIndicator(
        onRefresh: _loadFromNotifications,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _filter = 'pending'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _filter == 'pending' ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filter == 'pending' ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.pending_actions, size: 18),
                              SizedBox(width: 6),
                              Text('Pending'),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => setState(() => _filter = 'past'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _filter == 'past' ? Theme.of(context).colorScheme.primary.withOpacity(0.12) : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _filter == 'past' ? Theme.of(context).colorScheme.primary : Theme.of(context).dividerColor,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.history, size: 18),
                              SizedBox(width: 6),
                              Text('Past'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: CircularProgressIndicator(),
              ))
            else ...[
              if (_filter == 'pending') ...[
                if (_pending.isEmpty)
                  const _Placeholder(title: 'No payments required', subtitle: 'When a group completes, you will see it here.')
                else ..._pending.map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PayRequiredCard(
                        groupName: '${it['groupName'] ?? ''}',
                        costPerPerson: (it['costPerPerson'] is num) ? (it['costPerPerson'] as num).toDouble() : null,
                        payUrl: '${it['payUrl'] ?? ''}',
                        payLabel: '${it['payLabel'] ?? 'Pay now'}',
                        expiresAtIso: '${it['expiresAt'] ?? ''}',
                        groupId: '${it['groupId'] ?? ''}',
                        members: (it['members'] is List) ? (it['members'] as List).cast<String>() : const <String>[],
                        location: '${it['location'] ?? ''}',
                        onLeave: () => _leaveGroup('${it['groupId'] ?? ''}'),
                      ),
                    )),
              ] else ...[
                if (_past.isEmpty)
                  const _Placeholder(title: 'No past bookings', subtitle: 'Expired or completed bookings will appear here.')
                else ..._past.map((it) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _PastBookingCard(
                        groupName: '${it['groupName'] ?? ''}',
                        costPerPerson: (it['costPerPerson'] is num) ? (it['costPerPerson'] as num).toDouble() : null,
                        expiresAtIso: '${it['expiresAt'] ?? ''}',
                      ),
                    )),
              ],
            ],
          ],
        ),
      );
    }
    // Direct-pay card when navigated via notification with specific params
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title removed; AppBar already shows it
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.payment_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _groupName?.isNotEmpty == true
                              ? '$_groupName — payment required'
                              : 'Group complete — payment required',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (widget.costPerPerson != null)
                    Text('Cost per person: ${widget.costPerPerson!.toStringAsFixed(2)} ETB'),
                  if (widget.source != null) ...[
                    const SizedBox(height: 4),
                    Text('Opened from: ${widget.source}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                  if (_expiresAt != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.timer_outlined, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          _timeLeft == null || _timeLeft == Duration.zero
                              ? 'Expired'
                              : 'Expires in ${_format(_timeLeft!)}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const SizedBox(width: 20),
                        Text('Expires at: ' + _expiresAt!.toLocal().toString().split('.').first),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Proceeding to payment: $payUrl')),
                        );
                        // TODO: Navigate to actual payment flow using payUrl
                      },
                      child: Text(widget.payLabel?.isNotEmpty == true ? widget.payLabel! : 'Pay now'),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Leave group?'),
                      content: const Text('Are you sure you want to leave this group?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
                      ],
                    ),
                  );
                  if (confirm != true) return;
                  // TODO: Call leave group API with widget.groupId
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Leaving group...')),
                  );
                },
                icon: const Icon(Icons.exit_to_app),
                label: const Text('Leave Group'),
              ),
            ],
          )
        ],
      ),
    );
  }

  Future<void> _leaveGroup(String groupId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave group?'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Leave')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final auth = context.read<AuthViewModel>();
      final token = auth.token;
      if (token == null || token.isEmpty) return;
      await MatchingService().leaveGroup(token, groupId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Left group')));
      await _loadFromNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to leave group: $e')));
    }
  }
}

class _PayRequiredCard extends StatefulWidget {
  final String groupName;
  final double? costPerPerson;
  final String payUrl;
  final String payLabel;
  final String? expiresAtIso;
  final String groupId;
  final List<String> members;
  final String location;
  final Future<void> Function()? onLeave;

  const _PayRequiredCard({
    required this.groupName,
    required this.costPerPerson,
    required this.payUrl,
    required this.payLabel,
    required this.expiresAtIso,
    required this.groupId,
    required this.members,
    required this.location,
    this.onLeave,
  });

  @override
  State<_PayRequiredCard> createState() => _PayRequiredCardState();
}

class _PayRequiredCardState extends State<_PayRequiredCard> {
  Duration? _left;
  DateTime? _exp;

  @override
  void initState() {
    super.initState();
    final parsed = (widget.expiresAtIso != null && widget.expiresAtIso!.isNotEmpty)
        ? DateTime.tryParse(widget.expiresAtIso!)
        : null;
    if (parsed != null) {
      _exp = parsed.isUtc ? parsed.toLocal() : parsed;
    } else {
      _exp = null;
    }
    // Initialize remaining time immediately so UI shows countdown without waiting a tick
    if (_exp != null) {
      final now = DateTime.now();
      final d = _exp!.difference(now);
      _left = d.isNegative ? Duration.zero : d;
    }
    _tick();
  }

  void _tick() {
    if (_exp == null) return;
    void update() {
      final now = DateTime.now();
      final d = _exp!.difference(now);
      if (!mounted) return;
      setState(() => _left = d.isNegative ? Duration.zero : d);
      if (d.isNegative) return;
      Future.delayed(const Duration(seconds: 1), update);
    }
    update();
  }

  String _fmt(Duration d) {
    final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
    if (h > 0) {
      final mm = m.toString().padLeft(2, '0');
      final ss = s.toString().padLeft(2, '0');
      return '${h}:${mm}:${ss}';
    }
    final mm = (d.inMinutes).toString().padLeft(2, '0');
    final ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final Duration? liveLeft = _exp != null ? _exp!.difference(now) : null;
    final expired = liveLeft != null && liveLeft.inSeconds <= 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payment_outlined, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.groupName.isNotEmpty
                        ? '${widget.groupName} — payment required'
                        : 'Group complete — payment required',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (widget.costPerPerson != null)
              Text('Price per person: ${widget.costPerPerson!.toStringAsFixed(2)} ETB'),
            if (widget.location.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.place_outlined, size: 16),
                  const SizedBox(width: 4),
                  Expanded(child: Text(widget.location, maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ],
            if (_exp != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.timer_outlined, size: 16),
                  const SizedBox(width: 4),
                  Text('Expires at: ' + _exp!.toLocal().toString().split('.').first),
                ],
              ),
            ],
            if (widget.members.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Members', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: -6,
                children: widget.members
                    .map((m) => Chip(label: Text(m), visualDensity: VisualDensity.compact, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap))
                    .toList(),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: widget.onLeave,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Leave Group'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: () {
                    final url = widget.payUrl.trim();
                    if (url.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment link not available yet.')),
                      );
                      return;
                    }
                    final now = DateTime.now();
                    final expired = _exp != null && _exp!.isBefore(now);
                    if (expired) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Payment window may have expired, attempting to open anyway...')),
                      );
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Proceeding to payment: $url')),
                    );
                    // TODO: navigate to payment screen using `url`
                  },
                  child: Text(widget.payLabel.isNotEmpty ? widget.payLabel : 'Pay now'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _PastBookingCard extends StatelessWidget {
  final String groupName;
  final double? costPerPerson;
  final String? expiresAtIso;

  const _PastBookingCard({
    required this.groupName,
    required this.costPerPerson,
    required this.expiresAtIso,
  });

  @override
  Widget build(BuildContext context) {
    final exp = (expiresAtIso != null && expiresAtIso!.isNotEmpty) ? DateTime.tryParse(expiresAtIso!) : null;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    groupName.isNotEmpty ? '$groupName — past booking' : 'Past booking',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            if (costPerPerson != null) ...[
              const SizedBox(height: 8),
              Text('Cost per person: ${costPerPerson!.toStringAsFixed(2)} ETB'),
            ],
            if (exp != null) ...[
              const SizedBox(height: 8),
              Text('Expired at: ${exp.toLocal()}'),
            ]
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Placeholder({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(subtitle, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
