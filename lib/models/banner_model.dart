/// Model representing a dynamic promotional banner from Supabase `banners` table.
class AppBanner {
  final String id;
  final String title;
  final String imageUrl;
  final String? targetUrl;
  final String placement;
  final int durationSeconds;
  final DateTime? startDate;
  final DateTime? endDate;
  final bool isActive;
  final int priorityOrder;
  final int clicksCount;
  final int viewsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AppBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.targetUrl,
    this.placement = 'home_slider',
    this.durationSeconds = 5,
    this.startDate,
    this.endDate,
    this.isActive = true,
    this.priorityOrder = 0,
    this.clicksCount = 0,
    this.viewsCount = 0,
    this.createdAt,
    this.updatedAt,
  });

  /// Factory constructor to create an [AppBanner] from a JSON / Supabase Map.
  factory AppBanner.fromJson(Map<String, dynamic> json) {
    return AppBanner(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      imageUrl: (json['image_url'] ?? json['imageUrl']) as String? ?? '',
      targetUrl: (json['target_url'] ?? json['targetUrl']) as String?,
      placement: json['placement'] as String? ?? 'home_slider',
      durationSeconds: (json['duration_seconds'] ?? json['durationSeconds'] ?? 5) as int,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : (json['startDate'] != null ? DateTime.tryParse(json['startDate'].toString()) : null),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : (json['endDate'] != null ? DateTime.tryParse(json['endDate'].toString()) : null),
      isActive: (json['is_active'] ?? json['isActive'] ?? true) as bool,
      priorityOrder: (json['priority_order'] ?? json['priorityOrder'] ?? 0) as int,
      clicksCount: (json['clicks_count'] ?? json['clicksCount'] ?? 0) as int,
      viewsCount: (json['views_count'] ?? json['viewsCount'] ?? 0) as int,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at'].toString()) : null,
    );
  }

  /// Alias for `fromJson` for standard map-based decoding
  factory AppBanner.fromMap(Map<String, dynamic> map, [String? id]) {
    final effectiveMap = Map<String, dynamic>.from(map);
    if (id != null && id.isNotEmpty) {
      effectiveMap['id'] = id;
    }
    return AppBanner.fromJson(effectiveMap);
  }

  /// Converts the banner to a JSON map suitable for Supabase insertion / updates.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'image_url': imageUrl,
      'target_url': targetUrl,
      'placement': placement,
      'duration_seconds': durationSeconds,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'is_active': isActive,
      'priority_order': priorityOrder,
      'clicks_count': clicksCount,
      'views_count': viewsCount,
      if (createdAt != null) 'created_at': createdAt?.toIso8601String(),
      if (updatedAt != null) 'updated_at': updatedAt?.toIso8601String(),
    };
  }

  /// Alias for `toJson`
  Map<String, dynamic> toMap() => toJson();

  /// Checks if the banner is currently active and within its valid date range.
  bool get isValidNow {
    if (!isActive) return false;
    final now = DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  /// Helper to check whether the target is an external web link
  bool get isExternalUrl {
    if (targetUrl == null || targetUrl!.trim().isEmpty) return false;
    final lower = targetUrl!.trim().toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://') || lower.startsWith('wa.me');
  }

  /// Copy with helper
  AppBanner copyWith({
    String? id,
    String? title,
    String? imageUrl,
    String? targetUrl,
    String? placement,
    int? durationSeconds,
    DateTime? startDate,
    DateTime? endDate,
    bool? isActive,
    int? priorityOrder,
    int? clicksCount,
    int? viewsCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      targetUrl: targetUrl ?? this.targetUrl,
      placement: placement ?? this.placement,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      isActive: isActive ?? this.isActive,
      priorityOrder: priorityOrder ?? this.priorityOrder,
      clicksCount: clicksCount ?? this.clicksCount,
      viewsCount: viewsCount ?? this.viewsCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
