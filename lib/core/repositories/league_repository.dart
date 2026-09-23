import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';
import '../constants/egypt_governorates.dart';

class LeagueRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  LeagueRepository();

  /// Stream of active 1v1 tournament (registration_open, in_progress, completed, published)
  Stream<Map<String, dynamic>?> getActive1v1TournamentStream({String? governorate}) {
    late StreamController<Map<String, dynamic>?> controller;
    RealtimeChannel? tournamentChannel;

    Future<void> fetchAndEmit() async {
      try {
        var query = _supabase
            .from('vsp_1v1_tournaments')
            .select()
            .inFilter('status', ['registration_open', 'in_progress', 'completed', 'published']);

        if (governorate != null && governorate.isNotEmpty && governorate != 'All') {
          final stdGov = EgyptGovernorates.resolveGoogleName(governorate) ?? governorate;
          final arGov = EgyptGovernorates.governorateToArabic[stdGov] ?? stdGov;
          query = query.or('governorate.eq.$stdGov,governorate.eq.$arGov');
        }

        final response = await query
            .order('created_at', ascending: false)
            .limit(1);

        final list = response as List<dynamic>;
        if (list.isNotEmpty) {
          if (!controller.isClosed) controller.add(list.first as Map<String, dynamic>);
        } else {
          if (!controller.isClosed) controller.add(null);
        }
      } catch (e) {
        debugPrint('Error fetching active 1v1 tournament: $e');
        if (!controller.isClosed) controller.add(null);
      }
    }

    controller = StreamController<Map<String, dynamic>?>.broadcast(
      onListen: () {
        fetchAndEmit();
        final tag = DateTime.now().millisecondsSinceEpoch;
        final channelGovTag = (governorate != null && governorate.isNotEmpty) ? governorate.replaceAll(' ', '_') : 'all';
        tournamentChannel = _supabase
            .channel('realtime_1v1_tourney_${channelGovTag}_$tag')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vsp_1v1_tournaments',
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
      },
      onCancel: () {
        tournamentChannel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Stream of players registered in a specific 1v1 tournament (strictly paid players)
  Stream<List<Map<String, dynamic>>> getTournamentPlayersStream(String tournamentId, {bool isCompleted = false}) {
    late StreamController<List<Map<String, dynamic>>> controller;
    RealtimeChannel? playersChannel;

    Future<void> fetchAndEmit() async {
      try {
        final List<dynamic> response = isCompleted
            ? await _supabase
                .from('vsp_1v1_tournament_players')
                .select('*')
                .eq('tournament_id', tournamentId)
                .eq('payment_status', 'paid')
                .order('total_points', ascending: false)
            : await _supabase
                .from('vsp_1v1_tournament_players')
                .select('*')
                .eq('tournament_id', tournamentId)
                .eq('payment_status', 'paid')
                .order('registered_at', ascending: true);

        final list = List<Map<String, dynamic>>.from(response);
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        debugPrint('Error fetching 1v1 tournament players: $e');
        if (!controller.isClosed) controller.add([]);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>.broadcast(
      onListen: () {
        fetchAndEmit();
        final tag = DateTime.now().millisecondsSinceEpoch;
        playersChannel = _supabase
            .channel('realtime_1v1_tplayers_${tournamentId}_$tag')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vsp_1v1_tournament_players',
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
      },
      onCancel: () {
        playersChannel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  /// Create pending 1v1 tournament payment order atomically
  Future<Map<String, dynamic>> create1v1PaymentOrder(String tournamentId) async {
    try {
      final response = await _supabase.rpc(
        'create_1v1_payment_order_atomic',
        params: {'p_tournament_id': tournamentId},
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': false, 'error': 'استجابة غير متوقعة من الخادم'};
    } catch (e) {
      debugPrint('Error in create1v1PaymentOrder: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Instant atomic mobile registration for 1v1 tournament
  Future<Map<String, dynamic>> join1v1Tournament(String tournamentId) async {
    try {
      final response = await _supabase.rpc(
        'join_1v1_tournament_atomic',
        params: {'p_tournament_id': tournamentId},
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error in join1v1Tournament: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Atomic leave for 1v1 tournament
  Future<Map<String, dynamic>> leave1v1Tournament(String tournamentId) async {
    try {
      final response = await _supabase.rpc(
        'leave_1v1_tournament_atomic',
        params: {'p_tournament_id': tournamentId},
      );

      if (response is Map) {
        return Map<String, dynamic>.from(response);
      }
      return {'success': true};
    } catch (e) {
      debugPrint('Error in leave1v1Tournament: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Check if user is registered and paid in tournament
  Future<bool> isUserRegisteredIn1v1(String tournamentId, String userId) async {
    try {
      final response = await _supabase
          .from('vsp_1v1_tournament_players')
          .select('id')
          .eq('tournament_id', tournamentId)
          .eq('user_id', userId)
          .eq('payment_status', 'paid')
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Error checking user 1v1 registration: $e');
      return false;
    }
  }

  /// Stream of 1v1 Standings for completed tournament (Podium and Full Table)
  Stream<List<VSP1v1Player>> get1v1Standings({String? governorate, String? tournamentId}) {
    late StreamController<List<VSP1v1Player>> controller;
    RealtimeChannel? tournamentChannel;
    RealtimeChannel? playersChannel;

    Future<void> fetchAndEmit() async {
      try {
        dynamic tournament;
        if (tournamentId != null && tournamentId.isNotEmpty) {
          tournament = await _supabase
              .from('vsp_1v1_tournaments')
              .select()
              .eq('id', tournamentId)
              .maybeSingle();
        } else {
          var query = _supabase
              .from('vsp_1v1_tournaments')
              .select()
              .inFilter('status', ['completed', 'published']);

          if (governorate != null && governorate.isNotEmpty && governorate != 'All') {
            final stdGov = EgyptGovernorates.resolveGoogleName(governorate) ?? governorate;
            final arGov = EgyptGovernorates.governorateToArabic[stdGov] ?? stdGov;
            query = query.or('governorate.eq.$stdGov,governorate.eq.$arGov');
          }

          tournament = await query
              .order('published_at', ascending: false)
              .limit(1)
              .maybeSingle();
        }

        if (tournament == null) {
          final globalResponse = await _supabase
              .from('vsp_1vs1_players')
              .select('*')
              .order('total_points', ascending: false)
              .limit(50);
          final globalList = globalResponse as List<dynamic>;
          if (globalList.isNotEmpty) {
            final List<VSP1v1Player> players = [];
            for (int i = 0; i < globalList.length; i++) {
              final data = globalList[i];
              final tackles = (data['tackles'] ?? 0) as int;
              final goals = (data['goals'] ?? 0) as int;
              final skills = (data['skill_points'] ?? data['skills'] ?? 0) as int;
              final total = (data['total_points'] ?? (tackles + goals + skills)) as int;
              players.add(VSP1v1Player(
                id: data['id'].toString(),
                name: data['name'] ?? data['player_name'] ?? 'لاعب',
                avatarUrl: data['avatar_url'] ?? '',
                totalPoints: total,
                skillPoints: skills,
                goals: goals,
                tackles: tackles,
                titles: (data['titles'] ?? (i == 0 ? 1 : 0)) as int,
                rank: i + 1,
                trend: data['trend'] ?? (i == 0 ? 'up' : 'stable'),
                roundReached: data['round_reached']?.toString(),
              ));
            }
            if (!controller.isClosed) controller.add(players);
            return;
          }
          if (!controller.isClosed) controller.add([]);
          return;
        }

        final response = await _supabase
            .from('vsp_1v1_tournament_players')
            .select('*')
            .eq('tournament_id', tournament['id'])
            .order('total_points', ascending: false);

        final rawList = response as List<dynamic>;
        final List<VSP1v1Player> players = [];
        for (int i = 0; i < rawList.length; i++) {
          final data = rawList[i];
          final tackles = (data['tackles'] ?? 0) as int;
          final goals = (data['goals'] ?? 0) as int;
          final skills = (data['skills'] ?? data['skill_points'] ?? 0) as int;
          final totalPoints = (data['total_points'] ?? (tackles + goals + skills)) as int;
          final isChampion = data['round_reached']?.toString().toLowerCase() == 'champion';
          players.add(VSP1v1Player(
            id: data['id'].toString(),
            name: data['player_name'] ?? data['name'] ?? 'لاعب',
            avatarUrl: data['avatar_url'] ?? '',
            totalPoints: totalPoints,
            skillPoints: skills,
            goals: goals,
            tackles: tackles,
            titles: (data['titles'] != null) ? (data['titles'] as int) : (isChampion ? 1 : 0),
            rank: i + 1,
            trend: isChampion ? 'up' : (data['trend'] ?? 'stable'),
            roundReached: data['round_reached']?.toString(),
          ));
        }

        if (!controller.isClosed) controller.add(players);
      } catch (e) {
        debugPrint('Error fetching 1v1 standings: $e');
        if (!controller.isClosed) controller.add([]);
      }
    }

    controller = StreamController<List<VSP1v1Player>>.broadcast(
      onListen: () {
        fetchAndEmit();

        final tag = DateTime.now().millisecondsSinceEpoch;
        tournamentChannel = _supabase
            .channel('realtime_1v1_tournaments_$tag')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vsp_1v1_tournaments',
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();

        playersChannel = _supabase
            .channel('realtime_1v1_players_$tag')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vsp_1v1_tournament_players',
              callback: (_) => fetchAndEmit(),
            )
            .subscribe();
      },
      onCancel: () {
        tournamentChannel?.unsubscribe();
        playersChannel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

  // ==================== LEGACY COMPATIBILITY METHODS ====================

  Future<int> get1v1RegistrationsCount() async {
    try {
      final response = await _supabase
          .from('vsp_1v1_registrations')
          .select('id')
          .inFilter('status', ['pending', 'approved']);
      return (response as List).length;
    } catch (e) {
      debugPrint('Error getting 1v1 registrations count: $e');
      return 0;
    }
  }

  Future<bool> hasUserRegistered1v1(String userId) async {
    try {
      final response = await _supabase
          .from('vsp_1v1_registrations')
          .select('id')
          .eq('user_id', userId)
          .inFilter('status', ['pending', 'approved'])
          .maybeSingle();
      return response != null;
    } catch (e) {
      debugPrint('Error checking user 1v1 registration: $e');
      return false;
    }
  }

  Future<bool> registerFor1v1(String userId) async {
    try {
      final currentCount = await get1v1RegistrationsCount();
      if (currentCount >= 32) {
        throw Exception('roster_full_32');
      }

      await _supabase.from('vsp_1v1_registrations').insert({
        'user_id': userId,
        'status': 'pending',
      });
      return true;
    } catch (e) {
      debugPrint('Error registering for 1v1: $e');
      rethrow;
    }
  }

  Stream<int> stream1v1RegistrationsCount() async* {
    yield await get1v1RegistrationsCount();
    yield* _supabase
        .from('vsp_1v1_registrations')
        .stream(primaryKey: ['id'])
        .map((list) {
          return list.where((item) {
            final status = item['status'];
            return status == 'pending' || status == 'approved';
          }).length;
        })
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final freshCount = await get1v1RegistrationsCount();
            sink.add(freshCount);
          },
        )
        .handleError((error) {
          debugPrint('Handled realtime error in stream1v1RegistrationsCount: $error');
        });
  }
}
