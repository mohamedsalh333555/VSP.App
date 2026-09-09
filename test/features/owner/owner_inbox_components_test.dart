import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/user_model.dart';
import 'package:vsp_application/core/repositories/user_repository.dart';
import 'package:vsp_application/features/owner/widgets/inbox/owner_chat_item_card.dart';
import 'package:vsp_application/features/owner/widgets/inbox/user_search_delegate.dart';

class _FakeUserRepository extends UserRepository {
  final List<UserModel> fakeUsers;

  _FakeUserRepository({required this.fakeUsers});

  @override
  Future<List<UserModel>> searchUsers({
    required String currentUserId,
    String? role,
    String query = '',
    int limit = 50,
  }) async {
    return fakeUsers;
  }
}

void main() {
  group('OwnerChatItemCard', () {
    testWidgets('renders title, subtitle, timeStr and unread badge', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerChatItemCard(
              title: 'Ahmed Mahmoud',
              subtitle: 'See you on the pitch!',
              timeStr: '04:30 PM',
              avatar: null,
              hasUnread: true,
              unreadCount: 3,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Ahmed Mahmoud'), findsOneWidget);
      expect(find.text('See you on the pitch!'), findsOneWidget);
      expect(find.text('04:30 PM'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);

      await tester.tap(find.byType(OwnerChatItemCard));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('hides unread badge when hasUnread is false', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: OwnerChatItemCard(
              title: 'VSP Support',
              subtitle: 'Welcome to support',
              timeStr: '12:00 PM',
              avatar: null,
              hasUnread: false,
              unreadCount: 0,
              onTap: () {},
            ),
          ),
        ),
      );

      expect(find.text('VSP Support'), findsOneWidget);
      expect(find.text('0'), findsNothing);
    });
  });

  group('UserSearchDelegate', () {
    test('instantiates and provides search metadata and actions', () {
      final fakeRepo = _FakeUserRepository(fakeUsers: []);
      final delegate = UserSearchDelegate(
        currentUserId: 'owner_123',
        currentUserRole: 'owner',
        userRepository: fakeRepo,
      );

      expect(delegate.searchFieldLabel, isNotNull);
      expect(delegate.currentUserId, equals('owner_123'));
      expect(delegate.currentUserRole, equals('owner'));
    });

    testWidgets('renders search results from repository', (tester) async {
      final fakeUser = UserModel(
        uid: 'player_456',
        name: 'Tarek Hamed',
        email: 'tarek@example.com',
        phone: '01000000001',
        role: 'player',
        createdAt: DateTime.now(),
      );

      final fakeRepo = _FakeUserRepository(fakeUsers: [fakeUser]);
      final delegate = UserSearchDelegate(
        currentUserId: 'owner_123',
        currentUserRole: 'owner',
        userRepository: fakeRepo,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: delegate.buildResults(context),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Tarek Hamed'), findsOneWidget);
    });
  });
}
