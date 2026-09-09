import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/copilot_message.dart';

/// Client service communicating with the secure Supabase Edge Function `vsp_copilot`
/// and managing persistent conversation history with strict RLS.
class VspCopilotService {
  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  const VspCopilotService({SupabaseClient? client}) : _client = client;

  /// Fetches all conversation sessions belonging to the authenticated user.
  Future<List<CopilotConversation>> fetchConversations() async {
    try {
      final res = await _supabase
          .from('copilot_conversations')
          .select()
          .order('updated_at', ascending: false);

      return (res as List<dynamic>)
          .map((m) => CopilotConversation.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[VspCopilotService] fetchConversations error: $e');
      return [];
    }
  }

  /// Fetches all historical messages for a specific conversation session.
  Future<List<CopilotMessage>> fetchMessages(String conversationId) async {
    try {
      final res = await _supabase
          .from('copilot_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: true);

      return (res as List<dynamic>)
          .map((m) => CopilotMessage.fromMap(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('[VspCopilotService] fetchMessages error: $e');
      return [];
    }
  }

  /// Deletes a conversation session and all its associated messages (via CASCADE).
  Future<bool> deleteConversation(String conversationId) async {
    try {
      await _supabase
          .from('copilot_conversations')
          .delete()
          .eq('id', conversationId);
      return true;
    } catch (e) {
      debugPrint('[VspCopilotService] deleteConversation error: $e');
      return false;
    }
  }

  /// Sends a user message to VSP Copilot with optional multi-turn conversation ID.
  Future<CopilotMessage> sendMessage(String text, {String? conversationId}) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return CopilotMessage.assistant(
        'الرجاء كتابة رسالة واضحة للبحث يا كابتن.',
        conversationId: conversationId,
      );
    }

    try {
      final payload = <String, dynamic>{'message': cleanText};
      if (conversationId != null && conversationId.isNotEmpty) {
        payload['conversation_id'] = conversationId;
      }

      final response = await _supabase.functions.invoke(
        'vsp_copilot',
        body: payload,
      );

      final statusCode = response.status;

      if (statusCode == 401) {
        return CopilotMessage.assistant(
          'يجب تسجيل الدخول أولاً لاستخدام كابتن VSP الذكي.',
          conversationId: conversationId,
        );
      }

      if (statusCode == 429) {
        return CopilotMessage.assistant(
          'تم تجاوز الحد المسموح من الرسائل في الدقيقة. يرجى الانتظار دقيقة واحدة والمحاولة مرة أخرى.',
          conversationId: conversationId,
        );
      }

      if (statusCode >= 400) {
        final errorData = response.data is Map ? response.data['error'] : null;
        debugPrint('[VspCopilotService] Error response ($statusCode): $errorData');
        return CopilotMessage.assistant(
          'عذراً، حدث خطأ أثناء الاتصال بالخادم. يرجى المحاولة لاحقاً.',
          conversationId: conversationId,
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final replyText = data['message']?.toString() ?? 'تم استلام طلبك بنجاح.';
        final returnedConvId = data['conversation_id']?.toString() ?? conversationId;
        final rawStadiums = data['stadiums'];
        final List<CopilotStadiumSummary> stadiums = [];

        if (rawStadiums is List) {
          for (final item in rawStadiums) {
            if (item is Map<String, dynamic>) {
              stadiums.add(CopilotStadiumSummary.fromMap(item));
            } else if (item is Map) {
              stadiums.add(CopilotStadiumSummary.fromMap(Map<String, dynamic>.from(item)));
            }
          }
        }

        return CopilotMessage.assistant(
          replyText,
          conversationId: returnedConvId,
          stadiums: stadiums,
        );
      }

      return CopilotMessage.assistant(
        'تم استلام الرد بنجاح بدون نتائج إضافية.',
        conversationId: conversationId,
      );
    } on FunctionException catch (fe) {
      debugPrint('[VspCopilotService] FunctionException: ${fe.status} -> ${fe.details}');
      if (fe.status == 401) {
        return CopilotMessage.assistant(
          'انتهت جلسة تسجيل الدخول. يرجى إعادة الدخول للتطبيق.',
          conversationId: conversationId,
        );
      }
      if (fe.status == 429) {
        return CopilotMessage.assistant(
          'أنت ترسل رسائل بسرعة كبيرة! يرجى الانتظار دقيقة.',
          conversationId: conversationId,
        );
      }
      return CopilotMessage.assistant(
        'عذراً، تعذر الوصول لخدمة المساعد الذكي حالياً.',
        conversationId: conversationId,
      );
    } catch (e, stack) {
      debugPrint('[VspCopilotService] Unexpected error: $e\n$stack');
      return CopilotMessage.assistant(
        'تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.',
        conversationId: conversationId,
      );
    }
  }
}
