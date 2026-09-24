import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models.dart';
import '../../constants/egypt_governorates.dart';
import '../../services/logger_service.dart';

/// Coordinates querying, filtering, and real-time streaming of championships and matches.
class TournamentQueryCoordinator {
  final SupabaseClient? _client;

  TournamentQueryCoordinator({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Stream list of championships with REST fallback and realtime subscriptions.
  Stream<List<Championship>> getChampionshipsStream({
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) async* {
    try {
      final List<dynamic> response;
      if (isOwner && ownerId != null) {
        response = await _supabase
            .from('championships')
            .select()
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        response = await _supabase
            .from('championships')
            .select()
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(50);
      }
      yield parseChampionshipsList(
        response,
        governorate: governorate,
        sportType: sportType,
        isOwner: isOwner,
        ownerId: ownerId,
      );
    } catch (e, s) {
      VSPLogger.e('Error fetching initial championships via REST', e, s);
    }

    try {
      dynamic streamQuery =
          _supabase.from('championships').stream(primaryKey: ['id']);
      if (isOwner && ownerId != null) {
        streamQuery = streamQuery.eq('owner_id', ownerId);
      } else if (!isOwner) {
        streamQuery = streamQuery.eq('is_approved', true);
      }

      yield* streamQuery
          .timeout(
            const Duration(seconds: 10),
            onTimeout: (sink) {
              VSPLogger.w(
                'Championships realtime stream timed out. Relying on REST query.',
              );
            },
          )
          .map<List<Championship>>((list) {
            return parseChampionshipsList(
              list as List<Map<String, dynamic>>,
              governorate: governorate,
              sportType: sportType,
              isOwner: isOwner,
              ownerId: ownerId,
            );
          })
          .handleError((error) {
            VSPLogger.w(
              'Handled realtime stream error in getChampionshipsStream: $error',
            );
          });
    } catch (e, s) {
      VSPLogger.e('Error listening to championships stream', e, s);
    }
  }

  /// Fetch championships once via direct REST query.
  Future<List<Championship>> getChampionships({
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) async {
    try {
      final List<dynamic> response;
      if (isOwner && ownerId != null) {
        response = await _supabase
            .from('championships')
            .select()
            .eq('owner_id', ownerId)
            .order('created_at', ascending: false)
            .limit(50);
      } else {
        response = await _supabase
            .from('championships')
            .select()
            .eq('is_approved', true)
            .order('created_at', ascending: false)
            .limit(50);
      }
      return parseChampionshipsList(
        response,
        governorate: governorate,
        sportType: sportType,
        isOwner: isOwner,
        ownerId: ownerId,
      );
    } catch (e, s) {
      VSPLogger.e('Error fetching championships via REST', e, s);
      return [];
    }
  }

  /// Fetch single championship by ID.
  Future<Championship?> getChampionshipById(String id) async {
    try {
      final data = await _supabase
          .from('championships')
          .select()
          .eq('id', id)
          .maybeSingle();
      if (data == null) return null;
      return Championship.fromFirestore(data, data['id'].toString());
    } catch (e, s) {
      VSPLogger.e('Error fetching championship by id', e, s);
      return null;
    }
  }

  /// Parses raw championship JSON list into domain objects with client filtering.
  List<Championship> parseChampionshipsList(
    List<dynamic> list, {
    String? governorate,
    String? sportType,
    bool isOwner = false,
    String? ownerId,
  }) {
    return list
        .map((data) {
          if (data is! Map<String, dynamic>) return null;
          if (!isOwner) {
            final dynamic approvedVal =
                data['is_approved'] ?? data['isApproved'];
            if (approvedVal != true) return null;
          }
          if (isOwner && ownerId != null) {
            final String champOwnerId =
                (data['owner_id'] ?? data['ownerId'] ?? '').toString();
            if (champOwnerId != ownerId) return null;
          }
          if (governorate != null &&
              governorate.isNotEmpty &&
              governorate != 'All' &&
              governorate != 'الكل' &&
              governorate != 'الجميع') {
            final String champGov = data['governorate']?.toString() ?? '';
            if (champGov.isNotEmpty) {
              final stdGov1 =
                  EgyptGovernorates.resolveGoogleName(governorate) ??
                      governorate.trim().toLowerCase();
              final stdGov2 =
                  EgyptGovernorates.resolveGoogleName(champGov) ??
                      champGov.trim().toLowerCase();
              if (stdGov1 != stdGov2) return null;
            }
          }
          if (sportType != null &&
              sportType.isNotEmpty &&
              sportType != 'All' &&
              sportType != 'الكل' &&
              sportType != 'الجميع') {
            final String champSport =
                (data['sport_type'] ?? data['sportType'] ?? 'Football')
                    .toString();
            if (champSport.isNotEmpty &&
                champSport.toLowerCase() != sportType.toLowerCase()) {
              return null;
            }
          }
          try {
            return Championship.fromFirestore(data, data['id'].toString());
          } catch (e) {
            debugPrint('Error parsing championship: $e');
            return null;
          }
        })
        .whereType<Championship>()
        .toList();
  }

  /// Fetch joined teams for a championship by ID list in a single batch query.
  Future<List<Team>> getTeamsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];
    try {
      final response = await _supabase
          .from('teams')
          .select('*, team_members(user_id, users(profile_image_url))')
          .inFilter('id', ids);

      final List<Team> teams = [];
      for (final doc in (response as List)) {
        final teamId = doc['id'].toString();
        final membersList = doc['team_members'] as List? ?? [];
        final List<String> memberUids = [];
        final List<String> playerImages = [];

        for (var m in membersList) {
          final uid = m['user_id']?.toString();
          if (uid != null) memberUids.add(uid);
          final userMap = m['users'];
          if (userMap is Map && userMap['profile_image_url'] != null) {
            playerImages.add(userMap['profile_image_url'].toString());
          }
        }

        final data = Map<String, dynamic>.from(doc);
        data['memberUids'] = memberUids;
        data['playerImages'] = playerImages;
        data['playersCount'] = memberUids.length;

        teams.add(Team.fromFirestore(data, teamId));
      }
      return teams;
    } catch (e) {
      debugPrint('Error getting teams by IDs: $e');
      return [];
    }
  }

  /// Fetch tournament matches directly via REST query.
  Future<List<TournamentMatch>> getTournamentMatchesDirectly(
    String championshipId,
  ) async {
    try {
      final response = await _supabase
          .from('tournament_matches')
          .select()
          .eq('championship_id', championshipId);
      final matches = (response as List)
          .map(
            (data) => TournamentMatch.fromFirestore(
              data as Map<String, dynamic>,
              data['id'].toString(),
            ),
          )
          .toList();
      matches.sort((a, b) {
        if (a.roundIndex != b.roundIndex) {
          return b.roundIndex.compareTo(a.roundIndex);
        }
        return a.matchIndex.compareTo(b.matchIndex);
      });
      return matches;
    } catch (e) {
      debugPrint('Error fetching tournament matches directly: $e');
      return [];
    }
  }

  /// Stream tournament matches for a championship with initial REST and realtime updates.
  Stream<List<TournamentMatch>> getTournamentMatches(
    String championshipId,
  ) async* {
    final direct = await getTournamentMatchesDirectly(championshipId);
    if (direct.isNotEmpty) yield direct;

    yield* _supabase
        .from('tournament_matches')
        .stream(primaryKey: ['id'])
        .map((list) {
          final matches = list
              .map(
                (data) =>
                    TournamentMatch.fromFirestore(data, data['id'].toString()),
              )
              .where((m) => m.championshipId == championshipId)
              .toList();
          matches.sort((a, b) {
            if (a.roundIndex != b.roundIndex) {
              return b.roundIndex.compareTo(a.roundIndex);
            }
            return a.matchIndex.compareTo(b.matchIndex);
          });
          return matches;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getTournamentMatchesDirectly(championshipId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          debugPrint('Handled realtime error in getTournamentMatches: $error');
        });
  }

  /// Stream a single championship with timeout fallback.
  Stream<Championship?> getSingleChampionshipStream(
    String championshipId,
  ) async* {
    try {
      final direct = await getChampionshipById(championshipId);
      if (direct != null) yield direct;
    } catch (_) {}

    yield* _supabase
        .from('championships')
        .stream(primaryKey: ['id'])
        .eq('id', championshipId)
        .map((list) {
          if (list.isEmpty) return null;
          try {
            return Championship.fromFirestore(list.first, championshipId);
          } catch (e) {
            debugPrint('Error parsing realtime championship stream: $e');
            return null;
          }
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final refreshed = await getChampionshipById(championshipId);
            sink.add(refreshed);
          },
        )
        .handleError((error) {
          debugPrint(
            'Handled realtime error in getSingleChampionshipStream: $error',
          );
        });
  }

  /// Stream raw championship JSON updates.
  Stream<List<Map<String, dynamic>>> streamChampionshipRaw(
    String championshipId,
  ) {
    return _supabase
        .from('championships')
        .stream(primaryKey: ['id'])
        .eq('id', championshipId)
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) => sink.add([]),
        )
        .handleError((e) {
          VSPLogger.w('Handled realtime error in championship stream: $e');
        });
  }
}
