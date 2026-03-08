import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/utils/vsp_feedback.dart';

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
        VSPFeedback.showError(context, bookingProvider.errorMessage ?? 'Failed to create booking');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      VSPFeedback.showError(context, 'Payment failed: $e');
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
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: VSPColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: VSPColors.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Payment Gateway',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(VSPSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Booking Summary Card
            Container(
              padding: const EdgeInsets.all(VSPSpacing.md),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
                border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.bookingDraft.stadiumName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today, color: VSPColors.accent, size: 16),
                      const SizedBox(width: VSPSpacing.xs),
                      Text(
                        '${widget.bookingDraft.startTime.day}/${widget.bookingDraft.startTime.month}/${widget.bookingDraft.startTime.year}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                      const SizedBox(width: VSPSpacing.md),
                      const Icon(Icons.access_time, color: VSPColors.accent, size: 16),
                      const SizedBox(width: VSPSpacing.xs),
                      Text(
                        '${widget.bookingDraft.startTime.hour}:${widget.bookingDraft.startTime.minute.toString().padLeft(2, '0')} - ${widget.bookingDraft.endTime.hour}:${widget.bookingDraft.endTime.minute.toString().padLeft(2, '0')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Type: ${widget.bookingDraft.bookingType.name.toUpperCase()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                      ),
                      Text(
                        '${widget.bookingDraft.totalPrice.toInt()} ${widget.bookingDraft.currency}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: VSPColors.accent,
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
                color: VSPColors.textPrimary,
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
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [VSPColors.accent.withValues(alpha: 0.8), VSPColors.background],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(VSPRadius.xl),
                  border: Border.all(color: VSPColors.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Bank Card',
                      style: TextStyle(color: VSPColors.textSecondary, fontSize: 16),
                    ),
                    const Text(
                      '4582  1547  3265  1984',
                      style: TextStyle(
                        color: VSPColors.textPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Card Holder', style: TextStyle(color: VSPColors.textSecondary, fontSize: 10)),
                            const Text('MOHAMED SALAH', style: TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Expires', style: TextStyle(color: VSPColors.textSecondary, fontSize: 10)),
                            const Text('12/28', style: TextStyle(color: VSPColors.textPrimary, fontWeight: FontWeight.bold)),
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
                margin: const EdgeInsets.only(top: VSPSpacing.xs),
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.account_balance_wallet, color: VSPColors.accent, size: 48),
                    const SizedBox(height: VSPSpacing.md),
                    Text(
                      'Pay with Wallet',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: VSPSpacing.sm),
                    Text(
                      'Your wallet balance will be used for this payment.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],

            if (_selectedPaymentMethod == 'cash') ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(top: VSPSpacing.xs),
                padding: const EdgeInsets.all(VSPSpacing.lg),
                decoration: BoxDecoration(
                  color: VSPColors.surface,
                  borderRadius: BorderRadius.circular(VSPRadius.lg),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.money, color: VSPColors.accent, size: 48),
                    const SizedBox(height: VSPSpacing.md),
                    Text(
                      'Pay with Cash',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: VSPSpacing.sm),
                    Text(
                      'Pay cash at the stadium when you arrive.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 48),

            // Pay Button
            PrimaryButton(
              text: 'Pay ${widget.bookingDraft.totalPrice.toInt()} ${widget.bookingDraft.currency}',
              isLoading: _isLoading,
              onPressed: _processPayment,
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
        padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
        decoration: BoxDecoration(
          color: isSelected ? VSPColors.accent.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(VSPRadius.md),
          border: Border.all(
            color: isSelected ? VSPColors.accent : VSPColors.textSecondary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? VSPColors.accent : VSPColors.textSecondary, size: 20),
            const SizedBox(width: VSPSpacing.xs),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
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
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
        const SizedBox(height: VSPSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscureText,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: VSPColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(VSPRadius.md), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          ),
        ),
      ],
    );
  }
}
