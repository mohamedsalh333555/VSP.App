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
   final rawDate = data['createdAt'] ?? data['created_at'];
   // Some historical notification producers wrote Unix seconds/milliseconds
   // rather than ISO timestamps. Preserve their chronological order.
   final numericDate = rawDate is num
       ? rawDate
       : (rawDate is String ? num.tryParse(rawDate.trim()) : null);
   // Validate after unit conversion: large numeric values must not throw
   // RangeError and hide the rest of the notification inbox.
   final timestampMs = numericDate == null || !numericDate.isFinite
       ? null
       : (numericDate.abs() < 100000000000
           ? numericDate * 1000
           : numericDate);
   final parsedDate = rawDate is DateTime
       ? rawDate
       : timestampMs != null &&
               timestampMs >= -8640000000000000 &&
               timestampMs <= 8640000000000000
           ? DateTime.fromMillisecondsSinceEpoch(
               timestampMs.round(),
               isUtc: true,
             )
           : numericDate == null
               ? DateTime.tryParse(rawDate?.toString() ?? '')
               : null;
   final rawRead = data['isRead'] ?? data['is_read'];
   final normalizedRead = rawRead?.toString().trim().toLowerCase();
   final read = rawRead == true ||
       rawRead == 1 ||
       normalizedRead == 'true' ||
       normalizedRead == '1';
   final rawMetadata = data['metadata'];
   return AppNotification(
     id: id,
     title: data['title']?.toString() ?? '',
     // Historical notifications used message instead of body.
     body: (data['body']?.toString().trim().isNotEmpty == true
         ? data['body']
         : data['message'])?.toString() ?? '',
     type: data['type']?.toString() ?? 'info',
     isRead: read,
     // Malformed legacy timestamps must not crash the whole notification list.
     createdAt: parsedDate ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
     bookingId: (data['bookingId'] ?? data['booking_id'])?.toString(),
     // Ignore malformed metadata keys rather than dropping the whole inbox.
     metadata: rawMetadata is Map
         ? <String, dynamic>{
             for (final entry in rawMetadata.entries)
               if (entry.key is String) (entry.key as String): entry.value,
           }
         : null,
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

