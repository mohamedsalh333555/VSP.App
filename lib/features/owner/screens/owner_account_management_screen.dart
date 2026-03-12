import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/ui/components/vsp_card.dart';
import '../../../shared/widgets/primary_button.dart';
import '../../../data/models.dart';

class OwnerAccountManagementScreen extends StatefulWidget {
  const OwnerAccountManagementScreen({super.key});

  @override
  State<OwnerAccountManagementScreen> createState() => _OwnerAccountManagementScreenState();
}

class _OwnerAccountManagementScreenState extends State<OwnerAccountManagementScreen> {
  // Mock Data
  final TextEditingController _nameController = TextEditingController(text: 'Sal adc');
  final TextEditingController _phoneController = TextEditingController(text: '+20 01111000222');
  final TextEditingController _emailController = TextEditingController(text: 'hana.mohamed@gmail.com');
  final TextEditingController _socialController = TextEditingController(text: 'https://www.facebook.com/search/pages/?q=VSPS&sde=Abrg...'); // Truncated as per image
  
  List<Stadium> _stadiums = [];

  @override
  void initState() {
    super.initState();
    // Mock Stadiums Matches the screenshot
    _stadiums = [
      Stadium(
        id: '1',
        name: 'Santiago Bernabeu 11 VS 11 Football',
        location: 'Madrid',
        imageUrl: 'https://images.unsplash.com/photo-1556056504-5c7696c4c28d?w=800&h=600&fit=crop&q=80',
        type: 'Football',
        size: '11 VS 11',
        baths: 5,
        cafeteria: 2,
        seatsCapacity: 90000,
        pricePerHour: 1000000,
        area: 'Jerash',
        isFavorite: false,
        address: 'Madrid, Spain',
        pitchCondition: 'Excellent',
      ),
      // Add more if needed for horizontal scroll demo
      Stadium(
         id: '2',
         name: 'Salam Acd',
         location: 'Aswan',
         imageUrl: 'https://images.unsplash.com/photo-1624880357913-a8539238245b?w=800&h=600&fit=crop&q=80',
         type: 'Volleyball',
         size: '8 VS 8',
         baths: 2,
         cafeteria: 1,
         seatsCapacity: 50,
         pricePerHour: 250,
         area: 'Jerash',
         isFavorite: false,
         address: 'Aswan, Egypt',
         pitchCondition: 'Good',
       ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VSPColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Text(
          'Account',
          style: Theme.of(context).textTheme.displaySmall,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // Space for button
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Stadium Selector (Horizontal List)
            SizedBox(
              height: 220, // Height for card + padding
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: VSPSpacing.sm),
                scrollDirection: Axis.horizontal,
                itemCount: _stadiums.length,
                itemBuilder: (context, index) {
                  return Container(
                    width: 300, // Fixed width for horizontal items
                    margin: const EdgeInsets.only(right: VSPSpacing.md),
                    child: _buildStadiumCard(_stadiums[index]),
                  );
                },
              ),
            ),
            
            const SizedBox(height: 20),

            // 2. Personal Info Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('Owner Name'),
                   _buildTextField(_nameController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Number'),
                   _buildTextField(_phoneController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Email'),
                   _buildTextField(_emailController),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Add Address'),
                   // Map Widget Placeholder
                   Container(
                     height: 150,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(VSPRadius.md),
                       image: const DecorationImage(
                         image: NetworkImage('https://images.unsplash.com/photo-1569336415962-a4bd9f69cd83?w=800&q=80'), // Map placeholder
                         fit: BoxFit.cover,
                       ),
                       border: Border.all(color: VSPColors.divider),
                     ),
                   ),
                   // Address formatted box below map
                   Container(
                     width: double.infinity,
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: VSPColors.surface, // Dark box
                       borderRadius: BorderRadius.only(
                         bottomLeft: Radius.circular(VSPRadius.md),
                         bottomRight: Radius.circular(VSPRadius.md),
                       ),
                     ),
                     child: Text( // Arabic Address as plain text for now, right aligned if RTL, but keeping English LTR for structure
                       'مصر - أسوان - مركز شباب الساحة',
                       textAlign: TextAlign.right,
                       style: Theme.of(context).textTheme.bodyMedium,
                     ),
                   ),
                   
                   const SizedBox(height: 16),
                   _buildInputLabel('Social media'),
                   _buildTextField(_socialController),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 3. Documents (Read Only)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _buildInputLabel('National ID front'),
                   _buildDocumentCard('National ID front', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('National ID back'),
                   _buildDocumentCard('National ID Back', '500 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Tax card'), // Typo from image 'Tex card' corrected to 'Tax card' unless strictly 'Tex' required. Image says 'Tex card' in label, 'Tax card' in box. I will use 'Tax card'.
                   _buildDocumentCard('Tax card', '300 KB'),
                   const SizedBox(height: 16),
                   
                   _buildInputLabel('Commercial register'),
                   _buildDocumentCard('commercial register', '200 KB'),
                ],
              ),
            ),
          ],
        ),
      ),
      // 4. Fixed Confirm Button
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(VSPSpacing.md, VSPSpacing.md, VSPSpacing.md, MediaQuery.of(context).padding.bottom + VSPSpacing.md),
        color: VSPColors.background,
        child: PrimaryButton(
          text: 'Confirm',
          onPressed: () {
             Navigator.pop(context); // Go back on confirm
          },
        ),
      ),
    );
  }
  
  Widget _buildInputLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: VSPSpacing.xs, left: 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(
        color: VSPColors.surface, // Darker input bg
        borderRadius: BorderRadius.circular(VSPRadius.md), 
        border: Border.all(color: VSPColors.divider, width: 0.5),
      ),
      child: TextField(
        controller: controller,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildDocumentCard(String title, String size) {
    return VSPCard(
      padding: const EdgeInsets.all(VSPSpacing.md),
      margin: EdgeInsets.zero,
      color: VSPColors.accent.withValues(alpha: 0.05),
      border: Border.all(color: VSPColors.accent.withValues(alpha: 0.2)),
      child: Row(
        children: [
           const Icon(Icons.image_outlined, color: VSPColors.textPrimary, size: 24),
           const SizedBox(width: VSPSpacing.md),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: Theme.of(context).textTheme.titleSmall),
                 Text(size, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                 const SizedBox(height: 4),
                 GestureDetector(
                   onTap: () {
                     // View logic
                   },
                   child: Text(
                     'Click to view',
                     style: Theme.of(context).textTheme.labelMedium?.copyWith(
                       color: VSPColors.accent,
                       fontWeight: FontWeight.bold,
                       decoration: TextDecoration.underline,
                     ),
                   ),
                 ),
               ],
             ),
           )
        ],
      ),
    );
  }

  // Reuse logic from OwnerStadiumsScreen for visual consistency, simplified for horizontal list
  Widget _buildStadiumCard(Stadium stadium) {
    return VSPCard(
      padding: EdgeInsets.zero,
      margin: EdgeInsets.zero,
      border: Border.all(color: VSPColors.accent),
      child: Stack(
        children: [
          // Background Image
          ClipRRect(
            borderRadius: BorderRadius.circular(VSPRadius.lg),
            child: Image.network(
              stadium.imageUrl,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          // Overlay
          Container(
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(VSPRadius.lg),
              color: Colors.black.withValues(alpha: 0.4),
            ),
          ),
          // Top Left: Location Badge
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(VSPRadius.xl),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: VSPColors.accent, size: 14),
                  const SizedBox(width: 4),
                  Text(stadium.location, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
            ),
          ),
          
          // Top Right: Edit Icon
          Positioned(
            top: 12,
            right: 12,
            child: InkWell(
              onTap: () {
                 // Navigate to Edit Stadium
                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit Stadium - Coming Soon')));
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(color: VSPColors.accent),
                ),
                child: const Icon(Icons.edit_outlined, color: VSPColors.accent, size: 18),
              ),
            ),
          ),

          // Bottom Info
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(VSPRadius.lg),
                  bottomRight: Radius.circular(VSPRadius.lg),
                ),
                color: Colors.black.withValues(alpha: 0.7),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                   Text(stadium.name, style: Theme.of(context).textTheme.titleSmall, maxLines: 1),
                   const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Row(children: const [
                         Icon(Icons.male, color: VSPColors.textPrimary, size: 14),
                         SizedBox(width: 4),
                         Icon(Icons.location_on_outlined, color: VSPColors.textPrimary, size: 14),
                       ]),
                       Text('Cafeteria', style: Theme.of(context).textTheme.labelSmall),
                       Text('Seats K${(stadium.seatsCapacity/1000).toStringAsFixed(0)} person', style: Theme.of(context).textTheme.labelSmall),
                     ],
                   ),
                    const SizedBox(height: 4),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                        Text('Price ${NumberFormat('#,###').format(stadium.pricePerHour)} eg', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
                        Text(stadium.area, style: Theme.of(context).textTheme.labelSmall),
                     ],
                   )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}


