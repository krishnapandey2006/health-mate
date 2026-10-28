import 'package:flutter_test/flutter_test.dart';
import 'package:healthmate_mb/models/health_campaign.dart';

void main() {
  const campaign = HealthCampaign(
    id: 'world-health-day',
    title: 'World Health Day',
    organizer: 'World Health Organization',
    sourceName: 'WHO',
    sourceUrl: 'https://www.who.int/campaigns/world-health-day',
    description: 'Global health awareness day.',
    category: 'public_health',
    startMonth: 4,
    startDay: 7,
  );

  test('single-day observance is upcoming before the date', () {
    final view = campaign.occurrence(DateTime(2026, 4, 6, 12));
    expect(view.status, CampaignStatus.upcoming);
    expect(view.start, DateTime(2026, 4, 7));
  });

  test('single-day observance is ongoing on the date', () {
    final view = campaign.occurrence(DateTime(2026, 4, 7, 12));
    expect(view.status, CampaignStatus.ongoing);
    expect(view.start, DateTime(2026, 4, 7));
  });

  test('observance rolls forward to next year after the date', () {
    final view = campaign.occurrence(DateTime(2026, 4, 8, 12));
    expect(view.status, CampaignStatus.upcoming);
    expect(view.start, DateTime(2027, 4, 7));
  });

  test('previous occurrence rolls back before the date', () {
    final view = campaign.previousOccurrence(DateTime(2026, 1, 1));
    expect(view.status, CampaignStatus.past);
    expect(view.start, DateTime(2025, 4, 7));
  });

  test('multi-day observance crossing a year boundary is handled', () {
    const yearEnd = HealthCampaign(
      id: 'year-end',
      title: 'Year-end observance',
      organizer: 'WHO',
      sourceName: 'WHO',
      sourceUrl: 'https://www.who.int/',
      description: 'A range that crosses the new year.',
      category: 'public_health',
      startMonth: 12,
      startDay: 28,
      endMonth: 1,
      endDay: 3,
    );

    final ongoing = yearEnd.occurrence(DateTime(2026, 12, 31, 12));
    expect(ongoing.status, CampaignStatus.ongoing);
    expect(ongoing.end, DateTime(2027, 1, 3, 23, 59, 59));

    final after = yearEnd.occurrence(DateTime(2027, 1, 4, 12));
    expect(after.status, CampaignStatus.upcoming);
    expect(after.start, DateTime(2027, 12, 28));
  });
}
