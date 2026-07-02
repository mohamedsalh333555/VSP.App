import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Privacy Policy',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag, 
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection('Data Collection', 'We Collect Information You Provide Directly To Us, Such As When You Create An Account, Enroll In Courses, Or Contact Us For Support. This May Include Your Name, Email Address, Contact Details, And Course Preferences.'),
            _buildSection('Data Use', 'We Use Your Data To Provide And Improve Our Services, Personalize Your Learning Experience, Communicate With You About Courses And Updates, And Respond To Your Inquiries. We May Also Use Aggregated And Anonymized Data For Analytical Purposes.'),
            _buildSection('Data Sharing', 'We May Share Your Information With Our Partners, Such As ITI, NTI, And TIEC, To Facilitate Course Delivery And Support. We Do Not Sell Your Personal Data To Third Parties. We May Disclose Information If Required By Law Or To Protect Our Rights And Safety.'),
            _buildSection('User Rights', 'You Have The Right To Access, Correct, Or Delete Your Personal Data. You Can Manage Your Account Settings Or Contact Us To Exercise These Rights. We Retain Your Data As Long As Necessary To Provide Services And Comply With Legal Obligations.'),
             _buildSection('Data Collection', 'We Collect Information You Provide Directly To Us, Such As When You Create An Account, Enroll In Courses, Or Contact Us For Support. This May Include Your Name, Email Address, Contact Details, And Course Preferences.'),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(color: VSPColors.textSecondary, fontSize: 13, height: 1.5)),
        ],
      ),
    );
  }
}

