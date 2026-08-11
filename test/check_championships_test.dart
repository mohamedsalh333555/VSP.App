import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('Check championships and owner/player visibility', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Supabase.initialize(
      url: 'https://mktqkddbcddrxjxabdua.supabase.co',
      anonKey: 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE',
      authOptions: FlutterAuthClientOptions(
        localStorage: const EmptyLocalStorage(),
      ),
    );

    final client = Supabase.instance.client;

    // 1. Get all championships
    print('\n========== ALL CHAMPIONSHIPS ==========');
    try {
      final championships = await client.from('championships').select();
      if ((championships as List).isEmpty) {
        print('❌ NO CHAMPIONSHIPS FOUND IN DB');
      } else {
        for (final c in championships) {
          print('---');
          print('🏆 ID: ${c['id']}');
          print('   Name: ${c['name']}');
          print('   Type: ${c['type']}');
          print('   Sport: ${c['sport_type']}');
          print('   Status: ${c['status']}');
          print('   is_approved: ${c['is_approved']}');
          print('   owner_id: ${c['owner_id']}');
          print('   governorate: ${c['governorate']}');
          print('   start_date: ${c['start_date']}');
          print('   end_date: ${c['end_date']}');
          print('   max_teams: ${c['max_teams']}');
          print('   joined_teams: ${c['joined_teams']}');
          print('   entry_fee: ${c['entry_fee']}');
          print('   grand_prize: ${c['grand_prize']}');

          // 2. Find owner info for this championship
          final ownerId = c['owner_id']?.toString() ?? '';
          if (ownerId.isNotEmpty) {
            try {
              final owner = await client
                  .from('users')
                  .select('id, name, email, role')
                  .eq('id', ownerId)
                  .maybeSingle();
              if (owner != null) {
                print('   👤 Owner Name: ${owner['name']}');
                print('   👤 Owner Email: ${owner['email']}');
                print('   👤 Owner Role: ${owner['role']}');
              } else {
                print('   ⚠️ Owner user not found in users table');
              }
            } catch (e) {
              print('   ⚠️ Error fetching owner: $e');
            }
          }

          // 3. Find stadium linked to this owner
          if (ownerId.isNotEmpty) {
            try {
              final stadiums = await client
                  .from('stadiums')
                  .select('id, name, sport_type, is_verified, is_deleted_by_owner')
                  .eq('owner_id', ownerId);
              if ((stadiums as List).isNotEmpty) {
                for (final s in stadiums) {
                  print('   🏟️ Stadium: ${s['name']} | Sport: ${s['sport_type']} | Verified: ${s['is_verified']} | Deleted: ${s['is_deleted_by_owner']}');
                }
              } else {
                print('   ⚠️ No stadiums found for this owner');
              }
            } catch (e) {
              print('   ⚠️ Error fetching stadiums: $e');
            }
          }
        }
      }
    } catch (e) {
      print('ERROR: $e');
    }

    // 4. Check what players would see: only approved championships
    print('\n========== PLAYER VIEW (is_approved=true ONLY) ==========');
    try {
      final approved = await client
          .from('championships')
          .select()
          .eq('is_approved', true);
      if ((approved as List).isEmpty) {
        print('❌ No approved championships - players see NOTHING');
      } else {
        for (final c in approved) {
          print('✅ Players can see: [${c['name']}] | Status: ${c['status']} | Gov: ${c['governorate']}');
        }
      }
    } catch (e) {
      // Try without filter to detect if column exists
      print('is_approved filter error: $e');
      final all = await client.from('championships').select('id, name, is_approved');
      print('All championships with is_approved: $all');
    }
  });
}
