import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';
import 'package:vsp_application/shared/widgets/vsp_animated_button.dart';
import 'package:vsp_application/shared/widgets/vsp_empty_state.dart';

void main() {
 group(' VSP App UI & Widget Tests', () {
 testWidgets('1. PrimaryButton renders text and triggers onPressed tap', (WidgetTester tester) async {
 bool tapped = false;
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Confirm Selection',
 onPressed: () => tapped = true,
 ),
 ),
 ),
 );

 expect(find.text('Confirm Selection'), findsOneWidget);
 await tester.tap(find.byType(PrimaryButton));
 await tester.pumpAndSettle();
 expect(tapped, isTrue);
 });

 testWidgets('2. PrimaryButton shows CircularProgressIndicator when isLoading=true', (WidgetTester tester) async {
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Submit',
 isLoading: true,
 onPressed: () {},
 ),
 ),
 ),
 );

 expect(find.byType(CircularProgressIndicator), findsOneWidget);
 expect(find.text('Submit'), findsNothing);
 });

 testWidgets('3. VSPAnimatedButton renders label correctly', (WidgetTester tester) async {
 await tester.pumpWidget(
 MaterialApp(
 home: Scaffold(
 body: VSPAnimatedButton(
 text: 'Book Pitch',
 onPressed: () {},
 ),
 ),
 ),
 );

 expect(find.text('Book Pitch'), findsOneWidget);
 });

 testWidgets('4. VSPEmptyState renders title and subtitle correctly', (WidgetTester tester) async {
 await tester.pumpWidget(
 const MaterialApp(
 home: Scaffold(
 body: VSPEmptyState(
 icon: Icons.calendar_today,
 title: 'No Active Bookings',
 subtitle: 'Explore available pitches to book your match.',
 ),
 ),
 ),
 );

 expect(find.text('No Active Bookings'), findsOneWidget);
 expect(find.text('Explore available pitches to book your match.'), findsOneWidget);
 });

 testWidgets('5. PrimaryButton disabled state when onPressed is null', (WidgetTester tester) async {
 await tester.pumpWidget(
 const MaterialApp(
 home: Scaffold(
 body: PrimaryButton(
 text: 'Disabled Button',
 onPressed: null,
 ),
 ),
 ),
 );

 expect(find.text('Disabled Button'), findsOneWidget);
 });
 });
}
