import '../../../../../core/repositories/tournament_repository.dart';
import '../../../../../data/models.dart';

/// Pure logic and submission coordinator for [CreateTournamentWizard].
class TournamentWizardCoordinator {
  const TournamentWizardCoordinator._();

  /// Validates inputs before allowing submission. Returns error message or null if valid.
  static String? validateSubmission({
    required String name,
    required String fee,
    required String prize,
    required DateTime startDate,
    required DateTime endDate,
    required String selectedTeams,
    required bool isAr,
  }) {
    if (name.trim().isEmpty) {
      return isAr ? 'يرجى إدخال اسم البطولة' : 'Please enter tournament name';
    }
    if (fee.trim().isEmpty) {
      return isAr
          ? 'يرجى إدخال رسوم الاشتراك في البطولة'
          : 'Please enter tournament entry fee';
    }
    if (prize.trim().isEmpty) {
      return isAr
          ? 'يرجى إدخال قيمة الجائزة الكبرى'
          : 'Please enter grand prize amount';
    }
    if (!endDate.isAfter(startDate)) {
      return isAr
          ? 'تاريخ الانتهاء يجب أن يكون بعد تاريخ البدء!'
          : 'End date must be strictly after start date!';
    }
    final maxTeamsNum = int.tryParse(selectedTeams) ?? 0;
    if (maxTeamsNum != 4 &&
        maxTeamsNum != 8 &&
        maxTeamsNum != 16 &&
        maxTeamsNum != 32) {
      return isAr
          ? 'عدد الفرق يجب أن يكون (4، 8، 16، 32) فقط!'
          : 'Number of teams must be a power of 2 (4, 8, 16, 32)!';
    }
    return null;
  }

  /// Builds standardized Championship schema payload from wizard state.
  static Map<String, dynamic> buildTournamentPayload({
    required String name,
    required String type,
    required String sportType,
    required DateTime startDate,
    required DateTime endDate,
    required String governorate,
    required String ownerId,
    required String selectedTeams,
    required String prize,
    required String fee,
    required int numberOfGroups,
    required int qualifyingPerGroup,
    required bool isTwoLegs,
    required String duration,
    Championship? existingTournament,
  }) {
    return {
      'name': name.trim(),
      'type': type,
      'sportType': sportType,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'governorate': governorate,
      'ownerId': ownerId,
      'image': existingTournament?.imageUrl ?? '',
      'teamsCount': int.parse(selectedTeams),
      'maxTeams': int.parse(selectedTeams),
      'grandPrize': double.tryParse(prize.trim()) ?? 0.0,
      'entryFee': double.tryParse(fee.trim()) ?? 0.0,
      'number_of_groups': numberOfGroups,
      'numberOfGroups': numberOfGroups,
      'qualifying_per_group': qualifyingPerGroup,
      'qualifyingPerGroup': qualifyingPerGroup,
      'is_two_legs': isTwoLegs,
      'isTwoLegs': isTwoLegs,
      'rules': existingTournament?.rules ?? '',
      'paymentMethods': existingTournament?.paymentMethods ?? ['cash'],
      'settings': {
        'maxPlayers': existingTournament?.maxPlayersPerTeam ?? 11,
        'minPlayers': existingTournament?.minPlayersPerTeam ?? 5,
        'winningPoints': existingTournament?.winningPoints ?? 3,
        'drawPoints': existingTournament?.drawPoints ?? 1,
        'lossPoints': existingTournament?.lossPoints ?? 0,
        'matchDuration': int.tryParse(duration.trim()) ?? 30,
        'isBackAndForth': existingTournament?.isBackAndForth ?? false,
        'trophyMedals': existingTournament?.trophyMedals ?? true,
        'redCardSuspension': existingTournament?.redCardSuspension ?? true,
        'fairPlayScoring': existingTournament?.fairPlayScoring ?? false,
      },
    };
  }

  /// Submits championship creation or update to the repository.
  static Future<({bool success, String? createdId, String? errorMessage})>
      submitTournament({
    required Map<String, dynamic> payload,
    required bool isEditing,
    String? tournamentId,
    TournamentRepository? repository,
  }) async {
    final repo = repository ?? TournamentRepository();
    try {
      if (isEditing) {
        if (tournamentId == null) {
          return (
            success: false,
            createdId: null,
            errorMessage: 'معرف البطولة غير موجود.',
          );
        }
        final success = await repo.updateChampionship(tournamentId, payload);
        return (
          success: success,
          createdId: null,
          errorMessage:
              success ? null : 'فشل تعديل البطولة. يرجى المحاولة مرة أخرى.',
        );
      } else {
        final id = await repo.createChampionship(payload);
        return (
          success: id != null,
          createdId: id,
          errorMessage: id != null
              ? null
              : 'فشل إنشاء البطولة. يرجى التحقق من دورك والاتصال بالإنترنت.',
        );
      }
    } catch (e) {
      return (success: false, createdId: null, errorMessage: e.toString());
    }
  }
}
