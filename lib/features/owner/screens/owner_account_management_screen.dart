import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/stadium_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../auth/screens/welcome_screen.dart';

class OwnerAccountManagementScreen extends StatefulWidget {
  const OwnerAccountManagementScreen({super.key});

  @override
  State<OwnerAccountManagementScreen> createState() => _OwnerAccountManagementScreenState();
}

class _OwnerAccountManagementScreenState extends State<OwnerAccountManagementScreen> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _socialController;
  
  bool _isLoading = false;
  bool _isDeleting = false;
  bool _isLocating = false;
  List<Stadium> _stadiums = [];

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userModel = authProvider.userModel;
    
    _nameController = TextEditingController(text: userModel?.name ?? '');
    _phoneController = TextEditingController(text: userModel?.phone ?? '');
    _emailController = TextEditingController(text: userModel?.email ?? '');
    _socialController = TextEditingController(text: userModel?.additionalData?['socialMedia'] ?? '');
    
    final stadiumProvider = Provider.of<StadiumProvider>(context, listen: false);
    _stadiums = stadiumProvider.stadiums;
  }

  Future<void> _updateUserData() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      VSPFeedback.showError(context, 'Name cannot be empty');
      return;
    }
    if (phone.isEmpty) {
      VSPFeedback.showError(context, 'Phone number cannot be empty');
      return;
    }

    setState(() => _isLoading = true);
    
    final success = await authProvider.updateProfile({
      'name': name,
      'phone': phone,
      'additionalData': {
        ...authProvider.userModel?.additionalData ?? {},
        'socialMedia': _socialController.text.trim(),
      }
    });
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        VSPFeedback.showSuccess(context, 'Profile updated successfully');
        Navigator.pop(context);
      } else {
        VSPFeedback.showError(context, 'Failed to update profile');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userModel = authProvider.userModel;

    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Account',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector
            SizedBox(
              height: 220,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                scrollDirection: Axis.horizontal,
                itemCount: _stadiums.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 300,
                    margin: const EdgeInsets.only(right: VSPSpacing.md),
                    child: _buildStadiumCard(_stadiums[index]),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. Personal Info Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('Owner Name'),
                   _buildTextField(_nameController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Number'),
                   _buildTextField(_phoneController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Email'),
                   _buildTextField(_emailController, enabled: false), // Email usually not editable here
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Location'),
                   Container(
                     padding: const EdgeInsets.all(VSPSpacing.md),
                     decoration: BoxDecoration(
                       color: VSPColors.surface,
                       borderRadius: BorderRadius.circular(VSPRadius.md),
                       border: Border.all(color: VSPColors.divider.withValues(alpha: 0.1)),
                     ),
                     child: Row(
                       children: [
                         const Icon(Icons.location_on, color: VSPColors.accent, size: 28),
                         const SizedBox(width: 12),
                         Expanded(
                           child: Column(
                             crossAxisAlignment: CrossAxisAlignment.start,
                             children: [
                               Text(
                                 'Current Governorate',
                                 style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                               ),
                               Text(
                                 userModel?.governorate ?? 'Not set',
                                 style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                               ),
                             ],
                           ),
                         ),
                         _isLocating 
                         ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: VSPColors.accent))
                         : IconButton(
                           icon: const Icon(Icons.my_location, color: VSPColors.accent),
                           onPressed: () async {
                             setState(() => _isLocating = true);
                             await authProvider.updateUserLocation();
                             if (mounted) {
                               if (!context.mounted) return;
                               setState(() => _isLocating = false);
                               VSPFeedback.showSuccess(context, 'Location updated!');
                             }
                           },
                         ),
                       ],
                     ),
                   ),
                   
                   const SizedBox(height: 16),
                   _buildInputLabel('Social media'),
                   _buildTextField(_socialController),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Documents
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('National ID front'),
                   _buildDocumentCard('National ID front', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('National ID back'),
                   _buildDocumentCard('National ID Back', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Tax card'),
                   _buildDocumentCard('Tax card', '300 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Commercial register'),
                   _buildDocumentCard('commercial register', '200 KB'),

                   const SizedBox(height: 40),

                   // --- Delete Account Button ---
                   Center(
                      child: TextButton(
                        onPressed: () => _showDeleteAccountDialog(context),
                        child: const Text(
                          'Delete Account',
                          style: TextStyle(
                            color: VSPColors.error,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
        color: VSPColors.background,
        child: PrimaryButton(
          text: 'Confirm',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _updateUserData,
        ),
      ),
    );
  }
  
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, {bool enabled = true}) {
    return Container(
      decoration: BoxDecoration(
        color: enabled ? VSPColors.surface : VSPColors.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(VSPRadius.md), 
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        enabled: enabled,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: enabled ? VSPColors.textPrimary : VSPColors.textSecondary,
        ),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String size) {
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.md),
      margin: EdgeInsets.zero,
      color: VSPColors.accent.withValues(alpha: 0.05),
      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      child: Row(
        children: [
           const Icon(Icons.image_outlined, color: VSPColors.textPrimary, size: 24),
           const SizedBox(width: VSPSpacing.md),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: Theme.of(context).textTheme.titleSmall),
                 Text(size, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                 const SizedBox(height: 4),
                 GestureDetector(
                   onTap: () {
                     // View logic
                   },
                   child: Text(
                     'Click to view',
                     style: Theme.of(context).textTheme.labelMedium?.copyWith(
                       color: VSPColors.accent,
                       fontWeight: FontWeight.bold,
                       decoration: TextDecoration.underline,
                     ),
                   ),
                 ),
               ],
             ),
           )
        ],
      ),
    );
  }

  // Reuse logic from OwnerStadiumsScreen for visual consistency, simplified for horizontal list
  Widget _buildStadiumCard(Stadium stadium) {
    return VSPCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      border: Border.all(color: VSPColors.accent),
      child: Stack(
        children: [
          // Background Image
          ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            child: Image.network(
              stadium.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          // Top Left: Location Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Text(stadium.location, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
          
          // Bottom Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(VSPRadius.lg),
                  bottomRight: Radius.circular(VSPRadius.lg),
                ),
                color: Colors.black.withValues(alpha: 0.7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(stadium.name, style: Theme.of(context).textTheme.titleSmall, maxLines: 1),
                   const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(children: const [
                         Icon(Icons.male, color: VSPColors.textPrimary, size: 14),
                         SizedBox(width: 4),
                         Icon(Icons.location_on_outlined, color: VSPColors.textPrimary, size: 14),
                       ]),
                       Text('Cafeteria', style: Theme.of(context).textTheme.labelSmall),
                       Text('Seats K${(stadium.seatsCapacity/1000).toStringAsFixed(0)} person', style: Theme.of(context).textTheme.labelSmall),
                     ],
                   ),
                    const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text('Price ${NumberFormat('#,###').format(stadium.pricePerHour)} eg', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                        Text(stadium.area, style: Theme.of(context).textTheme.labelSmall),
                     ],
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: VSPColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.lg)),
            title: const Text('Delete Account?', style: TextStyle(color: VSPColors.error, fontWeight: FontWeight.bold)),
            content: const Text(
              'Are you sure? This action cannot be undone. You will lose all your data, stadiums, and match history permanently.',
              style: TextStyle(color: VSPColors.textSecondary, height: 1.5),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      text: 'Cancel',
                      height: 48,
                      color: VSPColors.surfaceAlt,
                      textColor: VSPColors.textPrimary,
                      onPressed: _isDeleting ? null : () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: VSPSpacing.md),
                  Expanded(
                    child: PrimaryButton(
                      text: 'Delete',
                      height: 48,
                      color: VSPColors.error,
                      textColor: VSPColors.background,
                      isLoading: _isDeleting,
                      onPressed: _isDeleting ? null : () async {
                        setDialogState(() => _isDeleting = true);
                        final authProvider = Provider.of<AuthProvider>(context, listen: false);
                        final success = await authProvider.deleteAccount();
                        
                        if (!context.mounted) return;
                        
                        if (success) {
                           Navigator.of(context).pushAndRemoveUntil(
                             MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                             (route) => false,
                           );
                        } else {
                          setDialogState(() => _isDeleting = false);
                          VSPFeedback.showError(context, authProvider.errorMessage ?? "Failed to delete account");
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          );
        }
      ),
    );
  }
}
