import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/utils/image_processor.dart';
import '../../../core/utils/location_service.dart';
import '../../auth/data/auth_repository.dart';
import '../data/report_repository.dart';
import '../domain/report_model.dart';

class ReportFormState {
  final Uint8List? imageBytes;
  final int originalImageSizeBytes;
  final int compressedImageSizeBytes;
  final GpsReading? gpsReading;
  final bool isLocating;
  final String? locationError;
  final HazardCategory? category;
  final String description;
  final String addressText;
  final bool isSubmitting;
  final String? submissionProgress;
  final String? submissionError;
  final String? submittedReportId;

  const ReportFormState({
    this.imageBytes,
    this.originalImageSizeBytes = 0,
    this.compressedImageSizeBytes = 0,
    this.gpsReading,
    this.isLocating = false,
    this.locationError,
    this.category,
    this.description = '',
    this.addressText = '',
    this.isSubmitting = false,
    this.submissionProgress,
    this.submissionError,
    this.submittedReportId,
  });

  bool get hasPhoto => imageBytes != null && imageBytes!.isNotEmpty;
  bool get hasValidGps => gpsReading != null && gpsReading!.isAcceptableThreshold;
  bool get hasCategory => category != null;

  bool get canProceedToReview => hasPhoto && hasValidGps && hasCategory;

  String? get validationError {
    if (!hasPhoto) {
      return 'Please capture or attach a photo of the breeding site.';
    }
    if (gpsReading == null) {
      return 'GPS coordinates are required. Please acquire location.';
    }
    if (!gpsReading!.isAcceptableThreshold) {
      return 'GPS accuracy is too low (±${gpsReading!.accuracy.toStringAsFixed(0)}m). Please step outdoors for a clearer satellite signal.';
    }
    if (!hasCategory) {
      return 'Please select a hazard category.';
    }
    if (description.length > 300) {
      return 'Description cannot exceed 300 characters.';
    }
    return null;
  }

  ReportFormState copyWith({
    Uint8List? imageBytes,
    bool clearImage = false,
    int? originalImageSizeBytes,
    int? compressedImageSizeBytes,
    GpsReading? gpsReading,
    bool clearGps = false,
    bool? isLocating,
    String? locationError,
    bool clearLocationError = false,
    HazardCategory? category,
    String? description,
    String? addressText,
    bool? isSubmitting,
    String? submissionProgress,
    bool clearSubmissionProgress = false,
    String? submissionError,
    bool clearSubmissionError = false,
    String? submittedReportId,
  }) {
    return ReportFormState(
      imageBytes: clearImage ? null : (imageBytes ?? this.imageBytes),
      originalImageSizeBytes:
          clearImage ? 0 : (originalImageSizeBytes ?? this.originalImageSizeBytes),
      compressedImageSizeBytes:
          clearImage ? 0 : (compressedImageSizeBytes ?? this.compressedImageSizeBytes),
      gpsReading: clearGps ? null : (gpsReading ?? this.gpsReading),
      isLocating: isLocating ?? this.isLocating,
      locationError: clearLocationError ? null : (locationError ?? this.locationError),
      category: category ?? this.category,
      description: description ?? this.description,
      addressText: addressText ?? this.addressText,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionProgress: clearSubmissionProgress
          ? null
          : (submissionProgress ?? this.submissionProgress),
      submissionError:
          clearSubmissionError ? null : (submissionError ?? this.submissionError),
      submittedReportId: submittedReportId ?? this.submittedReportId,
    );
  }
}

class ReportFormNotifier extends Notifier<ReportFormState> {
  late final LocationService _locationService;
  late final ReportRepository _reportRepository;

  @override
  ReportFormState build() {
    _locationService = ref.watch(locationServiceProvider);
    _reportRepository = ref.watch(reportRepositoryProvider);
    return const ReportFormState();
  }

  /// Picks photo from camera or gallery, compresses it and strips EXIF tags
  Future<void> pickImage(ImageSource source, {ImagePicker? picker}) async {
    try {
      final imagePicker = picker ?? ImagePicker();
      final pickedFile = await imagePicker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
      );

      if (pickedFile == null) return;

      final rawBytes = await pickedFile.readAsBytes();
      final originalSize = rawBytes.length;

      // Compress and remove EXIF
      final compressedBytes = await ImageProcessor.compressAndStripExif(rawBytes);

      state = state.copyWith(
        imageBytes: compressedBytes,
        originalImageSizeBytes: originalSize,
        compressedImageSizeBytes: compressedBytes.length,
        clearSubmissionError: true,
      );
    } catch (e) {
      state = state.copyWith(
        submissionError: 'Failed to process image: ${e.toString()}',
      );
    }
  }

  /// Sets raw image bytes directly (for testing or direct injection)
  Future<void> setImageBytes(Uint8List rawBytes) async {
    final originalSize = rawBytes.length;
    final compressedBytes = await ImageProcessor.compressAndStripExif(rawBytes);

    state = state.copyWith(
      imageBytes: compressedBytes,
      originalImageSizeBytes: originalSize,
      compressedImageSizeBytes: compressedBytes.length,
      clearSubmissionError: true,
    );
  }

  /// Clears selected image
  void clearImage() {
    state = state.copyWith(clearImage: true);
  }

  /// Requests and acquires high-accuracy GPS position
  Future<void> fetchLocation() async {
    state = state.copyWith(isLocating: true, clearLocationError: true);
    try {
      final reading = await _locationService.getCurrentReading();
      state = state.copyWith(
        gpsReading: reading,
        isLocating: false,
        clearLocationError: true,
      );
    } on LocationServiceDisabledException {
      state = state.copyWith(
        isLocating: false,
        locationError: 'Device location services are disabled. Please turn on GPS.',
      );
    } on PermissionDeniedException catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationError: e.message ?? 'Location permission denied.',
      );
    } catch (e) {
      state = state.copyWith(
        isLocating: false,
        locationError: 'Failed to acquire GPS: ${e.toString()}',
      );
    }
  }

  /// Sets GPS reading directly (useful for tests or mocking)
  void setGpsReading(GpsReading reading) {
    state = state.copyWith(
      gpsReading: reading,
      clearLocationError: true,
    );
  }

  void setCategory(HazardCategory category) {
    state = state.copyWith(
      category: category,
      clearSubmissionError: true,
    );
  }

  void setDescription(String description) {
    state = state.copyWith(description: description);
  }

  void setAddressText(String address) {
    state = state.copyWith(addressText: address);
  }

  /// Submits the report with double-tap protection and progress updates
  Future<bool> submitReport() async {
    // 1. Double-tap protection: ignore if submission is already active
    if (state.isSubmitting) {
      debugPrint('[CleanSpot] Submit requested while already submitting. Duplicate ignored.');
      return false;
    }

    // 2. Validate form
    final error = state.validationError;
    if (error != null) {
      state = state.copyWith(submissionError: error);
      return false;
    }

    final authUser = ref.read(authRepositoryProvider).currentUser;
    final userId = authUser?.uid ?? 'anonymous_user';

    state = state.copyWith(
      isSubmitting: true,
      submissionProgress: 'Preparing hazard report...',
      clearSubmissionError: true,
    );

    try {
      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}';

      // Step A: Upload image to Firebase Storage
      state = state.copyWith(
        submissionProgress: 'Uploading photo to secure cloud storage...',
      );

      final uploadResult = await _reportRepository.uploadReportImage(
        userId: userId,
        imageBytes: state.imageBytes!,
        fileName: fileName,
      );

      // Step B: Submit through authoritative Cloud Function
      state = state.copyWith(
        submissionProgress: 'Registering with dengue surveillance system...',
      );

      final reportId = await _reportRepository.submitReport(
        imageUrl: uploadResult.downloadUrl,
        storagePath: uploadResult.storagePath,
        latitude: state.gpsReading!.latitude,
        longitude: state.gpsReading!.longitude,
        accuracy: state.gpsReading!.accuracy,
        category: state.category!,
        description: state.description,
        addressText: state.addressText,
      );

      state = state.copyWith(
        isSubmitting: false,
        clearSubmissionProgress: true,
        submittedReportId: reportId,
      );

      return true;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        clearSubmissionProgress: true,
        submissionError: 'Submission failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Resets state for a new report
  void reset() {
    state = const ReportFormState();
  }
}

final reportFormProvider =
    NotifierProvider.autoDispose<ReportFormNotifier, ReportFormState>(
  ReportFormNotifier.new,
);
