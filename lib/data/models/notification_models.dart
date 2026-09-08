class AppNotification {
 final String id;
 final String title;
 final String body;
 final String type; // 'info', 'result_confirmation'
 final bool isRead;
 final DateTime createdAt;
 final String? bookingId; 
 final Map<String, dynamic>? metadata;

 AppNotification({
 required this.id,
 required this.title,
 required this.body,
 required this.type,
 this.isRead = false,
 required this.createdAt,
 this.bookingId,
 this.metadata,
 });

 factory AppNotification.fromMap(Map<String, dynamic> data, [String? id]) =>
 AppNotification.fromFirestore(data, id ?? (data['id']?.toString() ?? ''));

 factory AppNotification.fromFirestore(Map<String, dynamic> data, String id) {
 return AppNotification(
 id: id,
 title: data['title'] ?? '',
 body: data['body'] ?? '',
 type: data['type'] ?? 'info',
 isRead: data['isRead'] ?? false,
 createdAt: data['createdAt'] != null 
 ? (data['createdAt'] is DateTime 
 ? data['createdAt'] 
 : DateTime.parse(data['createdAt'].toString()))
 : DateTime.now(),
 bookingId: data['bookingId'],
 metadata: data['metadata'] is Map<String, dynamic> ? Map<String, dynamic>.from(data['metadata']) : null,
 );
 }

 Map<String, dynamic> toMap() => toFirestore();

 Map<String, dynamic> toFirestore() {
 return {
 'title': title,
 'body': body,
 'type': type,
 'isRead': isRead,
 'createdAt': createdAt.toIso8601String(),
 'bookingId': bookingId,
 'metadata': metadata,
 };
 }
}

