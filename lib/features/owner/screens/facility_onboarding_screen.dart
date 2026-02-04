import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/providers/language_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/config/app_config.dart';
import '../../../shared/widgets/custom_text_field.dart';
import '../../../shared/widgets/primary_button.dart';
import 'document_upload_screen.dart';

/// شاشة تسجيل بيانات الملعب - للمالك فقط
class FacilityOnboardingScreen extends StatefulWidget {
  const FacilityOnboardingScreen({super.key});

  @override
  State<FacilityOnboardingScreen> createState() => _FacilityOnboardingScreenState();
}

class _FacilityOnboardingScreenState extends State<FacilityOnboardingScreen> {
  final _stadiumNameController = TextEditingController();
  final _locationController = TextEditingController();
  final _facebookController = TextEditingController();
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _stadiumNameController.dispose();
    _locationController.dispose();
    _facebookController.dispose();
    _instagramController.dispose();
    _twitterController.dispose();
    super.dispose();
  }

  Future<void> _handleContinue() async {
    // Demo Mode Bypass
    if (AppConfig.demoMode) {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const DocumentUploadScreen(),
          ),
        );
      }
      return;
    }

    if (_stadiumNameController.text.isEmpty || _locationController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    // محاكاة حفظ البيانات
    await Future.delayed(const Duration(seconds: 1));

    setState(() => _isLoading = false);

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const DocumentUploadScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color(0xFF0A0A0A),
              Color(0xFF1A3A1A),
              Color(0xFF0A0A0A),
            ],
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Back Button
                IconButton(
                  icon: Icon(
                    languageProvider.isArabic
                        ? Icons.arrow_forward
                        : Icons.arrow_back,
                    color: AppTheme.textPrimary,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  languageProvider.getText(AppStrings.facilityDetails),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                // Subtitle
                Text(
                  languageProvider.isArabic
                      ? 'أدخل بيانات ملعبك لإكمال التسجيل'
                      : 'Enter your facility details to complete registration',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 40),

                // Stadium Name
                CustomTextField(
                  controller: _stadiumNameController,
                  hintText: languageProvider.getText(AppStrings.stadiumName),
                  prefixIcon: Icons.stadium,
                ),

                const SizedBox(height: 20),

                // Location
                CustomTextField(
                  controller: _locationController,
                  hintText: languageProvider.getText(AppStrings.location),
                  prefixIcon: Icons.location_on_outlined,
                ),

                const SizedBox(height: 30),

                // Social Media Section
                Text(
                  languageProvider.getText(AppStrings.socialMedia),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Facebook
                CustomTextField(
                  controller: _facebookController,
                  hintText: 'Facebook',
                  prefixIcon: Icons.facebook,
                ),

                const SizedBox(height: 16),

                // Instagram
                CustomTextField(
                  controller: _instagramController,
                  hintText: 'Instagram',
                  prefixIcon: Icons.camera_alt_outlined,
                ),

                const SizedBox(height: 16),

                // Twitter
                CustomTextField(
                  controller: _twitterController,
                  hintText: 'Twitter',
                  prefixIcon: Icons.alternate_email,
                ),

                const SizedBox(height: 40),

                // Continue Button
                PrimaryButton(
                  text: languageProvider.getText(AppStrings.continueButton),
                  onPressed: () {
                    if (_isLoading) return;
                    _handleContinue();
                  },
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
