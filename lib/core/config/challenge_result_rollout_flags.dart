/// Explicit compile-time gate. OFF in normal builds.
/// Only enable after staging has deployed and verified every server candidate
/// (independent votes, owner reporting, appeals and protected public feeds).
abstract final class ChallengeResultRolloutFlags {
  static const bool nonPlayedReportsEnabled = bool.fromEnvironment(
    'VSP_ENABLE_NON_PLAYED_MATCH_REPORTS',
    defaultValue: false,
  );
}
