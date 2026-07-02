class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, String id) {
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
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'sender_id': senderId,
      'sender_name': senderName,
      'text': text,
      'created_at': timestamp.toUtc().toIso8601String(),
    };
  }
}
