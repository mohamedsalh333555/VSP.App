import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/vsp_ui.dart';
import 'dart:async';
import '../../../core/repositories/search_repository.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../data/models.dart';
import 'stadium_details_screen.dart';
import 'championship_details_screen.dart';
import 'team_profile_screen.dart';
import '../widgets/collective_match_invite_sheet.dart';
import '../../../core/repositories/match_repository.dart';

class GlobalSearchScreen extends StatefulWidget {
  final String? initialQuery;
  const GlobalSearchScreen({super.key, this.initialQuery});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  late TextEditingController _searchController;
  bool _isSearching = false;
  Map<String, List<dynamic>> _results = {'stadiums': [], 'teams': [], 'championships': []};
  
  // Recent searches will be populated from user interaction
  final List<String> _recentSearches = [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _performSearch(widget.initialQuery!);
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _results = {'stadiums': [], 'teams': [], 'championships': []};
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    
    final results = await SearchRepository().globalUnifiedSearch(query);
    
    if (mounted) {
      setState(() {
        _results = results;
        _isSearching = false;
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }


  Future<void> _openCollectiveInviteCode() async {
    final controller = TextEditingController();
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
        title: Text(
          ar ? 'كود التجميعية' : 'Collective match code',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          decoration: InputDecoration(
            hintText: ar ? 'مثال: AB12CD34' : 'e.g. AB12CD34',
            hintStyle: const TextStyle(color: VSPColors.textSecondary),
            filled: true,
            fillColor: VSPColors.surfaceAlt,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ar ? 'إلغاء' : 'Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim().toUpperCase()),
            child: Text(ar ? 'فتح' : 'Open'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (code == null || code.isEmpty || !mounted) return;

    final data = await MatchRepository().getPrivateCollectiveInviteByCode(code);
    if (!mounted) return;
    final token = data?['invite_token']?.toString();
    if (token == null || token.isEmpty) {
      VSPFeedback.showError(context, ar ? 'كود التجميعية غير صالح أو انتهى.' : 'The collective match code is invalid or expired.');
      return;
    }
    await CollectiveMatchInviteSheet.showForInvite(
      context,
      inviteToken: token,
      initialInviteData: data,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResults = _results.values.any((list) => list.isNotEmpty);
    final ar = Localizations.localeOf(context).languageCode == 'ar';

    return VSPScaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: widget.initialQuery == null,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: AppLocalizations.of(context)!.searchHint,
            hintStyle: const TextStyle(color: VSPColors.textSecondary),
            border: InputBorder.none,
          ),
          onChanged: (val) => _onSearchChanged(val),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
              onPressed: () {
                _searchController.clear();
                _performSearch('');
              },
            ),
        ],
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: VSPColors.accent))
          : SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
              padding: EdgeInsets.only(
                left: VSPSpacing.md,
                right: VSPSpacing.md,
                top: VSPSpacing.md,
                bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_searchController.text.isEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      margin: const EdgeInsets.only(bottom: VSPSpacing.lg),
                      decoration: BoxDecoration(
                        color: VSPColors.surface,
                        borderRadius: BorderRadius.circular(VSPRadius.lg),
                        border: Border.all(color: VSPColors.divider),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: VSPColors.surfaceAlt,
                              borderRadius: BorderRadius.circular(VSPRadius.md),
                            ),
                            child: const Icon(Iconsax.key_copy, color: VSPColors.accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(ar ? 'لديك كود تجميعية؟' : 'Have a collective code?', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text(ar ? 'افتح الدعوة مباشرة بالكود.' : 'Open a private invitation by code.', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          TextButton(onPressed: _openCollectiveInviteCode, child: Text(ar ? 'فتح' : 'Open')),
                        ],
                      ),
                    ),
                    Text(AppLocalizations.of(context)!.recentSearches, style: const TextStyle(color: VSPColors.textSecondary, fontWeight: FontWeight.bold)),
                    const SizedBox(height: VSPSpacing.md),
                    Wrap(
                      spacing: 8,
                      children: _recentSearches.map((s) => ActionChip(
                        label: Text(s, style: const TextStyle(color: Colors.black)),
                        backgroundColor: VSPColors.accent.withValues(alpha: 0.8),
                        onPressed: () {
                          _searchController.text = s;
                          _performSearch(s);
                        },
                      )).toList(),
                    ),
                  ] else if (!hasResults) ...[
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 100),
                        child: Text(AppLocalizations.of(context)!.noResults, style: const TextStyle(color: VSPColors.textSecondary)),
                      ),
                    ),
                  ] else ...[
                    _buildCategory(AppLocalizations.of(context)!.stadiumsCategory, _results['stadiums'] as List<Stadium>),
                    _buildCategory(AppLocalizations.of(context)!.teamsCategory, _results['teams'] as List<Team>),
                    _buildCategory(AppLocalizations.of(context)!.championshipsCategory, _results['championships'] as List<Championship>),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildCategory(String title, List<dynamic> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(title, style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            String name = '';
            String sub = '';
            IconData icon = Iconsax.info_circle_copy;
            VoidCallback? onTap;

            if (item is Stadium) {
              name = item.name;
              sub = item.location;
              icon = Iconsax.location_copy;
              onTap = () => Navigator.push(context, MaterialPageRoute(builder: (c) => StadiumDetailsScreen(stadium: item)));
            } else if (item is Team) {
              name = item.name;
              sub = '${item.sportType} - ${item.governorate}';
              icon = Iconsax.people_copy;
              onTap = () => Navigator.push(context, MaterialPageRoute(builder: (c) => TeamProfileScreen(team: item)));
            } else if (item is Championship) {
              name = item.name;
              sub = AppLocalizations.of(context)!.prizeLabel(item.grandPrize.toString());
              icon = Iconsax.cup_copy;
              onTap = () => Navigator.push(context, MaterialPageRoute(builder: (c) => ChampionshipDetailsScreen(championship: item)));
            }

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: VSPColors.textSecondary, size: 20),
              ),
              title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              subtitle: Text(sub, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12)),
              onTap: onTap,
            );
          },
        ),
      ],
    );
  }
}
