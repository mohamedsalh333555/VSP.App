import 'package:flutter_test/flutter_test.dart';
import 'package:vsp_application/core/models/copilot_message.dart';

void main() {
  test('restores persisted Copilot UI metadata', () {
    final message = CopilotMessage.fromMap({
      'id': 'm1',
      'conversation_id': 'c1',
      'role': 'assistant',
      'content': 'لقيتلك ملعب',
      'created_at': '2026-09-21T10:00:00Z',
      'stadium_results': [],
      'ui_metadata': {
        'stadiums': [
          {
            'id': 's1',
            'name': 'ملعب الصداقة الجديدة',
            'governorate': 'أسوان',
            'price_per_hour': 200,
            'rating': 4.8,
          }
        ],
        'action': {
          'action_type': 'NAVIGATE',
          'route': '/bookings',
          'label': 'عرض الحجوزات',
        },
        'task_state': {
          'stadium_id': 's1',
          'preferred_times': ['22:00', '23:00'],
        },
      },
    });

    expect(message.stadiumResults, hasLength(1));
    expect(message.stadiumResults.single.id, 's1');
    expect(message.action?.route, '/bookings');
    expect(message.uiMetadata['task_state']['preferred_times'], ['22:00', '23:00']);
  });

  test('restores conversation context and nested message count', () {
    final conversation = CopilotConversation.fromMap({
      'id': 'c1',
      'title': 'حجز ملعب',
      'created_at': '2026-09-21T10:00:00Z',
      'updated_at': '2026-09-21T10:05:00Z',
      'context_snapshot': {
        'task_state': {
          'stadium_id': 's1',
          'date': '2026-09-21',
        }
      },
      'copilot_messages': [
        {'count': 4}
      ],
    });

    expect(conversation.messageCount, 4);
    expect(conversation.contextSnapshot['task_state']['stadium_id'], 's1');
  });
}
