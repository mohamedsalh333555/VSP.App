import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Help Center',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
           const Spacer(),
           
           // Suggestions
           Padding(
             padding: const EdgeInsets.symmetric(horizontal: 16),
             child: Row(
               children: [
                 Expanded(child: _buildSuggestionCard('Why Does The Earth Rotate?', 'Discover The Science Behind Earth\'s Motion.')),
                 const SizedBox(width: 12),
                 Expanded(child: _buildSuggestionCard('Write Me A Recommendation Letter', 'Get A Professional And Persuasive Letter Instantly.')),
               ],
             ),
           ),

           const SizedBox(height: 24),

           // Input Area
           Padding(
             padding: const EdgeInsets.all(16),
             child: Row(
               children: [
                 Expanded(
                   child: Container(
                     padding: const EdgeInsets.symmetric(horizontal: 16),
                     height: 50,
                     decoration: BoxDecoration(
                       color: AppTheme.cardBackground,
                       borderRadius: BorderRadius.circular(25),
                       border: Border.all(color: Colors.grey.withOpacity(0.5)),
                     ),
                     child: Row(
                       children: [
                         const Expanded(child: Text('Generate A Name Of ....', style: TextStyle(color: AppTheme.textSecondary))),
                         Icon(Icons.upload_file, color: AppTheme.textSecondary.withOpacity(0.7)),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Container(
                   width: 50,
                   height: 50,
                   decoration: const BoxDecoration(
                     color: AppTheme.neonGreen,
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.send, color: Colors.black),
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(16),
      height: 140,
      decoration: BoxDecoration(
         color: AppTheme.cardBackground,
         borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
           const Spacer(),
          Text(subtitle, style: const TextStyle(color: Colors.teal, fontSize: 11, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
