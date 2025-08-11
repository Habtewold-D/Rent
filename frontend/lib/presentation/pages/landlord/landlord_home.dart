import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import 'landlord_listings_page.dart';
import 'landlord_new_listing_page.dart';
import 'landlord_bookings_page.dart';
import 'landlord_profile_page.dart';
import 'landlord_verification_page.dart';
import '../notifications/notifications_page.dart';
import '../auth/login_page.dart';
import '../../widgets/notification_bell.dart';

class LandlordHome extends StatefulWidget {
  const LandlordHome({super.key});

  @override
  State<LandlordHome> createState() => _LandlordHomeState();
}

class _LandlordHomeState extends State<LandlordHome> {
  int _index = 0;

  final _pages = const [
    LandlordListingsPage(),  // 0 - Listings is home
    LandlordBookingsPage(),  // 1 - Bookings tab
    LandlordProfilePage(),   // 2 - Profile tab
    LandlordNewListingPage(), // 3 - drawer only
    LandlordVerificationPage(), // 4 - drawer only
  ];

  final _titles = const [
    'Listings',
    'Bookings',
    'Profile',
    'New Listing',
    'Verification',
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
          statusBarColor: Colors.teal,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
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
            ListTile(
              leading: const Icon(Icons.add_box_outlined),
              title: const Text('New Listing'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 3);
              },
            ),
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
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('Verification'),
              onTap: () {
                Navigator.pop(context);
                setState(() => _index = 4);
              },
            ),
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
        currentIndex: _index > 2 ? 0 : _index,
        type: BottomNavigationBarType.fixed,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), label: 'Listings'),
          BottomNavigationBarItem(icon: Icon(Icons.book_online_outlined), label: 'Bookings'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
