import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

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
          'Help Center',
          style: Theme.of(context).textTheme.displaySmall,
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
                       color: VSPColors.surface,
                       borderRadius: BorderRadius.circular(VSPRadius.full),
                       border: Border.all(color: VSPColors.divider.withValues(alpha: 0.5)),
                     ),
                     child: Row(
                       children: [
                         const Expanded(child: Text('Generate A Name Of ....', style: TextStyle(color: VSPColors.textSecondary))),
                         Icon(Icons.upload_file, color: VSPColors.textSecondary.withValues(alpha: 0.7)),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Container(
                   width: 50,
                   height: 50,
                   decoration: const BoxDecoration(
                     color: VSPColors.accent,
                     shape: BoxShape.circle,
                   ),
                   child: const Icon(Icons.send, color: VSPColors.background),
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
         color: VSPColors.surface,
         borderRadius: BorderRadius.circular(VSPRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: VSPColors.textPrimary, fontSize: 13, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
           const Spacer(),
          Text(subtitle, style: const TextStyle(color: VSPColors.accent, fontSize: 11, height: 1.4), maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}
