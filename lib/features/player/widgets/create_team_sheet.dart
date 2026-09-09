import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/image_pick_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/roster_parser_utils.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../core/repositories/team_repository.dart';
import '../../../shared/widgets/primary_button.dart';
import 'add_player_sheet.dart';
import 'create_team_logo_picker_row.dart';
import 'create_team_members_section.dart';

class CreateTeamSheet extends StatefulWidget {
  const CreateTeamSheet({super.key});

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet> {
  final _nameController = TextEditingController();
  String _selectedSport = 'Football';
  final List<UserModel> _teamMembers = [];
  bool _isSubmitting = false;
  XFile? _selectedLogo;
  String? _uploadedLogoUrl;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final image = await ImagePickService.pick(
      context,
      aspectRatio: CropAspectRatioPreset.square,
    );
    if (image != null && mounted) {
      setState(() => _selectedLogo = image);
    }
  }

  void _showAddPlayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlayerSheet(
        onPlayerAdded: (user) {
          setState(() {
            if (!_teamMembers.any((m) => m.uid == user.uid)) {
              _teamMembers.add(user);
            }
          });
        },
      ),
    );
  }

  Future<void> _pasteFromWhatsApp() async {
    final parsedNames = await RosterParserUtils.showImportSquadDialog(context);
    if (parsedNames.isEmpty) {
      if (mounted) {
        VSPFeedback.showError(context, 'لم يتم العثور على أسماء واضحة في النص الملصوق.');
      }
      return;
    }

    int addedCount = 0;
    setState(() {
      for (int i = 0; i < parsedNames.length; i++) {
        if (_teamMembers.length + 1 >= 12) break;
        final name = parsedNames[i];
        if (!_teamMembers.any((m) => m.name == name)) {
          _teamMembers.add(UserModel(
            uid: 'guest_${DateTime.now().microsecondsSinceEpoch}_$i',
            name: name,
            email: 'guest_$i@vsp.app',
            role: 'player',
            governorate: 'Cairo',
          ));
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
            ? 'تمت إضافة $addedCount أعضاء من نص التشكيلة بنجاح! '
            : 'Successfully added $addedCount members from WhatsApp text! ',
      );
    }
  }

  Future<void> _handleCreateTeam() async {
    final name = _nameController.text.trim();
    final l10n = AppLocalizations.of(context)!;

    if (name.isEmpty) {
      VSPFeedback.showError(context, l10n.enterTeamName);
      return;
    }

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid;

      if (uid == null) {
        VSPFeedback.showError(context, 'Session expired. Please sign in again.');
        return;
      }

      setState(() => _isSubmitting = true);

      if (_teamMembers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.friendsRequiredNote),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      if (_selectedLogo != null) {
        _uploadedLogoUrl = await StorageService().uploadFile(
          file: _selectedLogo!,
          bucket: 'profile-pictures',
          path: 'teams/$uid/logos/team_logo_${DateTime.now().millisecondsSinceEpoch}.jpg',
        );
      }

      final teamData = {
        'name': name,
        'captainName': auth.userModel?.name ?? 'Captain',
        'captainPhone': PhoneUtils.normalize(auth.userModel?.phone ?? ''),
        'captainImageUrl': auth.userModel?.profileImageUrl ?? '',
        'logoUrl': _uploadedLogoUrl ?? '',
        'playersCount': _teamMembers.length + 1,
        'maxPlayers': 12,
        'memberUids': [uid, ..._teamMembers.map((m) => m.uid)],
        'playerImages': [
          auth.userModel?.profileImageUrl ?? '',
          ..._teamMembers.map((m) => m.profileImageUrl ?? ''),
        ],
        'governorate': auth.userModel?.governorate ?? 'Cairo',
        'sportType': _selectedSport,
      };

      final teamId = await TeamRepository().createTeam(teamData);

      if (teamId != null && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.teamCreatedSuccess,
              style: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: VSPColors.background, fontWeight: FontWeight.bold),
            ),
            backgroundColor: VSPColors.accent,
          ),
        );
      } else if (mounted) {
        VSPFeedback.showError(context, 'فشل إنشاء الفريق، يرجى إعادة المحاولة.');
      }
    } catch (e) {
      if (mounted) VSPFeedback.showError(context, 'Error creating team: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bottomInset = MediaQuery.of(context).padding.bottom +
        MediaQuery.of(context).viewInsets.bottom +
        16;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.lg, VSPSpacing.md, bottomInset),
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.createTeamTitle, style: Theme.of(context).textTheme.displayMedium),
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    l10n.createTeamSubtitle,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: VSPColors.textSecondary),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Scrollable form body
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team name field
                  Text(l10n.teamNameLabel, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: VSPSpacing.sm),
                  TextField(
                    controller: _nameController,
                    style: Theme.of(context).textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: 'e.g. Star Team',
                      hintStyle: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                      filled: true,
                      fillColor: VSPColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(VSPRadius.md),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: VSPSpacing.md, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.md),

                  // Sport type dropdown
                  Text(l10n.sportsType, style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: VSPSpacing.sm),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    height: 44,
                    decoration: BoxDecoration(
                      color: VSPColors.surface,
                      borderRadius: BorderRadius.circular(VSPRadius.lg),
                      border: Border.all(color: VSPColors.divider, width: 0.5),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSport,
                        isExpanded: true,
                        icon: const Icon(Iconsax.arrow_down_1_copy,
                            color: VSPColors.accent, size: 16),
                        dropdownColor: VSPColors.surface,
                        items: VSPConstants.sports
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child:
                                      Text(s, style: Theme.of(context).textTheme.bodyMedium),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedSport = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: VSPSpacing.lg),

                  // Logo picker
                  CreateTeamLogoPickerRow(
                    selectedLogo: _selectedLogo,
                    onPickImage: _pickImage,
                  ),
                  const SizedBox(height: VSPSpacing.lg),

                  // Members section
                  CreateTeamMembersSection(
                    members: _teamMembers,
                    onAddMember: _showAddPlayerSheet,
                    onPasteWhatsApp: _pasteFromWhatsApp,
                    onRemoveMember: (member) => setState(() => _teamMembers.remove(member)),
                  ),
                  const SizedBox(height: VSPSpacing.xl),
                ],
              ),
            ),
          ),

          // Action buttons
          const SizedBox(height: VSPSpacing.md),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: l10n.cancelBtn,
                  onPressed: () => Navigator.pop(context),
                  color: VSPColors.surfaceAlt,
                  textColor: VSPColors.textPrimary,
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              Expanded(
                child: PrimaryButton(
                  text: l10n.confirmBtn,
                  onPressed: _handleCreateTeam,
                  isLoading: _isSubmitting,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
