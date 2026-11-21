import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/providers/auth_provider.dart';
import 'package:vsp_application/core/repositories/stadium_repository.dart';
import 'package:vsp_application/features/owner/widgets/add_stadium/stadium_wizard_submit_service.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

class _OwnerAuth extends Fake implements AuthProvider {
  @override
  UserModel? get userModel => null;

  @override
  User? get currentUser => User.fromJson({
        'id': 'owner-1',
        'aud': 'authenticated',
        'role': 'authenticated',
        'email': 'owner@test.invalid',
        'created_at': '2026-01-01T00:00:00.000Z',
        'app_metadata': <String, dynamic>{},
        'user_metadata': <String, dynamic>{},
      });

  @override
  Future<void> refreshProfile() async {}
}

class _UpdateRepository extends Fake implements StadiumRepository {
  _UpdateRepository(this.accepted);
  final bool accepted;
  Map<String, dynamic>? submitted;

  @override
  Future<bool> updateStadium(String id, Map<String, dynamic> data) async {
    expect(id, 'pitch-1');
    submitted = data;
    return accepted;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final accepted in [false, true]) {
    testWidgets('owner price edit respects repository result ($accepted)',
        (tester) async {
      late BuildContext editContext;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: Builder(builder: (context) => ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute<void>(
            builder: (ctx) {
              editContext = ctx;
              return const Scaffold(body: Text('Edit stadium'));
            },
          )),
          child: const Text('Open editor'),
        ))),
      ));
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      final repository = _UpdateRepository(accepted);
      final pendingDeletion = accepted ? <String>{} : <String>{'old-image-url'};
      final saved = await StadiumWizardSubmitService.submit(
        context: editContext,
        auth: _OwnerAuth(),
        databaseService: repository,
        stadiumId: 'pitch-1',
        name: 'Nile Pitch',
        location: 'Aswan',
        governorate: 'Aswan',
        priceText: '320',
        capacityText: '5',
        depositText: '',
        requireDeposit: false,
        notes: '',
        stadiumPhone: '01000000000',
        sportType: 'Football',
        floorType: 'Artificial',
        bathOption: 'Yes',
        cafeteria: true,
        garage: false,
        changingRoom: true,
        seats: '20',
        length: '40',
        width: '20',
        hasBall: false,
        ballPriceText: '',
        startTime: null,
        endTime: null,
        isSplitShift: false,
        breakTimes: const [],
        images: [{'url': 'https://example.invalid/cover.jpg'}],
        removedExistingImageUrls: pendingDeletion,
        latitude: 24.0889,
        longitude: 32.8998,
        uid: 'owner-1',
      );
      expect(saved, accepted);
      expect(repository.submitted?['pricePerHour'], 320);
      expect(repository.submitted?['imageUrl'], 'https://example.invalid/cover.jpg');
      await tester.pumpAndSettle();
      if (accepted) {
        expect(find.text('Open editor'), findsOneWidget);
        expect(find.text('Edit stadium'), findsNothing);
      } else {
        expect(find.text('Edit stadium'), findsOneWidget);
        expect(pendingDeletion, {'old-image-url'});
      }
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
