import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../data/services/matching_service.dart';
import '../renter/renter_bookings_page.dart';
import '../../navigation/notification_router.dart';
import '../../viewmodels/auth_view_model.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _service = MatchingService();
  bool _loading = true;
  String? _error;
  List<dynamic> _items = [];

  @override
  void initState() {
    super.initState();
    _markAllAndLoad();
  }

  Future<void> _markAllAndLoad() async {
    final token = context.read<AuthViewModel?>()?.token;
    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'You must be logged in to view notifications';
      });
      return;
    }
    try {
      await _service.markAllNotificationsRead(token);
    } catch (_) {}
    await _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final token = context.read<AuthViewModel?>()?.token;
      if (token == null || token.isEmpty) {
        throw Exception('You must be logged in to view notifications');
      }
      final data = await _service.getNotifications(token);
      final list = (data['notifications'] is List) ? data['notifications'] as List<dynamic> : const <dynamic>[];
      setState(() => _items = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
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
            if (_loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: _items.isEmpty
                  ? const Center(child: Text('No notifications yet'))
                  : ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (ctx, i) {
                        final n = _items[i];
                        final type = ((n is Map) ? (n['type'] ?? '') : '').toString();
                        final title = ((n is Map) ? (n['title'] ?? '') : '').toString();
                        final message = ((n is Map) ? (n['message'] ?? '') : '').toString();
                        // Prefer 'data' (DB column), fallback to legacy 'payload'
                        final rawPayload = (n is Map && n['data'] is Map)
                            ? (n['data'] as Map)
                            : (n is Map && n['payload'] is Map)
                                ? (n['payload'] as Map)
                                : const {};
                        final Map<String, dynamic> payload = {
                          ...rawPayload.cast<String, dynamic>(),
                        };
                        final payRequired = (payload['payRequired'] == true);
                        final payLabel = (payload['payLabel'] ?? 'Pay').toString();
                        final payUrl = (payload['payUrl'] ?? '').toString();
                        final costPerPerson = payload['costPerPerson'];
                        void _routeFromPayload() {
                          final screen = (payload['screen'] ?? '').toString();
                          if (screen.isNotEmpty) {
                            // When using router-based payload structure, expect params inside 'params'
                            final params = (payload['params'] is Map)
                                ? (payload['params'] as Map).cast<String, dynamic>()
                                : <String, dynamic>{
                                    // backward-compat: allow flat payment fields
                                    'payUrl': payUrl,
                                    'payLabel': payLabel,
                                    'costPerPerson': costPerPerson,
                                  };
                            NotificationRouter.navigate(context, {
                              'screen': screen,
                              'params': params,
                            });
                            return;
                          }
                          // Fallback: direct to bookings if payment data present
                          if (payRequired && payUrl.isNotEmpty) {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => RenterBookingsPage(
                                  payUrl: payUrl,
                                  payLabel: payLabel,
                                  costPerPerson: (costPerPerson is num) ? costPerPerson.toDouble() : null,
                                  source: 'notification',
                                ),
                              ),
                            );
                          }
                        }
                        return Card(
                          child: InkWell(
                            onTap: _routeFromPayload,
                            child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(title.isEmpty ? type : title, style: Theme.of(context).textTheme.titleMedium),
                                const SizedBox(height: 6),
                                if (message.isNotEmpty) Text(message),
                                if (costPerPerson != null) ...[
                                  const SizedBox(height: 6),
                                  Text('Cost per person: $costPerPerson ETB'),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (payRequired && payUrl.isNotEmpty)
                                      FilledButton(
                                        onPressed: _routeFromPayload,
                                        child: Text(payLabel),
                                      ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ),
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: _items.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
