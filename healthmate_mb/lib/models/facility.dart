class Facility {
  final String id;
  final String name;
  final String type;
  final String address;
  final String? phone;
  final String? website;
  final double latitude;
  final double longitude;
  final double? distanceKm;
  final String? openingHours;

  const Facility({
    required this.id,
    required this.name,
    required this.type,
    required this.address,
    this.phone,
    this.website,
    required this.latitude,
    required this.longitude,
    this.distanceKm,
    this.openingHours,
  });

  factory Facility.fromMap(Map<String, dynamic> map) {
    return Facility(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      type: (map['type'] ?? 'hospital').toString(),
      address: (map['address'] ?? '').toString(),
      phone: _cleanPhone(map['phone']?.toString()),
      website: _cleanUrl(map['website']?.toString()),
      latitude: _asDouble(map['lat'] ?? map['latitude']),
      longitude: _asDouble(map['lon'] ?? map['longitude']),
      distanceKm: map['distanceKm'] == null ? null : _asDouble(map['distanceKm']),
      openingHours: map['openingHours']?.toString(),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _cleanPhone(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  static String? _cleanUrl(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return null;
    }
    return uri.toString();
  }

  String get typeLabel {
    switch (type) {
      case 'clinic':
        return 'Clinic';
      case 'doctors':
        return "Doctor's office";
      case 'pharmacy':
        return 'Pharmacy';
      default:
        return 'Hospital';
    }
  }

  String get displayName => name.trim().isEmpty ? typeLabel : name;
}
