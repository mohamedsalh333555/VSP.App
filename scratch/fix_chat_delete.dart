import 'dart:io';

void main() {
  final chatFile = File('lib/core/repositories/chat_repository.dart');
  if (chatFile.existsSync()) {
    var content = chatFile.readAsStringSync();
    final oldMethod = '''  Future<void> deleteConversationForUser(String bookingId, String userId) async {
    try {
      final messages = await _supabase
          .from('chat_messages')
          .select('id, deleted_for_users')
          .eq('booking_id', bookingId);

      for (final msg in (messages as List)) {
        final String msgId = msg['id'].toString();
        final List<dynamic> currentDeleted = msg['deleted_for_users'] ?? [];
        final Set<String> updatedSet = currentDeleted.map((e) => e.toString()).toSet()..add(userId);

        await _supabase.from('chat_messages').update({
          'deleted_for_users': updatedSet.toList(),
        }).eq('id', msgId);
      }
    } catch (e) {
      VSPLogger.e('Error deleting conversation for user \$userId', e);
    }
  }''';

    final newMethod = '''  Future<void> deleteConversationForUser(String bookingId, String userId) async {
    try {
      final messages = await _supabase
          .from('chat_messages')
          .select('id, deleted_for_users')
          .eq('booking_id', bookingId);

      for (final msg in (messages as List)) {
        final String msgId = msg['id'].toString();
        final List<dynamic> currentDeleted = msg['deleted_for_users'] ?? [];
        final Set<String> updatedSet = currentDeleted.map((e) => e.toString()).toSet()..add(userId);

        await _supabase.from('chat_messages').update({
          'deleted_for_users': updatedSet.toList(),
        }).eq('id', msgId);
      }

      final bookingResponse = await _supabase
          .from('bookings')
          .select('deleted_for_users')
          .eq('id', bookingId)
          .maybeSingle();

      if (bookingResponse != null) {
        final List<dynamic> currentDeleted = bookingResponse['deleted_for_users'] ?? [];
        final Set<String> updatedSet = currentDeleted.map((e) => e.toString()).toSet()..add(userId);

        await _supabase.from('bookings').update({
          'deleted_for_users': updatedSet.toList(),
        }).eq('id', bookingId);
      }
    } catch (e) {
      VSPLogger.e('Error deleting conversation for user \$userId', e);
    }
  }''';

    if (!content.contains('select(\'deleted_for_users\')')) {
      content = content.replaceFirst(oldMethod, newMethod);
      chatFile.writeAsStringSync(content);
      print('✅ Updated lib/core/repositories/chat_repository.dart');
    } else {
      print('ℹ️ lib/core/repositories/chat_repository.dart is already updated.');
    }
  }

  final inboxFile = File('lib/features/owner/screens/owner_inbox_screen.dart');
  if (inboxFile.existsSync()) {
    var content = inboxFile.readAsStringSync();
    final oldLoop = 'for (final data in rawBookings) {\n            final b = Booking.fromFirestore(data, data[\'id\'].toString());';
    final newLoop = 'for (final data in rawBookings) {\n            final List<dynamic> deletedForUsers = data[\'deleted_for_users\'] ?? [];\n            if (deletedForUsers.map((e) => e.toString()).contains(ownerId)) {\n              continue;\n            }\n\n            final b = Booking.fromFirestore(data, data[\'id\'].toString());';

    if (!content.contains('deletedForUsers.map')) {
      content = content.replaceFirst(oldLoop, newLoop);
      inboxFile.writeAsStringSync(content);
      print('✅ Updated lib/features/owner/screens/owner_inbox_screen.dart');
    } else {
      print('ℹ️ lib/features/owner/screens/owner_inbox_screen.dart is already updated.');
    }
  }
}
