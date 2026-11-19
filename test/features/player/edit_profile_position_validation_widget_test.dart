import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
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
  Completer<bool>? pendingSave;
  bool throwOnSave = false;
  bool photoSaveSuccess = false;
  bool throwOnPhotoSave = false;
  int photoUpdates = 0;
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
    if (throwOnSave) throw StateError('Private database exception');
    if (pendingSave != null) return pendingSave!.future;
    return success;
  }

  @override
  Future<bool> updateProfilePhoto(XFile file) async {
    photoUpdates++;
    if (throwOnPhotoSave) throw StateError('PRIVATE PHOTO FAILURE');
    return photoSaveSuccess;
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

Widget host(FakeProfileAuth auth, String language, {
      Future<XFile?> Function(BuildContext)? pickProfileImage,
      Future<XFile?> Function(XFile)? compressProfileImage,
    }) =>
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: EditProfileScreen(
          pickProfileImage: pickProfileImage,
          compressProfileImage: compressProfileImage,
        ),
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

Future<XFile> testProfilePhoto() async {
  final path = '${Directory.systemTemp.path}/vsp_edit_avatar_${DateTime.now().microsecondsSinceEpoch}.png';
  final png = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/GloAAAAASUVORK5CYII=');
  final file = await File(path).writeAsBytes(png);
  addTearDown(() async { if (await file.exists()) await file.delete(); });
  return XFile(path);
}

void main() {
  for (final language in ['ar', 'en']) {
    testWidgets('image picker exception shows safe feedback and keeps editable form in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person());
      await tester.pumpWidget(host(auth, language,
          pickProfileImage: (_) async => throw StateError('Private picker error')));
      await tester.tap(find.byKey(const ValueKey('edit-profile-pick-image')));
      await tester.pump();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(find.textContaining('Private picker error'), findsNothing);
      expect(auth.updates, 0);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
    });

    testWidgets('failed photo upload preserves selection for explicit retry in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person());
      final image = await testProfilePhoto();
      await tester.pumpWidget(host(auth, language,
          pickProfileImage: (_) async => image,
          compressProfileImage: (file) async => file));
      await tester.tap(find.byKey(const ValueKey('edit-profile-pick-image')));
      await tester.pump();
      await save(tester);
      expect(auth.updates, 1);
      expect(auth.photoUpdates, 1);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      auth.photoSaveSuccess = true;
      await save(tester);
      expect(auth.updates, 2);
      expect(auth.photoUpdates, 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('compression exception reports partial save and retries image in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person())..photoSaveSuccess = true;
      final image = await testProfilePhoto();
      var failCompression = true;
      await tester.pumpWidget(host(auth, language,
          pickProfileImage: (_) async => image,
          compressProfileImage: (file) async {
            if (failCompression) throw StateError('Private image compression exception');
            return file;
          }));
      await tester.tap(find.byKey(const ValueKey('edit-profile-pick-image')));
      await tester.pump();
      await save(tester);
      expect(auth.updates, 1);
      expect(auth.photoUpdates, 0);
      expect(find.textContaining('Private image compression exception'), findsNothing);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      failCompression = false;
      await save(tester);
      expect(auth.photoUpdates, 1);
      expect(tester.takeException(), isNull);
    });
  }

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

    testWidgets('save button cannot submit twice while update is pending in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person())
        ..pendingSave = Completer<bool>();
      await tester.pumpWidget(host(auth, language));
      final button = find.byType(PrimaryButton);
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(auth.updates, 1);
      expect(tester.widget<PrimaryButton>(button).isLoading, isTrue);

      // Submitting a second time must not enqueue another server update.
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      expect(auth.updates, 1);
      auth.pendingSave!.complete(false);
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('unexpected provider error is redacted and form remains editable in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person())..throwOnSave = true;
      await tester.pumpWidget(host(auth, language));
      await tester.enterText(find.byType(TextFormField).first, 'Safe Edited Name');
      await save(tester);
      expect(auth.updates, 1);
      expect(find.textContaining('Private database exception'), findsNothing);
      expect(find.text('Safe Edited Name'), findsOneWidget);
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('account replacement during an in-flight update cannot show another account success in $language',
        (tester) async {
      final auth = FakeProfileAuth(profile: person())
        ..pendingSave = Completer<bool>();
      await tester.pumpWidget(host(auth, language));
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(auth.updates, 1);

      auth.profile = person(owner: true, position: null);
      auth.notifyListeners();
      await tester.pump();
      auth.pendingSave!.complete(true);
      await tester.pump();
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(auth.submitted?.containsKey('role'), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();
    });
  }
}
