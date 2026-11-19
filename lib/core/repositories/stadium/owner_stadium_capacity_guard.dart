/// Fail-closed interpretation of the authoritative owner-capacity RPC.
///
/// This is a client pre-flight UX gate, NOT a substitute for database-side
/// enforcement. A direct REST insert can bypass it until Issue #41 is fixed.
final class OwnerStadiumCapacityGuard {
  const OwnerStadiumCapacityGuard._();

  static void requireAllowed(Object? raw) {
    if (raw is! Map) {
      throw StateError('STADIUM_CAPACITY_UNVERIFIED');
    }

    final allowed = raw['allowed'];
    if (allowed != true && allowed != false) {
      throw StateError('STADIUM_CAPACITY_UNVERIFIED');
    }

    if (allowed == false) {
      if (raw['error'] == 'UNAUTHORIZED') {
        throw StateError('STADIUM_OWNER_UNAUTHORIZED');
      }
      final maxAllowed = raw['max_allowed'];
      if (maxAllowed is num &&
          maxAllowed.isFinite &&
          maxAllowed > 0 &&
          maxAllowed == maxAllowed.toInt()) {
        throw StateError(
          'وصلت للحد الأقصى لعدد الملاعب في باقتك (${maxAllowed.toInt()} ملاعب).',
        );
      }
      throw StateError('STADIUM_CAPACITY_UNVERIFIED');
    }

    // A successful response must include a coherent capacity count, never
    // merely a truthy flag. Do not trust strings, null, negative or NaN.
    final max = raw['max_allowed'];
    final count = raw['current_count'];
    final isAdmin = raw['plan_code'] == 'admin';
    if (max is! num ||
        count is! num ||
        !max.isFinite ||
        !count.isFinite ||
        max <= 0 ||
        count < 0 ||
        max != max.toInt() ||
        count != count.toInt() ||
        (!isAdmin && count >= max)) {
      throw StateError('STADIUM_CAPACITY_UNVERIFIED');
    }
  }
}
