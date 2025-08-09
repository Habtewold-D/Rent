import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../data/models/room.dart';
import '../../../data/models/room_image.dart';
import '../../../data/services/room_service.dart';
import '../../viewmodels/auth_view_model.dart';

class LandlordEditListingPage extends StatefulWidget {
  final Room room;
  const LandlordEditListingPage({super.key, required this.room});

  @override
  State<LandlordEditListingPage> createState() => _LandlordEditListingPageState();
}

class _LandlordEditListingPageState extends State<LandlordEditListingPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _rentCtrl;
  late TextEditingController _maxOccCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _amenitiesCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;

  late String _roomType;
  late String _gender;
  bool _submitting = false;
  final _service = RoomService();

  // existing images from server
  late List<RoomImage> _existingImages;
  // new images to append
  List<UploadImage> _newImages = [];

  @override
  void initState() {
    super.initState();
    final r = widget.room;
    _rentCtrl = TextEditingController(text: r.monthlyRent.toStringAsFixed(2));
    _maxOccCtrl = TextEditingController(text: r.maxOccupants.toString());
    _addressCtrl = TextEditingController(text: r.address);
    _cityCtrl = TextEditingController(text: r.city);
    // Room model does not currently expose amenities/contact fields in frontend model
    _amenitiesCtrl = TextEditingController(text: '');
    _phoneCtrl = TextEditingController(text: '');
    _emailCtrl = TextEditingController(text: '');
    _roomType = RoomService.roomTypes.contains(r.roomType) ? r.roomType : RoomService.roomTypes.first;
    _gender = RoomService.genderPreferences.contains(r.genderPreference) ? r.genderPreference : RoomService.genderPreferences.last;
    _existingImages = List<RoomImage>.from(r.images);
  }

  @override
  void dispose() {
    _rentCtrl.dispose();
    _maxOccCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _amenitiesCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  String _labelize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  Future<void> _pickImages() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg','jpeg','png','gif','bmp','webp','heic','heif'],
      allowMultiple: true,
      withData: true,
    );
    if (res == null) return;
    final filesAll = res.files;
    final files = filesAll.where((f) {
      final name = (f.name ?? '').toLowerCase();
      final ok = (f.bytes != null && f.bytes!.isNotEmpty) &&
          (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.gif') || name.endsWith('.bmp') || name.endsWith('.webp') || name.endsWith('.heic') || name.endsWith('.heif'));
      return ok;
    }).toList();
    final skipped = filesAll.length - files.length;
    if (skipped > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Skipped $skipped non-image file(s)')),
      );
    }
    String _inferMime(String name) {
      final lower = name.toLowerCase();
      if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
      if (lower.endsWith('.png')) return 'image/png';
      if (lower.endsWith('.gif')) return 'image/gif';
      if (lower.endsWith('.bmp')) return 'image/bmp';
      if (lower.endsWith('.webp')) return 'image/webp';
      if (lower.endsWith('.heic')) return 'image/heic';
      if (lower.endsWith('.heif')) return 'image/heif';
      return 'image/jpeg';
    }

    setState(() {
      _newImages.addAll(files.map((f) => UploadImage(bytes: f.bytes as Uint8List, filename: f.name, contentType: _inferMime(f.name))));
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final token = context.read<AuthViewModel>().token;
    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Not authenticated')));
      return;
    }
    setState(() => _submitting = true);

    try {
      final safeRoomType = RoomService.roomTypes.contains(_roomType) ? _roomType : RoomService.roomTypes.first;
      final safeGender = RoomService.genderPreferences.contains(_gender) ? _gender : RoomService.genderPreferences.last;

      final parsedMaxOcc = int.tryParse(_maxOccCtrl.text.trim()) ?? 1;
      final clampedMaxOcc = parsedMaxOcc < 1 ? 1 : (parsedMaxOcc > 10 ? 10 : parsedMaxOcc);

      final fields = <String, String>{
        'monthlyRent': _rentCtrl.text.trim(),
        'roomType': safeRoomType,
        'maxOccupants': clampedMaxOcc.toString(),
        'genderPreference': safeGender,
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
      };

      final amenities = _amenitiesCtrl.text.trim();
      if (amenities.isNotEmpty) {
        final items = amenities.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        fields['amenities'] = items.isEmpty ? '[]' : '["' + items.join('\",\"') + '"]';
      }
      if (_phoneCtrl.text.trim().isNotEmpty) fields['contactPhone'] = _phoneCtrl.text.trim();
      if (_emailCtrl.text.trim().isNotEmpty) fields['contactEmail'] = _emailCtrl.text.trim();

      // ignore: avoid_print
      print('[UpdateRoom] id=${widget.room.id}, fields: ' + fields.toString() + ', newImages: ' + _newImages.length.toString());

      await _service.updateRoom(token, widget.room.id, fields: fields, images: _newImages);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing updated')));
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Listing')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _rentCtrl,
                      decoration: const InputDecoration(labelText: 'Monthly Rent (ETB) *'),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final val = double.tryParse(v.trim());
                        if (val == null) return 'Enter a valid number';
                        if (val < 0) return 'Must be >= 0';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _maxOccCtrl,
                      decoration: const InputDecoration(labelText: 'Max Occupants *'),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Required';
                        final n = int.tryParse(v.trim());
                        if (n == null) return 'Enter a valid integer';
                        if (n < 1) return 'Must be at least 1';
                        if (n > 10) return 'Must be at most 10';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: RoomService.roomTypes.contains(_roomType) ? _roomType : RoomService.roomTypes.first,
                      items: RoomService.roomTypes.map((v) => DropdownMenuItem(value: v, child: Text(_labelize(v)))).toList(),
                      onChanged: (v) => setState(() => _roomType = v ?? RoomService.roomTypes.first),
                      decoration: const InputDecoration(labelText: 'Room Type *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: RoomService.genderPreferences.contains(_gender) ? _gender : RoomService.genderPreferences.last,
                      items: RoomService.genderPreferences.map((v) => DropdownMenuItem(value: v, child: Text(_labelize(v)))).toList(),
                      onChanged: (v) => setState(() => _gender = v ?? RoomService.genderPreferences.last),
                      decoration: const InputDecoration(labelText: 'Gender Preference *'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Address *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'City *'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amenitiesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Amenities (comma separated)',
                  helperText: 'Example: Wifi, Parking, Kitchen',
                ),
              ),
              const SizedBox(height: 16),
              Text('Images', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              _ExistingImagesGrid(
                images: _existingImages,
                onRemove: (img) => setState(() => _existingImages.remove(img)), // UI only removal; backend removal would need API support
              ),
              const SizedBox(height: 8),
              _NewImagesGrid(
                images: _newImages,
                onRemove: (i) => setState(() => _newImages.removeAt(i)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(onPressed: _pickImages, icon: const Icon(Icons.image_outlined), label: const Text('Add Images')),
                  const SizedBox(width: 12),
                  Text('${_newImages.length} new image(s) to add'),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Phone'),
                      keyboardType: TextInputType.phone,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _emailCtrl,
                      decoration: const InputDecoration(labelText: 'Contact Email'),
                      keyboardType: TextInputType.emailAddress,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submitting ? null : _submit,
                  child: _submitting
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExistingImagesGrid extends StatelessWidget {
  final List<RoomImage> images;
  final ValueChanged<RoomImage> onRemove;
  const _ExistingImagesGrid({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final img in images)
          Stack(
            alignment: Alignment.topRight,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(img.imageUrl, width: 100, height: 100, fit: BoxFit.cover),
              ),
              IconButton(
                onPressed: () => onRemove(img),
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove (UI only)',
              ),
            ],
          )
      ],
    );
  }
}

class _NewImagesGrid extends StatelessWidget {
  final List<UploadImage> images;
  final ValueChanged<int> onRemove;
  const _NewImagesGrid({required this.images, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (int i = 0; i < images.length; i++)
          Stack(
            alignment: Alignment.topRight,
            children: [
              Container(
                width: 100,
                height: 100,
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, size: 36),
              ),
              IconButton(
                onPressed: () => onRemove(i),
                style: IconButton.styleFrom(backgroundColor: Colors.black54, foregroundColor: Colors.white),
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Remove',
              ),
            ],
          )
      ],
    );
  }
}
