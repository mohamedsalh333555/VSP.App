import 'package:flutter/material.dart';

import '../../../../data/models.dart';

/// Keeps the last valid venue details visible through a refresh failure.
/// A cached or route-supplied venue is never enough to enable booking.
class StadiumSnapshotResolver {
  String? _venueId;
  Stadium? _lastValid;

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
