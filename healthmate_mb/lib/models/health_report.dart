enum ReportType { personalConcern, feedback }

/// Reports are local notes. There is no remote submission status.
enum ReportStatus { saved }

class HealthReport {
  final String id;
  final String reference;
  final ReportType type;
  final String category;
  final String description;
  final String area;
  final double? latitude;
  final double? longitude;
  final ReportStatus status;
  final DateTime createdAt;

  const HealthReport({
    required this.id,
    required this.reference,
    required this.type,
    required this.category,
    required this.description,
    this.area = '',
    this.latitude,
    this.longitude,
    this.status = ReportStatus.saved,
    required this.createdAt,
  });

  HealthReport copyWith({
    String? id,
    String? reference,
    ReportStatus? status,
    DateTime? createdAt,
  }) {
    return HealthReport(
      id: id ?? this.id,
      reference: reference ?? this.reference,
      type: type,
      category: category,
      description: description,
      area: area,
      latitude: latitude,
      longitude: longitude,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String toShareText() {
    final buffer = StringBuffer()
      ..writeln('HealthMate report')
      ..writeln('Reference: $reference')
      ..writeln('Date: ${createdAt.toIso8601String().split('T').first}')
      ..writeln('Type: ${type == ReportType.personalConcern ? 'Health concern' : 'App feedback'}')
      ..writeln('Category: $category')
      ..writeln()
      ..writeln(description);
    if (area.isNotEmpty) {
      buffer
        ..writeln()
        ..writeln('Area: $area');
    }
    if (latitude != null && longitude != null) {
      buffer.writeln(
        'Coordinates: ${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}',
      );
    }
    buffer
      ..writeln()
      ..writeln('Saved locally in HealthMate. Not automatically sent.');
    return buffer.toString();
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'reference': reference,
        'type': type.name,
        'category': category,
        'description': description,
        'area': area,
        'latitude': latitude,
        'longitude': longitude,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HealthReport.fromMap(Map<String, dynamic> map) {
    return HealthReport(
      id: (map['id'] ?? '').toString(),
      reference: (map['reference'] ?? '').toString(),
      type: map['type'] == ReportType.personalConcern.name
          ? ReportType.personalConcern
          : ReportType.feedback,
      category: (map['category'] ?? 'other').toString(),
      description: (map['description'] ?? '').toString(),
      area: (map['area'] ?? '').toString(),
      latitude:
          map['latitude'] is num ? (map['latitude'] as num).toDouble() : null,
      longitude:
          map['longitude'] is num ? (map['longitude'] as num).toDouble() : null,
      status: ReportStatus.saved,
      createdAt:
          DateTime.tryParse((map['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
