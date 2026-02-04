import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

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
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Methods',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
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
                  backgroundColor: AppTheme.neonGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: const Text('Add Payment', style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
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
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: isSelected ? Border.all(color: AppTheme.neonGreen) : Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Row(
          children: [
             // Placeholder Icon
             Container(
               width: 32,
               height: 32,
               decoration: BoxDecoration(
                 color: Colors.white,
                 borderRadius: BorderRadius.circular(4),
               ),
               // Placeholder for actual brand icons
               child: Center(child: Text(title[0], style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))), 
             ),
             const SizedBox(width: 16),
             Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 16)),
             const Spacer(),
             Container(
               width: 24,
               height: 24,
               decoration: BoxDecoration(
                 shape: BoxShape.circle,
                 border: Border.all(color: isSelected ? AppTheme.neonGreen : Colors.grey, width: 2),
               ),
               child: isSelected ? Center(child: Container(width: 12, height: 12, decoration: const BoxDecoration(color: AppTheme.neonGreen, shape: BoxShape.circle))) : null,
             )
          ],
        ),
      ),
    );
  }
}
