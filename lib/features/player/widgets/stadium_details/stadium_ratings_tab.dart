import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/repositories/stadium_repository.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../core/utils/app_date_formatter.dart';
import '../../../../core/utils/vsp_feedback.dart';
import '../../../../data/models.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Ratings and reviews tab with live score calculations and atomic review submission.
class StadiumRatingsTab extends StatefulWidget {
  final Stadium stadium;

  const StadiumRatingsTab({super.key, required this.stadium});

  @override
  State<StadiumRatingsTab> createState() => _StadiumRatingsTabState();
}

class _StadiumRatingsTabState extends State<StadiumRatingsTab> {
  late final Stream<List<Map<String, dynamic>>> _reviewsStream;

  @override
  void initState() {
    super.initState();
    _reviewsStream = StadiumRepository().streamReviews(widget.stadium.id);
  }

  Future<void> _showAddReviewSheet(BuildContext context) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (!auth.isAuthenticated) {
      VSPFeedback.showError(
          context, isArabic ? 'يرجى تسجيل الدخول أولاً لإضافة تقييم' : 'Please login to leave a review');
      return;
    }

    int selectedRating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    try {
      await showModalBottomSheet(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetCtx) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              return Padding(
                padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    VSPSpacing.md,
                    VSPSpacing.md,
                    VSPSpacing.md,
                    VSPSpacing.md + MediaQuery.of(context).padding.bottom + 16,
                  ),
                  decoration: const BoxDecoration(
                    color: VSPColors.background,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(VSPRadius.xl)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: VSPColors.divider, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        isArabic ? 'تقييم وإبداء رأيك في الملعب' : 'Rate & Review Stadium',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      // Star Picker
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(5, (index) {
                          final starIndex = index + 1;
                          final isSelected = starIndex <= selectedRating;
                          return IconButton(
                            icon: Icon(
                              isSelected ? Iconsax.star_1_copy : Iconsax.star_copy,
                              color: isSelected ? Colors.amber : VSPColors.textSecondary,
                              size: 36,
                            ),
                            onPressed: () {
                              setSheetState(() {
                                selectedRating = starIndex;
                              });
                            },
                          );
                        }),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: commentController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: isArabic
                              ? 'اكتب انطباعك عن جودة الملعب والإضاءة والمعاملة...'
                              : 'Write your feedback...',
                          hintStyle: const TextStyle(color: VSPColors.textSecondary, fontSize: 12),
                          filled: true,
                          fillColor: VSPColors.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(VSPRadius.md),
                            borderSide: const BorderSide(color: VSPColors.divider),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      PrimaryButton(
                        text: isArabic ? 'إرسال التقييم ' : 'Submit Review',
                        isLoading: isSubmitting,
                        onPressed: () async {
                          final comment = commentController.text.trim();
                          if (comment.isEmpty) {
                            VSPFeedback.showError(sheetCtx, isArabic ? 'يرجى كتابة تعليق' : 'Please enter a comment');
                            return;
                          }
                          setSheetState(() => isSubmitting = true);
                          try {
                            final userModel = auth.userModel;
                            final userId = userModel?.uid ?? auth.currentUser?.id;
                            if (userId == null || userId.isEmpty) {
                              VSPFeedback.showError(
                                  sheetCtx, isArabic ? 'يرجى تسجيل الدخول أولاً لإضافة تقييم' : 'Please log in to submit a review');
                              setSheetState(() => isSubmitting = false);
                              return;
                            }

                            final userName = userModel?.name ??
                                auth.currentUser?.email?.split('@').first ??
                                (isArabic ? 'لاعب VSP' : 'VSP Player');
                            final userAvatar = userModel?.profileImageUrl ?? '';

                            await StadiumRepository().submitStadiumReviewAtomic(
                              stadiumId: widget.stadium.id,
                              userId: userId,
                              userName: userName,
                              userImageUrl: userAvatar,
                              rating: selectedRating.toDouble(),
                              comment: comment,
                            );

                            if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                            if (context.mounted) {
                              VSPFeedback.showSuccess(
                                  context, isArabic ? 'شكراً لك! تم إرسال تقييمك بنجاح ' : 'Review submitted successfully ');
                            }
                          } catch (e, stack) {
                            VSPLogger.e(' Error saving review to Supabase', e, stack);
                            setSheetState(() => isSubmitting = false);
                            if (sheetCtx.mounted) {
                              final errStr = e.toString().toLowerCase();
                              String msg;
                              if (errStr.contains('must_have_completed_booking')) {
                                msg = isArabic
                                    ? 'يجب أن يكون لديك حجز سابق مكتمل في هذا الملعب لتتمكن من تقييمه '
                                    : 'You must have a completed booking at this stadium to add a review ';
                              } else if (errStr.contains('cannot_review_own_stadium')) {
                                msg = isArabic
                                    ? 'لا يمكن لصاحب الملعب إضافة تقييم لملعبه الخاص '
                                    : 'Stadium owner cannot review their own stadium ';
                              } else {
                                msg = isArabic ? 'حدث خطأ أثناء حفظ التقييم' : 'Error saving review';
                              }
                              VSPFeedback.showError(sheetCtx, msg);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      commentController.dispose();
    }
  }

  Widget _buildReviewItem(
    BuildContext context, {
    required String name,
    required String imageUrl,
    required int rating,
    required String timeAgo,
    required String comment,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: VSPSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: VSPColors.surfaceAlt,
            backgroundImage: imageUrl.isNotEmpty ? NetworkImage(imageUrl) : null,
            child: imageUrl.isEmpty ? const Icon(Iconsax.user_copy, color: VSPColors.textSecondary) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(name, style: Theme.of(context).textTheme.titleSmall),
                    Text(timeAgo, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary)),
                  ],
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Iconsax.star_1_copy : Iconsax.star_copy,
                      size: 14,
                      color: i < rating ? Colors.amber : VSPColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(comment, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: VSPColors.textSecondary, height: 1.4)),
                const Padding(padding: EdgeInsets.symmetric(vertical: VSPSpacing.md), child: Divider(color: VSPColors.divider)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _reviewsStream,
      builder: (context, snapshot) {
        final docs = snapshot.data ?? [];
        final count = docs.length;

        double liveRating = 0.0;
        if (count > 0) {
          double sum = 0.0;
          for (final doc in docs) {
            sum += (doc['rating'] as num?)?.toDouble() ?? 0.0;
          }
          liveRating = sum / count;
        }

        Widget buildReviewHeader() {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: VSPSpacing.md),
                padding: const EdgeInsets.all(VSPSpacing.md),
                decoration: BoxDecoration(color: VSPColors.surface, borderRadius: BorderRadius.circular(VSPRadius.lg)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            count > 0 ? liveRating.toStringAsFixed(1) : '0.0',
                            style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 42),
                          ),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                (i) => Icon(
                                  i < liveRating.round() ? Iconsax.star_1_copy : Iconsax.star_copy,
                                  color: i < liveRating.round() ? Colors.amber : VSPColors.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: VSPSpacing.xs),
                          Text(
                            count > 0 ? l10n.reviews(count) : (isArabic ? 'ملعب جديد ' : 'New Stadium '),
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: VSPColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              PrimaryButton(
                text: isArabic ? 'إضافة تقييمك ورأيك' : 'Add Your Review',
                height: 44,
                color: VSPColors.surfaceAlt,
                textColor: VSPColors.accent,
                onPressed: () => _showAddReviewSheet(context),
              ),
              const SizedBox(height: VSPSpacing.md),
            ],
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting && docs.isEmpty) {
          return const Center(child: CircularProgressIndicator(color: VSPColors.accent));
        }

        if (docs.isEmpty) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(VSPSpacing.md),
            child: Column(
              children: [
                buildReviewHeader(),
                Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Text(
                    l10n.noReviews,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: VSPColors.textSecondary),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          padding: const EdgeInsets.all(VSPSpacing.md),
          itemCount: docs.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return buildReviewHeader();
            }

            final doc = docs[index - 1];
            final createdAtStr = doc['created_at'] as String?;
            final userName = doc['user_name']?.toString() ?? doc['userName']?.toString() ?? l10n.player;
            final userImage = doc['user_image_url']?.toString() ?? doc['userImageUrl']?.toString() ?? '';

            String formattedTime = l10n.recently;
            if (createdAtStr != null) {
              try {
                final dt = DateTime.parse(createdAtStr);
                final diff = DateTime.now().difference(dt);
                if (diff.inSeconds < 60) {
                  formattedTime = isArabic ? 'منذ لحظات' : 'Just now';
                } else if (diff.inMinutes < 60) {
                  formattedTime = isArabic ? 'منذ ${diff.inMinutes} دقيقة' : '${diff.inMinutes}m ago';
                } else if (diff.inHours < 24) {
                  formattedTime = isArabic ? 'منذ ${diff.inHours} ساعة' : '${diff.inHours}h ago';
                } else if (diff.inDays < 30) {
                  formattedTime = isArabic ? 'منذ ${diff.inDays} يوم' : '${diff.inDays}d ago';
                } else {
                  formattedTime = AppDateFormatter.formatDayMonth(dt, isArabic ? 'ar' : 'en');
                }
              } catch (e, stack) {
                VSPLogger.e('Error formatting review date', e, stack);
              }
            }

            return _buildReviewItem(
              context,
              name: userName,
              imageUrl: userImage,
              rating: (doc['rating'] as num?)?.toInt() ?? 0,
              timeAgo: formattedTime,
              comment: doc['review_text'] as String? ?? '',
            );
          },
        );
      },
    );
  }
}
