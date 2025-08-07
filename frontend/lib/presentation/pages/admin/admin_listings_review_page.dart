import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../data/services/admin_landlord_service.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../core/constants/api_constants.dart';
import 'document_preview_page.dart';
import 'request_detail_page.dart';

class AdminListingsReviewPage extends StatefulWidget {
  const AdminListingsReviewPage({super.key});

  @override
  State<AdminListingsReviewPage> createState() => _AdminListingsReviewPageState();
}

class _AdminListingsReviewPageState extends State<AdminListingsReviewPage> {
  final _service = AdminLandlordService();
  bool _loading = false;
  String? _error;
  String? _status; // null=all, else 'pending'|'approved'|'rejected'
  String _search = '';
  int _page = 1;
  int _limit = 10;

  Map<String, dynamic>? _stats; // {pending, approved, rejected, total}
  List<dynamic> _requests = [];
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadStats(), _loadRequests(resetPage: true)]);
  }

  Future<void> _loadStats() async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    try {
      final res = await _service.getStats(token);
      setState(() => _stats = res);
    } catch (e) {
      // non-blocking
    }
  }

  Future<void> _loadRequests({bool resetPage = false}) async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    setState(() { _loading = true; _error = null; if (resetPage) _page = 1; });
    try {
      final data = await _service.getRequests(
        token,
        status: _status,
        search: _search.isEmpty ? null : _search,
        page: _page,
        limit: _limit,
      );
      setState(() {
        final rawList = data['requests'];
        final list = (rawList is List) ? rawList : <dynamic>[];
        _requests = list.map((e) {
          if (e is Map<String, dynamic>) return e;
          if (e is Map) return Map<String, dynamic>.from(e as Map);
          return <String, dynamic>{};
        }).toList();
        final rawPg = data['pagination'];
        final Map<String, dynamic>? pg =
            rawPg is Map<String, dynamic> ? rawPg : (rawPg is Map ? Map<String, dynamic>.from(rawPg as Map) : null);
        _totalPages = _asInt(pg?['totalPages'], 1);
      });
    } catch (e) {
      setState(() => _error = _cleanError(e));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_error ?? 'Failed to load requests')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _cleanError(Object e) {
    final s = e.toString();
    const p = 'Exception: ';
    return s.startsWith(p) ? s.substring(p.length) : s;
  }

  String _asString(dynamic v, [String fallback = '']) {
    if (v == null) return fallback;
    return v.toString();
  }

  String? _pickUrl(Map<String, dynamic> map, List<String> keys) {
    for (final k in keys) {
      final value = map[k];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }
    return null;
  }

  String _ensureAbsoluteUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    final base = ApiConstants.baseUrl;
    if (url.startsWith('/')) {
      return base + url;
    }
    return base + '/' + url;
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString();
    final parsed = int.tryParse(s);
    return parsed ?? fallback;
  }

  Future<void> _review(String id, String status) async {
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    String? notes;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(status == 'approved' ? 'Approve request' : 'Reject request'),
          content: TextField(
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Admin notes (optional)'),
            onChanged: (v) => notes = v,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(status == 'approved' ? 'Approve' : 'Reject'),
            ),
          ],
        );
      },
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await _service.reviewRequest(token, id: id, status: status, adminNotes: notes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Request $status successfully')),
      );
      await _loadStats();
      await _loadRequests();
    } catch (e) {
      final msg = _cleanError(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open document')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        if (_stats != null) _StatsHeader(stats: _stats!),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: [
                  _statusChip('All', _status == null, () { setState(() => _status = null); _loadRequests(resetPage: true); }),
                  _statusChip('Pending', _status == 'pending', () { setState(() => _status = 'pending'); _loadRequests(resetPage: true); }),
                  _statusChip('Approved', _status == 'approved', () { setState(() => _status = 'approved'); _loadRequests(resetPage: true); }),
                  _statusChip('Rejected', _status == 'rejected', () { setState(() => _status = 'rejected'); _loadRequests(resetPage: true); }),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextField(
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'Search by user email or name',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (v) { setState(() => _search = v.trim()); _loadRequests(resetPage: true); },
              ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: () => _loadRequests(resetPage: true),
                      child: _requests.isEmpty
                          ? ListView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: const [
                                SizedBox(height: 120),
                                Center(child: Text('No requests found')),
                              ],
                            )
                          : ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: _requests.length,
                            itemBuilder: (context, index) {
                              try {
                                final r = _requests[index] as Map<String, dynamic>;
                                final dynamic rawUser = r['user'];
                                final Map<String, dynamic>? user = rawUser is Map<String, dynamic>
                                    ? rawUser
                                    : (rawUser is Map ? Map<String, dynamic>.from(rawUser as Map) : null);
                                final dynamic rawReviewer = r['reviewer'];
                                final Map<String, dynamic>? reviewer = rawReviewer is Map<String, dynamic>
                                    ? rawReviewer
                                    : (rawReviewer is Map ? Map<String, dynamic>.from(rawReviewer as Map) : null);
                                final String id = (r['id'] ?? r['_id'] ?? '').toString();
                                final status = _asString(r['status'], 'pending');
                                final createdAt = _asString(r['createdAt']);
                                String? nationalIdUrl = _pickUrl(r, ['nationalIdUrl', 'nationalId', 'national_id_url']);
                                String? propertyDocUrl = _pickUrl(r, ['propertyDocumentUrl', 'propertyDoc', 'property_document_url']);
                                if (nationalIdUrl != null) nationalIdUrl = _ensureAbsoluteUrl(nationalIdUrl);
                                if (propertyDocUrl != null) propertyDocUrl = _ensureAbsoluteUrl(propertyDocUrl);

                                final name = [user?['firstName'], user?['lastName']]
                                    .where((e) => _asString(e).isNotEmpty)
                                    .join(' ');
                                final email = _asString(user?['email']);

                                return InkWell(
                                  onTap: () {
                                    final payload = Map<String, dynamic>.from(r);
                                    if (nationalIdUrl != null) payload['nationalIdUrl'] = nationalIdUrl;
                                    if (propertyDocUrl != null) payload['propertyDocumentUrl'] = propertyDocUrl;
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => RequestDetailPage(request: payload),
                                      ),
                                    );
                                  },
                                  child: Card(
                                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      name.isEmpty ? 'Unknown user' : name,
                                                      style: theme.textTheme.titleMedium,
                                                    ),
                                                    if (email.isNotEmpty)
                                                      Text(email, style: theme.textTheme.bodySmall),
                                                  ],
                                                ),
                                              ),
                                              _StatusPill(status: status),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Text('Submitted: $createdAt', style: theme.textTheme.bodySmall),
                                          const SizedBox(height: 8),
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              if (nationalIdUrl != null)
                                                TextButton.icon(
                                                  onPressed: () => Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => DocumentPreviewPage(
                                                        title: 'National ID',
                                                        url: nationalIdUrl!,
                                                      ),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.badge_outlined),
                                                  label: const Text('National ID'),
                                                ),
                                              if (propertyDocUrl != null)
                                                TextButton.icon(
                                                  onPressed: () => Navigator.of(context).push(
                                                    MaterialPageRoute(
                                                      builder: (_) => DocumentPreviewPage(
                                                        title: 'Property Document',
                                                        url: propertyDocUrl!,
                                                      ),
                                                    ),
                                                  ),
                                                  icon: const Icon(Icons.description_outlined),
                                                  label: const Text('Property Doc'),
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: Wrap(
                                              spacing: 10,
                                              runSpacing: 8,
                                              crossAxisAlignment: WrapCrossAlignment.center,
                                              children: [
                                                if (status == 'pending') ...[
                                                  ElevatedButton.icon(
                                                    onPressed: () => _review(id, 'approved'),
                                                    icon: const Icon(Icons.check_rounded, size: 18),
                                                    label: const Text('Approve'),
                                                    style: ElevatedButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      minimumSize: const Size(0, 36),
                                                    ),
                                                  ),
                                                  OutlinedButton.icon(
                                                    onPressed: () => _review(id, 'rejected'),
                                                    icon: const Icon(Icons.close_rounded, size: 18),
                                                    label: const Text('Reject'),
                                                    style: OutlinedButton.styleFrom(
                                                      visualDensity: VisualDensity.compact,
                                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                                      minimumSize: const Size(0, 36),
                                                    ),
                                                  ),
                                                ] else ...[
                                                  const Icon(Icons.verified_outlined, size: 18),
                                                  Text(
                                                    status == 'approved'
                                                        ? 'Reviewed by ${_asString(reviewer?['firstName'])} ${_asString(reviewer?['lastName'])}'
                                                        : 'Rejected by ${_asString(reviewer?['firstName'])} ${_asString(reviewer?['lastName'])}',
                                                    style: theme.textTheme.bodySmall,
                                                  ),
                                                ]
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              } catch (e) {
                                return Card(
                                  color: Colors.red.withOpacity(0.06),
                                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  child: Padding(
                                    padding: const EdgeInsets.all(12.0),
                                    child: Text('Error rendering item: ${_cleanError(e)}'),
                                  ),
                                );
                              }
                            },
                      ),
                    ),
        ),
        _Pagination(
          page: _page,
          totalPages: _totalPages,
          onPrev: _page > 1 && !_loading ? () { setState(() => _page -= 1); _loadRequests(); } : null,
          onNext: _page < _totalPages && !_loading ? () { setState(() => _page += 1); _loadRequests(); } : null,
        ),
      ],
    );
  }

  Widget _statusChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }
}

class _StatsHeader extends StatelessWidget {
  const _StatsHeader({required this.stats});
  final Map<String, dynamic> stats;

  @override
  Widget build(BuildContext context) {
    final items = [
      _StatItem(label: 'Pending', value: stats['pending']?.toString() ?? '0', color: Colors.amber),
      _StatItem(label: 'Approved', value: stats['approved']?.toString() ?? '0', color: Colors.green),
      _StatItem(label: 'Rejected', value: stats['rejected']?.toString() ?? '0', color: Colors.redAccent),
      _StatItem(label: 'Total', value: stats['total']?.toString() ?? '0', color: Colors.blueGrey),
    ];
    // Build row children explicitly to ensure correct typing (List<Widget>)
    final List<Widget> rowChildren = [];
    for (int i = 0; i < items.length; i++) {
      rowChildren.add(Expanded(child: items[i]));
      if (i != items.length - 1) {
        rowChildren.add(const SizedBox(width: 8));
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: rowChildren,
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color c;
    String t;
    switch (status) {
      case 'approved':
        c = Colors.green;
        t = 'Approved';
        break;
      case 'rejected':
        c = Colors.redAccent;
        t = 'Rejected';
        break;
      default:
        c = Colors.amber;
        t = 'Pending';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        border: Border.all(color: c.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(t, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
    );
  }
}

class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onPrev,
    required this.onNext,
  });
  final int page;
  final int totalPages;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton(
            onPressed: onPrev,
            child: const Text('Previous'),
          ),
          const SizedBox(width: 12),
          Text('$page / $totalPages'),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}
