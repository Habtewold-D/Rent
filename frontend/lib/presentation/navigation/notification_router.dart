import 'package:flutter/material.dart';

import '../pages/renter/renter_bookings_page.dart';

class NotificationRouter {
  /// Navigate to a specific screen based on the notification `data` payload.
  /// Expected shape:
  /// {
  ///   "screen": "bookings" | "group_details" | "room",
  ///   "params": { ... }
  /// }
  static void navigate(BuildContext context, Map<String, dynamic> data) {
    final screen = (data['screen'] ?? '').toString();
    final params = (data['params'] is Map<String, dynamic>)
        ? data['params'] as Map<String, dynamic>
        : <String, dynamic>{};

    switch (screen) {
      case 'bookings':
        _toBookings(context, params);
        break;
      // You can expand with more destinations later
      // case 'group_details':
      //   _toGroupDetails(context, params);
      //   break;
      // case 'room':
      //   _toRoom(context, params);
      //   break;
      default:
        // No-op for unknown screens for now
        break;
    }
  }

  static void _toBookings(BuildContext context, Map<String, dynamic> params) {
    final payUrl = (params['payUrl'] ?? '').toString();
    final payLabel = (params['payLabel'] ?? 'Pay now').toString();
    final costRaw = params['costPerPerson'];
    final cost = (costRaw is num) ? costRaw.toDouble() : null;
    final expiresAtIso = (params['expiresAt'] ?? '').toString();
    final groupId = (params['groupId'] ?? '').toString();
    final roomId = (params['roomId'] ?? '').toString();
    final groupName = (params['groupName'] ?? '').toString();

    if (payUrl.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RenterBookingsPage(
          payUrl: payUrl,
          payLabel: payLabel,
          costPerPerson: cost,
          source: 'notification',
          expiresAtIso: expiresAtIso.isNotEmpty ? expiresAtIso : null,
          groupId: groupId.isNotEmpty ? groupId : null,
          roomId: roomId.isNotEmpty ? roomId : null,
          groupName: groupName.isNotEmpty ? groupName : null,
        ),
      ),
    );
  }
}
