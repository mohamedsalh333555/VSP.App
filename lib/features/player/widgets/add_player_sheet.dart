import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../core/models/user_model.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/utils/phone_utils.dart';
import '../../../core/utils/vsp_launcher_utils.dart';
import 'package:provider/provider.dart';
import '../../../core/repositories/user_repository.dart';

class AddPlayerSheet extends StatefulWidget {
 final Function(UserModel) onPlayerAdded;
 final List<String> existingMemberUids;
 final String? requiredGovernorate;

 const AddPlayerSheet({
 super.key,
 required this.onPlayerAdded,
 this.existingMemberUids = const [],
 this.requiredGovernorate,
 });

 @override
 State<AddPlayerSheet> createState() => _AddPlayerSheetState();
}

class _AddPlayerSheetState extends State<AddPlayerSheet> {
 final TextEditingController _phoneController = TextEditingController();
 UserModel? _foundUser;
 bool _isSearching = false;
 bool _hasSearched = false;
 bool _governorateMismatch = false;

 Future<void> _searchPlayer() async {
 final phone = _phoneController.text.trim();
 if (phone.isEmpty) return;

 setState(() {
 _isSearching = true;
 _hasSearched = false;
 _foundUser = null;
 });

 final normalized = PhoneUtils.normalize(phone);
 if (normalized == null) {
   if (mounted) {
     final isArabic = Localizations.localeOf(context).languageCode == 'ar';
     setState(() => _isSearching = false);
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(isArabic ? 'أدخل رقم هاتف صحيحاً.' : 'Enter a valid phone number.')),
     );
   }
   return;
 }

 UserModel? user;
 try {
   user = await UserRepository().getUserByPhoneStrict(normalized);
 } catch (_) {
   if (mounted) {
     final isArabic = Localizations.localeOf(context).languageCode == 'ar';
     setState(() => _isSearching = false);
     ScaffoldMessenger.of(context).showSnackBar(
       SnackBar(content: Text(isArabic ? 'تعذر البحث عن اللاعب. تحقق من الاتصال وحاول مرة أخرى.' : 'Could not search for this player. Check your connection and try again.')),
     );
   }
   return;
 }

 if (mounted) {
 if (user != null) {
 final currentUid = context.read<AuthProvider>().currentUser?.id;
 if (user.uid == currentUid) {
 ScaffoldMessenger.of(context).showSnackBar(
 SnackBar(content: Text(Localizations.localeOf(context).languageCode == 'ar' ? 'أنت قائد الفريق بالفعل.' : 'You are already the team captain.'), backgroundColor: VSPColors.accent),
 );
 setState(() {
 _isSearching = false;
 _hasSearched = true;
 });
 return;
 }
 }

 final requiredGov = widget.requiredGovernorate?.trim();
 final playerGov = user?.governorate?.trim();
 _governorateMismatch = user != null &&
     requiredGov != null &&
     requiredGov.isNotEmpty &&
     (playerGov == null ||
       playerGov.isEmpty ||
       playerGov.toLowerCase() != requiredGov.toLowerCase());

 setState(() {
 _foundUser = user;
 _isSearching = false;
 _hasSearched = true;
 });
 }
 }


 @override
 Widget build(BuildContext context) {
 final isArabic = Localizations.localeOf(context).languageCode == 'ar';
 final media = MediaQuery.of(context);
 final bottomPadding = media.padding.bottom;
 final availableHeight = (media.size.height -
         media.viewInsets.bottom -
         media.padding.top -
         media.padding.bottom -
         24)
     .clamp(0.0, media.size.height)
     .toDouble();

 return Container(
 constraints: BoxConstraints(maxHeight: availableHeight),
 padding: EdgeInsets.only(
 top: VSPSpacing.lg,
 left: VSPSpacing.md,
 right: VSPSpacing.md,
 bottom: bottomPadding > 0 ? bottomPadding + VSPSpacing.lg : VSPSpacing.lg,
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
 Expanded(
 child: Text(
 isArabic ? 'إضافة لاعب للفريق' : 'Add Team Member',
 maxLines: 2,
 overflow: TextOverflow.ellipsis,
 softWrap: true,
 style: Theme.of(context).textTheme.displaySmall,
 ),
 ),
 IconButton(
 tooltip: isArabic ? 'إغلاق' : 'Close',
 onPressed: () => Navigator.pop(context),
 icon: const Icon(Iconsax.close_circle_copy, color: VSPColors.textSecondary),
 ),
 ],
 ),
 const SizedBox(height: VSPSpacing.lg),
 Text(isArabic ? 'البحث برقم الهاتف' : 'Search by Phone Number', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
 const SizedBox(height: VSPSpacing.sm),
 Row(
 children: [
 Expanded(
 child: TextField(
 controller: _phoneController,
 keyboardType: TextInputType.phone,
 textDirection: TextDirection.ltr,
 textInputAction: TextInputAction.search,
 onSubmitted: (_) {
   if (!_isSearching) _searchPlayer();
 },
 style: Theme.of(context).textTheme.bodyMedium,
 decoration: InputDecoration(
 hintText: isArabic ? 'مثال: 01012345678' : 'e.g. 01012345678',
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
 Tooltip(
 message: isArabic ? 'البحث عن اللاعب' : 'Search for player',
 child: Semantics(
 button: true,
 label: isArabic ? 'البحث عن اللاعب' : 'Search for player',
 child: InkWell(
 excludeFromSemantics: true,
 onTap: _isSearching ? null : _searchPlayer,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 child: SizedBox(
 height: 50,
 width: 50,
 child: DecoratedBox(
 decoration: BoxDecoration(
 color: _isSearching
 ? VSPColors.accent.withValues(alpha: 0.55)
 : VSPColors.accent,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 ),
 child: _isSearching
 ? const Padding(
 padding: EdgeInsets.all(VSPSpacing.sm),
 child: CircularProgressIndicator(color: VSPColors.background, strokeWidth: 2),
 )
 : const Icon(Iconsax.search_normal_copy, color: VSPColors.background),
 ),
 ),
 ),
 ),
 ),
 ],
 ),
 const SizedBox(height: VSPSpacing.xl),
 if (_foundUser != null)
 _buildFoundUserCard(isArabic)
 else if (_hasSearched)
 _buildInviteCard(),
 const SizedBox(height: 16),
 ],
 ),
 ),
 );
 }

 Widget _buildFoundUserCard(bool isArabic) {
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
 _foundUser!.name ?? (isArabic ? 'لاعب' : 'Player'),
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
 const Icon(Iconsax.tick_circle_copy, color: VSPColors.accent, size: 16),
 const SizedBox(width: 4),
 Text(isArabic ? 'منضم' : 'Joined', style: const TextStyle(color: VSPColors.accent, fontWeight: FontWeight.bold)),
 ],
 ),
 )
 else if (_governorateMismatch)
 Container(
 constraints: const BoxConstraints(maxWidth: 150),
 padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
 decoration: BoxDecoration(
 color: VSPColors.surfaceAlt,
 borderRadius: BorderRadius.circular(VSPRadius.md),
 border: Border.all(color: Colors.orange.withValues(alpha: 0.45)),
 ),
 child: Text(
 isArabic
 ? 'محافظة اللاعب مختلفة عن محافظة الكابتن'
 : 'Player is from a different governorate',
 textAlign: TextAlign.center,
 style: Theme.of(context).textTheme.labelSmall?.copyWith(
 color: Colors.orange,
 fontWeight: FontWeight.bold,
 ),
 ),
 )
 else
 SizedBox(
 width: 80,
 height: 40,
 child: PrimaryButton(
 text: isArabic ? 'إضافة' : 'Add',
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
    final phone = _phoneController.text.trim();
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
              const Icon(Iconsax.user_add_copy, color: VSPColors.accent, size: 24),
              const SizedBox(width: 8),
              Text(
                isArabic ? 'رقم غير مسجل في VSP' : 'This number is not registered on VSP',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isArabic
                ? 'الرقم ده لسه مش مسجل في VSP. ابعت له دعوة عشان ينزّل التطبيق وتقدر تضيفه لفريقك.'
                : 'This number is not registered on VSP yet. Send an invitation so they can install the app and join your team.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () async {
                final normalizedPhone = PhoneUtils.normalize(phone) ?? phone;
                final message = isArabic
                    ? 'يا كابتن! حمّل تطبيق VSP وسجّل برقمك عشان أضيفك لفريقي. حمّل التطبيق من هنا: https://vsp.app'
                    : 'Join my team on VSP. Install the app and register with this phone number: https://vsp.app';
                await VSPLauncherUtils.openWhatsApp(context, phone: normalizedPhone, message: message);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VSPColors.whatsApp,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                elevation: 0,
              ),
              icon: const Icon(Iconsax.messages_3_copy, color: Colors.white, size: 20),
              label: Text(
                isArabic ? 'إرسال دعوة عبر واتساب' : 'Send WhatsApp invitation',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
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



