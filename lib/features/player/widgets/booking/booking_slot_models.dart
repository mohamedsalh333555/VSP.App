/// نموذج يمثل شريحة زمنية قابلة للحجز في الملعب
class TimeSlotItem {
  final String startTime;
  final String endTime;
  final String key;
  final int startMinutes;

  TimeSlotItem({
    required this.startTime,
    required this.endTime,
    required this.key,
    required this.startMinutes,
  });
}
