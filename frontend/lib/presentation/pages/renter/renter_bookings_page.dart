import 'package:flutter/material.dart';

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
  Duration? _timeLeft;
  late final DateTime? _expiresAt;
  late final String? _groupName;

  @override
  void initState() {
    super.initState();
    _expiresAt = (widget.expiresAtIso != null && widget.expiresAtIso!.isNotEmpty)
        ? DateTime.tryParse(widget.expiresAtIso!)
        : null;
    _groupName = widget.groupName;
    _tick();
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

  @override
  Widget build(BuildContext context) {
    final payUrl = widget.payUrl;
    final showPayment = (payUrl != null && payUrl.isNotEmpty);
    if (!showPayment) {
      return const _Placeholder(title: 'Bookings', subtitle: 'Your booking requests and history');
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Bookings', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 12),
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
