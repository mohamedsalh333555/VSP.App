import 'package:flutter/material.dart';

import '../../../../data/models.dart';

/// Keeps the last valid venue details visible through a refresh failure.
/// A cached or route-supplied venue is never enough to enable booking.
class StadiumSnapshotResolver {
  String? _venueId;
  Stadium? _lastValid;

  /// Mixed SQL/legacy aliases must agree before a live venue can be booked.
  /// Otherwise model fallback precedence could silently trust a stale price,
  /// deposit requirement or moderation flag.
  static bool _hasConflictingBookingAliases(Map<String, dynamic> row) {
    for (final keys in const [
      ['price_per_hour', 'pricePerHour'],
      ['base_price', 'basePrice'],
      ['deposit_amount', 'depositAmount'],
    ]) {
      if (!row.containsKey(keys[0]) || !row.containsKey(keys[1])) continue;
      final rawA = row[keys[0]];
      final rawB = row[keys[1]];
      final a = rawA is num ? rawA : num.tryParse(rawA?.toString() ?? '');
      final b = rawB is num ? rawB : num.tryParse(rawB?.toString() ?? '');
      if (a == null || b == null || !a.isFinite || !b.isFinite ||
          a != b) return true;
    }

    for (final keys in const [
      ['is_verified', 'isVerified'],
      ['is_blocked', 'isBlocked'],
      ['needs_deposit', 'needsDeposit'],
    ]) {
      if (!row.containsKey(keys[0]) || !row.containsKey(keys[1])) continue;
      final a = row[keys[0]];
      final b = row[keys[1]];
      if (a is! bool || b is! bool || a != b) return true;
    }
    return false;
  }

  StadiumSnapshotResolution resolve({
    required Stadium routeStadium,
    required AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  }) {
    if (_venueId != routeStadium.id) {
      _venueId = routeStadium.id;
      _lastValid = null;
    }

    var stadium = _lastValid ?? routeStadium;
    var parseFailed = false;
    final hasRow = snapshot.hasData && snapshot.data!.length == 1;
    // A primary-key filtered venue feed must contain exactly one source row.
    // Duplicates are ambiguous: never select rows.first and allow booking.
    if (snapshot.connectionState == ConnectionState.active &&
        !snapshot.hasError && hasRow) {
      try {
        final row = snapshot.data!.first;
        if (row['id']?.toString() != routeStadium.id) {
          throw const FormatException('Venue identity mismatch');
        }
        if (_hasConflictingBookingAliases(row)) {
          throw const FormatException('Conflicting live booking fields');
        }
        stadium = Stadium.fromFirestore(row, routeStadium.id);
        _lastValid = stadium;
      } catch (_) {
        parseFailed = true;
      }
    }

    final priceIsValid = stadium.basePrice.isFinite &&
        stadium.basePrice > 0 && stadium.pricePerHour.isFinite &&
        stadium.pricePerHour > 0;
    final depositIsValid = stadium.depositAmount.isFinite &&
        stadium.depositAmount >= 0 &&
        (!stadium.needsDeposit || stadium.depositAmount > 0);

    return StadiumSnapshotResolution(
      stadium: stadium,
      parseFailed: parseFailed || (snapshot.hasData && snapshot.data!.length > 1),
      canBook: snapshot.connectionState == ConnectionState.active &&
          !snapshot.hasError && !parseFailed && hasRow &&
          stadium.isVerified && !stadium.isBlocked &&
          !stadium.isUnderMaintenance &&
          priceIsValid && depositIsValid,
    );
  }
}

class StadiumSnapshotResolution {
  final Stadium stadium;
  final bool parseFailed;
  final bool canBook;

  const StadiumSnapshotResolution({
    required this.stadium,
    required this.parseFailed,
    required this.canBook,
  });
}
