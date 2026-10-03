import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/location_service.dart';
import 'report_form_controller.dart';

class ReportReviewScreen extends ConsumerWidget {
  const ReportReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(reportFormProvider);
    final formNotifier = ref.read(reportFormProvider.notifier);

    // If somehow entered with missing data, offer a redirect
    if (!formState.hasPhoto || formState.gpsReading == null || formState.category == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Review Report')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 56, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Incomplete Report Details',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Please return to the report form to capture photo and GPS.'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Form'),
              ),
            ],
          ),
        ),
      );
    }

    final gps = formState.gpsReading!;
    final accuracyColor = _getAccuracyColor(gps.accuracyLevel);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Submit'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Photo preview with EXIF Stripped badge
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Image.memory(
                      formState.imageBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.shield_outlined, color: Colors.tealAccent, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'EXIF Stripped • ${(formState.compressedImageSizeBytes / 1024).toStringAsFixed(0)} KB',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Hazard Category Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF00897B).withValues(alpha: 0.15),
                  child: const Icon(Icons.pest_control_outlined, color: Color(0xFF00897B)),
                ),
                title: const Text(
                  'Hazard Category',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                subtitle: Text(
                  formState.category!.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 3. Verified GPS Location Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
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
                            Icon(Icons.location_on, color: Color(0xFF00897B), size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Verified GPS Coordinates',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: accuracyColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            gps.accuracyFeedback,
                            style: TextStyle(
                              color: accuracyColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Latitude: ${gps.latitude.toStringAsFixed(5)} • Longitude: ${gps.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    ),
                    if (formState.addressText.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Landmark: ${formState.addressText}',
                        style: const TextStyle(fontSize: 13, color: Colors.black87),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // 4. Notes / Description
            if (formState.description.isNotEmpty) ...[
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.3)),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reporter Notes',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        formState.description,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // 5. Verification Notice & Anti-fraud Info
            Container(
              padding: const EdgeInsets.all(14.0),
              decoration: BoxDecoration(
                color: const Color(0xFF00897B).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF00897B).withValues(alpha: 0.2)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF00897B), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Submitted breeding hazards are evaluated by automated server AI and verified by regional Public Health Inspectors (PHIs) before civic points (+50 pts) are attributed.',
                      style: TextStyle(fontSize: 12, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Error display if submission fails
            if (formState.submissionError != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
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
              const SizedBox(height: 16),
            ],

            // 6. Double-Tap Protected Submit Button
            ElevatedButton(
              key: const Key('submit_report_button'),
              onPressed: formState.isSubmitting
                  ? null // Prevents concurrent double-tap execution
                  : () async {
                      final success = await formNotifier.submitReport();
                      if (success && context.mounted) {
                        _showSuccessDialog(context, formState.submittedReportId ?? 'Submitted');
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: formState.isSubmitting
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          formState.submissionProgress ?? 'Submitting report...',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    )
                  : const Text(
                      'Confirm & Submit Report',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: formState.isSubmitting ? null : () => context.pop(),
              child: const Text('Edit Details'),
            ),
          ],
        ),
      ),
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

  void _showSuccessDialog(BuildContext context, String reportId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.check_circle, color: Color(0xFF00897B), size: 56),
          title: const Text('Hazard Report Submitted'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Thank you for protecting your neighborhood! Your breeding site report has been registered.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Report ID: $reportId',
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/home');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00897B),
                foregroundColor: Colors.white,
              ),
              child: const Text('Return to Dashboard'),
            ),
          ],
        );
      },
    );
  }
}
