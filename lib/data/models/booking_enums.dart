/// Booking Status Enum
enum BookingStatus {
  pending, // Draft state before payment
  confirmed, // After successful payment, before match starts
  upcoming, // Same as confirmed (alias)
  completed, // After match time has passed
  noShow, // Match ended and player/participant was recorded absent
  cancelled, // User/owner cancelled
  expired, // Payment lock window elapsed without payment
}

extension BookingStatusExtension on BookingStatus {
  /// Canonical lifecycle state used for comparison and idempotency checks.
  BookingStatus get canonical =>
      this == BookingStatus.upcoming ? BookingStatus.confirmed : this;

  /// Client-side transition contract. Server-side authorization, payment
  /// reconciliation and cancellation cutoffs must be enforced separately.
  bool canTransitionTo(BookingStatus next) {
    final from = canonical;
    final to = next.canonical;
    if (from == to) return true; // Idempotent replay, not a new event.
    switch (from) {
      case BookingStatus.pending:
        return to == BookingStatus.confirmed ||
            to == BookingStatus.cancelled ||
            to == BookingStatus.expired;
      case BookingStatus.confirmed:
        return to == BookingStatus.completed ||
            to == BookingStatus.noShow ||
            to == BookingStatus.cancelled;
      case BookingStatus.completed:
      case BookingStatus.noShow:
      case BookingStatus.cancelled:
      case BookingStatus.expired:
        return false;
      case BookingStatus.upcoming:
        return false; // Normalized by canonical above.
    }
  }

  /// Ensures 'upcoming' is serialized as 'confirmed' to PostgreSQL.
  String toDbValue() {
    if (this == BookingStatus.upcoming) {
      return 'confirmed';
    }
    return name;
  }
}

enum MatchResultStatus { noResult, waitingOpponent, confirmed, disputed }

enum MatchOutcome { homeWin, draw, awayWin }

enum MatchResultChoice { weWon, draw, weLost }

/// Booking Type Enum
enum BookingType {
  personal, // Solo/Standard booking (حجز عادي)
  openJoin, // Open gathering match (حجز انضمام وتجميع)
  challenge, // Team challenge match (حجز تحدي فرق)
  team, // Legacy alias for challenge
  matchup, // Matchups mode: Duo or Winner Stays (مواجهات)
  maintenance, // Owner-blocked time for maintenance; not a player booking
}

/// مصدر وسيلة الدفع الموحد للتطبيق
enum PaymentSource {
  cash, // دفع نقدي مباشر بالملعب
  paymob, // دفع رقمي عبر Paymob (بطاقة / محفظة)
  instapay, // تحويل بنكي فوري
  vodafoneCash, // محفظة فودافون كاش
  bankTransfer, // تحويل بنكي
  unknown,
}

extension PaymentSourceExtension on PaymentSource {
  bool get isCash => this == PaymentSource.cash;
  bool get isDigital =>
      this != PaymentSource.cash && this != PaymentSource.unknown;
  bool get isUnknown => this == PaymentSource.unknown;
}
