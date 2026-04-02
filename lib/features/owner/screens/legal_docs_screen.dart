import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import 'id_verification_screen.dart';

class LegalDocsScreen extends StatelessWidget {
  const LegalDocsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, matchTextDirection: true, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Owner information',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Container(
                  width: index == 0 ? 30 : 8,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: index == 0 ? VSPColors.accent : VSPColors.divider, // Step 1 of Owner Info
                    borderRadius: BorderRadius.circular(VSPRadius.xs),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            Text(
              'Upload an image',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

             // Main Upload Button
            Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: VSPColors.accent, 
                borderRadius: BorderRadius.circular(VSPRadius.md),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const Icon(Icons.add_photo_alternate_outlined, size: 40, color: Colors.black),
                   const SizedBox(height: 8),
                   Text(
                     'Click to upload', 
                     style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black, fontWeight: FontWeight.bold),
                   ),
                   Text(
                     'JPG, JPEG, PNG less than 10MB', 
                     style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.black.withValues(alpha: 0.7)),
                   ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _buildLabel(context, 'Tax card'),
            _buildUploadedFile(context, 'Tax card', '200 KB'),

            const SizedBox(height: 16),

            _buildLabel(context, 'Commercial register'),
             _buildUploadedFile(context, 'commercial register', '200 KB'),

            const SizedBox(height: 40),

            PrimaryButton(
              text: 'Save',
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const IdVerificationScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  Widget _buildUploadedFile(BuildContext context, String name, String size) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(VSPRadius.md),
        border: Border.all(color: VSPColors.accent),
        color: VSPColors.accent.withValues(alpha: 0.1),
      ),
      child: Row(
        children: [
          const Icon(Icons.image_outlined, color: VSPColors.textPrimary),
          const SizedBox(width: VSPSpacing.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.bodyMedium),
              Text(size, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
              Text(
                'Click to view', 
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: VSPColors.textPrimary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

