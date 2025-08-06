import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_view_model.dart';
import '../../../data/services/landlord_service.dart';

class LandlordVerificationPage extends StatefulWidget {
  const LandlordVerificationPage({super.key});

  @override
  State<LandlordVerificationPage> createState() => _LandlordVerificationPageState();
}

class _LandlordVerificationPageState extends State<LandlordVerificationPage> {
  final _service = LandlordService();
  bool _submitting = false;

  Uint8List? _nationalBytes;
  String? _nationalName;
  Uint8List? _propertyBytes;
  String? _propertyName;
  bool _propertyIsPdf = false;

  Future<void> _pickNational() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (res != null && res.files.single.bytes != null) {
      setState(() {
        _nationalBytes = res.files.single.bytes;
        _nationalName = res.files.single.name;
      });
    }
  }

  Future<void> _pickProperty() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'jpg', 'jpeg', 'png', 'gif', 'bmp', 'webp', 'heic', 'heif', 'pdf'
      ],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final name = res.files.single.name.toLowerCase();
      final isPdf = name.endsWith('.pdf');
      setState(() {
        _propertyBytes = res.files.single.bytes;
        _propertyName = res.files.single.name;
        _propertyIsPdf = isPdf;
      });
    }
  }

  Future<void> _submit() async {
    if (_nationalBytes == null || _propertyBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both National ID and Property Document images')),
      );
      return;
    }
    final token = context.read<AuthViewModel>().token;
    if (token == null) return;
    setState(() => _submitting = true);
    try {
      await _service.requestVerification(
        token,
        nationalIdBytes: _nationalBytes!,
        nationalIdFilename: _nationalName ?? 'national-id.jpg',
        propertyDocBytes: _propertyBytes!,
        propertyDocFilename: _propertyName ?? 'property-doc.jpg',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification request submitted'), backgroundColor: Colors.green),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().startsWith('Exception: ')
          ? e.toString().substring('Exception: '.length)
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final subtitleStyle = t.textTheme.bodyMedium?.copyWith(
      color: t.colorScheme.onBackground.withOpacity(0.8),
    );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Landlord Verification'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Upload National ID and Property Ownership Document',
                style: subtitleStyle,
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text('National ID', style: t.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: t.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _nationalBytes == null
                                  ? const Center(child: Text('No file selected'))
                                  : ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.memory(
                                        _nationalBytes!,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickNational,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Choose'),
                          ),
                        ],
                      ),
                      if (_nationalName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _nationalName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      Text('Property Document', style: t.textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Container(
                              height: 140,
                              decoration: BoxDecoration(
                                color: t.colorScheme.surfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _propertyBytes == null
                                  ? const Center(child: Text('No file selected'))
                                  : _propertyIsPdf
                                      ? Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.picture_as_pdf, size: 48, color: Colors.redAccent),
                                              const SizedBox(height: 8),
                                              Text(
                                                _propertyName ?? 'document.pdf',
                                                textAlign: TextAlign.center,
                                                style: const TextStyle(fontSize: 12),
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 2,
                                              ),
                                            ],
                                          ),
                                        )
                                      : ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Image.memory(
                                            _propertyBytes!,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _submitting ? null : _pickProperty,
                            icon: const Icon(Icons.upload_file),
                            label: const Text('Choose'),
                          ),
                        ],
                      ),
                      if (_propertyName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          _propertyName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: t.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _submitting ? null : _submit,
                          icon: const Icon(Icons.send),
                          label: Text(_submitting ? 'Submitting...' : 'Submit Request'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
