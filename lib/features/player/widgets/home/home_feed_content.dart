import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/stadium_provider.dart';
import '../../../../core/ui/tokens/vsp_tokens.dart';
import '../../../../shared/widgets/banner_slider_widget.dart';
import 'book_tonight_card.dart';
import 'home_feed_sections.dart';
import 'home_stadiums_section.dart';
import 'home_top_bar.dart';

/// محتوى الصفحة الرئيسية للاعب (الشريط العلوي، السلايدر، الملاعب، المباريات، والبطولات)
class HomeFeedContent extends StatelessWidget {
  final Function(int, {Map<String, dynamic>? arguments}) onNavigate;

  const HomeFeedContent({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        HomeTopBar(onNavigate: onNavigate),
        Expanded(
          child: RefreshIndicator(
            color: VSPColors.accent,
            backgroundColor: VSPColors.surface,
            onRefresh: () async {
              context.read<StadiumProvider>().fetchStadiums(isRefresh: true);
              await Future.delayed(const Duration(milliseconds: 800));
            },
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: EdgeInsets.only(bottom: VSPScrollPadding.bottom(context, hasFloatingNavBar: true)),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  const BannerSliderWidget(placement: 'home_slider'),
                  const SizedBox(height: 10),
                  BookTonightCard(onNavigate: onNavigate),
                  const SizedBox(height: 14),
                  const HomeStadiumsSection(),
                  const SizedBox(height: 16),
                  HomeMatchesSection(onNavigate: onNavigate),
                  const SizedBox(height: 16),
                  HomeChampionshipsSection(onNavigate: onNavigate),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
