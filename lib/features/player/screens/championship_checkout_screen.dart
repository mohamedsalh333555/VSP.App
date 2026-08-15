import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/repositories/tournament_repository.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../data/models.dart';
import '../../../shared/widgets/primary_button.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/roster_parser_utils.dart';
import 'payment_gateway_screen.dart';

class ChampionshipCheckoutScreen extends StatefulWidget {
  final Championship championship;
  final Team team;

  const ChampionshipCheckoutScreen({
    super.key,
    required this.championship,
    required this.team,
  });

  @override
  State<ChampionshipCheckoutScreen> createState() => _ChampionshipCheckoutScreenState();
}

class _ChampionshipCheckoutScreenState extends State<ChampionshipCheckoutScreen> {
  final List<String> _selectedPlayerIds = [];
  final List<String> _offlineGuestNames = [];
  final TextEditingController _guestController = TextEditingController();

  List<Map<String, dynamic>> _teamMembers = [];
  bool _isLoadingMembers = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTeamMembers();
  }

  @override
  void dispose() {
    _guestController.dispose();
    super.dispose();
  }

  Future<void> _loadTeamMembers() async {
    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('id, name, profile_image_url')
          .inFilter('id', widget.team.memberUids);
      _teamMembers = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error loading team members: $e');
    }

    for (final uid in widget.team.memberUids) {
      if (!_teamMembers.any((m) => m['id'] == uid)) {
        _teamMembers.add({
          'id': uid,
          'name': uid == widget.team.captainName ? widget.team.captainName : 'لاعب ${_teamMembers.length + 1}',
          'profile_image_url': '',
        });
      }
    }

    if (!mounted) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = auth.currentUser?.uid;

    if (currentUserId != null && widget.team.memberUids.contains(currentUserId)) {
      if (!_selectedPlayerIds.contains(currentUserId)) {
        _selectedPlayerIds.add(currentUserId);
      }
    } else if (widget.team.memberUids.isNotEmpty) {
      _selectedPlayerIds.add(widget.team.memberUids.first);
    }

    if (mounted) {
      setState(() => _isLoadingMembers = false);
    }
  }

  void _addGuestPlayer() {
    final name = _guestController.text.trim();
    if (name.isEmpty) return;
    if (_offlineGuestNames.contains(name)) return;

    final maxPlayers = widget.championship.maxPlayersPerTeam;
    if (_selectedPlayerIds.length + _offlineGuestNames.length >= maxPlayers) {
      VSPFeedback.showError(context, 'تجاوزت الحد الأقصى للاعبين ($maxPlayers لاعبين)!');
      return;
    }

    setState(() {
      _offlineGuestNames.add(name);
      _guestController.clear();
    });
  }

  Future<void> _pasteFromWhatsApp() async {
    String textToParse = '';

    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      if (data != null && data.text != null && data.text!.trim().isNotEmpty) {
        textToParse = data.text!;
      }
    } catch (e) {
      debugPrint('Clipboard read notice: $e');
    }

    if (textToParse.trim().isEmpty && mounted) {
      textToParse = await _showManualPasteDialog() ?? '';
    }

    if (textToParse.trim().isEmpty) return;

    final parsedNames = RosterParserUtils.parseSquadText(textToParse);
    if (parsedNames.isEmpty) {
      if (mounted) VSPFeedback.showError(context, 'لم يتم العثور على أسماء واضحة في النص الملصوق.');
      return;
    }

    final maxPlayers = widget.championship.maxPlayersPerTeam;
    int addedCount = 0;

    setState(() {
      for (final name in parsedNames) {
        if (_selectedPlayerIds.length + _offlineGuestNames.length >= maxPlayers) break;
        if (!_offlineGuestNames.contains(name)) {
          _offlineGuestNames.add(name);
          addedCount++;
        }
      }
    });

    if (addedCount > 0 && mounted) {
      HapticFeedback.mediumImpact();
      final isArabic = Localizations.localeOf(context).languageCode == 'ar';
      VSPFeedback.showSuccess(
        context,
        isArabic
            ? 'تمت إضافة $addedCount لاعبين من نص التشكيلة بنجاح! ⚽'
            : 'Successfully added $addedCount players from WhatsApp text! ⚽',
      );
    }
  }

  Future<String?> _showManualPasteDialog() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final controller = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VSPColors.surface,
        title: Text(
          isArabic ? 'لصق نص تشكيلة واتساب 📋' : 'Paste WhatsApp Squad List 📋',
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isArabic ? 'انسخ القائمة من واتساب والصقها هنا مباشرة:' : 'Copy list from WhatsApp and paste here:',
              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 6,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: '1- أحمد\n2- علي\n3- محمود...',
                hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                filled: true,
                fillColor: VSPColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: Text(isArabic ? 'إلغاء' : 'Cancel', style: const TextStyle(color: VSPColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: VSPColors.accent, foregroundColor: Colors.black),
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(isArabic ? 'استخراج الأسماء ⚽' : 'Extract Names ⚽', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _handleConfirmAndPay() async {
    final minPlayers = widget.championship.minPlayersPerTeam;
    final maxPlayers = widget.championship.maxPlayersPerTeam;
    final totalCount = _selectedPlayerIds.length + _offlineGuestNames.length;

    if (totalCount < minPlayers) {
      VSPFeedback.showError(context, 'يرجى اختيار $minPlayers لاعبين على الأقل للتشكيلة.');
      return;
    }
    if (totalCount > maxPlayers) {
      VSPFeedback.showError(context, 'التشكيلة تجاوزت الحد الأقصى ($maxPlayers لاعبين).');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final entryFee = widget.championship.entryFee;

      if (entryFee > 0) {
        final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
        String validStadiumId = '';
        String validOwnerId = uuidRegex.hasMatch(widget.championship.ownerId) ? widget.championship.ownerId : '';

        try {
          final res = await Supabase.instance.client
              .from('stadiums')
              .select('id, owner_id')
              .limit(1)
              .maybeSingle();

          if (res != null) {
            validStadiumId = res['id'].toString();
            if (validOwnerId.isEmpty) validOwnerId = (res['owner_id'] ?? '').toString();
          }
        } catch (e) {
          debugPrint('Error fetching stadium fallback: $e');
        }

        if (validStadiumId.isEmpty) {
          validStadiumId = 'champ_stadium_${widget.championship.id}';
        }

        final draft = BookingDraft(
          stadiumId: validStadiumId,
          stadiumName: 'بطولة: ${widget.championship.name}',
          stadiumImageUrl: widget.championship.logoUrl,
          ownerId: validOwnerId,
          startTime: widget.championship.startDate,
          endTime: widget.championship.endDate,
          bookingType: BookingType.team,
          playerTeamId: widget.team.id,
          playerTeamName: widget.team.name,
          totalPrice: entryFee,
          isPaid: false,
          isPrivate: false,
          rentBall: false,
          currentPlayers: totalCount,
          totalFieldCapacity: maxPlayers,
          depositPaid: entryFee,
          isDepositPaid: false,
          needsDeposit: true,
        );

        if (mounted) {
          setState(() => _isSubmitting = false);
          final paymentResult = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => PaymentGatewayScreen(
                bookingDraft: draft,
                forceFullPayment: true,
                isTournamentPayment: true,
              ),
            ),
          );

          if (paymentResult == true && mounted) {
            await _executeJoinChampionship();
          }
          return;
        }
      }

      await _executeJoinChampionship();
    } catch (e) {
      if (mounted) {
        VSPFeedback.showError(context, 'حدث خطأ أثناء الاشتراك: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _executeJoinChampionship() async {
    final success = await TournamentRepository().joinChampionship(
      widget.championship.id,
      widget.team.id,
      selectedPlayerIds: _selectedPlayerIds,
      offlineGuestNames: _offlineGuestNames,
      isPaid: true,
    );

    if (success && mounted) {
      VSPFeedback.showSuccess(context, 'تم الاشتراك في البطولة بنجاح! 🏆');
      Navigator.pop(context, true);
    } else if (mounted) {
      VSPFeedback.showError(context, 'فشل الانضمام للبطولة، يرجى المحاولة مرة أخرى.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final minPlayers = widget.championship.minPlayersPerTeam;
    final maxPlayers = widget.championship.maxPlayersPerTeam;
    final totalCount = _selectedPlayerIds.length + _offlineGuestNames.length;
    final isSelectionValid = totalCount >= minPlayers && totalCount <= maxPlayers;

    final entryFee = widget.championship.entryFee;
    // Unified Platform & Processing Service Fee: 4.75% + 3 EGP fixed
    final serviceFee = (entryFee * 0.0475) + 3.0;
    final totalCheckoutPrice = entryFee + serviceFee;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? Iconsax.arrow_right_3_copy : Iconsax.arrow_left_2_copy,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'التسجيل في البطولة',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(VSPSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Championship Summary Header Card
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: VSPColors.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                    ),
                    child: const Icon(Iconsax.cup_copy, color: VSPColors.accent, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.championship.name,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Iconsax.location_copy, color: VSPColors.textSecondary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.championship.governorate,
                              style: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(width: 12),
                            Icon(Iconsax.people_copy, color: VSPColors.textSecondary, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              widget.team.name,
                              style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.lg),

            // 2. Squad Selection Requirement Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelectionValid 
                    ? VSPColors.accent.withValues(alpha: 0.08) 
                    : VSPColors.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(VSPRadius.lg),
                border: Border.all(
                  color: isSelectionValid 
                      ? VSPColors.accent.withValues(alpha: 0.3) 
                      : VSPColors.warning.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isSelectionValid 
                          ? VSPColors.accent.withValues(alpha: 0.15) 
                          : VSPColors.warning.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.people_copy,
                      color: isSelectionValid ? VSPColors.accent : VSPColors.warning,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              isArabic ? 'تشكيلة الفريق' : 'Team Roster',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSelectionValid ? VSPColors.accent : VSPColors.warning,
                                borderRadius: BorderRadius.circular(VSPRadius.full),
                              ),
                              child: Text(
                                isArabic ? '$totalCount لاعبين' : '$totalCount Players',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          minPlayers == maxPlayers
                              ? (isArabic ? 'المطلوب: $minPlayers لاعبين بالضبط' : 'Required: Exactly $minPlayers players')
                              : (isArabic ? 'المطلوب: من $minPlayers إلى $maxPlayers لاعبين' : 'Required: $minPlayers to $maxPlayers players'),
                          style: TextStyle(
                            color: isSelectionValid ? VSPColors.textSecondary : VSPColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.md),

            // 3. Team Roster Selection List
            Text(
              'أعضاء الفريق المسجلين:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
            const SizedBox(height: VSPSpacing.sm),

            if (_isLoadingMembers)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator(color: VSPColors.accent)))
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _teamMembers.length,
                itemBuilder: (context, index) {
                  final member = _teamMembers[index];
                  final isSelected = _selectedPlayerIds.contains(member['id']);
                  final auth = Provider.of<AuthProvider>(context, listen: false);
                  final isCaptain = member['id'] == auth.currentUser?.uid || member['id'] == widget.team.captainName;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      border: Border.all(color: isSelected ? VSPColors.accent.withValues(alpha: 0.5) : VSPColors.divider),
                    ),
                    child: CheckboxListTile(
                      value: isSelected,
                      activeColor: VSPColors.accent,
                      title: Text(
                        member['name'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                      subtitle: isCaptain
                          ? const Text('قائد الفريق (إجباري)', style: TextStyle(color: VSPColors.accent, fontSize: 11, fontWeight: FontWeight.bold))
                          : null,
                      secondary: CircleAvatar(
                        radius: 18,
                        backgroundImage: (member['profile_image_url'] != null && member['profile_image_url'].toString().isNotEmpty)
                            ? NetworkImage(member['profile_image_url'])
                            : null,
                        backgroundColor: VSPColors.surfaceAlt,
                        child: (member['profile_image_url'] == null || member['profile_image_url'].toString().isEmpty)
                            ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary, size: 18)
                            : null,
                      ),
                      onChanged: isCaptain
                          ? null
                          : (val) {
                              setState(() {
                                if (val == true) {
                                  _selectedPlayerIds.add(member['id']);
                                } else {
                                  _selectedPlayerIds.remove(member['id']);
                                }
                              });
                            },
                    ),
                  );
                },
              ),

            const SizedBox(height: VSPSpacing.lg),

            // 4. Add Guest Players Section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isArabic ? 'إضافة أصدقاء من خارج التطبيق:' : 'Add External Guests:',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                TextButton.icon(
                  onPressed: _pasteFromWhatsApp,
                  icon: const Icon(Iconsax.copy_copy, size: 16, color: VSPColors.accent),
                  label: Text(
                    isArabic ? 'لصق من واتساب 📋' : 'Paste from WhatsApp 📋',
                    style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSPSpacing.xs),

            if (totalCount < minPlayers) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                  border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.info_circle_copy, color: Colors.amber, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isArabic
                            ? 'متبقي [${minPlayers - totalCount}] لاعبين لاكتمال نصاب الفريق ⚽'
                            : '[${minPlayers - totalCount}] more players needed to complete squad ⚽',
                        style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _guestController,
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) => _addGuestPlayer(),
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: isArabic ? 'اسم الصديق (اضغط التالي للإضافة السريعة)' : 'Guest name (press Next to add)',
                      hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                      filled: true,
                      fillColor: VSPColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addGuestPlayer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VSPColors.accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                  ),
                  child: Text(isArabic ? 'إضافة' : 'Add', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),

            if (_offlineGuestNames.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _offlineGuestNames.map((name) {
                  return Chip(
                    backgroundColor: VSPColors.surface,
                    label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                    deleteIcon: const Icon(Iconsax.close_circle_copy, size: 14, color: VSPColors.error),
                    onDeleted: () {
                      setState(() => _offlineGuestNames.remove(name));
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      side: const BorderSide(color: VSPColors.divider),
                    ),
                  );
                }).toList(),
              ),
            ],

            const SizedBox(height: VSPSpacing.xl),

            // 5. Financial Breakdown Card (3% Net Platform Commission)
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.xl),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'تفاصيل الرسوم والاشتراك',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: VSPColors.divider, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('رسوم اشتراك البطولة:', style: TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
                      Text('${entryFee.toInt()} ج.م', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isArabic ? 'رسوم خدمات المنصة:' : 'Platform Service Fee:',
                        style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13),
                      ),
                      Text('${serviceFee.toStringAsFixed(1)} ج.م', style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  const Divider(color: VSPColors.divider, height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('المبلغ الإجمالي المطلـوب:', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(
                        '${totalCheckoutPrice.toStringAsFixed(1)} ج.م',
                        style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.w900, fontSize: 18),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),

      // Sticky Bottom Navigation Action Bar
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          VSPSpacing.lg,
          VSPSpacing.sm,
          VSPSpacing.lg,
          MediaQuery.of(context).padding.bottom + VSPSpacing.sm,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.surface,
          border: Border(top: BorderSide(color: VSPColors.divider, width: 0.5)),
        ),
        child: PrimaryButton(
          text: entryFee > 0 ? (isArabic ? 'الانتقال للدفع الآمن' : 'Proceed to Secure Payment') : (isArabic ? 'تأكيد الاشتراك في البطولة' : 'Confirm Registration'),
          isLoading: _isSubmitting,
          onPressed: isSelectionValid ? _handleConfirmAndPay : null,
        ),
      ),
    );
  }
}
