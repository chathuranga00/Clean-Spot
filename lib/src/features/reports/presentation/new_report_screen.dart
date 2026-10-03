import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/location_service.dart';
import '../domain/report_model.dart';
import 'report_form_controller.dart';

class NewReportScreen extends ConsumerStatefulWidget {
  const NewReportScreen({super.key});

  @override
  ConsumerState<NewReportScreen> createState() => _NewReportScreenState();
}

class _NewReportScreenState extends ConsumerState<NewReportScreen> {
  final _descriptionController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Auto-trigger GPS acquisition when opening report screen
      final formState = ref.read(reportFormProvider);
      if (formState.gpsReading == null && !formState.isLocating) {
        ref.read(reportFormProvider.notifier).fetchLocation();
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(reportFormProvider);
    final formNotifier = ref.read(reportFormProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Breeding Site'),
        actions: [
          TextButton(
            onPressed: () {
              formNotifier.reset();
              _descriptionController.clear();
              _addressController.clear();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Section 1: Photo Capture & EXIF Stripped Preview
            _buildPhotoSection(formState, formNotifier),
            const SizedBox(height: 16),

            // Section 2: Live GPS Location & Accuracy Threshold
            _buildLocationSection(formState, formNotifier),
            const SizedBox(height: 16),

            // Section 3: Hazard Category Selection
            _buildCategorySection(formState, formNotifier),
            const SizedBox(height: 16),

            // Section 4: Optional Landmark & Description
            _buildDetailsSection(formState, formNotifier),
            const SizedBox(height: 24),

            // Validation Error feedback
            if (formState.submissionError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formState.submissionError!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Step Navigation: Proceed to Review Screen
            ElevatedButton(
              key: const Key('proceed_to_review_button'),
              onPressed: () {
                final validationError = formState.validationError;
                if (validationError != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(validationError),
                      backgroundColor: Colors.red.shade700,
                    ),
                  );
                  return;
                }
                context.push('/report/review');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Review Report',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 8),
                  Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSection(ReportFormState formState, ReportFormNotifier formNotifier) {
    if (formState.hasPhoto) {
      return Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Image.memory(
                    formState.imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'EXIF Stripped • ${(formState.compressedImageSizeBytes / 1024).toStringAsFixed(0)} KB',
                          style: const TextStyle(color: Colors.white, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    radius: 18,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 18),
                      tooltip: 'Remove photo',
                      onPressed: () => formNotifier.clearImage(),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton.icon(
                    onPressed: () => formNotifier.pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt, size: 18),
                    label: const Text('Retake Camera'),
                  ),
                  TextButton.icon(
                    onPressed: () => formNotifier.pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('From Gallery'),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00897B).withValues(alpha: 0.3),
          style: BorderStyle.solid,
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.add_a_photo_outlined, size: 54, color: Color(0xFF00897B)),
          const SizedBox(height: 12),
          const Text(
            'Hazard Site Photo',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'High quality photo helps AI and PHIs verify breeding containers.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                key: const Key('photo_camera_button'),
                onPressed: () => formNotifier.pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt, size: 18),
                label: const Text('Camera'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00897B),
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                key: const Key('photo_gallery_button'),
                onPressed: () => formNotifier.pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library, size: 18),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(ReportFormState formState, ReportFormNotifier formNotifier) {
    final gps = formState.gpsReading;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.gps_fixed, color: Color(0xFF00897B), size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Live GPS Coordinates',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                if (formState.isLocating)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    tooltip: 'Refresh GPS signal',
                    onPressed: () => formNotifier.fetchLocation(),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            if (formState.locationError != null) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formState.locationError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    TextButton(
                      onPressed: () => formNotifier.fetchLocation(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ] else if (gps != null) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lat: ${gps.latitude.toStringAsFixed(4)} • Lng: ${gps.longitude.toStringAsFixed(4)}',
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getAccuracyColor(gps.accuracyLevel).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      gps.accuracyFeedback,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _getAccuracyColor(gps.accuracyLevel),
                      ),
                    ),
                  ),
                ],
              ),
              if (!gps.isAcceptableThreshold) ...[
                const SizedBox(height: 6),
                const Text(
                  'Notice: Accuracy is above 100m. Please move outside for a clearer satellite view.',
                  style: TextStyle(fontSize: 11, color: Colors.orange),
                ),
              ],
            ] else ...[
              const Text(
                'Waiting for device GPS satellite lock...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySection(ReportFormState formState, ReportFormNotifier formNotifier) {
    const categories = [
      (HazardCategory.standingWater, Icons.water_drop_outlined, 'Standing Water'),
      (HazardCategory.discardedContainers, Icons.delete_outline, 'Containers'),
      (HazardCategory.blockedDrain, Icons.view_stream_outlined, 'Blocked Drain'),
      (HazardCategory.tyres, Icons.tire_repair_outlined, 'Tyres'),
      (HazardCategory.constructionSite, Icons.construction_outlined, 'Construction'),
      (HazardCategory.other, Icons.more_horiz_outlined, 'Other Site'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Hazard Category',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((cat) {
            final isSelected = formState.category == cat.$1;
            return ChoiceChip(
              key: Key('category_${cat.$1.name}'),
              selected: isSelected,
              avatar: Icon(
                cat.$2,
                size: 18,
                color: isSelected ? Colors.white : const Color(0xFF00897B),
              ),
              label: Text(cat.$3),
              selectedColor: const Color(0xFF00897B),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              onSelected: (_) => formNotifier.setCategory(cat.$1),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDetailsSection(ReportFormState formState, ReportFormNotifier formNotifier) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location Notes & Landmark',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('report_address_field'),
          controller: _addressController,
          decoration: const InputDecoration(
            hintText: 'e.g. Behind community hall, near water tank',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.place_outlined),
          ),
          onChanged: (val) => formNotifier.setAddressText(val),
        ),
        const SizedBox(height: 12),
        const Text(
          'Description & Observations (Optional)',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('report_description_field'),
          controller: _descriptionController,
          maxLines: 3,
          maxLength: 300,
          decoration: const InputDecoration(
            hintText: 'Note visible mosquito larvae, smell, or persistent water accumulation...',
            border: OutlineInputBorder(),
          ),
          onChanged: (val) => formNotifier.setDescription(val),
        ),
      ],
    );
  }

  Color _getAccuracyColor(GpsAccuracyLevel level) {
    switch (level) {
      case GpsAccuracyLevel.high:
        return const Color(0xFF2E7D32);
      case GpsAccuracyLevel.acceptable:
        return const Color(0xFFF57F17);
      case GpsAccuracyLevel.poor:
      case GpsAccuracyLevel.unavailable:
        return const Color(0xFFC62828);
    }
  }
}
