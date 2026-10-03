import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'package:cleanspot/src/core/theme/app_theme.dart';
import 'package:cleanspot/src/core/widgets/app_loading_indicator.dart';
import 'package:cleanspot/src/features/map/data/map_repository.dart';
import 'package:cleanspot/src/features/map/domain/map_marker_model.dart';
import 'package:cleanspot/src/features/map/domain/marker_cluster.dart';
import 'package:cleanspot/src/features/reports/domain/report_model.dart';

class MapScreen extends ConsumerStatefulWidget {
  final bool enableTiles;
  final bool autoLocate;
  final bool initialLocationDenied;

  const MapScreen({
    super.key,
    this.enableTiles = true,
    this.autoLocate = true,
    this.initialLocationDenied = false,
  });

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  late final MapController _mapController;
  double _currentZoom = 13.0;

  // Default coordinates: Colombo, Sri Lanka
  static const LatLng defaultColombo = LatLng(6.9271, 79.8612);

  bool _isLocationDenied = false;
  bool _isLocating = false;
  bool _showLegend = false;
  LatLng _mapCenter = defaultColombo;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _isLocationDenied = widget.initialLocationDenied;
    if (widget.autoLocate) {
      _checkLocationPermissionAndCenter();
    }
  }

  Future<void> _checkLocationPermissionAndCenter() async {
    setState(() => _isLocating = true);
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isLocationDenied = true;
            _isLocating = false;
          });
        }
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _isLocationDenied = true;
            _isLocating = false;
          });
        }
        return;
      }

      // Permission granted - get current position
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        final userLatLng = LatLng(position.latitude, position.longitude);
        setState(() {
          _mapCenter = userLatLng;
          _isLocationDenied = false;
          _isLocating = false;
        });
        _mapController.move(userLatLng, 14.0);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLocationDenied = true;
          _isLocating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final markersAsync = ref.watch(approvedMarkersStreamProvider);
    final filterState = ref.watch(mapFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Dengue Hotspot Map'),
        actions: [
          IconButton(
            key: const Key('btn_toggle_legend'),
            tooltip: 'Map Legend',
            icon: Icon(
              _showLegend ? Icons.layers_clear : Icons.layers,
              color: _showLegend ? AppColors.primaryTeal : null,
            ),
            onPressed: () => setState(() => _showLegend = !_showLegend),
          ),
          IconButton(
            tooltip: 'My Location',
            icon: _isLocating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            onPressed: _checkLocationPermissionAndCenter,
          ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Interactive flutter_map with OpenStreetMap Tiles
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: _currentZoom,
              onPositionChanged: (camera, _) {
                if (camera.zoom != _currentZoom) {
                  setState(() => _currentZoom = camera.zoom);
                }
              },
            ),
            children: [
              // OpenStreetMap Standard Tiles (Policy compliant with custom User-Agent)
              if (widget.enableTiles)
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.cleanspot.dengue',
                ),

              // Clustered Markers Layer
              markersAsync.when(
                data: (markers) {
                  final clusterNodes = MarkerClusterer.clusterMarkers(
                    markers: markers,
                    zoom: _currentZoom,
                  );

                  return MarkerLayer(
                    markers: clusterNodes.map((node) {
                      return node.isCluster
                          ? _buildClusterMarker(node)
                          : _buildSingleMarker(node.markers.first);
                    }).toList(),
                  );
                },
                loading: () => const MarkerLayer(markers: []),
                error: (error, stack) => const MarkerLayer(markers: []),
              ),
            ],
          ),

          // 2. Permission Denied Fallback Notice Banner
          if (_isLocationDenied)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.alertAmber.withValues(alpha: 0.95),
                child: Row(
                  children: [
                    const Icon(Icons.location_off, size: 18, color: Colors.black87),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Location access denied. Centered on Colombo. Pan or search to explore.',
                        style: TextStyle(fontSize: 12, color: Colors.black87),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        foregroundColor: Colors.black87,
                      ),
                      onPressed: _checkLocationPermissionAndCenter,
                      child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),

          // 3. Category & Date Filters Bar (Floating Top)
          Positioned(
            top: _isLocationDenied ? 45 : 12,
            left: 12,
            right: 12,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildCategoryFilterBar(ref, filterState),
                const SizedBox(height: 6),
                _buildDateFilterRow(ref, filterState),
              ],
            ),
          ),

          // 4. Map Legend (Toggleable Floating Card)
          if (_showLegend)
            Positioned(
              bottom: 40,
              right: 12,
              child: _buildLegendCard(),
            ),

          // 5. OpenStreetMap Attribution (Required by Policy)
          Positioned(
            bottom: 4,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Filter Bar Widgets ---

  Widget _buildCategoryFilterBar(WidgetRef ref, MapFilterState filterState) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          FilterChip(
            key: const Key('map_filter_all'),
            label: const Text('All Hazards', style: TextStyle(fontSize: 12)),
            selected: filterState.category == null,
            onSelected: (_) =>
                ref.read(mapFilterProvider.notifier).setCategory(null),
          ),
          const SizedBox(width: 6),
          ...HazardCategory.values.map((cat) {
            final isSelected = filterState.category == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                key: Key('map_filter_${cat.name}'),
                label: Text(
                  cat.displayName,
                  style: const TextStyle(fontSize: 12),
                ),
                selected: isSelected,
                selectedColor: AppColors.primaryTeal.withValues(alpha: 0.2),
                checkmarkColor: AppColors.primaryTeal,
                onSelected: (_) =>
                    ref.read(mapFilterProvider.notifier).setCategory(cat),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildDateFilterRow(WidgetRef ref, MapFilterState filterState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 14, color: AppColors.primaryTeal),
          const SizedBox(width: 6),
          DropdownButton<MapDateFilter>(
            key: const Key('dropdown_date_filter'),
            value: filterState.dateFilter,
            isDense: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            onChanged: (val) {
              if (val != null) {
                ref.read(mapFilterProvider.notifier).setDateFilter(val);
              }
            },
            items: const [
              DropdownMenuItem(
                value: MapDateFilter.all,
                child: Text('All Time'),
              ),
              DropdownMenuItem(
                value: MapDateFilter.last24Hours,
                child: Text('Past 24 Hours'),
              ),
              DropdownMenuItem(
                value: MapDateFilter.last7Days,
                child: Text('Past 7 Days'),
              ),
              DropdownMenuItem(
                value: MapDateFilter.last30Days,
                child: Text('Past 30 Days'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Markers and Clustering ---

  Marker _buildClusterMarker(MapClusterNode cluster) {
    final color = _getRiskColor(cluster.maxRiskLevel);

    return Marker(
      point: cluster.position,
      width: 44,
      height: 44,
      child: GestureDetector(
        key: Key('cluster_${cluster.count}_${cluster.position.latitude}'),
        onTap: () {
          // Zoom into cluster center
          _mapController.move(cluster.position, _currentZoom + 2.0);
        },
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.9),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.25),
                blurRadius: 6,
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${cluster.count}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Marker _buildSingleMarker(PublicMapMarker marker) {
    final color = _getRiskColor(marker.riskLevel);

    return Marker(
      point: marker.position,
      width: 36,
      height: 36,
      child: GestureDetector(
        key: Key('marker_${marker.reportId}'),
        onTap: () => _showPublicReportDetailSheet(context, marker.reportId),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 3),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(
            _getCategoryIcon(marker.category),
            color: color,
            size: 18,
          ),
        ),
      ),
    );
  }

  // --- Detail Sheet via getPublicReportDetails ---

  void _showPublicReportDetailSheet(BuildContext context, String reportId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return FutureBuilder<PublicReportDetailsModel>(
          future: ref.read(mapRepositoryProvider).getPublicReportDetails(reportId),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(32.0),
                child: AppLoadingIndicator(message: 'Loading verified hazard details...'),
              );
            }

            if (snapshot.hasError || !snapshot.hasData) {
              return Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.hazardRed, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load report details: ${snapshot.error ?? 'Unknown error'}',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final details = snapshot.data!;
            final formattedDate =
                '${details.createdAt.year}-${details.createdAt.month.toString().padLeft(2, '0')}-${details.createdAt.day.toString().padLeft(2, '0')}';

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag Handle
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Header with Category & Risk Level
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _getCategoryIcon(details.category),
                            color: _getRiskColor(details.riskLevel),
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            details.category.displayName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getRiskColor(details.riskLevel).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Risk Level ${details.riskLevel}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _getRiskColor(details.riskLevel),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Location & Date Info
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          details.addressText.isNotEmpty
                              ? '${details.addressText}, ${details.district}'
                              : details.district,
                          style: const TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ),
                      Text(
                        formattedDate,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Description
                  if (details.description.isNotEmpty) ...[
                    Text(
                      details.description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Observation Count
                  if (details.observationCount > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.alertAmber.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.repeat, size: 16, color: AppColors.alertAmber),
                          const SizedBox(width: 6),
                          Text(
                            'Reported ${details.observationCount} times (Active Hazard)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.alertAmber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Privacy Notice
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  const Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, size: 14, color: Colors.grey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Citizen identity protected. Anonymized public civic record.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- Legend Card ---

  Widget _buildLegendCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'HAZARD LEGEND',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 8),
            _buildLegendRow(AppColors.hazardRed, 'High Risk (Level 3)'),
            const SizedBox(height: 4),
            _buildLegendRow(AppColors.alertAmber, 'Moderate Risk (Level 2)'),
            const SizedBox(height: 4),
            _buildLegendRow(AppColors.primaryTeal, 'Low Risk (Level 1)'),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primaryTeal,
                  ),
                  child: const Center(
                    child: Text('3', style: TextStyle(color: Colors.white, fontSize: 9)),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('Cluster of Sites', style: TextStyle(fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendRow(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Color _getRiskColor(int riskLevel) {
    switch (riskLevel) {
      case 3:
        return AppColors.hazardRed;
      case 2:
        return AppColors.alertAmber;
      default:
        return AppColors.primaryTeal;
    }
  }

  IconData _getCategoryIcon(HazardCategory category) {
    switch (category) {
      case HazardCategory.standingWater:
        return Icons.water_drop;
      case HazardCategory.tyres:
        return Icons.radio_button_checked;
      case HazardCategory.blockedDrain:
        return Icons.waves;
      case HazardCategory.discardedContainers:
        return Icons.delete_outline;
      case HazardCategory.constructionSite:
        return Icons.construction;
      case HazardCategory.other:
        return Icons.warning_amber_rounded;
    }
  }
}
