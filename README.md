A Dart library that finds the time zone name for any position on Earth given by latitude and longitude coordinates in degrees.

The name of the time zone found corresponds to the time zone name as defined in the [IANA timezone database][timezone_db] (for example: Europe/Madrid or Asia/Shanghai).

The boundaries of the world's time zones used to perform the search have been compiled by the [Timezone Boundary Builder][timezone_boundary_builder] from Evan Siroky.

[timezone_db]: https://www.iana.org/time-zones
[timezone_boundary_builder]: https://github.com/evansiroky/timezone-boundary-builder

## Limitations

The limitations are the same as the [Timezone Boundary Builder][timezone_boundary_builder] project.

## Performances

The size of the database is about 150 Mo and as there is a huge amount of polygons to parse and as the current version does not use a spatial-aware database, it takes between 3 and 5 seconds to find the time zone name.

At the very first call, it might take more time because the database needs to be decompressed.

## Usage

```dart
import 'package:timezone_finder/timezone_finder.dart';

void main() async {
  final latitude = 41.29708;
  final longitude = 2.07846;

  final timezoneFinder = TimezoneFinder();
  final timezoneName = await timezoneFinder.findTimezoneName(latitude, longitude);
  print(timezoneName); // Europe/Madrid
}
```# time_zone_finder
