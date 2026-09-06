import os

# 1. Patch champion_screen.dart for Team list item
champ_path = r'K:\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\champion_screen.dart'
with open(champ_path, 'r', encoding='utf-8') as f:
    champ_text = f.read()

old_team_name = '''              children: [
                Text(
                  team.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),'''

new_team_name = '''              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        team.name,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    FutureBuilder<bool>(
                      future: TeamRepository().has1v1Champion(team.id),
                      builder: (context, champSnap) {
                        if (champSnap.data == true) {
                          return Container(
                            margin: const EdgeInsetsDirectional.only(start: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF332608),
                              borderRadius: BorderRadius.circular(VSPRadius.full),
                              border: Border.all(color: const Color(0xFFEAB308), width: 0.8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('👑', style: TextStyle(fontSize: 10)),
                                SizedBox(width: 3),
                                Text(
                                  'بطل 1v1',
                                  style: TextStyle(color: Color(0xFFFDE047), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 2),'''

if old_team_name in champ_text:
    champ_text = champ_text.replace(old_team_name, new_team_name)
    with open(champ_path, 'w', encoding='utf-8') as f:
        f.write(champ_text)
    print('Successfully patched champion_screen.dart for team badge!')
else:
    print('old_team_name not found in champion_screen.dart')

# 2. Patch my_team_screen.dart
my_team_path = r'K:\.gemini\antigravity\scratch\vsp_application\lib\features\player\screens\profile_subscreens\my_team_screen.dart'
with open(my_team_path, 'r', encoding='utf-8') as f:
    my_team_text = f.read()

old_stats_grid = '''              // 1. Stats Grid (Show ONLY if team is created)
              if (team != null) ...['''

new_stats_grid = '''              // 1. Stats Grid (Show ONLY if team is created)
              if (team != null) ...[
                FutureBuilder<bool>(
                  future: TeamRepository().has1v1Champion(team.id),
                  builder: (context, champSnap) {
                    if (champSnap.data == true) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF332608), Color(0xFF1E1A0C)],
                          ),
                          borderRadius: BorderRadius.circular(VSPRadius.lg),
                          border: Border.all(color: const Color(0xFFEAB308), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Text('👑', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isArabic ? 'فريق يضم بطل 1v1 رسمي! 🏆' : 'Home of Official 1v1 Champion! 🏆',
                                    style: const TextStyle(color: Color(0xFFFDE047), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  Text(
                                    isArabic ? 'أحد لاعبي هذا الفريق حاصل على المركز الأول في بطولة الفردي' : 'A member of this team won 1st place in the 1v1 tournament',
                                    style: const TextStyle(color: Color(0xFFCA8A04), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),'''

if old_stats_grid in my_team_text:
    my_team_text = my_team_text.replace(old_stats_grid, new_stats_grid)
    with open(my_team_path, 'w', encoding='utf-8') as f:
        f.write(my_team_text)
    print('Successfully patched my_team_screen.dart for 1v1 badge banner!')
else:
    print('old_stats_grid not found in my_team_screen.dart')
