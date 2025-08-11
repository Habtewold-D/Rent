import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import 'renter_listings_page.dart';
import 'renter_match_page.dart';
import 'renter_bookings_page.dart';
import 'renter_profile_page.dart';
import '../notifications/notifications_page.dart';
import '../auth/login_page.dart';
import '../../widgets/notification_bell.dart';

class RenterHome extends StatefulWidget {
  const RenterHome({super.key});

  @override
  State<RenterHome> createState() => _RenterHomeState();
}

class _RenterHomeState extends State<RenterHome> {
  int _index = 0;

  final _pages = const [
    RenterListingsPage(), // 0 - Listings is home
    RenterBookingsPage(), // 1 - Bookings tab
    RenterProfilePage(),  // 2 - Profile tab
    RenterMatchPage(),    // 3 - drawer only
  ];

  final _titles = const [
    'Listings',
    'Bookings',
    'Profile',
    'Match',
  ];

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final name = auth.userName ?? 'User';
    final email = auth.userEmail ?? '';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(_titles[_index]),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.teal, // make the status bar the same green
          statusBarIconBrightness: Brightness.light, // Android icons color
          statusBarBrightness: Brightness.dark, // iOS
        ),
        actions: const [NotificationBell()],
      ),
      drawer: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.teal,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Builder(
              builder: (context) {
                final top = MediaQuery.of(context).padding.top;
                return Container(
                  color: Colors.teal,
                  padding: EdgeInsets.only(top: top + 20, left: 20, right: 20, bottom: 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 44, color: Colors.white)),
                      const SizedBox(height: 12),
                      Text(
                        name,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        email,
                        textAlign: TextAlign.start,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            // Removed Match from the drawer
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NotificationsPage()),
                );
              },
            ),
            // Bookings is now a bottom tab
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                Navigator.pop(context);
                context.read<AuthViewModel>().logout();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              },
            ),
          ],
        ),
        ),
      ),
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index > 2 ? 0 : _index, // drawer-only pages map to first tab for highlight
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.apartment_outlined), label: 'Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
