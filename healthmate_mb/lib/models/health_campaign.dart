enum CampaignStatus { upcoming, ongoing, past }

class CampaignView {
  final HealthCampaign campaign;
  final DateTime start;
  final DateTime end;
  final CampaignStatus status;

  const CampaignView({
    required this.campaign,
    required this.start,
    required this.end,
    required this.status,
  });
}

/// A verified public-health observance or campaign.
///
/// The bundled dataset uses recurring month/day rules sourced from WHO, UN and
/// MoHFW/NHM. No venue, organizer or registration link is invented: fields are
/// only shown when the source provides them.
class HealthCampaign {
  final String id;
  final String title;
  final String organizer;
  final String sourceName;
  final String sourceUrl;
  final String description;
  final String category;
  final String venue;
  final String city;
  final int startMonth;
  final int startDay;
  final int? endMonth;
  final int? endDay;
  final String? timeNote;

  const HealthCampaign({
    required this.id,
    required this.title,
    required this.organizer,
    required this.sourceName,
    required this.sourceUrl,
    required this.description,
    required this.category,
    this.venue = 'Nationwide',
    this.city = '',
    required this.startMonth,
    required this.startDay,
    this.endMonth,
    this.endDay,
    this.timeNote,
  });

  factory HealthCampaign.fromMap(Map<String, dynamic> map) {
    return HealthCampaign(
      id: (map['id'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      organizer: (map['organizer'] ?? '').toString(),
      sourceName: (map['sourceName'] ?? map['source'] ?? '').toString(),
      sourceUrl: (map['sourceUrl'] ?? map['url'] ?? '').toString(),
      description: (map['description'] ?? map['details'] ?? '').toString(),
      category: (map['category'] ?? 'public_health').toString(),
      venue: (map['venue'] ?? '').toString(),
      city: (map['city'] ?? '').toString(),
      startMonth: _asInt(map['month'] ?? map['startMonth'], 1),
      startDay: _asInt(map['day'] ?? map['startDay'], 1),
      endMonth: map['endMonth'] == null ? null : _asInt(map['endMonth'], 1),
      endDay: map['endDay'] == null ? null : _asInt(map['endDay'], 1),
      timeNote: map['timeNote']?.toString(),
    );
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  DateTime startForYear(int year) => DateTime(year, startMonth, startDay);

  DateTime endForYear(int year) {
    final start = startForYear(year);
    if (endMonth == null || endDay == null) {
      return DateTime(start.year, start.month, start.day, 23, 59, 59);
    }
    var end = DateTime(year, endMonth!, endDay!, 23, 59, 59);
    if (end.isBefore(start)) {
      // Ranges such as 28 Dec - 3 Jan cross a year boundary.
      end = DateTime(year + 1, endMonth!, endDay!, 23, 59, 59);
    }
    return end;
  }

  /// The occurrence that should be shown for [now]: the current one if it is
  /// ongoing, otherwise the next upcoming one. For past listings the caller
  /// uses [previousOccurrence].
  ({DateTime start, DateTime end, CampaignStatus status}) occurrence(DateTime now) {
    var start = startForYear(now.year);
    var end = endForYear(now.year);

    if (now.isAfter(end)) {
      start = startForYear(now.year + 1);
      end = endForYear(now.year + 1);
      return (start: start, end: end, status: CampaignStatus.upcoming);
    }
    if (now.isBefore(start)) {
      return (start: start, end: end, status: CampaignStatus.upcoming);
    }
    return (start: start, end: end, status: CampaignStatus.ongoing);
  }

  ({DateTime start, DateTime end, CampaignStatus status}) previousOccurrence(DateTime now) {
    var start = startForYear(now.year);
    var end = endForYear(now.year);
    if (now.isBefore(start)) {
      start = startForYear(now.year - 1);
      end = endForYear(now.year - 1);
    }
    return (start: start, end: end, status: CampaignStatus.past);
  }
}
