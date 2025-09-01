import 'package:geojson/geojson.dart';
import 'package:timezone_finder/src/geoBoundingBox.dart';

/// Geofencing search extensions.
///
/// The original geofencing search provided by the GeoJson package is not suitable to find in which polygons a single point is
/// when having a large number of polygons.
/// Indeed, it is necessary to search each polygon individually and as there is more than 1,000 polygons used to define
/// timezones, it was not a viable solution.
///
/// Thanks to lukepighetti (see link below), he proposed a fast solution using pre-computed bounding boxes.
///
/// Source: https://gist.github.com/lukepighetti/442fca7115c752b9a93b025fc04b4c18
extension GeoJsonSearchX on GeoJson {
  /// Given a list of polygons, find which one contains a given point.
  ///
  /// If the point isn't within any of these polygons, return `null`.
  Future<List<GeoJsonFeature<GeoJsonPolygon>>?> geofenceSearch(
    List<GeoJsonFeature<GeoJsonPolygon>> geofences,
    GeoJsonPoint query,
  ) async {
    final boundingBoxes = getBoundingBoxes(geofences);
    final filteredGeofences = <GeoJsonFeature<GeoJsonPolygon>>[];

    for (var box in boundingBoxes) {
      if (box.contains(query.geoPoint.latitude, query.geoPoint.longitude)) {
        if (box.feature != null) {
          filteredGeofences.add(box.feature!);
        }
      }
    }

    if (filteredGeofences.isEmpty) {
      return null;
    }
    return await _geofencesContainingPointNaive(filteredGeofences, query);
  }

  /// Return all geofences that contain the point provided.
  ///
  /// Naive implementation. The geofences should be filtered first using a method such
  /// as searching bounding boxes first.
  Future<List<GeoJsonFeature<GeoJsonPolygon>>> _geofencesContainingPointNaive(
    List<GeoJsonFeature<GeoJsonPolygon>> geofences,
    GeoJsonPoint query,
  ) async {
    // Safer: put the type on the literal to avoid “>” counting mistakes
    final futures = <Future<GeoJsonFeature<GeoJsonPolygon>?>>[
      for (final geofence in geofences)
        if (geofence.geometry != null)
          geofencePolygon(
            polygon: geofence.geometry!,
            points: [query],
          ).then<GeoJsonFeature<GeoJsonPolygon>?>((results) {
            if (results.isEmpty) return null;
            return (results.first.name == query.name) ? geofence : null;
          }),
    ];

    final results = await Future.wait(futures);

    // Convert List<T?> → List<T>
    return results.whereType<GeoJsonFeature<GeoJsonPolygon>>().toList();
  }

  /// Given a set of geofence polygons, find all of their bounding boxes, and the index at which they were found.
  List<GeoBoundingBox> getBoundingBoxes(
      List<GeoJsonFeature<GeoJsonPolygon>> geofences) {
    final boundingBoxes = <GeoBoundingBox>[];

    for (var i = 0; i <= geofences.length - 1; i++) {
      final geofence = geofences[i];

      double? maxLat;
      double? minLat;
      double? maxLong;
      double? minLong;

      for (var geoSerie in geofence.geometry?.geoSeries ?? []) {
        for (var geoPoint in geoSerie.geoPoints) {
          final lat = geoPoint.latitude;
          final long = geoPoint.longitude;

          /// Make sure they get seeded if they are null
          minLat ??= lat;
          maxLong ??= long;
          minLong ??= long;

          /// Update values
          if ((maxLat ?? 0) < lat) maxLat = lat;
          if ((minLat ?? 0) > lat) minLat = lat;
          if ((maxLong ?? 0) < long) maxLong = long;
          if ((minLong ?? 0) > long) minLong = long;
        }
      }
      if (maxLat == null ||
          minLat == null ||
          maxLong == null ||
          minLong == null) {
        continue;
      }
      boundingBoxes.add(GeoBoundingBox(
        feature: geofence,
        minLat: minLat,
        maxLong: maxLong,
        maxLat: maxLat,
        minLong: minLong,
      ));
    }

    return boundingBoxes;
  }
}
