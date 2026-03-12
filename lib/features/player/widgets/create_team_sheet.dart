import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/database_service.dart';

import '../../../core/ui/tokens/vsp_tokens.dart';
import '../../../core/widgets/shimmer_image.dart';
import '../../../shared/widgets/primary_button.dart';
import 'add_player_sheet.dart';

class CreateTeamSheet extends StatefulWidget {
  const CreateTeamSheet({super.key});

  @override
  State<CreateTeamSheet> createState() => _CreateTeamSheetState();
}

class _CreateTeamSheetState extends State<CreateTeamSheet> {
  final _nameController = TextEditingController();
  String _selectedSport = 'Football';
  final List<UserModel> _teamMembers = [];
  bool _isSubmitting = false;
  XFile? _selectedLogo;
  String? _uploadedLogoUrl;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (image != null) {
      setState(() => _selectedLogo = image);
    }
  }

  Future<void> _handleCreateTeam() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team name')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final uid = auth.currentUser?.uid;

      // 1. Upload Logo if selected
      if (_selectedLogo != null) {
        _uploadedLogoUrl = await CloudinaryService().uploadImage(
          _selectedLogo!,
          folder: 'teams/$uid/logos',
        );
      }

      // 2. Prepare Payload (Cleaned for Hardened Service)
      final teamData = {
        'name': name,
        'captainName': auth.userModel?.name ?? 'Captain',
        'captainPhone': auth.userModel?.phone,
        'captainImageUrl': auth.userModel?.profileImageUrl ?? '',
        // Use uploaded URL or fallback to a default generic sport image
        'logoUrl': _uploadedLogoUrl ?? 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80',
        'playersCount': _teamMembers.length + 1, // +1 for captain
        'maxPlayers': 12,
        'memberUids': [
          if (uid != null) uid,
          ..._teamMembers.map((m) => m.uid),
        ],
        'playerImages': [
          auth.userModel?.profileImageUrl ?? '',
          ..._teamMembers.map((m) => m.profileImageUrl ?? ''),
        ],
        'governorate': auth.userModel?.governorate ?? 'Cairo',
        'sportType': _selectedSport,
      };

      final teamId = await DatabaseService().createTeam(teamData);

      if (teamId != null && mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Team created successfully!', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: VSPColors.background, fontWeight: FontWeight.bold)),
            backgroundColor: VSPColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating team: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _showAddPlayerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddPlayerSheet(
        onPlayerAdded: (user) {
          setState(() {
            if (!_teamMembers.any((m) => m.uid == user.uid)) {
              _teamMembers.add(user);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: VSPSpacing.lg,
        left: VSPSpacing.md,
        right: VSPSpacing.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + VSPSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: VSPColors.background,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(VSPRadius.xl),
          topRight: Radius.circular(VSPRadius.xl),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    'Create Team',
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  const SizedBox(height: VSPSpacing.xs),
                  Text(
                    'Create Your Team To Have Your Favorite Friends Join You.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: VSPColors.textSecondary,
                        ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: VSPColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.lg),

          // Team Name Input
          Text('Team Name*', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: VSPSpacing.sm),
          TextField(
            controller: _nameController,
            style: Theme.of(context).textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: 'El Mokatm',
              hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.5)),
              filled: true,
              fillColor: VSPColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(VSPRadius.md),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 14),
            ),
          ),
          const SizedBox(height: 16),

          // Sports Type Input
          Text('Sports Type*', style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: VSPColors.surface,
              borderRadius: BorderRadius.circular(VSPRadius.md),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSport,
                isExpanded: true,
                dropdownColor: VSPColors.surface,
                items: ['Football', 'Basketball', 'Volleyball', 'Handball', 'Padel']
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s, style: Theme.of(context).textTheme.bodyMedium),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSport = val!),
              ),
            ),
          ),
          
          const SizedBox(height: VSPSpacing.lg),

          // Upload Photo Section
          GestureDetector(
            onTap: _pickImage,
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: VSPColors.surface,
                    borderRadius: BorderRadius.circular(VSPRadius.md),
                    border: Border.all(color: VSPColors.divider),
                    image: _selectedLogo != null 
                        ? DecorationImage(
                            image: FileImage(File(_selectedLogo!.path)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _selectedLogo == null 
                      ? const Icon(Icons.add_photo_alternate_outlined, color: VSPColors.accent)
                      : null,
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: VSPColors.accent,
                      borderRadius: BorderRadius.circular(VSPRadius.md),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(Icons.cloud_upload_outlined, color: VSPColors.background),
                         const SizedBox(width: VSPSpacing.sm),
                         Text(
                          _selectedLogo == null ? 'Upload Logo' : 'Change Logo',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: VSPColors.background,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: VSPSpacing.lg),

          // Add Team Members Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Team Members (${_teamMembers.length}/12)',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
              ),
              TextButton.icon(
                onPressed: _showAddPlayerSheet,
                icon: const Icon(Icons.add_circle_outline, size: 18, color: VSPColors.accent),
                label: Text('Add Member', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: VSPColors.accent, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: VSPSpacing.sm),
          
          if (_teamMembers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: VSPSpacing.xl),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
                border: Border.all(color: VSPColors.divider),
              ),
              child: Column(
                children: [
                  Icon(Icons.group_add_outlined, color: VSPColors.textSecondary.withValues(alpha: 0.1), size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'No members added yet',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary.withValues(alpha: 0.3)),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(VSPSpacing.sm),
              decoration: BoxDecoration(
                color: VSPColors.surface,
                borderRadius: BorderRadius.circular(VSPRadius.lg),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _teamMembers.map((member) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: VSPColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(VSPRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ShimmerImage(
                          imageUrl: member.profileImageUrl ?? '',
                          width: 28,
                          height: 28,
                          borderRadius: VSPRadius.full,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          member.name ?? 'Player',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => setState(() => _teamMembers.remove(member)),
                          child: const Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Icon(Icons.close, size: 14, color: VSPColors.textSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: VSPSpacing.xl),

          // Bottom Buttons
            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Cancel',
                    onPressed: () => Navigator.pop(context),
                    color: VSPColors.surfaceAlt,
                    textColor: VSPColors.textPrimary,
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Confirm',
                    onPressed: _handleCreateTeam,
                    isLoading: _isSubmitting,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
