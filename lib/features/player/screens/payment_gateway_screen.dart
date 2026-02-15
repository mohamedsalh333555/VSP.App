import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';

class PaymentGatewayScreen extends StatefulWidget {
  final BookingDraft bookingDraft;

  const PaymentGatewayScreen({
    super.key,
    required this.bookingDraft,
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
  String _selectedPaymentMethod = 'card';

  void _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate Payment Processing
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    try {
      // Get providers
      final bookingProvider = Provider.of<BookingProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      // Get current user ID (or use demo user)
      final userId = authProvider.currentUser?.uid ?? 'demo_user';

      // Update draft with payment info
      final draftWithPayment = widget.bookingDraft.copyWith(
        paymentMethod: _selectedPaymentMethod,
        paymentTransactionId: 'TXN_${DateTime.now().millisecondsSinceEpoch}',
      );

      // Create booking in database
      final booking = await bookingProvider.createBooking(draftWithPayment, userId);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (booking != null) {
        // Navigate to success screen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BookingSuccessScreen(
              booking: booking,
            ),
          ),
        );
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(bookingProvider.errorMessage ?? 'Failed to create booking'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Payment failed: $e'),
          backgroundColor: Colors.red,
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
            // Booking Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bookingDraft.stadiumName,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: AppTheme.neonGreen, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.bookingDraft.startTime.day}/${widget.bookingDraft.startTime.month}/${widget.bookingDraft.startTime.year}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(width: 16),
                      const Icon(Icons.access_time, color: AppTheme.neonGreen, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.bookingDraft.startTime.hour}:${widget.bookingDraft.startTime.minute.toString().padLeft(2, '0')} - ${widget.bookingDraft.endTime.hour}:${widget.bookingDraft.endTime.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Type: ${widget.bookingDraft.bookingType.name.toUpperCase()}',
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                      Text(
                        '${widget.bookingDraft.totalPrice.toInt()} ${widget.bookingDraft.currency}',
                        style: const TextStyle(
                          color: AppTheme.neonGreen,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),

            // Payment Method Selection
            const Text(
              'Payment Method',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildPaymentMethodChip('card', 'Card', Icons.credit_card),
                const SizedBox(width: 12),
                _buildPaymentMethodChip('wallet', 'Wallet', Icons.account_balance_wallet),
                const SizedBox(width: 12),
                _buildPaymentMethodChip('cash', 'Cash', Icons.money),
              ],
            ),

            const SizedBox(height: 24),

            // Card Preview (Only show for card payment)
            if (_selectedPaymentMethod == 'card') ...[
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
                  border: Border.all(color: AppTheme.neonGreen.withValues(alpha: 0.3)),
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
              
              const SizedBox(height: 24),

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
            ],
            
            // Wallet/Cash info
            if (_selectedPaymentMethod == 'wallet') ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.account_balance_wallet, color: AppTheme.neonGreen, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Pay with Wallet',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your wallet balance will be used for this payment.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            if (_selectedPaymentMethod == 'cash') ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.money, color: AppTheme.neonGreen, size: 48),
                    SizedBox(height: 12),
                    Text(
                      'Pay with Cash',
                      style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pay cash at the stadium when you arrive.',
                      style: TextStyle(color: AppTheme.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
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
                  disabledBackgroundColor: AppTheme.neonGreen.withValues(alpha: 0.5),
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
                        'Pay ${widget.bookingDraft.totalPrice.toInt()} ${widget.bookingDraft.currency}',
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

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.neonGreen.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.neonGreen : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
