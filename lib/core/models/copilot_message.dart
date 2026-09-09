import 'package:flutter/foundation.dart';

/// Represents a stadium search result returned by VSP Copilot
@immutable
class CopilotStadiumSummary {
  final String id;
  final String name;
  final String governorate;
  final double pricePerHour;
  final String imageUrl;
  final double rating;

  const CopilotStadiumSummary({
    required this.id,
    required this.name,
    required this.governorate,
    required this.pricePerHour,
    this.imageUrl = '',
    this.rating = 0.0,
  });

  factory CopilotStadiumSummary.fromMap(Map<String, dynamic> map) {
    final rawPPH = map['price_per_hour'] ?? map['pricePerHour'] ?? 0;
    final rawRating = map['rating'] ?? 0;

    return CopilotStadiumSummary(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      governorate: map['governorate']?.toString() ?? '',
      pricePerHour: rawPPH is num ? rawPPH.toDouble() : (double.tryParse(rawPPH.toString()) ?? 0.0),
      imageUrl: map['image_url']?.toString() ?? map['imageUrl']?.toString() ?? '',
      rating: rawRating is num ? rawRating.toDouble() : (double.tryParse(rawRating.toString()) ?? 0.0),
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'governorate': governorate,
    'price_per_hour': pricePerHour,
    'image_url': imageUrl,
    'rating': rating,
  };
}

/// Represents a conversation session
@immutable
class CopilotConversation {
  final String id;
  final String title;
  final DateTime createdAt;
  final DateTime updatedAt;

  const CopilotConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CopilotConversation.fromMap(Map<String, dynamic> map) {
    return CopilotConversation(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? 'محادثة جديدة',
      createdAt: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Represents a chat message between the user and VSP Copilot
@immutable
class CopilotMessage {
  final String id;
  final String? conversationId;
  final String sender; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final List<CopilotStadiumSummary> stadiumResults;

  const CopilotMessage({
    required this.id,
    this.conversationId,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.stadiumResults = const [],
  });

  bool get isUser => sender == 'user';
  bool get hasStadiums => stadiumResults.isNotEmpty;

  factory CopilotMessage.user(String text, {String? conversationId}) {
    return CopilotMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: conversationId,
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );
  }

  factory CopilotMessage.assistant(
    String text, {
    String? conversationId,
    List<CopilotStadiumSummary> stadiums = const [],
  }) {
    return CopilotMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: conversationId,
      sender: 'assistant',
      text: text,
      timestamp: DateTime.now(),
      stadiumResults: stadiums,
    );
  }

  factory CopilotMessage.fromMap(Map<String, dynamic> map) {
    final rawStadiums = map['stadium_results'] as List<dynamic>? ?? [];
    return CopilotMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString(),
      sender: map['role']?.toString() ?? 'assistant',
      text: map['content']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      stadiumResults: rawStadiums
          .whereType<Map<String, dynamic>>()
          .map((s) => CopilotStadiumSummary.fromMap(s))
          .toList(),
    );
  }
}
