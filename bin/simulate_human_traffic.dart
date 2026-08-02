import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() async {
  print('🚀 بدء محاكاة 70 مستخدماً بشرياً على سيرفر VSP...');

  const supabaseUrl = 'https://mktqkddbcddrxjxabdua.supabase.co';
  const supabaseAnonKey = 'sb_publishable_I6UoUL32GmnFZcXQ5ioasA_WLgizloE';

  await Supabase.initialize(
    url: supabaseUrl,
    publishableKey: supabaseAnonKey,
  );

  final client = Supabase.instance.client;
  final random = Random();

  print('👥 تشغيل 10 بوتات للمالكين و 60 بوت للاعبين...');

  // 1. تشغيل 10 بوتات ملاك
  for (int i = 1; i <= 10; i++) {
    simulateOwnerBot(client, i, random);
  }

  // 2. تشغيل 60 بوت لاعبين
  for (int i = 1; i <= 60; i++) {
    simulatePlayerBot(client, i, random);
  }

  // إبقاء العملية نشطة لمدة 30 ثانية لمتابعة الأداء
  await Future.delayed(const Duration(seconds: 30));
  print('✨ اكتملت جلسة محاكاة ضغط المستخدمين بنجاح!');
}

// محاكاة سلوك المالك البشري
void simulateOwnerBot(SupabaseClient client, int id, Random random) async {
  // تأخير بشري عشوائي قبل البدء (بين 1 إلى 5 ثوانٍ)
  await Future.delayed(Duration(seconds: random.nextInt(5) + 1));
  print('🏟️ [مالك $id] فتح التطبيق ويتصفح لوحة التحكم...');

  // الاستماع اللحظي للحجوزات الواردة عبر Realtime Stream
  try {
    client.from('bookings').stream(primaryKey: ['id']).listen((data) {
      print('⚡ [مالك $id] استلم تحديثاً لحظياً للحجوزات! (${data.length} حجز)');
    }, onError: (err) {
      print('ℹ️ [مالك $id] Realtime stream event: $err');
    });
  } catch (e) {
    print('⚠️ [مالك $id] تعذر فتح الستريم: $e');
  }
}

// محاكاة سلوك اللاعب البشري
void simulatePlayerBot(SupabaseClient client, int id, Random random) async {
  // 1. تأخير بشري لتصفح الملاعب (قراءة الشاشة لمدة 3 إلى 8 ثوانٍ)
  await Future.delayed(Duration(seconds: random.nextInt(6) + 3));
  print('⚽ [لاعب $id] يتصفح الملاعب القريبة...');

  // 2. محاولة انضمام لمباراة عامة
  try {
    final response = await client.rpc('request_join_public_match', params: {
      'p_booking_id': '00000000-0000-0000-0000-000000000001', // UUID افتراضي للمباراة التجريبية
      'p_user_id': '00000000-0000-0000-0000-0000000000$id',
    });
    print('✅ [لاعب $id] استجابة الانضمام: $response');
  } catch (e) {
    final cleanErr = e.toString().replaceAll('\n', ' ');
    print('🛑 [لاعب $id] نتيجة الطلب: $cleanErr');
  }
}
