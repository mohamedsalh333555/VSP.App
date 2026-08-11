import 'dart:convert';
import 'dart:io';

/// Standalone Dart script (not Flutter test) to directly query Supabase REST API
/// and inspect championships data including owner info and player visibility.
void main() async {
  const supabaseUrl = 'https://mktqkddbcddrxjxabdua.supabase.co';
  const anonKey = 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  final client = HttpClient();

  Future<List<Map<String, dynamic>>> query(String table, {String? filter}) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$table?select=*${filter != null ? '&$filter' : ''}');
    final req = await client.getUrl(uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final parsed = jsonDecode(body);
    if (parsed is List) {
      return parsed.cast<Map<String, dynamic>>();
    }
    return [];
  }

  Future<Map<String, dynamic>?> queryOne(String table, String id) async {
    final uri = Uri.parse('$supabaseUrl/rest/v1/$table?select=*&id=eq.$id&limit=1');
    final req = await client.getUrl(uri);
    headers.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final parsed = jsonDecode(body);
    if (parsed is List && parsed.isNotEmpty) return parsed.first as Map<String, dynamic>;
    return null;
  }

  print('\n========== ALL CHAMPIONSHIPS IN DB ==========');
  final championships = await query('championships');

  if (championships.isEmpty) {
    print('❌ NO CHAMPIONSHIPS FOUND IN DB');
  } else {
    print('Found ${championships.length} championship(s):');
    for (final c in championships) {
      print('\n---');
      print('🏆 ID:          ${c['id']}');
      print('   Name:        ${c['name']}');
      print('   Type:        ${c['type']}');
      print('   Sport:       ${c['sport_type']}');
      print('   Status:      ${c['status']}');
      print('   is_approved: ${c['is_approved']}');
      print('   owner_id:    ${c['owner_id']}');
      print('   governorate: ${c['governorate']}');
      print('   start_date:  ${c['start_date']}');
      print('   end_date:    ${c['end_date']}');
      print('   max_teams:   ${c['max_teams']}');
      print('   joined_teams:${c['joined_teams']}');
      print('   entry_fee:   ${c['entry_fee']}');
      print('   grand_prize: ${c['grand_prize']}');

      // Find owner
      final ownerId = c['owner_id']?.toString() ?? '';
      if (ownerId.isNotEmpty) {
        final owner = await queryOne('users', ownerId);
        if (owner != null) {
          print('   👤 Owner Name:  ${owner['name']}');
          print('   👤 Owner Email: ${owner['email']}');
          print('   👤 Owner Role:  ${owner['role']}');
        } else {
          print('   ⚠️  Owner not found in users table (id=$ownerId)');
        }

        // Find stadiums for this owner
        final stadiums = await query('stadiums', filter: 'owner_id=eq.$ownerId');
        if (stadiums.isNotEmpty) {
          for (final s in stadiums) {
            print('   🏟️ Stadium:     ${s['name']} | Sport: ${s['sport_type']} | Verified: ${s['is_verified']} | Deleted: ${s['is_deleted_by_owner']}');
          }
        } else {
          print('   ⚠️  No stadiums found for owner');
        }
      }
    }
  }

  print('\n========== PLAYER VIEW (is_approved = true) ==========');
  final approved = championships.where((c) => c['is_approved'] == true).toList();
  if (approved.isEmpty) {
    print('❌ No approved championships → Players see NOTHING');
    print('\nAll championships is_approved values:');
    for (final c in championships) {
      print('   [${c['name']}] → is_approved = ${c['is_approved']}');
    }
  } else {
    for (final c in approved) {
      print('✅ Players CAN see: [${c['name']}] | Status: ${c['status']} | Gov: ${c['governorate']} | Sport: ${c['sport_type']}');
    }
  }

  client.close();
}
