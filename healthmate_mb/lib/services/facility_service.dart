import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/facility.dart';
import 'api_client.dart';

class PlaceResult {
  final String displayName;
  final double latitude;
  final double longitude;

  const PlaceResult({
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });
}

class FacilityResult {
  final List<Facility> facilities;
  final String? warning;
  final ApiException? error;
  final String source;

  const FacilityResult({
    required this.facilities,
    this.warning,
    this.error,
    this.source = 'OpenStreetMap',
  });

  bool get isError => error != null;
}

class FacilityService {
  final ApiClient _api;
  final http.Client _directClient;

  FacilityService({ApiClient? api, http.Client? client})
      : _api = api ?? ApiClient(),
        _directClient = client ?? http.Client();

  Future<List<PlaceResult>> searchPlaces(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 2) return const [];

    try {
      final json = await _api.getJson(
        '/api/geocode',
        query: {'q': trimmed, 'limit': '5'},
        timeout: const Duration(seconds: 12),
      );
      final raw = json['results'];
      if (raw is List) {
        final places = raw
            .whereType<Map>()
            .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
            .whereType<PlaceResult>()
            .toList();
        if (places.isNotEmpty) return places;
      }
    } on ApiException {
      // Try Nominatim directly (it permits browser CORS requests).
    }

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&limit=5&addressdetails=0&q=${Uri.encodeQueryComponent(trimmed)}',
      );
      final response = await _directClient
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) {
          return decoded
              .whereType<Map>()
              .map((item) => _placeFromMap(Map<String, dynamic>.from(item)))
              .whereType<PlaceResult>()
              .toList();
        }
      }
    } catch (_) {
      // Return an empty list; the UI explains that search is unavailable.
    }
    return const [];
  }

  PlaceResult? _placeFromMap(Map<String, dynamic> map) {
    final lat = _asDouble(map['lat'] ?? map['latitude']);
    final lon = _asDouble(map['lon'] ?? map['longitude']);
    final name = (map['display_name'] ?? map['name'] ?? '').toString();
    if (name.isEmpty || (lat == 0 && lon == 0)) return null;
    return PlaceResult(displayName: name, latitude: lat, longitude: lon);
  }

  Future<FacilityResult> nearby({
    required double latitude,
    required double longitude,
    double radiusKm = 8,
    String type = 'all',
  }) async {
    try {
      final json = await _api.getJson(
        '/api/facilities',
        query: {
          'lat': latitude.toStringAsFixed(5),
          'lon': longitude.toStringAsFixed(5),
          'radius': radiusKm.toStringAsFixed(1),
          'type': type,
        },
        // Overpass routinely needs 30s+ under load. Giving up earlier means the
        // proxy answer arrives after the client has already gone away.
        timeout: const Duration(seconds: 50),
        retries: 0,
      );
      final raw = json['facilities'];
      final facilities = <Facility>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            final facility = Facility.fromMap(Map<String, dynamic>.from(item));
            if (facility.latitude != 0 || facility.longitude != 0) {
              facilities.add(facility);
            }
          }
        }
      }
      return FacilityResult(
        facilities: facilities,
        warning: json['warning']?.toString(),
        source: json['source']?.toString() ?? 'OpenStreetMap',
      );
    } on ApiException catch (error) {
      // Direct Overpass fallback for mobile/desktop and browsers that allow it.
      final direct = await _directOverpass(
        latitude: latitude,
        longitude: longitude,
        radiusKm: radiusKm,
        type: type,
      );
      if (direct != null) {
        return FacilityResult(
          facilities: direct,
          warning: 'Live facility data came from a direct OpenStreetMap request.',
        );
      }
      return FacilityResult(facilities: const [], error: error);
    }
  }

  Future<List<Facility>?> _directOverpass({
    required double latitude,
    required double longitude,
    required double radiusKm,
    required String type,
  }) async {
    final amenity = _amenityFilter(type);
    final radius = (radiusKm * 1000).round();
    final query = '''
[out:json][timeout:25];
(
  node["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
  way["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
  relation["amenity"~"$amenity"](around:$radius,$latitude,$longitude);
);
out center tags 60;
''';
    try {
      final uri = Uri.parse('https://overpass-api.de/api/interpreter').replace(
        queryParameters: {'data': query},
      );
      final response = await _directClient
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'HealthMate/1.0 (local development)',
            },
          )
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(response.body);
      if (decoded is! Map || decoded['elements'] is! List) return null;
      return (decoded['elements'] as List)
          .whereType<Map>()
          .map((element) => _facilityFromOverpass(
                Map<String, dynamic>.from(element),
                latitude,
                longitude,
              ))
          .whereType<Facility>()
          .toList()
        ..sort((a, b) => (a.distanceKm ?? 999).compareTo(b.distanceKm ?? 999));
    } catch (_) {
      return null;
    }
  }

  String _amenityFilter(String type) {
    switch (type) {
      case 'hospital':
        return 'hospital';
      case 'clinic':
        return 'clinic|doctors';
      case 'pharmacy':
        return 'pharmacy';
      default:
        return 'hospital|clinic|doctors|pharmacy';
    }
  }

  Facility? _facilityFromOverpass(Map<String, dynamic> element, double originLat, double originLon) {
    final tags = element['tags'] is Map
        ? Map<String, dynamic>.from(element['tags'] as Map)
        : <String, dynamic>{};
    final lat = _asDouble(element['lat'] ?? (element['center'] is Map ? element['center']['lat'] : null));
    final lon = _asDouble(element['lon'] ?? (element['center'] is Map ? element['center']['lon'] : null));
    if (lat == 0 && lon == 0) return null;

    final addressParts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:suburb'],
      tags['addr:city'],
      tags['addr:postcode'],
    ].where((value) => value != null && value.toString().trim().isNotEmpty).map((value) => value.toString()).toList();

    final type = (tags['amenity'] ?? 'hospital').toString();
    return Facility(
      id: (element['id'] ?? '$lat,$lon').toString(),
      name: (tags['name'] ?? '').toString(),
      type: type == 'doctors' ? 'doctors' : type,
      address: addressParts.join(', '),
      phone: tags['phone']?.toString() ?? tags['contact:phone']?.toString(),
      website: tags['website']?.toString() ?? tags['contact:website']?.toString(),
      latitude: lat,
      longitude: lon,
      distanceKm: _haversineKm(originLat, originLon, lat, lon),
      openingHours: tags['opening_hours']?.toString(),
    );
  }

  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadiusKm = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_radians(lat1)) *
            math.cos(_radians(lat2)) *
            math.pow(math.sin(dLon / 2), 2);
    return earthRadiusKm * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  double _radians(double degrees) => degrees * math.pi / 180;

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
