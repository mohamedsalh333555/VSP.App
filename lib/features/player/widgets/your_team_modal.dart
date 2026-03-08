import 'package:flutter/material.dart';
import 'package:vsp_application/core/widgets/shimmer_image.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

class YourTeamModal extends StatefulWidget {
  const YourTeamModal({super.key});

  @override
  State<YourTeamModal> createState() => _YourTeamModalState();
}

class _YourTeamModalState extends State<YourTeamModal> {
  // Mock data for team members
  final List<Map<String, String>> _members = [
    {
      'name': 'Saleh Ahmed',
      'role': 'Defender',
      'image': 'https://images.unsplash.com/photo-1552674605-db6ffd4facb5?w=150&h=150&fit=crop&q=80',
    },
    {
      'name': 'Mahmoud Hassan',
      'role': 'Forward',
      'image': 'https://images.unsplash.com/photo-1543351611-58f69d7c1781?w=150&h=150&fit=crop&q=80',
    },
    {
      'name': 'Omar Ali',
      'role': 'Midfielder',
      'image': 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&q=80',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(VSPSpacing.lg),
        decoration: BoxDecoration(
          color: VSPColors.surface,
          borderRadius: BorderRadius.circular(VSPRadius.lg),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.05),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Team',
                  style: Theme.of(context).textTheme.displayMedium,
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: VSPSpacing.sm),
            Text(
              'Manage your current team members and invite new ones.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: VSPColors.textSecondary,
                  ),
            ),
            const SizedBox(height: VSPSpacing.lg),

            ..._members.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: VSPSpacing.md),
                  child: Row(
                    children: [
                      ShimmerImage(
                        imageUrl: member['image']!,
                        width: 48,
                        height: 48,
                        borderRadius: 24,
                      ),
                      const SizedBox(width: VSPSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member['name']!,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            Text(
                              member['role']!,
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _members.remove(member);
                          });
                        },
                        child: Text(
                          'Remove',
                          style: TextStyle(
                            color: Colors.redAccent.withValues(alpha: 0.8),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),

            const SizedBox(height: VSPSpacing.md),

            Text(
              'INVITE MEMBER',
              style: Theme.of(context).textTheme.labelMedium,
            ),
            const SizedBox(height: VSPSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: VSPSpacing.md, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(VSPRadius.md),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        color: VSPColors.textSecondary,
                        size: 20,
                      ),
                      SizedBox(width: VSPSpacing.sm),
                      Text(
                        'Select Team Member',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: VSPColors.textSecondary,
                  ),
                ],
              ),
            ),

            const SizedBox(height: VSPSpacing.xl),

            Row(
              children: [
                Expanded(
                  child: PrimaryButton(
                    text: 'Cancel',
                    color: Colors.white.withValues(alpha: 0.05),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: VSPSpacing.md),
                Expanded(
                  child: PrimaryButton(
                    text: 'Invite',
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
