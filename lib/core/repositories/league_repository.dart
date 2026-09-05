import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models.dart';

class LeagueRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  LeagueRepository();

  Stream<List<VSP1v1Player>> get1v1Standings() {
    late StreamController<List<VSP1v1Player>> controller;
    RealtimeChannel? tournamentChannel;
    RealtimeChannel? playersChannel;

    Future<void> fetchAndEmit() async {
      try {
        final tournament = await _supabase
            .from('vsp_1v1_tournaments')
            .select()
            .eq('status', 'published')
            .maybeSingle();

        if (tournament == null) {
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
          players.add(VSP1v1Player(
            id: data['id'].toString(),
            name: data['player_name'] ?? 'لاعب',
            avatarUrl: data['avatar_url'] ?? '',
            totalPoints: (data['total_points'] ?? 0) as int,
            skillPoints: (data['skills'] ?? 0) as int,
            goals: (data['goals'] ?? 0) as int,
            tackles: (data['tackles'] ?? 0) as int,
            titles: i == 0 ? 1 : 0,
            rank: i + 1,
            trend: i == 0 ? 'up' : 'stable',
          ));
        }

        if (!controller.isClosed) controller.add(players);
      } catch (e) {
        debugPrint('Error fetching 1v1 standings: $e');
        if (!controller.isClosed) controller.add([]);
      }
    }

    // ignore: close_sinks
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
              callback: (payload) {
                fetchAndEmit();
              },
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.timedOut) {
                debugPrint('1v1 tournaments channel timed out: $error');
                fetchAndEmit();
              }
            });

        playersChannel = _supabase
            .channel('realtime_1v1_players_$tag')
            .onPostgresChanges(
              event: PostgresChangeEvent.all,
              schema: 'public',
              table: 'vsp_1v1_tournament_players',
              callback: (payload) {
                fetchAndEmit();
              },
            )
            .subscribe((status, [error]) {
              if (status == RealtimeSubscribeStatus.timedOut) {
                debugPrint('1v1 players channel timed out: $error');
                fetchAndEmit();
              }
            });
      },
      onCancel: () {
        tournamentChannel?.unsubscribe();
        playersChannel?.unsubscribe();
        controller.close();
      },
    );

    return controller.stream;
  }

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
    // 1. Immediate REST count
    yield await get1v1RegistrationsCount();

    // 2. Realtime with safety timeout & error recovery
    yield* _supabase
        .from('vsp_1v1_registrations')
        .stream(primaryKey: ['id'])
        .timeout(
          const Duration(seconds: 10),
          onTimeout: (sink) async {
            final freshCount = await get1v1RegistrationsCount();
            sink.add(freshCount);
          },
        )
        .map((list) {
          return list.where((item) {
            final status = item['status'];
            return status == 'pending' || status == 'approved';
          }).length;
        })
        .handleError((error) {
          debugPrint('Handled realtime error in stream1v1RegistrationsCount: $error');
        });
  }
}
