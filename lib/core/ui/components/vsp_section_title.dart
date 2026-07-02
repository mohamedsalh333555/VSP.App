import 'package:flutter/material.dart';

class VSPSectionTitle extends StatelessWidget {
  final String text;

  const VSPSectionTitle(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}
