import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/copilot_message.dart';

/// Client service communicating with the secure Supabase Edge Function `vsp_copilot`.
/// ZERO AI API keys are stored or referenced in this client layer.
class VspCopilotService {
  final SupabaseClient? _client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  const VspCopilotService({SupabaseClient? client}) : _client = client;

  /// Sends a user message to VSP Copilot and parses the returned assistant message and stadium results.
  Future<CopilotMessage> sendMessage(String text) async {
    final cleanText = text.trim();
    if (cleanText.isEmpty) {
      return CopilotMessage.assistant('الرجاء كتابة رسالة واضحة للبحث يا كابتن.');
    }

    try {
      final response = await _supabase.functions.invoke(
        'vsp_copilot',
        body: {'message': cleanText},
      );

      final statusCode = response.status;

      if (statusCode == 401) {
        return CopilotMessage.assistant(
          'يجب تسجيل الدخول أولاً لاستخدام كابتن VSP الذكي.',
        );
      }

      if (statusCode == 429) {
        return CopilotMessage.assistant(
          'تم تجاوز الحد المسموح من الرسائل في الدقيقة. يرجى الانتظار دقيقة واحدة والمحاولة مرة أخرى.',
        );
      }

      if (statusCode >= 400) {
        final errorData = response.data is Map ? response.data['error'] : null;
        debugPrint('[VspCopilotService] Error response ($statusCode): $errorData');
        return CopilotMessage.assistant(
          'عذراً، حدث خطأ أثناء الاتصال بالخادم. يرجى المحاولة لاحقاً.',
        );
      }

      final data = response.data;
      if (data is Map<String, dynamic>) {
        final replyText = data['message']?.toString() ?? 'تم استلام طلبك بنجاح.';
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

        return CopilotMessage.assistant(replyText, stadiums: stadiums);
      }

      return CopilotMessage.assistant('تم استلام الرد بنجاح بدون نتائج إضافية.');
    } on FunctionException catch (fe) {
      debugPrint('[VspCopilotService] FunctionException: ${fe.status} -> ${fe.details}');
      if (fe.status == 401) {
        return CopilotMessage.assistant('انتهت جلسة تسجيل الدخول. يرجى إعادة الدخول للتطبيق.');
      }
      if (fe.status == 429) {
        return CopilotMessage.assistant('أنت ترسل رسائل بسرعة كبيرة! يرجى الانتظار دقيقة.');
      }
      return CopilotMessage.assistant('عذراً، تعذر الوصول لخدمة المساعد الذكي حالياً.');
    } catch (e, stack) {
      debugPrint('[VspCopilotService] Unexpected error: $e\n$stack');
      return CopilotMessage.assistant('تعذر الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت.');
    }
  }
}
