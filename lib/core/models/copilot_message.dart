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

/// Represents an in-app actionable command (e.g. navigation or screen jump)
@immutable
class CopilotAction {
  final String actionType;
  final String route;
  final String label;
  final Map<String, dynamic>? params;

  const CopilotAction({
    required this.actionType,
    required this.route,
    required this.label,
    this.params,
  });

  factory CopilotAction.fromMap(Map<String, dynamic> map) {
    return CopilotAction(
      actionType: map['action_type']?.toString() ?? 'NAVIGATE',
      route: map['route']?.toString() ?? '/player',
      label: map['label']?.toString() ?? 'الانتقال',
      params: map['params'] is Map<String, dynamic> ? map['params'] as Map<String, dynamic> : null,
    );
  }
}

/// Represents a tournament summary returned by VSP Copilot
@immutable
class CopilotTournamentSummary {
  final String id;
  final String name;
  final String type;
  final double grandPrize;
  final double entryFee;
  final String governorate;
  final String status;

  const CopilotTournamentSummary({
    required this.id,
    required this.name,
    this.type = 'knockout',
    this.grandPrize = 0.0,
    this.entryFee = 0.0,
    this.governorate = '',
    this.status = 'open',
  });

  factory CopilotTournamentSummary.fromMap(Map<String, dynamic> map) {
    final rawPrize = map['grand_prize'] ?? map['prize_pool'] ?? 0;
    final rawFee = map['entry_fee'] ?? 0;
    return CopilotTournamentSummary(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? 'بطولة',
      type: map['type']?.toString() ?? 'tournament',
      grandPrize: rawPrize is num ? rawPrize.toDouble() : (double.tryParse(rawPrize.toString()) ?? 0.0),
      entryFee: rawFee is num ? rawFee.toDouble() : (double.tryParse(rawFee.toString()) ?? 0.0),
      governorate: map['governorate']?.toString() ?? '',
      status: map['status']?.toString() ?? 'open',
    );
  }
}

/// Represents an open match booking waiting for players
@immutable
class CopilotOpenMatchSummary {
  final String id;
  final String stadiumName;
  final DateTime? startTime;
  final int currentPlayers;
  final int maxPlayers;
  final String notes;
  final double totalPrice;

  const CopilotOpenMatchSummary({
    required this.id,
    required this.stadiumName,
    this.startTime,
    this.currentPlayers = 0,
    this.maxPlayers = 10,
    this.notes = '',
    this.totalPrice = 0.0,
  });

  int get missingPlayers => (maxPlayers - currentPlayers).clamp(0, maxPlayers);

  factory CopilotOpenMatchSummary.fromMap(Map<String, dynamic> map) {
    final rawPrice = map['total_price'] ?? 0;
    return CopilotOpenMatchSummary(
      id: map['id']?.toString() ?? '',
      stadiumName: map['stadium_name']?.toString() ?? 'ملعب',
      startTime: DateTime.tryParse(map['start_time']?.toString() ?? ''),
      currentPlayers: (map['current_players'] ?? 0) as int,
      maxPlayers: (map['max_players'] ?? 10) as int,
      notes: map['notes']?.toString() ?? '',
      totalPrice: rawPrice is num ? rawPrice.toDouble() : (double.tryParse(rawPrice.toString()) ?? 0.0),
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
  final List<CopilotTournamentSummary> tournamentResults;
  final List<CopilotOpenMatchSummary> openMatchResults;
  final CopilotAction? action;

  const CopilotMessage({
    required this.id,
    this.conversationId,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.stadiumResults = const [],
    this.tournamentResults = const [],
    this.openMatchResults = const [],
    this.action,
  });

  bool get isUser => sender == 'user';
  bool get hasStadiums => stadiumResults.isNotEmpty;
  bool get hasTournaments => tournamentResults.isNotEmpty;
  bool get hasOpenMatches => openMatchResults.isNotEmpty;
  bool get hasAction => action != null;

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
    List<CopilotTournamentSummary> tournaments = const [],
    List<CopilotOpenMatchSummary> openMatches = const [],
    CopilotAction? action,
  }) {
    return CopilotMessage(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      conversationId: conversationId,
      sender: 'assistant',
      text: text,
      timestamp: DateTime.now(),
      stadiumResults: stadiums,
      tournamentResults: tournaments,
      openMatchResults: openMatches,
      action: action,
    );
  }

  factory CopilotMessage.fromMap(Map<String, dynamic> map) {
    final rawStadiums = map['stadium_results'] as List<dynamic>? ?? [];
    final rawTournaments = map['tournament_results'] as List<dynamic>? ?? map['tournaments'] as List<dynamic>? ?? [];
    final rawMatches = map['open_matches'] as List<dynamic>? ?? [];
    final rawAction = map['action'] is Map<String, dynamic> ? map['action'] as Map<String, dynamic> : null;

    return CopilotMessage(
      id: map['id']?.toString() ?? '',
      conversationId: map['conversation_id']?.toString(),
      sender: map['role']?.toString() ?? 'assistant',
      text: map['content']?.toString() ?? map['message']?.toString() ?? '',
      timestamp: DateTime.tryParse(map['created_at']?.toString() ?? '') ?? DateTime.now(),
      stadiumResults: rawStadiums
          .whereType<Map<String, dynamic>>()
          .map((s) => CopilotStadiumSummary.fromMap(s))
          .toList(),
      tournamentResults: rawTournaments
          .whereType<Map<String, dynamic>>()
          .map((t) => CopilotTournamentSummary.fromMap(t))
          .toList(),
      openMatchResults: rawMatches
          .whereType<Map<String, dynamic>>()
          .map((m) => CopilotOpenMatchSummary.fromMap(m))
          .toList(),
      action: rawAction != null ? CopilotAction.fromMap(rawAction) : null,
    );
  }
}
