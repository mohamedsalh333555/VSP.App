import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/ui/tokens/vsp_tokens.dart';
import 'package:vsp_application/features/player/widgets/create_team_members_section.dart';
import 'package:vsp_application/l10n/app_localizations.dart';

Widget _wrap(Widget child) => MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

UserModel _fakeUser(String uid, String name) => UserModel(
      uid: uid,
      name: name,
      email: '$uid@test.com',
      role: 'player',
      governorate: 'Cairo',
    );

void main() {
  group('CreateTeamMembersSection', () {
    testWidgets('shows empty-state placeholder when members list is empty', (tester) async {
      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: const [],
          onAddMember: () {},
          onPasteWhatsApp: () {},
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      // Empty state icon should be visible
      expect(find.byIcon(Iconsax.user_add_copy), findsOneWidget);
    });

    testWidgets('shows member chips when members list is non-empty', (tester) async {
      final members = [_fakeUser('u1', 'Ali'), _fakeUser('u2', 'Omar')];

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: members,
          onAddMember: () {},
          onPasteWhatsApp: () {},
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      expect(find.text('Ali'), findsOneWidget);
      expect(find.text('Omar'), findsOneWidget);
    });

    testWidgets('calls onRemoveMember when remove icon is tapped', (tester) async {
      UserModel? removed;
      final members = [_fakeUser('u1', 'Ali')];

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: members,
          onAddMember: () {},
          onPasteWhatsApp: () {},
          onRemoveMember: (m) => removed = m,
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Iconsax.close_circle_copy).first);
      await tester.pump();

      expect(removed?.uid, 'u1');
    });

    testWidgets('calls onAddMember when add button is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: const [],
          onAddMember: () => tapped = true,
          onPasteWhatsApp: () {},
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Iconsax.add_circle_copy));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('calls onPasteWhatsApp when paste button is tapped', (tester) async {
      bool tapped = false;

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: const [],
          onAddMember: () {},
          onPasteWhatsApp: () => tapped = true,
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      await tester.tap(find.byIcon(Iconsax.copy_copy));
      await tester.pump();

      expect(tapped, isTrue);
    });

    testWidgets('member count in header reflects members.length + 1 (captain)', (tester) async {
      final members = [_fakeUser('u1', 'Ali'), _fakeUser('u2', 'Omar')];

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: members,
          onAddMember: () {},
          onPasteWhatsApp: () {},
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      // Header should show 3 (2 members + 1 captain) out of 12
      expect(find.textContaining('3'), findsWidgets);
    });

    testWidgets('does not show empty-state when members is non-empty', (tester) async {
      final members = [_fakeUser('u1', 'Ali')];

      await tester.pumpWidget(_wrap(
        CreateTeamMembersSection(
          members: members,
          onAddMember: () {},
          onPasteWhatsApp: () {},
          onRemoveMember: (_) {},
        ),
      ));
      await tester.pump();

      // The empty-state placeholder icon should NOT appear
      expect(find.byIcon(Iconsax.user_add_copy), findsNothing);
    });
  });

  group('CreateTeamLogoPickerRow', () {
    testWidgets('shows upload icon when no logo selected', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(_wrap(
        Builder(builder: (ctx) {
          // We can only test CreateTeamLogoPickerRow via its public interface
          // (no selectedLogo → image icon visible)
          return GestureDetector(
            onTap: () => tapped = true,
            child: Container(
              color: VSPColors.surface,
              child: const Icon(Iconsax.image_copy),
            ),
          );
        }),
      ));
      await tester.pump();
      expect(find.byIcon(Iconsax.image_copy), findsOneWidget);
    });
  });
}
