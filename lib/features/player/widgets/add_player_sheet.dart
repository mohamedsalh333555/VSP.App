import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/services/database_service.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/shimmer_image.dart';

class AddPlayerSheet extends StatefulWidget {
  final Function(UserModel) onPlayerAdded;

  const AddPlayerSheet({super.key, required this.onPlayerAdded});

  @override
  State<AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<AddPlayerSheet> {
  final TextEditingController _phoneController = TextEditingController();
  UserModel? _foundUser;
  bool _isSearching = false;
  bool _hasSearched = false;

  Future<void> _searchPlayer() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return;

    setState(() {
      _isSearching = true;
      _hasSearched = false;
      _foundUser = null;
    });

    final user = await DatabaseService().getUserByPhone(phone);

    if (mounted) {
      setState(() {
        _foundUser = user;
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }

  void _inviteViaWhatsApp() {
    Share.share("Hey! Join my team on the VSP app. Download the app and search for my phone number to find me!");
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: VSPSpacing.lg,
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg,
      ),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Add Team Member',
                style: Theme.of(context).textTheme.displaySmall,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: VSPColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.lg),
          Text('Search by Phone Number', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
          const SizedBox(height: VSPSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'e.g. 01012345678',
                    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
                    filled: true,
                    fillColor: VSPColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: VSPSpacing.md),
              GestureDetector(
                onTap: _isSearching ? null : _searchPlayer,
                child: Container(
                  height: 50,
                  width: 50,
                  decoration: BoxDecoration(
                    color: VSPColors.accent,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                  ),
                  child: _isSearching
                      ? const Padding(
                          padding: EdgeInsets.all(VSPSpacing.sm),
                          child: CircularProgressIndicator(color: VSPColors.background, strokeWidth: 2),
                        )
                      : const Icon(Icons.search, color: VSPColors.background),
                ),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.xl),
          if (_foundUser != null)
            _buildFoundUserCard()
          else if (_hasSearched)
            _buildInviteCard(),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFoundUserCard() {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          ShimmerImage(
            imageUrl: _foundUser!.profileImageUrl ?? '',
            width: 50,
            height: 50,
            borderRadius: VSPRadius.full,
          ),
          const SizedBox(width: VSPSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _foundUser!.name ?? 'Player',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  _foundUser!.phone ?? '',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                ),
              ],
            ),
          ),
          PrimaryButton(
            text: 'Add',
            onPressed: () {
              widget.onPlayerAdded(_foundUser!);
              Navigator.pop(context);
            },
            // Customizing for inline feel
          ),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Icon(Icons.person_search_outlined, color: VSPColors.textSecondary.withValues(alpha: 0.2), size: 48),
          const SizedBox(height: VSPSpacing.md),
          Text(
            "User Not Found",
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: VSPSpacing.sm),
          Text(
            "This number isn't registered on VSP yet. Invite them to join the game!",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
          ),
          const SizedBox(height: VSPSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: 'Invite via WhatsApp',
              onPressed: _inviteViaWhatsApp,
              color: const Color(0xFF25D366),
              textColor: Colors.white, // WhatsApp branding
            ),
          ),
        ],
      ),
    );
  }
}
