import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/phone_utils.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/user_repository.dart';

class AddPlayerSheet extends StatefulWidget {
  final Function(UserModel) onPlayerAdded;
  final List<String> existingMemberUids;

  const AddPlayerSheet({
    super.key,
    required this.onPlayerAdded,
    this.existingMemberUids = const [],
  });

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

    final normalized = PhoneUtils.normalize(phone);
    final user = await UserRepository().getUserByPhone(normalized);

    if (mounted) {
      if (user != null) {
        final currentUid = context.read<AuthProvider>().currentUser?.uid;
        if (user.uid == currentUid) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('كما تعلم.. أنت الكابتن بالفعل! \n(You are the captain!)'), backgroundColor: VSPColors.accent),
          );
          setState(() {
            _isSearching = false;
            _hasSearched = true;
          });
          return;
        }
      }

      setState(() {
        _foundUser = user;
        _isSearching = false;
        _hasSearched = true;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        padding: const EdgeInsets.only(
          top: VSPSpacing.lg,
          left: VSPSpacing.md,
          right: VSPSpacing.md,
          bottom: VSPSpacing.lg,
        ),
        decoration: const BoxDecoration(
          color: VSPColors.background,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(VSPRadius.xl),
            topRight: Radius.circular(VSPRadius.xl),
          ),
        ),
        child: SingleChildScrollView(
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
                icon: Icon(LucideIcons.x, color: VSPColors.textSecondary),
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
                      : Icon(LucideIcons.search, color: VSPColors.background),
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
        ),
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
          if (widget.existingMemberUids.contains(_foundUser!.uid))
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: VSPColors.surfaceAlt,
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Row(
                children: [
                   Icon(LucideIcons.check, color: VSPColors.accent, size: 16),
                   const SizedBox(width: 4),
                   const Text('Joined', style: TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            SizedBox(
              width: 80,
              height: 40,
              child: PrimaryButton(
                text: 'Add',
                onPressed: () {
                  widget.onPlayerAdded(_foundUser!);
                  Navigator.pop(context);
                },
                height: 40,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInviteCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.lg),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.userPlus, color: VSPColors.accent, size: 24),
              const SizedBox(width: 8),
              Text(
                "دعوة صديقك عبر واتساب (Invite)",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "هذا الرقم غير مسجل في VSP حالياً. يمكنك دعوة صديقك مباشرة للتسجيل في التطبيق والانضمام لفريقك:",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                const message = 'حمل تطبيق VSP الرياضي وادخل برقمك عشان أضيفك في تشكيلة فريقي ونبدأ نلعب مباريات! ⚽🏆 حمل التطبيق من هنا: https://vsp.app';
                final encoded = Uri.encodeComponent(message);
                final whatsappUrl = Uri.parse('https://wa.me/?text=$encoded');
                try {
                  if (await canLaunchUrl(whatsappUrl)) {
                    await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                  }
                } catch (e) {
                  debugPrint('Error launching WhatsApp: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                elevation: 0,
              ),
              icon: const Icon(LucideIcons.messageCircle, color: Colors.white, size: 20),
              label: const Text(
                'دعوة صديق عبر واتساب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}



