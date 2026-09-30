import 'dart:math' as math;

import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Gruppo di elementi vicini sullo schermo: un solo elemento se isolato,
/// più elementi se raggruppati in un cluster.
class ClusterGroup<T> {
  ClusterGroup({required this.items, required this.center});

  final List<T> items;
  final LatLng center;

  bool get isCluster => items.length > 1;
}

/// Raggruppa [items] i cui punti proiettati sullo schermo (in
/// [screenPoints], stesso ordine di [items]) distano meno di
/// [pixelThreshold] l'uno dall'altro. Algoritmo greedy O(n²): adeguato al
/// numero di segnalazioni tipicamente visibili su una mappa (decine).
List<ClusterGroup<T>> clusterByScreenDistance<T>({
  required List<T> items,
  required List<ScreenCoordinate> screenPoints,
  required LatLng Function(T item) positionOf,
  double pixelThreshold = 56,
}) {
  final n = items.length;
  final visited = List<bool>.filled(n, false);
  final groups = <ClusterGroup<T>>[];

  for (var i = 0; i < n; i++) {
    if (visited[i]) continue;
    final groupIndices = <int>[i];
    visited[i] = true;
    for (var j = i + 1; j < n; j++) {
      if (visited[j]) continue;
      final dx = (screenPoints[i].x - screenPoints[j].x).toDouble();
      final dy = (screenPoints[i].y - screenPoints[j].y).toDouble();
      if (math.sqrt(dx * dx + dy * dy) <= pixelThreshold) {
        groupIndices.add(j);
        visited[j] = true;
      }
    }

    final groupItems = [for (final idx in groupIndices) items[idx]];
    final lat =
        groupItems.map((e) => positionOf(e).latitude).reduce((a, b) => a + b) /
        groupItems.length;
    final lng =
        groupItems.map((e) => positionOf(e).longitude).reduce((a, b) => a + b) /
        groupItems.length;
    groups.add(ClusterGroup(items: groupItems, center: LatLng(lat, lng)));
  }

  return groups;
}
