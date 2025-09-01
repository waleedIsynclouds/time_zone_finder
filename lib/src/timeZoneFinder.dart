// lib/src/timeZoneFinder.dart
//
// Robust, isolate-parallel timezone lookup from an SQLite polygons DB.
// - Returns `String?` (IANA tz id) or `null` if no polygon matches.
// - Handles Polygon and MultiPolygon records.
// - Aggregates hits from all chunks and prefers named IANA zones over "Etc/GMT±X".
// - Cleans up isolates, ports, and DB handles deterministically.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive.dart';
import 'package:geojson/geojson.dart';
import 'package:geopoint/geopoint.dart';
import 'package:sqlite3/sqlite3.dart';

// Keep if you have extensions; otherwise safe to remove.
// ignore: unused_import
import 'package:timezone_finder/src/extensions.dart';

const int _kOffset = 200;

class TimeZoneFinder {
  final List<Isolate?> _isolates = <Isolate?>[];

  // Paths (adjust if you store assets elsewhere)
  String get _zipPath => 'lib/assets/timezones.zip';
  String get _dbPath => 'lib/assets/timezones';

  /// Public API: Finds the IANA timezone ID for [latitude], [longitude].
  /// Returns `null` if the point is outside all polygons or if assets are missing.
  Future<String?> findTimeZoneName(double latitude, double longitude) async {
    // Bounds guard
    if (latitude > 90 ||
        latitude < -90 ||
        longitude > 180 ||
        longitude < -180) {
      return null;
    }

    // Ensure DB exists (unzip once if necessary)
    _ensureDbUnzippedSync();

    final dbFile = File(_dbPath);
    if (!dbFile.existsSync()) {
      // Asset missing; bail gracefully
      return null;
    }

    final db = sqlite3.open(_dbPath);

    // We will aggregate ALL hits and then choose the best zone.
    final hits = <String>{};

    // Completer for final answer (nullable)
    final completer = Completer<String?>();

    // Ports for inter-isolate comms
    final resultPort = ReceivePort();
    final errorPort = ReceivePort();

    // Isolate accounting
    var isolatesSpawned = 0;
    var isolatesExited = 0;
    var cleaned = false;

    Future<void> cleanup() async {
      if (cleaned) return;
      cleaned = true;
      _killIsolates();
      resultPort.close();
      errorPort.close();
      db.dispose();
    }

    // Listen for results / exits
    late final StreamSubscription resultSub;
    resultSub = resultPort.listen((data) async {
      if (data == null) {
        // An isolate exited
        isolatesExited += 1;
        if (isolatesExited == isolatesSpawned && !completer.isCompleted) {
          // All isolates done → choose best hit (if any)
          completer.complete(_chooseBest(hits));
          await resultSub.cancel();
          await cleanup();
        }
        return;
      }

      // Results may be String tzid or List<String> tzids (we aggregate)
      if (data is String) {
        hits.add(data);
      } else if (data is List) {
        for (final e in data) {
          if (e is String && e.isNotEmpty) hits.add(e);
        }
      }
      // Note: we DO NOT complete early anymore; we wait for all isolates to exit
      // to allow better-than-Etc matches from other chunks.
    });

    // Optional: listen to isolate errors (we just absorb; could surface)
    late final StreamSubscription errorSub;
    errorSub = errorPort.listen((err) async {
      // err is [error, stackTrace]
      // You could log or collect metrics here. We still rely on exit counting.
    });

    try {
      // Stream the DB in chunks and spawn an isolate per chunk
      var offset = 0;
      var rs = db.select('SELECT * FROM timezones LIMIT $_kOffset');

      final geoPoint = GeoJsonPoint(
        geoPoint: GeoPoint(latitude: latitude, longitude: longitude),
      );

      while (rs.isNotEmpty) {
        final msg = _IsolateMessage(rs, geoPoint, resultPort.sendPort);

        final isolate = await Isolate.spawn<_IsolateMessage>(
          _isolateProcessResultSet,
          msg,
          onExit: resultPort.sendPort, // sends `null` when isolate exits
          onError: errorPort.sendPort, // forwards [error, stack]
        );

        _isolates.add(isolate);
        isolatesSpawned += 1;

        offset += _kOffset;
        rs =
            db.select('SELECT * FROM timezones LIMIT $_kOffset OFFSET $offset');
      }

      // No data → immediate completion
      if (isolatesSpawned == 0) {
        await resultSub.cancel();
        await errorSub.cancel();
        await cleanup();
        return null;
      }

      // Wait for final answer
      final value = await completer.future;
      await errorSub.cancel();
      return value;
    } catch (_) {
      // On sync exception, cleanup & return null
      await resultSub.cancel();
      await errorSub.cancel();
      await cleanup();
      return null;
    }
  }

  // ---------- helpers ----------

  void _ensureDbUnzippedSync() {
    final dbFile = File(_dbPath);
    if (dbFile.existsSync()) return;

    final zipFile = File(_zipPath);
    if (!zipFile.existsSync()) return;

    final bytes = zipFile.readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    // Prefer an entry literally named 'timezones', else first file
    ArchiveFile? target;
    for (final f in archive) {
      if (f.isFile &&
          (f.name.endsWith('/timezones') || f.name == 'timezones')) {
        target = f;
        break;
      }
    }
    target ??= archive.firstWhere((f) => f.isFile,
        orElse: () => ArchiveFile('', 0, []));

    if (target.isFile) {
      final outPath = 'lib/assets/${target.name.split('/').last}';
      File(outPath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(target.content as List<int>);
    }
  }

  void _killIsolates() {
    for (var i = 0; i < _isolates.length; i++) {
      _isolates[i]?.kill(priority: Isolate.immediate);
      _isolates[i] = null;
    }
  }

  // Prefer named IANA zones over Etc/GMT±X; add light ranking if needed.
  String? _chooseBest(Set<String> hits) {
    if (hits.isEmpty) return null;

    // Filter out low-quality "Etc/*" when a named zone exists
    final named = hits.where((z) => !z.startsWith('Etc/')).toList();
    if (named.isEmpty) {
      // Only Etc present; return something deterministic
      return hits.first;
    }

    // Optional extra ranking: avoid generic "GMT" strings, prefer with a slash,
    // shorter names often indicate canonical areas (heuristic).
    int rank(String z) {
      var r = 0;
      if (z.contains('GMT')) r += 50;
      if (!z.contains('/')) r += 50;
      if (z.startsWith('posix/') || z.startsWith('right/') || z == 'Factory')
        r += 100;
      return r;
    }

    named.sort((a, b) => rank(a).compareTo(rank(b)));
    return named.first;
  }

  // ---------- isolate entrypoint ----------

  static Future<void> _isolateProcessResultSet(_IsolateMessage message) async {
    try {
      final polygons = <GeoJsonFeature<GeoJsonPolygon>>[];

      for (final row in message.resultSet.rows) {
        // Assuming schema: [id, coords_json, tzid]
        final coordsJson = row[1];
        final tzid = row[2];
        if (coordsJson == null || tzid == null) continue;

        final parsed = json.decode(coordsJson.toString());

        // Extract outer rings for Polygon or MultiPolygon
        final outerRings = _extractOuterRings(parsed);
        if (outerRings.isEmpty) continue;

        for (final ring in outerRings) {
          final geoPoints = <GeoPoint>[];
          for (final coord in ring) {
            if (coord is List && coord.length >= 2) {
              final lon = double.tryParse(coord[0].toString());
              final lat = double.tryParse(coord[1].toString());
              if (lat != null && lon != null) {
                geoPoints.add(GeoPoint(latitude: lat, longitude: lon));
              }
            }
          }
          if (geoPoints.length < 3) continue;

          final feature = GeoJsonFeature<GeoJsonPolygon>()
            ..type = GeoJsonFeatureType.polygon
            ..properties = {'tzid': tzid.toString()}
            ..geometry = GeoJsonPolygon(
              geoSeries: [
                GeoSerie(
                    geoPoints: geoPoints, name: '', type: GeoSerieType.polygon),
              ],
            );

          polygons.add(feature);
        }
      }

      if (polygons.isEmpty) return; // onExit will notify

      final geo = GeoJson();
      try {
        final result = await geo.geofenceSearch(polygons, message.geoPoint);
        if (result != null && result.isNotEmpty) {
          // Collect all tzids from this chunk (some points lie in overlapping polys)
          final tzids = <String>{};
          for (final f in result) {
            final id = f.properties?['tzid']?.toString();
            if (id != null && id.isNotEmpty) tzids.add(id);
          }
          if (tzids.isNotEmpty) {
            message.sendPort.send(tzids.toList());
          }
        }
      } finally {
        geo.dispose();
      }
    } catch (e, st) {
      // Surface to the main isolate's onError port
      Zone.current.handleUncaughtError(e, st);
    }
  }

  /// Returns a list of outer rings (each ring is List<List<num>>) from a
  /// GeoJSON Polygon or MultiPolygon `coordinates` field.
  static List<List<dynamic>> _extractOuterRings(dynamic coords) {
    // Polygon: [ [ ring0 ], [ hole1 ], ... ]
    bool _isPolygon(dynamic v) =>
        v is List &&
        v.isNotEmpty &&
        v.first is List &&
        (v.first as List).isNotEmpty &&
        (v.first as List).first is List &&
        ((v.first as List).first as List).isNotEmpty &&
        (((v.first as List).first as List).first is num ||
            ((v.first as List).first as List).first is int ||
            ((v.first as List).first as List).first is double);

    // MultiPolygon: [ polygon[], polygon[], ... ]
    bool _isMultiPolygon(dynamic v) =>
        v is List && v.isNotEmpty && _isPolygon(v.first);

    final rings = <List<dynamic>>[];

    if (_isPolygon(coords)) {
      // Take only the outer ring (index 0)
      final ring0 = (coords as List).first as List;
      rings.add(ring0);
    } else if (_isMultiPolygon(coords)) {
      // For each polygon, take its outer ring (index 0)
      for (final poly in (coords as List)) {
        if (_isPolygon(poly)) {
          final ring0 = (poly as List).first as List;
          rings.add(ring0);
        }
      }
    }

    return rings;
    // Note: If your DB stores true GeoJSON objects (with "type":"Polygon"),
    // you may need to look one level up; here we assume `row[1]` is already
    // the `coordinates` array field.
  }
}

class _IsolateMessage {
  final ResultSet resultSet;
  final GeoJsonPoint geoPoint;
  final SendPort sendPort;

  _IsolateMessage(this.resultSet, this.geoPoint, this.sendPort);
}
