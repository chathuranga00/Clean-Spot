import 'dart:math';
import 'package:latlong2/latlong.dart';

import 'package:cleanspot/src/features/map/domain/map_marker_model.dart';

class MapClusterNode {
  final LatLng position;
  final List<PublicMapMarker> markers;

  const MapClusterNode({
    required this.position,
    required this.markers,
  });

  bool get isCluster => markers.length > 1;
  int get count => markers.length;

  int get maxRiskLevel {
    int maxRisk = 1;
    for (final m in markers) {
      if (m.riskLevel > maxRisk) {
        maxRisk = m.riskLevel;
      }
    }
    return maxRisk;
  }
}

/// Lightweight, deterministic spatial clustering for flutter_map markers.
class MarkerClusterer {
  /// Clusters markers based on zoom level.
  /// At zoom <= 5, large radius; at zoom >= 16, no clustering (individual pins).
  static List<MapClusterNode> clusterMarkers({
    required List<PublicMapMarker> markers,
    required double zoom,
  }) {
    if (markers.isEmpty) return const [];
    if (zoom >= 16.0) {
      return markers
          .map((m) => MapClusterNode(position: m.position, markers: [m]))
          .toList();
    }

    // Distance threshold in degrees ~ 60 pixels at current zoom
    final double threshold = 60.0 * (360.0 / (256.0 * pow(2.0, zoom)));

    final List<MapClusterNode> clusters = [];
    final Set<String> processedIds = {};

    for (final marker in markers) {
      if (processedIds.contains(marker.reportId)) continue;

      final List<PublicMapMarker> clusterMembers = [marker];
      processedIds.add(marker.reportId);

      for (final other in markers) {
        if (processedIds.contains(other.reportId)) continue;

        final double dLat = marker.position.latitude - other.position.latitude;
        final double dLng = marker.position.longitude - other.position.longitude;
        final double dist = sqrt(dLat * dLat + dLng * dLng);

        if (dist <= threshold) {
          clusterMembers.add(other);
          processedIds.add(other.reportId);
        }
      }

      // Compute centroid
      double sumLat = 0.0;
      double sumLng = 0.0;
      for (final member in clusterMembers) {
        sumLat += member.position.latitude;
        sumLng += member.position.longitude;
      }

      final centroid = LatLng(
        sumLat / clusterMembers.length,
        sumLng / clusterMembers.length,
      );

      clusters.add(MapClusterNode(
        position: centroid,
        markers: clusterMembers,
      ));
    }

    return clusters;
  }
}
