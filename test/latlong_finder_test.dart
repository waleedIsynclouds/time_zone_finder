import 'package:test/test.dart';
import 'package:timezone_finder/timezone_finder.dart';

void main() {
  final finder = TimeZoneFinder();

  // ---------- 1) Classic world cities ----------
  final worldCities = <String, Map<String, dynamic>>{
    'Cairo': {
      'latitude': 30.0444,
      'longitude': 31.2357,
      'timezone': 'Africa/Cairo'
    },
    'Riyadh': {
      'latitude': 24.7136,
      'longitude': 46.6753,
      'timezone': 'Asia/Riyadh'
    },
    'London': {
      'latitude': 51.5074,
      'longitude': -0.1278,
      'timezone': 'Europe/London'
    },
    'Paris': {
      'latitude': 48.8566,
      'longitude': 2.3522,
      'timezone': 'Europe/Paris'
    },
    'Moscow': {
      'latitude': 55.7558,
      'longitude': 37.6173,
      'timezone': 'Europe/Moscow'
    },
    'Tokyo': {
      'latitude': 35.6762,
      'longitude': 139.6503,
      'timezone': 'Asia/Tokyo'
    },
    'Auckland': {
      'latitude': -36.8485,
      'longitude': 174.7633,
      'timezone': 'Pacific/Auckland'
    },
    'Johannesburg': {
      'latitude': -26.2041,
      'longitude': 28.0473,
      'timezone': 'Africa/Johannesburg'
    },
    'Lagos': {
      'latitude': 6.5244,
      'longitude': 3.3792,
      'timezone': 'Africa/Lagos'
    },
    'Tehran': {
      'latitude': 35.6892,
      'longitude': 51.3890,
      'timezone': 'Asia/Tehran'
    },
    'Karachi': {
      'latitude': 24.8607,
      'longitude': 67.0011,
      'timezone': 'Asia/Karachi'
    },
    'Kathmandu': {
      'latitude': 27.7172,
      'longitude': 85.3240,
      'timezone': 'Asia/Kathmandu'
    },
  };

  group('World Cities', () {
    for (final entry in worldCities.entries) {
      test('${entry.key} → ${entry.value['timezone']}', () async {
        final tzName = await finder.findTimeZoneName(
          entry.value['latitude'],
          entry.value['longitude'],
        );
        expect(tzName, entry.value['timezone']);
      });
    }
  });

  // ---------- 2) Multi-timezone countries (US & Brazil) ----------
  final multiZone = <String, Map<String, dynamic>>{
    // USA
    'New York': {
      'latitude': 40.7128,
      'longitude': -74.0060,
      'timezone': 'America/New_York'
    },
    'Chicago': {
      'latitude': 41.8781,
      'longitude': -87.6298,
      'timezone': 'America/Chicago'
    },
    'Denver': {
      'latitude': 39.7392,
      'longitude': -104.9903,
      'timezone': 'America/Denver'
    },
    'Los Angeles': {
      'latitude': 34.0522,
      'longitude': -118.2437,
      'timezone': 'America/Los_Angeles'
    },
    'Anchorage': {
      'latitude': 61.2181,
      'longitude': -149.9003,
      'timezone': 'America/Anchorage'
    },
    'Adak': {
      'latitude': 51.8836,
      'longitude': -176.6581,
      'timezone': 'America/Adak'
    },
    'Honolulu': {
      'latitude': 21.3069,
      'longitude': -157.8583,
      'timezone': 'Pacific/Honolulu'
    },

    // Brazil
    'Sao Paulo': {
      'latitude': -23.5505,
      'longitude': -46.6333,
      'timezone': 'America/Sao_Paulo'
    },
    'Manaus': {
      'latitude': -3.1190,
      'longitude': -60.0217,
      'timezone': 'America/Manaus'
    },
  };

  group('Multi-timezone Countries', () {
    for (final entry in multiZone.entries) {
      test('${entry.key} → ${entry.value['timezone']}', () async {
        final tzName = await finder.findTimeZoneName(
          entry.value['latitude'],
          entry.value['longitude'],
        );
        expect(tzName, entry.value['timezone']);
      });
    }
  });

  // ---------- 3) Islands & archipelagos ----------
  final islands = <String, Map<String, dynamic>>{
    'Canary Islands': {
      'latitude': 28.2916,
      'longitude': -16.6291,
      'timezone': 'Atlantic/Canary'
    },
    'Azores': {
      'latitude': 37.7412,
      'longitude': -25.6756,
      'timezone': 'Atlantic/Azores'
    },
    'Madeira': {
      'latitude': 32.7607,
      'longitude': -16.9595,
      'timezone': 'Atlantic/Madeira'
    },
    'Mauritius': {
      'latitude': -20.3484,
      'longitude': 57.5522,
      'timezone': 'Indian/Mauritius'
    },
    'Reunion': {
      'latitude': -21.1151,
      'longitude': 55.5364,
      'timezone': 'Indian/Reunion'
    },
    'Maldives': {
      'latitude': 4.1755,
      'longitude': 73.5093,
      'timezone': 'Indian/Maldives'
    },
    'Singapore': {
      'latitude': 1.3521,
      'longitude': 103.8198,
      'timezone': 'Asia/Singapore'
    },
    'Hong Kong': {
      'latitude': 22.3193,
      'longitude': 114.1694,
      'timezone': 'Asia/Hong_Kong'
    },
  };

  group('Islands', () {
    for (final entry in islands.entries) {
      test('${entry.key} → ${entry.value['timezone']}', () async {
        final tzName = await finder.findTimeZoneName(
          entry.value['latitude'],
          entry.value['longitude'],
        );
        expect(tzName, entry.value['timezone']);
      });
    }
  });

  // ---------- 4) International Date Line edge cases ----------
  final dateLine = <String, Map<String, dynamic>>{
    'Apia (Samoa)': {
      'latitude': -13.7590,
      'longitude': -171.7770,
      'timezone': 'Pacific/Apia'
    },
    'Nuku\'alofa': {
      'latitude': -21.1394,
      'longitude': -175.2047,
      'timezone': 'Pacific/Tongatapu'
    },
    'Suva (Fiji)': {
      'latitude': -18.1248,
      'longitude': 178.4501,
      'timezone': 'Pacific/Fiji'
    },
    // Near +180/-180 wrap:
    'Near 179.9E': {
      'latitude': 0.0,
      'longitude': 179.9,
      'timezone': 'Pacific/Kiritimati'
    }, // may vary by dataset
    'Near 179.9W': {
      'latitude': 0.0,
      'longitude': -179.9,
      'timezone': 'Pacific/Apia'
    }, // may vary by dataset
  };

  group('International Date Line (edge)', () {
    for (final entry in dateLine.entries) {
      test('${entry.key}', () async {
        final tzName = await finder.findTimeZoneName(
          entry.value['latitude'],
          entry.value['longitude'],
        );
        // Some datasets vary for “near” synthetic points, so only assert non-empty by default:
        if (entry.key.startsWith('Near 179.9')) {
          expect(tzName, isA<String>());
          expect(tzName, isNotEmpty);
        } else {
          expect(tzName, entry.value['timezone']);
        }
      });
    }
  });

  // ---------- 5) Your original European + extras ----------
  final europePlus = <String, Map<String, dynamic>>{
    'Barcelona': {
      'latitude': 41.387048,
      'longitude': 2.17413425,
      'timezone': 'Europe/Madrid'
    },
    'Brussels': {
      'latitude': 50.843471,
      'longitude': 4.36431884,
      'timezone': 'Europe/Brussels'
    },
    'Helsinki': {
      'latitude': 60.166114,
      'longitude': 24.9361887,
      'timezone': 'Europe/Helsinki'
    },
    'Dubai': {
      'latitude': 25.263792,
      'longitude': 55.3434562,
      'timezone': 'Asia/Dubai'
    },
    'Singapore': {
      'latitude': 1.3102843,
      'longitude': 103.846485,
      'timezone': 'Asia/Singapore'
    },
    'Sydney': {
      'latitude': -33.92614,
      'longitude': 151.222826,
      'timezone': 'Australia/Sydney'
    },
    'Ushuaia': {
      'latitude': -54.81631,
      'longitude': -68.327772,
      'timezone': 'America/Argentina/Ushuaia'
    },
    'Vancouver': {
      'latitude': 49.247112,
      'longitude': -123.10707,
      'timezone': 'America/Vancouver'
    },
    'Skopje': {
      'latitude': 42.0,
      'longitude': 21.433333,
      'timezone': 'Europe/Skopje'
    },
    'Sofia': {
      'latitude': 42.7,
      'longitude': 23.316667,
      'timezone': 'Europe/Sofia'
    },
  };

  group('Europe & Friends', () {
    for (final entry in europePlus.entries) {
      test('${entry.key} → ${entry.value['timezone']}', () async {
        final tzName = await finder.findTimeZoneName(
          entry.value['latitude'],
          entry.value['longitude'],
        );
        expect(tzName, entry.value['timezone']);
      });
    }
  });

  // ---------- 6) Performance / concurrency sanity ----------
  test('Batch lookup (concurrency)', () async {
    final points = [
      [30.0444, 31.2357], // Cairo
      [24.7136, 46.6753], // Riyadh
      [40.7128, -74.0060], // New York
      [-23.5505, -46.6333], // Sao Paulo
      [35.6762, 139.6503], // Tokyo
      [-36.8485, 174.7633], // Auckland
    ];

    final sw = Stopwatch()..start();
    final futures = points.map((p) => finder.findTimeZoneName(p[0], p[1]));
    final results = await Future.wait(futures);
    sw.stop();

    // All should resolve to non-empty strings quickly.
    expect(results.every((e) => e is String && e.isNotEmpty), isTrue,
        reason: 'All lookups should return valid timezone IDs');
    // Soft performance check (tune as needed for CI/device):
    expect(sw.elapsed.inSeconds < 5, isTrue,
        reason: 'Batch should be reasonably fast');
  });
}
