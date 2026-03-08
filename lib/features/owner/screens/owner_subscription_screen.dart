import 'package:flutter/material.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';

class OwnerSubscriptionScreen extends StatefulWidget {
  const OwnerSubscriptionScreen({super.key});

  @override
  State<OwnerSubscriptionScreen> createState() => _OwnerSubscriptionScreenState();
}

class _OwnerSubscriptionScreenState extends State<OwnerSubscriptionScreen> {
  int _selectedTabIndex = 0; // 0: Monthly, 1: Yearly
  int _selectedPlanIndex = 1; // Default select middle plan (Free trial)

  final List<Map<String, dynamic>> _plans = [
    {
      'title': 'Pro',
      'subtitle': 'Up To 8 Stadiums',
      'price': '25',
      'period': '/ 14 day', // Keeping as per screenshot text even if odd
    },
    {
      'title': 'Free trial',
      'subtitle': '1 Stadium',
      'price': '0',
      'period': '/ 14 day',
    },
    {
      'title': 'Basic',
      'subtitle': 'Up To 3 Stadiums',
      'price': '12',
      'period': '/ 14 day',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      extendBodyBehindAppBar: true, // Allow background image behind app bar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Subscription',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: Stack(
        children: [
          // 1. Background Image with Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.6, // Covers top 60%
            child: Stack(
              children: [
                Image.network(
                  'https://images.unsplash.com/photo-1577223625816-7546f13df25d?w=800&q=80', // Real Stadium Top View
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
                // Gradient Overlay
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.3),
                        VSPColors.background.withValues(alpha: 0.8),
                        VSPColors.background,
                      ],
                      stops: const [0.0, 0.7, 1.0],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 2. Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                // Toggle Switch (Monthly / Yearly)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: VSPColors.surface, // Dark Grey Background
                      borderRadius: BorderRadius.circular(VSPRadius.xl),
                    ),
                    child: Row(
                      children: [
                        _buildToggleButton('Monthly', 0),
                        _buildToggleButton('Yearly (20% Off)', 1),
                      ],
                    ),
                  ),
                ),
                
                const Spacer(), // Push plans to bottom area
                
                // Plans Row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end, // Align bottom
                    children: [
                      Expanded(child: _buildPlanCard(0, isSmall: true)),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(child: _buildPlanCard(1, isSmall: false)), // Middle one bigger/prominent
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(child: _buildPlanCard(2, isSmall: true)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                // Bottom Buttons
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: VSPColors.divider),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(VSPRadius.md),
                        ),
                      ),
                      child: Text(
                        'Custom plan',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md),
                  child: PrimaryButton(
                    text: 'Confirm',
                    onPressed: () {
                      // Confirm Logic
                      Navigator.pop(context);
                    },
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String text, int index) {
    bool isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent : Colors.transparent, // Solid Neon Green for active
            borderRadius: BorderRadius.circular(VSPRadius.xl),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.black : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlanCard(int index, {required bool isSmall}) {
    bool isSelected = _selectedPlanIndex == index;
    final plan = _plans[index];
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPlanIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: isSmall ? 150 : 170, // Slight adjustments
        decoration: BoxDecoration(
          color: VSPColors.surface, // Less transparent
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? VSPColors.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        padding: const EdgeInsets.all(10), // Reduced Padding
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              plan['title'],
              style: Theme.of(context).textTheme.titleSmall,
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: 4),
            Text(
              plan['subtitle'],
              style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
             Column( // Changed to Column for price/period to handle overflow better in narrow spaces
               mainAxisAlignment: MainAxisAlignment.end,
               children: [
                 FittedBox(
                   fit: BoxFit.scaleDown,
                   child: Text(
                     '\$${plan['price']}',
                     style: Theme.of(context).textTheme.displayMedium?.copyWith(
                           color: VSPColors.accent,
                           fontWeight: FontWeight.bold,
                         ),
                   ),
                 ),
                  Text(
                   plan['period'],
                   style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent),
                   maxLines: 1,
                  ),
               ],
             ),
          ],
        ),
      ),
    );
  }
}
