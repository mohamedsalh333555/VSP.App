import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/features/player/screens/profile_subscreens/edit_profile_screen.dart';
import 'package:vsp_application/l10n/app_localizations.dart';
import 'package:vsp_application/shared/widgets/primary_button.dart';

class FakeProfileAuth extends ChangeNotifier implements AuthProvider {
  UserModel profile;
  final bool success;
  int updates = 0;
  Map<String, dynamic>? submitted;
  FakeProfileAuth({required this.profile, this.success = true});

  @override
  UserModel? get userModel => profile;

  @override
  bool get isPlayer => profile.isPlayer;

  @override
  bool get isOwner => profile.isOwner;

  @override
  Future<bool> updateProfile(Map<String, dynamic> data) async {
    updates++;
    submitted = Map<String, dynamic>.from(data);
    return success;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UserModel person({bool owner = false, String? position = 'GK'}) => UserModel(
  uid: owner ? 'owner-1' : 'player-1',
  email: 'test@example.com',
  role: owner ? 'owner' : 'player',
  name: 'Old Name',
  phone: '01012345678',
  position: position,
);

Widget host(FakeProfileAuth auth, String language) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: const EditProfileScreen(),
      ),
    );

Future<void> save(WidgetTester tester) async {
  final button = find.byType(PrimaryButton);
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
  // Feedback is an overlay toast with a three-second timer. Finish the
  // user-visible feedback before closing this widget test.
  await tester.pump(const Duration(seconds: 4));
  await tester.pump();
}

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets('player can update a valid football position but not role in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person());
      await tester.pumpWidget(host(auth, language));
      await tester.enterText(find.byType(TextFormField).first, ' New Captain ');
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      final choice = find.text(language == 'ar' ? 'FW - مهاجم' : 'FW - Forward').last;
      await tester.tap(choice);
      await tester.pumpAndSettle();
      await save(tester);
      expect(auth.updates, 1);
      expect(auth.submitted?['name'], 'New Captain');
      expect(auth.submitted?['phone'], '01012345678');
      expect(auth.submitted?['position'], 'FW');
      expect(auth.submitted?.containsKey('role'), isFalse);
      expect(auth.submitted?.containsKey('uid'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unrecognized player position blocks profile writes in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person(position: 'UNVERIFIED'));
      await tester.pumpWidget(host(auth, language));
      await save(tester);
      expect(auth.updates, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('invalid phone number blocks update before provider call in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person());
      await tester.pumpWidget(host(auth, language));
      await tester.enterText(find.byType(TextFormField).last, '123');
      await save(tester);
      expect(auth.updates, 0);
      expect(tester.takeException(), isNull);
    });

    testWidgets('venue owner updates basic profile without player position in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person(owner: true, position: null));
      await tester.pumpWidget(host(auth, language));
      await save(tester);
      expect(auth.updates, 1);
      expect(auth.submitted?['name'], 'Old Name');
      expect(auth.submitted?.containsKey('position'), isFalse);
      expect(auth.submitted?.containsKey('role'), isFalse);
      expect(tester.takeException(), isNull);
    });

    testWidgets('failed backend save reports failure without losing editable form in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person(), success: false);
      await tester.pumpWidget(host(auth, language));
      await tester.enterText(find.byType(TextFormField).first, 'New Name');
      await save(tester);
      expect(auth.updates, 1);
      expect(find.text('New Name'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
