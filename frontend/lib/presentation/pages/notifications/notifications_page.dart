import 'package:flutter/material.dart';

import '../../../data/services/matching_service.dart';

class NotificationsPage extends StatefulWidget {
  final String token;
  const NotificationsPage({super.key, required this.token});

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
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.getNotifications(widget.token);
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
        actions: [
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
        ],
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
                        final payload = (n is Map && n['payload'] is Map) ? (n['payload'] as Map) : const {};
                        final payRequired = (payload['payRequired'] == true);
                        final payLabel = (payload['payLabel'] ?? 'Pay').toString();
                        final payUrl = (payload['payUrl'] ?? '').toString();
                        final costPerPerson = payload['costPerPerson'];
                        return Card(
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
                                        onPressed: () {
                                          // TODO: Navigate to your payment route with payUrl
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Proceed to payment: $payUrl')),
                                          );
                                        },
                                        child: Text(payLabel),
                                      ),
                                  ],
                                )
                              ],
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
