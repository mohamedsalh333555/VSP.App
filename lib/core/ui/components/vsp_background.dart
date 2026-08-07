import 'package:flutter/material.dart';
import '../tokens/vsp_tokens.dart';

class VSPBackgroundScaffold extends StatelessWidget {
  final Widget body;
  final Widget? bottomNavigationBar;
  final PreferredSizeWidget? appBar;

  const VSPBackgroundScaffold({
    super.key,
    required this.body,
    this.bottomNavigationBar,
    this.appBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VSPColors.background,
      appBar: appBar,
      body: Stack(
        children: [
          // 1. الإضاءة الخلفية العضوية (Ambient Radial Glow)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: VSPColors.backgroundAura,
              ),
            ),
          ),
          
          // 2. محتوى الشاشة
          SafeArea(
            child: body,
          ),
        ],
      ),
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}
