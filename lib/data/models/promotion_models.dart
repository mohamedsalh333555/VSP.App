class Promotion {
 final String id;
 final String title;
 final String imageUrl;
 final String? deepLink;
 final String type; // 'match', 'stadium', 'championship', 'external'
 final bool isActive;

 Promotion({
 required this.id,
 required this.title,
 required this.imageUrl,
 this.deepLink,
 required this.type,
 this.isActive = true,
 });

 factory Promotion.fromMap(Map<String, dynamic> data, [String? id]) =>
 Promotion.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

 factory Promotion.fromFirestore(Map<String, dynamic> data, String id) {
 return Promotion(
 id: id,
 title: data['title'] ?? '',
 imageUrl: data['imageUrl'] ?? data['image_url'] ?? '',
 deepLink: data['deepLink'] ?? data['deep_link'],
 type: data['type'] ?? 'info',
 isActive: data['isActive'] ?? data['is_active'] ?? true,
 );
 }

 Map<String, dynamic> toMap() => {
 'title': title,
 'imageUrl': imageUrl,
 'deepLink': deepLink,
 'type': type,
 'isActive': isActive,
 };

 Map<String, dynamic> toFirestore() => toMap();
}

// === VSP MATCHUPS DOMAIN MODELS (ميزة مواجهات) ===

