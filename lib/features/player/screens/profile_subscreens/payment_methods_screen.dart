import 'package:flutter/material.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int _selectedMethod = 0; // 0: InstaPay

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
          'Payment Methods',
          style: Theme.of(context).textTheme.displaySmall,
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildPaymentOption(0, 'Insta Pay', 'assets/icons/instapay.png'), // Mock icon logic
            const SizedBox(height: 12),
            _buildPaymentOption(1, 'Etisalat Wallet', 'assets/icons/etisalat.png'),
            const SizedBox(height: 12),
            _buildPaymentOption(2, 'Vodafone Wallet', 'assets/icons/vodafone.png'),
            const SizedBox(height: 12),
            _buildPaymentOption(3, 'Orange Wallet', 'assets/icons/orange.png'),
            const SizedBox(height: 12),
            _buildPaymentOption(4, 'We Wallet', 'assets/icons/we.png'),

            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: VSPColors.accent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(VSPRadius.md)),
                ),
                child: const Text('Add Payment', style: TextStyle(color: VSPColors.background, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption(int value, String title, String iconPath) {
    final isSelected = _selectedMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: isSelected ? Border.all(color: VSPColors.accent) : Border.all(color: VSPColors.divider.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
             // Placeholder Icon
             Container(
               width: 32,
               height: 32,
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(VSPRadius.xs),
               ),
               // Placeholder for actual brand icons
               child: Center(child: Text(title[0], style: const TextStyle(color: VSPColors.background, fontWeight: FontWeight.bold))), 
             ),
             const SizedBox(width: 16),
             Text(title, style: Theme.of(context).textTheme.bodyLarge),
             const Spacer(),
             Container(
               width: 24,
               height: 24,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: isSelected ? VSPColors.accent : VSPColors.divider, width: 2),
               ),
               child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: VSPColors.accent, shape: BoxShape.circle))) : null,
             )
          ],
        ),
      ),
    );
  }
}
