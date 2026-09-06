import os

repo_path = r'k:\.gemini\antigravity\scratch\vsp_application\lib\core\repositories\tournament_repository.dart'
with open(repo_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

start_idx = None
for i, line in enumerate(lines):
    if 'Future<void> generateFixtures(String championshipId) async {' in line:
        start_idx = i
        break

if start_idx is not None:
    # Find the line "int totalTeams = teamIds.length;"
    end_idx = None
    for j in range(start_idx, start_idx + 10):
        if 'if (totalTeams < 2)' in lines[j]:
            end_idx = j + 1
            break
            
    if end_idx is not None:
        replacement_block = """  Future<void> generateFixtures(String championshipId) async {
    try {
      // 1. First attempt atomic server-side generation
      try {
        final rpcRes = await _supabase.rpc('generate_tournament_bracket_atomic', params: {'p_championship_id': championshipId});
        if (rpcRes is Map && rpcRes['success'] == true) {
          VSPLogger.i('Tournament Fixtures generated via atomic server function: $rpcRes');
          _sendDrawNotifications(championshipId);
          return;
        }
      } catch (atomicErr) {
        VSPLogger.w('generate_tournament_bracket_atomic fallback to client generator: $atomicErr');
      }

      final champDoc = await _supabase
          .from('championships')
          .select()
          .eq('id', championshipId)
          .maybeSingle();
      if (champDoc == null) throw Exception('البطولة لا توجد.');

      final bool isPaidTourney = (champDoc['entry_fee'] != null && (champDoc['entry_fee'] as num) > 0);
      final List<String> teamIds = isPaidTourney
          ? List<String>.from(champDoc['paid_teams'] ?? [])
          : List<String>.from(champDoc['joined_teams'] ?? champDoc['joinedTeams'] ?? []);
      int totalTeams = teamIds.length;
      if (totalTeams < 2) {
        throw Exception(isPaidTourney
            ? 'يجب وجود فريقين مسددين لرسوم الاشتراك على الأقل لبدء البطولة.'
            : 'يجب وجود فريقين على الأقل لبدء البطولة.');
      }
"""
        new_lines = lines[:start_idx] + [replacement_block] + lines[end_idx:]
        with open(repo_path, 'w', encoding='utf-8') as f:
            f.writelines(new_lines)
        print("✅ tournament_repository.dart generateFixtures patched successfully via line slicing!")
    else:
        print("❌ Could not locate end_idx")
else:
    print("❌ Could not locate start_idx")
