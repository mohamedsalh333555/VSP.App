import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import 'booking_success_screen.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final double totalPrice;
  final DateTime bookingDate;
  final String timeRange;

  const PaymentGatewayScreen({
    super.key,
    required this.totalPrice,
    required this.bookingDate,
    required this.timeRange,
  });

  @override
  State<PaymentGatewayScreen> createState() => _PaymentGatewayScreenState();
}

class _PaymentGatewayScreenState extends State<PaymentGatewayScreen> {
  final _cardNumberController = TextEditingController(text: '4582 1547 3265 1984');
  final _expiryController = TextEditingController(text: '12/28');
  final _cvvController = TextEditingController(text: '123');
  final _nameController = TextEditingController(text: 'Mohamed Salah');

  bool _isLoading = false;

  void _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate Network Request
    await Future.delayed(const Duration(milliseconds: 1500)); // 1.5 Seconds

    if (mounted) {
       setState(() {
         _isLoading = false;
       });
       
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => BookingSuccessScreen(
            totalPrice: widget.totalPrice,
            paymentMethod: 'Credit Card',
            bookingDate: widget.bookingDate,
            timeRange: widget.timeRange,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: const Text(
          'Payment Gateway',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Agency FB',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Card Preview (Mock Visual)
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1C3A00), Colors.black],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bank Card',
                    style: TextStyle(color: Colors.white70, fontSize: 16, fontFamily: 'Agency FB'),
                  ),
                  const Text(
                    '4582  1547  3265  1984',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      fontFamily: 'Agency FB', 
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Card Holder', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('MOHAMED SALAH', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Expires', style: TextStyle(color: Colors.white54, fontSize: 10)),
                          Text('12/28', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // Form Fields
            _buildTextField('Card Number', _cardNumberController, TextInputType.number),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField('Expiry Date', _expiryController, TextInputType.datetime)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField('CVV', _cvvController, TextInputType.number, obscureText: true)),
              ],
            ),
            const SizedBox(height: 16),
             _buildTextField('Card Holder Name', _nameController, TextInputType.name),
            
            const SizedBox(height: 48),

            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _processPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.neonGreen,
                  foregroundColor: AppTheme.darkBackground,
                   disabledBackgroundColor: AppTheme.neonGreen.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.darkBackground,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Pay ${widget.totalPrice.toInt()} EGP',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, TextInputType type, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscureText,
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.cardBackground,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
