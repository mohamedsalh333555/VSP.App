import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';
import 'booking_success_screen.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/providers/booking_provider.dart';
import '../../../core/utils/vsp_feedback.dart';
import '../../../shared/widgets/vsp_fade_in_item.dart';

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
  final _nameController = TextEditingController();

  bool _isLoading = false;
  String _selectedPaymentMethod = 'card';

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.bookingDraft.playerTeamName ?? 'M. Salah';
  }

  void _processPayment() async {
    setState(() {
      _isLoading = true;
    });

    // Simulate Payment Processing
    await Future.delayed(const Duration(milliseconds: 2000));

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
      body: Stack(
        children: [
          // Background Glows for Premium feel
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VSPColors.accent.withOpacity(0.12),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SingleChildScrollView(
            padding: const EdgeInsets.all(VSPSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VSPFadeInItem(
                  delay: Duration(milliseconds: 100),
                  child: _SectionHeader(title: 'Booking Summary'),
                ),
                const SizedBox(height: 16),
                
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 200),
                  child: _BookingSummaryCard(bookingDraft: widget.bookingDraft),
                ),
                
                const SizedBox(height: 32),

                const VSPFadeInItem(
                  delay: Duration(milliseconds: 300),
                  child: _SectionHeader(title: 'Choose Payment Method'),
                ),
                const SizedBox(height: 16),
                
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 400),
                  child: Row(
                    children: [
                      _buildPaymentMethodChip('card', 'Card', Icons.credit_card),
                      const SizedBox(width: 12),
                      _buildPaymentMethodChip('wallet', 'Wallet', Icons.account_balance_wallet),
                      const SizedBox(width: 12),
                      _buildPaymentMethodChip('cash', 'Cash', Icons.payments_outlined),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Dynamic Content based on selection
                if (_selectedPaymentMethod == 'card') 
                  _CardPaymentContent(
                    cardNumberController: _cardNumberController,
                    expiryController: _expiryController,
                    cvvController: _cvvController,
                    nameController: _nameController,
                  )
                else if (_selectedPaymentMethod == 'wallet')
                  const VSPFadeInItem(
                    delay: Duration(milliseconds: 100),
                    child: _SimpleInfoCard(
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'VSP Wallet',
                      subtitle: 'The amount will be deducted from your available balance. Professional and fast.',
                    ),
                  )
                else
                  const VSPFadeInItem(
                    delay: Duration(milliseconds: 100),
                    child: _SimpleInfoCard(
                      icon: Icons.payments_outlined,
                      title: 'Cash Payment',
                      subtitle: 'Pay at the venue. Please note that cancellation policies still apply.',
                    ),
                  ),
                
                const SizedBox(height: 40),

                // Secure Transaction Badge
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 550),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.security, color: VSPColors.accent.withOpacity(0.5), size: 14),
                        const SizedBox(width: 8),
                        Text(
                          'Secure end-to-end encrypted transaction',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: VSPColors.textSecondary.withOpacity(0.5),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                // Pay Button
                VSPFadeInItem(
                  delay: const Duration(milliseconds: 600),
                  child: PrimaryButton(
                    text: 'Confirm & Pay ${widget.bookingDraft.totalPrice.toInt()} ${widget.bookingDraft.currency}',
                    isLoading: _isLoading,
                    onPressed: _processPayment,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodChip(String value, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPaymentMethod = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: VSPSpacing.md),
          decoration: BoxDecoration(
            color: isSelected ? VSPColors.accent.withOpacity(0.1) : VSPColors.surface,
            borderRadius: BorderRadius.circular(VSPRadius.md),
            border: Border.all(
              color: isSelected ? VSPColors.accent : VSPColors.divider,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon, 
                color: isSelected ? VSPColors.accent : VSPColors.textSecondary, 
                size: 24
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? VSPColors.accent : VSPColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: VSPColors.accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final BookingDraft bookingDraft;
  const _BookingSummaryCard({required this.bookingDraft});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(VSPSpacing.lg),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: VSPColors.accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(VSPRadius.md),
                ),
                child: const Icon(Icons.stadium_outlined, color: VSPColors.accent),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bookingDraft.stadiumName,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                    ),
                    Text(
                      bookingDraft.bookingType == BookingType.challenge ? 'Challenge Match' : 'Private Booking',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(color: VSPColors.divider, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem(context, Icons.calendar_today_outlined, 
                '${bookingDraft.startTime.day} ${_getMonthName(bookingDraft.startTime.month)}'),
              _buildSummaryItem(context, Icons.access_time, 
                '${bookingDraft.startTime.hour}:${bookingDraft.startTime.minute.toString().padLeft(2, '0')}'),
              _buildSummaryItem(context, Icons.sports_soccer, 
                bookingDraft.bookingType == BookingType.challenge ? 'Ranked' : 'Friendly'),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(VSPSpacing.md),
            decoration: BoxDecoration(
              color: VSPColors.background,
              borderRadius: BorderRadius.circular(VSPRadius.md),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Subtotal Amount',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary),
                ),
                Text(
                  '${bookingDraft.totalPrice.toInt()} ${bookingDraft.currency}',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: VSPColors.accent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: VSPColors.accent, size: 14),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }
}

class _CardPaymentContent extends StatelessWidget {
  final TextEditingController cardNumberController;
  final TextEditingController expiryController;
  final TextEditingController cvvController;
  final TextEditingController nameController;

  const _CardPaymentContent({
    required this.cardNumberController,
    required this.expiryController,
    required this.cvvController,
    required this.nameController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Premium Glass Card Visual
        VSPFadeInItem(
          delay: const Duration(milliseconds: 500),
          child: Container(
            height: 200,
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              boxShadow: [
                BoxShadow(
                  color: VSPColors.accent.withOpacity(0.25),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(VSPRadius.xl),
              child: Stack(
                children: [
                  // Animated background for the card
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  Positioned(
                    top: -50,
                    right: -50,
                    child: Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: VSPColors.accent.withOpacity(0.2),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    left: -30,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white10,
                      ),
                    ),
                  ),
                  // Glass Layer
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(VSPRadius.xl),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      padding: const EdgeInsets.all(VSPSpacing.xl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Image.network(
                                'https://upload.wikimedia.org/wikipedia/commons/thumb/5/5e/Visa_Inc._logo.svg/2560px-Visa_Inc._logo.svg.png',
                                height: 20,
                                color: Colors.white.withOpacity(0.8),
                              ),
                              const Icon(Icons.wifi, color: Colors.white38, size: 24),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            cardNumberController.text.isEmpty ? '**** **** **** ****' : cardNumberController.text,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 4,
                              fontFamily: 'Courier',
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('CARD HOLDER', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    nameController.text.toUpperCase(), 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('EXPIRES', style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 9, letterSpacing: 1.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    expiryController.text, 
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                                  ),
                                ],
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 32),

        VSPFadeInItem(
          delay: const Duration(milliseconds: 600),
          child: _buildTextField(context, 'Card Number', cardNumberController, TextInputType.number, icon: Icons.credit_card),
        ),
        const SizedBox(height: 16),
        VSPFadeInItem(
          delay: const Duration(milliseconds: 700),
          child: Row(
            children: [
              Expanded(child: _buildTextField(context, 'Expiry Date', expiryController, TextInputType.datetime, icon: Icons.calendar_today)),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField(context, 'CVV', cvvController, TextInputType.number, obscureText: true, icon: Icons.lock_outline)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        VSPFadeInItem(
          delay: const Duration(milliseconds: 800),
          child: _buildTextField(context, 'Card Holder Name', nameController, TextInputType.name, icon: Icons.person_outline),
        ),
      ],
    );
  }

  Widget _buildTextField(BuildContext context, String label, TextEditingController controller, TextInputType type, {bool obscureText = false, IconData? icon}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: VSPColors.textSecondary,
            fontWeight: FontWeight.bold,
          )
        ),
        const SizedBox(height: VSPSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: type,
          obscureText: obscureText,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            filled: true,
            fillColor: VSPColors.surface,
            prefixIcon: icon != null ? Icon(icon, color: VSPColors.accent, size: 20) : null,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.md), 
              borderSide: const BorderSide(color: VSPColors.divider)
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(VSPRadius.md), 
              borderSide: const BorderSide(color: VSPColors.accent)
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.md),
          ),
        ),
      ],
    );
  }
}

class _SimpleInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SimpleInfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(VSPSpacing.xl),
      decoration: BoxDecoration(
        color: VSPColors.surface,
        borderRadius: BorderRadius.circular(VSPRadius.xl),
        border: Border.all(color: VSPColors.divider),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: VSPColors.accent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: VSPColors.accent, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: VSPColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
