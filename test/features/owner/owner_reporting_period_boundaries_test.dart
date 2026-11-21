import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/utils/owner_financial_calculator.dart';
import 'package:vsp_application/data/models.dart';
import 'package:vsp_application/models/dashboard_filter.dart';

Booking booking(
  String id,
  DateTime operationalDay, {
  String venue = 'pitch-a',
  BookingStatus status = BookingStatus.confirmed,
  double price = 200,
}) => Booking(
  id: id,
  ownerId: 'owner-1',
  stadiumId: venue,
  stadiumName: 'Fixture Pitch',
  startTime: DateTime(operationalDay.year, operationalDay.month,
      operationalDay.day, 18),
  endTime: DateTime(operationalDay.year, operationalDay.month,
      operationalDay.day, 19),
  operationalDate: operationalDay,
  bookingType: BookingType.personal,
  isPrivate: true,
  rentBall: false,
  totalPrice: price,
  paymentMethod: 'cash',
  status: status,
  createdByUserId: 'player-1',
  createdAt: DateTime(2026, 11, 1),
);

OwnerFinancialMetrics report(
  List<Booking> all, {
  String timePeriod = 'custom',
  String stadiumFilter = 'all',
  DashboardFilter? periodFilter,
  DateTime? referenceNow,
}) => OwnerFinancialCalculator.calculate(
  allBookings: all,
  ownerChampionships: const [],
  timePeriod: timePeriod,
  stadiumFilter: stadiumFilter,
  periodFilter: periodFilter,
  referenceNow: referenceNow,
);

void main() {
  final d2 = DateTime(2026, 11, 2);
  final d3 = DateTime(2026, 11, 3);
  final d4 = DateTime(2026, 11, 4);
  final d5 = DateTime(2026, 11, 5);
  final rows = [
    booking('before', d2),
    booking('first', d3),
    booking('last', d4),
    booking('after', d5),
    booking('other-pitch', d3, venue: 'pitch-b'),
    booking('cancelled', d4, status: BookingStatus.cancelled),
  ];

  test('custom range includes both chosen dates, excludes adjacent days', () {
    final filter = DashboardFilter.custom(d3, d4);
    final summary = report(rows, periodFilter: filter, stadiumFilter: 'pitch-a');
    expect(summary.periodBookings.map((b) => b.id), ['first', 'last']);
    expect(summary.activeBookingsCount, 2);
    expect(summary.totalPipeline, 400);
    expect(summary.totalHours, 2);
  });

  test('unbounded custom range is empty, never all-time by accident', () {
    final summary = report(rows);
    expect(summary.periodBookings, isEmpty);
    expect(summary.totalPipeline, 0);
    expect(summary.activeBookingsCount, 0);
  });

  test('switching the court filter to all actually includes every venue', () {
    final selected = DashboardFilter.custom(d3, d4).copyWith(courtId: 'pitch-a');
    expect(selected.courtId, 'pitch-a');
    expect(report(rows, periodFilter: selected, stadiumFilter: 'pitch-a')
        .activeBookingsCount, 2);
    final cleared = selected.copyWith(clearCourtId: true);
    expect(cleared.courtId, isNull);
    expect(cleared.type, selected.type);
    expect(cleared.startDate, selected.startDate);
    expect(cleared.endDate, selected.endDate);
    expect(report(rows, periodFilter: cleared).activeBookingsCount, 3);
    expect(cleared.copyWith().courtId, isNull);
    expect(selected.copyWith().courtId, 'pitch-a');
  });

  test('calendar-year and week/month aliases are filtered, not all-time', () {
    final sample = [
      booking('2025', DateTime(2025, 12, 31)),
      booking('2026-jan', DateTime(2026, 1, 1)),
      booking('2026-nov', DateTime(2026, 11, 18)),
      booking('2027', DateTime(2027, 1, 1)),
    ];
    final now = DateTime(2026, 11, 18, 12);
    for (final key in ['year', 'thisYear']) {
      expect(report(sample, timePeriod: key, referenceNow: now)
          .periodBookings.map((b) => b.id), ['2026-jan', '2026-nov']);
    }
    for (final key in ['month', 'thisMonth', 'week', 'thisWeek']) {
      expect(report(sample, timePeriod: key, referenceNow: now)
          .periodBookings.map((b) => b.id), ['2026-nov']);
    }
  });

  test('operational date stays a civil day even if serialized as UTC', () {
    final serialized = DateTime.utc(2026, 11, 4);
    final summary = report([
      booking('utc-civil', serialized),
    ], periodFilter: DashboardFilter.custom(d4, d4));
    expect(summary.activeBookingsCount, 1);
    expect(summary.periodBookings.single.id, 'utc-civil');
  });

  test('no financial cache reuse when a booking changes venue or period', () {
    final source = File('lib/features/owner/screens/owner_dashboard_screen.dart')
        .readAsStringSync();
    expect(source, contains('periodFilter: _currentFilter,'));
    expect(source, contains('clearCourtId: id == \'all\''));
    expect(source, contains('b.operationalDate?.toIso8601String()'));
    expect(source, contains('b.startTime.toUtc().toIso8601String()'));
    expect(source, contains('b.stadiumId'));
    expect(source, contains('b.paymentReconcileState'));
    expect(source, contains('_currentFilter.startIsoUtc'));
  });

  test('civil day windows survive Cairo daylight-saving clock jumps', () {
    final source = File('lib/models/dashboard_filter.dart').readAsStringSync();
    expect(source, contains('DateTime(start.year, start.month, start.day + 1)'));
    expect(source, contains('DateTime(end.year, end.month, end.day + 1)'));
    expect(source, isNot(contains('start.add(const Duration(days: 1))')));
  });
}
