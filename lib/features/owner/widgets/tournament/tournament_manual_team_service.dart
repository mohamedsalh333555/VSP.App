import '../../../../core/repositories/team_repository.dart';
import '../../../../core/repositories/tournament_repository.dart';
import '../../../../data/models.dart';

/// Service coordinating creation and registration of manual offline teams for tournaments.
class TournamentManualTeamService {
  final TeamRepository? _teamRepo;
  final TournamentRepository? _tournamentRepo;

  TournamentManualTeamService({
    TeamRepository? teamRepo,
    TournamentRepository? tournamentRepo,
  })  : _teamRepo = teamRepo,
        _tournamentRepo = tournamentRepo;

  TeamRepository get _teamRepository => _teamRepo ?? TeamRepository();
  TournamentRepository get _tournamentRepository =>
      _tournamentRepo ?? TournamentRepository();

  Future<Championship> registerManualTeam({
    required Championship championship,
    required String teamName,
    required String currentUserId,
    required String primaryColor,
    required bool isPaid,
    required List<String> playerNames,
    required bool isArabic,
  }) async {
    final teamId = await _teamRepository.createTeam({
      'name': teamName,
      'captainName': isArabic ? 'تسجيل يدوي' : 'Manual Registration',
      'captainImageUrl': '',
      'logoUrl': '',
      'sportType': championship.sportType,
      'governorate': championship.governorate,
      'memberUids': [
        currentUserId.isNotEmpty
            ? currentUserId
            : '8d3d7d65-a167-4138-b36c-85bbdead1b7a'
      ],
      'date': 'Upcoming',
      'primary_color': primaryColor,
      'secondary_color': '#000000',
    });

    if (teamId == null) {
      throw Exception(isArabic ? 'فشل إنشاء الفريق' : 'Failed to create team');
    }

    await _tournamentRepository.joinChampionship(
      championship.id,
      teamId,
      skipMemberCheck: true,
      isPaid: isPaid,
    );

    await _tournamentRepository.insertChampionshipRoster(
      championshipId: championship.id,
      teamId: teamId,
      guestNames: playerNames,
    );

    return championship.copyWith(
      joinedTeams: [...championship.joinedTeams, teamId],
      paidTeams: isPaid
          ? [...championship.paidTeams, teamId]
          : championship.paidTeams,
    );
  }
}
