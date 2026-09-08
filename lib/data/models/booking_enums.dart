/// Booking Status Enum
enum BookingStatus {
  pending, // Draft state before payment
  confirmed, // After successful payment, before match starts
  upcoming, // Same as confirmed (alias)
  completed, // After match time has passed
  cancelled, // User/owner cancelled
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
}
