import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'lib/features/player/screens/challenge_select_team_screen.dart',
  ).readAsStringSync();

  test('account switch clears private opponent, code and team state', () {
    final from = source.indexOf('void didChangeDependencies()');
    final to = source.indexOf('Future<void> _loadUserTeam(', from);
    final scope = source.substring(from, to);
    for (final safeguard in <String>[
      'userId != _activeUserId',
      '++_opponentRequestGeneration;',
      '_selectedTeam = null;',
      '_userTeam = null;',
      '_appliedChallengeCode = null;',
      '_challengeCodeController.clear();',
      '_championStatusMap.clear();',
    ]) {
      expect(scope, contains(safeguard));
    }
  });

  test('challenge lookup ignores late responses, failures or stale accounts', () {
    final from = source.indexOf('Future<void> _handleLookupCode()');
    final to = source.indexOf('void _clearSelectedOpponent()', from);
    final scope = source.substring(from, to);
    expect(scope, contains('final lookupUserId ='));
    expect('currentUser?.id != lookupUserId'.allMatches(scope).length,
        greaterThanOrEqualTo(3));
    expect(scope, contains('opponentGeneration == _opponentRequestGeneration'));
    expect(scope, contains('_challengeCodeController.text.trim().toUpperCase()'));
  });

  test('captain code is never displayed after account or team changes', () {
    final from = source.indexOf('Future<void> _showMyChallengeCodeModal()');
    final to = source.indexOf('void _displayChallengeCodeBottomSheet(', from);
    final scope = source.substring(from, to);
    expect(scope, contains('final initiatingTeamId ='));
    expect(scope, contains('final initiatingUserId ='));
    expect(scope, contains('generateChallengeCode(initiatingTeamId)'));
    expect(scope, contains('currentUser?.id != initiatingUserId'));
    expect(scope, contains('_userTeam?.id != initiatingTeamId'));
    expect(scope, contains('_displayChallengeCodeBottomSheet(code);'));
  });
}
