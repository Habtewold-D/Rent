import 'package:flutter/material.dart';
import 'document_preview_page.dart';

class RequestDetailPage extends StatelessWidget {
  final Map<String, dynamic> request;
  const RequestDetailPage({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    final user = request['user'] as Map<String, dynamic>?;
    final reviewer = request['reviewer'] as Map<String, dynamic>?;
    final status = (request['status'] ?? 'pending').toString();
    final createdAt = (request['createdAt'] ?? '').toString();
    final name = [user?['firstName'], user?['lastName']]
        .where((e) => (e ?? '').toString().isNotEmpty)
        .join(' ');
    final email = (user?['email'] ?? '').toString();

    final nationalIdUrl = request['nationalIdUrl']?.toString() ?? request['nationalId']?.toString();
    final propertyDocUrl = request['propertyDocumentUrl']?.toString() ?? request['propertyDoc']?.toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Request details')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name.isEmpty ? 'Unknown user' : name, style: Theme.of(context).textTheme.titleMedium),
                    if (email.isNotEmpty) Text(email),
                    const SizedBox(height: 4),
                    Text('Status: $status'),
                    Text('Submitted: $createdAt'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (nationalIdUrl != null && nationalIdUrl.isNotEmpty) ...[
            Text('National ID', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PreviewTile(title: 'National ID', url: nationalIdUrl),
            const SizedBox(height: 16),
          ],
          if (propertyDocUrl != null && propertyDocUrl.isNotEmpty) ...[
            Text('Property Document', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _PreviewTile(title: 'Property Document', url: propertyDocUrl),
          ],
        ],
      ),
    );
  }
}

class _PreviewTile extends StatelessWidget {
  final String title;
  final String url;
  const _PreviewTile({required this.title, required this.url});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DocumentPreviewPage(title: title, url: url),
          ),
        );
      },
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.remove_red_eye_outlined),
            const SizedBox(height: 8),
            Text('Tap to preview'),
          ],
        ),
      ),
    );
  }
}
