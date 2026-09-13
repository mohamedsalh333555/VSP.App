import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:vsp_application/core/models/copilot_message.dart';
import 'package:vsp_application/core/providers/stadium_provider.dart';
import 'package:vsp_application/core/services/vsp_copilot_service.dart';
import 'package:vsp_application/features/copilot/screens/vsp_copilot_screen.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_chat_bubble.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_conversations_drawer.dart';
import 'package:vsp_application/features/copilot/widgets/copilot_starter_prompts.dart';

class MockLlmCopilotService extends VspCopilotService {
  final List<CopilotConversation> conversations;
  final List<CopilotMessage> messages;
  final CopilotMessage Function(String, String?) onSendMessage;

  const MockLlmCopilotService({
    this.conversations = const [],
    this.messages = const [],
    required this.onSendMessage,
  });

  @override
  Future<List<CopilotConversation>> fetchConversations() async => conversations;

  @override
  Future<List<CopilotMessage>> fetchMessages(String conversationId) async => messages;

  @override
  Future<bool> deleteConversation(String conversationId) async => true;

  @override
  Future<CopilotMessage> sendMessage({
    String? message,
    String? text,
    String? conversationId,
    String? governorate,
  }) async {
    return onSendMessage(message ?? text ?? '', conversationId);
  }
}

void main() {
  group('🤖 VSP Copilot LLM Models & Multi-Turn Tests', () {
    test('CopilotConversation fromMap parses correctly', () {
      final map = {
        'id': 'conv_123',
        'title': 'بحث عن ملاعب المعادي',
        'created_at': '2026-09-10T10:00:00.000Z',
        'updated_at': '2026-09-10T10:05:00.000Z',
      };

      final conv = CopilotConversation.fromMap(map);
      expect(conv.id, 'conv_123');
      expect(conv.title, 'بحث عن ملاعب المعادي');
      expect(conv.createdAt.year, 2026);
      expect(conv.updatedAt.minute, 5);
    });

    test('CopilotMessage fromMap with multi-turn conversation_id', () {
      final map = {
        'id': 'msg_001',
        'conversation_id': 'conv_123',
        'role': 'assistant',
        'content': 'تمام يا كابتن، لقيتلك ملاعب خماسي:',
        'stadium_results': [
          {
            'id': 'std_1',
            'name': 'ملعب الأبطال',
            'governorate': 'Cairo',
            'price_per_hour': 250,
            'rating': 4.7,
          }
        ],
        'created_at': '2026-09-10T10:01:00.000Z',
      };

      final msg = CopilotMessage.fromMap(map);
      expect(msg.id, 'msg_001');
      expect(msg.conversationId, 'conv_123');
      expect(msg.isUser, isFalse);
      expect(msg.hasStadiums, isTrue);
      expect(msg.stadiumResults.first.name, 'ملعب الأبطال');
    });
  });

  group('🎨 VSP Copilot Starter Prompts & Bubble Tests', () {
    testWidgets('CopilotStarterPrompts renders 4 starter cards and handles click', (tester) async {
      String? clickedPrompt;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopilotStarterPrompts(
              onSelectPrompt: (p) => clickedPrompt = p,
              isArabic: true,
            ),
          ),
        ),
      );

      expect(find.text('كابتن VSP الذكي'), findsOneWidget);
      expect(find.text('يا كابتن! قولي إيه اللي في بالك — ملعب، ماتش، أو بطولة؟'), findsOneWidget);
      expect(find.text('فين ألعب النهارده؟'), findsOneWidget);
      expect(find.text('في ماتش ناقص لاعيب؟'), findsOneWidget);
      expect(find.text('أرخص ملعب قريب مني'), findsOneWidget);
      expect(find.text('في بطولات أقدر أشترك فيها؟'), findsOneWidget);

      await tester.tap(find.text('فين ألعب النهارده؟'));
      await tester.pump();

      expect(clickedPrompt, 'فين ألعب النهارده؟');
    });

    testWidgets('CopilotChatBubble renders copy button and handles stadium book click', (tester) async {
      CopilotStadiumSummary? bookedStadium;
      final msg = CopilotMessage.assistant(
        'هذا رد الكابتن الذكي',
        stadiums: [
          const CopilotStadiumSummary(
            id: 'std_test',
            name: 'ملعب النجوم الدولي',
            governorate: 'Cairo',
            pricePerHour: 320,
            rating: 4.8,
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopilotChatBubble(
              message: msg,
              isArabic: true,
              onBookStadium: (s) => bookedStadium = s,
            ),
          ),
        ),
      );

      expect(find.text('هذا رد الكابتن الذكي'), findsOneWidget);
      expect(find.text('نسخ'), findsOneWidget);
      expect(find.text('ملعب النجوم الدولي'), findsOneWidget);
      expect(find.text('320 ج.م/ساعة'), findsOneWidget);
      expect(find.text('احجز'), findsOneWidget);

      await tester.tap(find.text('احجز'));
      await tester.pump();

      expect(bookedStadium?.id, 'std_test');
    });
  });

  group('📱 VspCopilotScreen Full Experience Tests', () {
    testWidgets('Renders full-screen, starts with starter prompts, and sends message', (tester) async {
      final mockService = MockLlmCopilotService(
        conversations: [
          CopilotConversation(
            id: 'c1',
            title: 'محادثة سابقة',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ],
        onSendMessage: (query, convId) {
          return CopilotMessage.assistant(
            'رد تجريبي على: $query',
            conversationId: 'c1',
            stadiums: [
              const CopilotStadiumSummary(
                id: 'std_c1',
                name: 'ملعب التجمع',
                governorate: 'New Cairo',
                pricePerHour: 400,
                rating: 4.9,
              ),
            ],
          );
        },
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<StadiumProvider>(create: (_) => StadiumProvider()),
          ],
          child: MaterialApp(
            locale: const Locale('ar'),
            home: VspCopilotScreen(
              copilotService: mockService,
              isArabic: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Starts with starter prompts in empty state
      expect(find.text('فين ألعب النهارده؟'), findsOneWidget);

      // Tap starter prompt
      await tester.tap(find.text('فين ألعب النهارده؟'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Prompt is sent and bubble appears
      expect(find.text('رد تجريبي على: فين ألعب النهارده؟'), findsOneWidget);
      expect(find.text('ملعب التجمع'), findsOneWidget);
    });

    testWidgets('CopilotConversationsDrawer opens and shows past conversations', (tester) async {
      bool newChatTriggered = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            drawer: CopilotConversationsDrawer(
              conversations: [
                CopilotConversation(
                  id: 'conv_old',
                  title: 'ملاعب المعادي الرخيصة',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ),
              ],
              activeConversationId: 'conv_old',
              isLoading: false,
              onNewChat: () => newChatTriggered = true,
              onSelectConversation: (_) {},
              onDeleteConversation: (_) {},
            ),
            body: const Center(child: Text('App Body')),
          ),
        ),
      );

      // Open drawer
      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      expect(find.text('سجل المحادثات'), findsOneWidget);
      expect(find.text('محادثة جديدة'), findsOneWidget);
      expect(find.text('ملاعب المعادي الرخيصة'), findsOneWidget);

      // Tap new chat
      await tester.tap(find.text('محادثة جديدة'));
      await tester.pumpAndSettle();

      expect(newChatTriggered, isTrue);
    });

    testWidgets('CopilotChatBubble renders action card and triggers onExecuteAction callback', (tester) async {
      CopilotAction? executedAction;

      final msg = CopilotMessage.assistant(
        'وديتك لشاشة فريقي يا كابتن',
        action: const CopilotAction(
          actionType: 'NAVIGATE',
          route: '/my-team',
          label: 'الانتقال لشاشة فريقي',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopilotChatBubble(
              message: msg,
              isArabic: true,
              onExecuteAction: (a) => executedAction = a,
            ),
          ),
        ),
      );

      expect(find.text('وديتك لشاشة فريقي يا كابتن'), findsOneWidget);
      expect(find.text('الانتقال لشاشة فريقي'), findsOneWidget);

      await tester.tap(find.text('الانتقال لشاشة فريقي'));
      await tester.pumpAndSettle();

      expect(executedAction, isNotNull);
      expect(executedAction!.route, '/my-team');
    });

    testWidgets('CopilotChatBubble renders tournaments and open matches carousels', (tester) async {
      CopilotTournamentSummary? selectedTourney;
      CopilotOpenMatchSummary? joinedMatch;

      final msg = CopilotMessage.assistant(
        'دي البطولات والماتشات المتاحة:',
        tournaments: [
          const CopilotTournamentSummary(
            id: 't1',
            name: 'كأس VSP الذهبي',
            grandPrize: 15000,
            entryFee: 500,
          ),
        ],
        openMatches: [
          CopilotOpenMatchSummary(
            id: 'm1',
            stadiumName: 'ملعب المعادي',
            currentPlayers: 8,
            maxPlayers: 10,
            notes: 'ناقص 2 لاعيبة',
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CopilotChatBubble(
                message: msg,
                isArabic: true,
                onSelectTournament: (t) => selectedTourney = t,
                onJoinMatch: (m) => joinedMatch = m,
              ),
            ),
          ),
        ),
      );

      expect(find.text('كأس VSP الذهبي'), findsOneWidget);
      expect(find.text('ملعب المعادي'), findsOneWidget);
      expect(find.text('ناقص 2 لاعبين'), findsOneWidget);

      await tester.tap(find.text('عرض'));
      await tester.pumpAndSettle();
      expect(selectedTourney?.name, 'كأس VSP الذهبي');

      await tester.tap(find.text('انضم'));
      await tester.pumpAndSettle();
      expect(joinedMatch?.stadiumName, 'ملعب المعادي');
    });

    testWidgets('CopilotChatBubble renders PROFILE_UPDATED action badge correctly', (tester) async {
      CopilotAction? executedAction;

      final msg = CopilotMessage.assistant(
        'تمام يا كابتن! تم تغيير مركزك إلى مهاجم بنجاح.',
        action: const CopilotAction(
          actionType: 'PROFILE_UPDATED',
          route: '/profile',
          label: 'تم تغيير مركزك إلى مهاجم بنجاح ✅',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CopilotChatBubble(
              message: msg,
              isArabic: true,
              onExecuteAction: (a) => executedAction = a,
            ),
          ),
        ),
      );

      expect(find.text('تم تغيير مركزك إلى مهاجم بنجاح ✅'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.tap(find.text('تم تغيير مركزك إلى مهاجم بنجاح ✅'));
      await tester.pumpAndSettle();

      expect(executedAction?.actionType, 'PROFILE_UPDATED');
    });
  });
}
