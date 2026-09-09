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

/// Represents a chat message between the user and VSP Copilot
@immutable
class CopilotMessage {
  final String id;
  final String sender; // 'user' | 'assistant'
  final String text;
  final DateTime timestamp;
  final List<CopilotStadiumSummary> stadiumResults;

  const CopilotMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.stadiumResults = const [],
  });

  bool get isUser => sender == 'user';
  bool get hasStadiums => stadiumResults.isNotEmpty;

  factory CopilotMessage.user(String text) {
    return CopilotMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'user',
      text: text,
      timestamp: DateTime.now(),
    );
  }

  factory CopilotMessage.assistant(String text, {List<CopilotStadiumSummary> stadiums = const []}) {
    return CopilotMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      sender: 'assistant',
      text: text,
      timestamp: DateTime.now(),
      stadiumResults: stadiums,
    );
  }
}
