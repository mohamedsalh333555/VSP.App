import 'dart:io';

void main() {
  // 1. Update chat_repository.dart
  final chatFile = File('lib/core/repositories/chat_repository.dart');
  if (chatFile.existsSync()) {
    var content = chatFile.readAsStringSync();

    final newMethod = '''  /// Delete conversation for current user by adding ID to local SharedPreferences and Supabase
  Future<void> deleteConversationForUser(String bookingId, String userId, {String? contactId}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> deletedList = prefs.getStringList('deleted_chats_\$userId') ?? [];
      if (!deletedList.contains(bookingId)) {
        deletedList.add(bookingId);
      }
      if (contactId != null && contactId.isNotEmpty && !deletedList.contains(contactId)) {
        deletedList.add(contactId);
      }
      await prefs.setStringList('deleted_chats_\$userId', deletedList);

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
        VSPLogger.w('chat_messages delete notice: \$e');
      }

      try {
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
        VSPLogger.w('bookings delete notice: \$e');
      }
    } catch (e) {
      VSPLogger.e('Error deleting conversation for user \$userId', e);
    }
  }''';

    final reg = RegExp(r'Future<void>\s+deleteConversationForUser[\s\S]*?\}\s*\}', multiLine: true);
    if (reg.hasMatch(content)) {
      content = content.replaceFirst(reg, newMethod.trim());
      chatFile.writeAsStringSync(content);
      print('✅ Updated lib/core/repositories/chat_repository.dart');
    }
  }

  // 2. Update owner_inbox_screen.dart
  final inboxFile = File('lib/features/owner/screens/owner_inbox_screen.dart');
  if (inboxFile.existsSync()) {
    var content = inboxFile.readAsStringSync();

    if (!content.contains('FutureBuilder<List<String>>(')) {
      content = content.replaceFirst(
        "body: StreamBuilder<List<Map<String, dynamic>>>(",
        '''body: FutureBuilder<List<String>>(
        future: SharedPreferences.getInstance().then((p) => p.getStringList('deleted_chats_\$ownerId') ?? []),
        builder: (context, prefsSnap) {
          final localDeleted = prefsSnap.data ?? [];

          return StreamBuilder<List<Map<String, dynamic>>('''
      );

      content = content.replaceFirst(
        "for (final data in rawBookings) {",
        '''for (final data in rawBookings) {
            final bId = data['id'].toString();
            final List<dynamic> deletedForUsers = data['deleted_for_users'] ?? [];

            if (localDeleted.contains(bId) || deletedForUsers.map((e) => e.toString()).contains(ownerId)) {
              continue;
            }'''
      );

      content = content.replaceFirst(
        "groupedByContact.putIfAbsent(contactId, () => []).add({",
        '''if (localDeleted.contains(contactId)) {
                    continue;
                  }

                  groupedByContact.putIfAbsent(contactId, () => []).add({'''
      );

      content = content.replaceFirst(
        "        },\n      ),",
        "        },\n      );\n        },"
      );

      inboxFile.writeAsStringSync(content);
      print('✅ Updated lib/features/owner/screens/owner_inbox_screen.dart');
    }
  }

  // 3. Update chat_screen.dart
  final chatScreenFile = File('lib/features/player/screens/chat_screen.dart');
  if (chatScreenFile.existsSync()) {
    var content = chatScreenFile.readAsStringSync();
    if (!content.contains('contactId: otherUserId')) {
      content = content.replaceFirst(
        "await ChatRepository().deleteConversationForUser(widget.booking.id, currentUserId);",
        '''final otherUserId = widget.booking.joinedUserIds.firstWhere(
                (uid) => uid != currentUserId,
                orElse: () => '',
              );

              await ChatRepository().deleteConversationForUser(
                widget.booking.id, 
                currentUserId,
                contactId: otherUserId.isNotEmpty ? otherUserId : null,
              );'''
      );
      chatScreenFile.writeAsStringSync(content);
      print('✅ Updated lib/features/player/screens/chat_screen.dart');
    }
  }
}
