import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/matching_service.dart';
import '../viewmodels/auth_view_model.dart';
import '../pages/notifications/notifications_page.dart';

class NotificationBell extends StatefulWidget {
  final Color? iconColor;
  final EdgeInsetsGeometry padding;
  final Duration refreshInterval;

  const NotificationBell({
    super.key,
    this.iconColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 4),
    this.refreshInterval = const Duration(seconds: 20),
  });

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> with RouteAware {
  final _service = MatchingService();
  int _count = 0;
  bool _loading = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(widget.refreshInterval, (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted || _loading) return;
    final token = context.read<AuthViewModel?>()?.token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final data = await _service.getNotifications(token);
      final unread = int.tryParse('${data['unreadCount'] ?? 0}') ?? 0;
      if (mounted) setState(() => _count = unread);
    } catch (_) {
      // ignore errors; keep previous count
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            tooltip: 'Notifications',
            icon: Icon(Icons.notifications_outlined, color: widget.iconColor),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
              // Refresh when returning
              _load();
            },
          ),
          if (_count > 0)
            Positioned(
              right: 10,
              top: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  _count > 99 ? '99+' : '$_count',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
