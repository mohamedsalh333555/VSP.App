import 'package:flutter/material.dart';
import '../tokens/vsp_design_tokens.dart';

class VSPSectionTitle extends StatelessWidget {
  final String text;

  const VSPSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: VSPDSTypography.titleLarge.copyWith(
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
