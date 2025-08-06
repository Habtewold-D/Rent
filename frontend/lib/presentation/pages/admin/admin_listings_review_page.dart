import 'package:flutter/material.dart';

class AdminListingsReviewPage extends StatelessWidget {
  const AdminListingsReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Placeholder(title: 'Listings Review', subtitle: 'Review and verify landlord/listings');
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
