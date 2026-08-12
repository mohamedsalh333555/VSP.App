class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isEdited;
  final List<String> deletedForUsers;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.deletedForUsers = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
    final deletedList = (json['deleted_for_users'] is List)
        ? (json['deleted_for_users'] as List).map((e) => e.toString()).toList()
        : <String>[];

    return ChatMessage(
      id: id,
      senderId: json['sender_id'] ?? json['senderId'] ?? '',
      senderName: json['sender_name'] ?? json['senderName'] ?? '',
      text: json['text'] ?? '',
      timestamp: json['created_at'] != null 
          ? DateTime.parse(json['created_at'].toString()).toLocal()
          : (json['timestamp'] != null 
              ? DateTime.parse(json['timestamp'].toString()).toLocal()
              : DateTime.now()),
      isRead: json['is_read'] ?? json['isRead'] ?? false,
      isEdited: json['is_edited'] ?? json['isEdited'] ?? false,
      deletedForUsers: deletedList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'text': text,
      'created_at': timestamp.toUtc().toIso8601String(),
      'is_read': isRead,
      'is_edited': isEdited,
      'deleted_for_users': deletedForUsers,
    };
  }
}
