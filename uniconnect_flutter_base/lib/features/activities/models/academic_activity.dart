enum ActivityPriority { critical, medium, low }

enum ActivityStatus { pending, inProgress, done }

class AcademicActivity {
  const AcademicActivity({
    this.demoReferenceTime,
    required this.id,
    required this.subject,
    required this.title,
    required this.description,
    required this.dueLabel,
    required this.dueDate,
    required this.teacher,
    required this.priority,
    required this.status,
    required this.criteria,
    required this.attachments,
  });

  final String id;
  final String subject;
  final String title;
  final String description;
  final String dueLabel;
  final DateTime? dueDate;
  final String teacher;
  final ActivityPriority priority;
  final ActivityStatus status;
  final List<String> criteria;
  final List<String> attachments;
  final DateTime? demoReferenceTime;

  DateTime get comparisonTime => demoReferenceTime ?? DateTime.now();
  bool get isExpired => dueDate?.isBefore(comparisonTime) ?? false;
  bool get isUpcoming => dueDate?.isAfter(comparisonTime) ?? false;
  bool get isDueSoon {
    final due = dueDate;
    final now = comparisonTime;
    return due != null &&
        due.isAfter(now) &&
        due.difference(now) <= const Duration(hours: 24);
  }

  DateTime? get displayDueDate => demoReferenceTime == null
      ? dueDate?.toLocal()
      : dueDate?.toUtc().subtract(const Duration(hours: 5));
  String get timeZoneLabel => demoReferenceTime == null
      ? 'Horário do dispositivo'
      : 'Horário do Acre (UTC−5)';
}
