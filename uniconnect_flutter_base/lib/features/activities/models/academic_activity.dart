enum ActivityPriority { critical, medium, low, expired, noDeadline }

enum ActivityStatus { pending, inProgress, done }

class AcademicActivity {
  const AcademicActivity({
    this.demoReferenceTime,
    this.publicationState,
    this.workflowEnabled = false,
    this.assessmentCategory,
    this.instructions = '',
    this.allowLate = false,
    required this.id,
    required this.subject,
    required this.title,
    required this.description,
    required this.dueDate,
    required this.teacher,
    required this.status,
    required this.criteria,
    required this.attachments,
  });

  final String id;
  final String? publicationState;
  final bool workflowEnabled;
  final String? assessmentCategory;
  final String instructions;
  final bool allowLate;
  final String subject;
  final String title;
  final String description;
  final DateTime? dueDate;
  final String teacher;
  final ActivityStatus status;
  final List<String> criteria;
  final List<String> attachments;
  final DateTime? demoReferenceTime;

  bool get acceptsTextSubmission =>
      workflowEnabled &&
      (assessmentCategory == null || assessmentCategory == 'activity');

  Duration? remainingAt(DateTime now) =>
      dueDate?.difference(demoReferenceTime ?? now);

  ActivityPriority priorityAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining == null) return ActivityPriority.noDeadline;
    if (remaining.isNegative) return ActivityPriority.expired;
    final days = _roundedDays(remaining);
    if (days <= 3) return ActivityPriority.critical;
    if (days <= 5) return ActivityPriority.medium;
    return ActivityPriority.low;
  }

  bool get isExpired => priorityAt(DateTime.now()) == ActivityPriority.expired;
  bool isUpcomingAt(DateTime now) =>
      (remainingAt(now) ?? Duration.zero) > Duration.zero;
  bool isDueSoonAt(DateTime now) {
    final remaining = remainingAt(now);
    return remaining != null &&
        remaining > Duration.zero &&
        remaining <= const Duration(days: 1);
  }

  String dueLabelAt(DateTime now) {
    final remaining = remainingAt(now);
    if (remaining == null) return 'Prazo não informado';
    if (remaining.isNegative) return 'Prazo encerrado';
    if (remaining.inHours < 1) return 'Vence em menos de 1 hora';
    if (remaining <= const Duration(days: 1)) {
      return 'Vence em ${remaining.inHours} h';
    }
    return 'Vence em ${_roundedDays(remaining)} dias';
  }

  static int _roundedDays(Duration remaining) =>
      (remaining.inMicroseconds / Duration.microsecondsPerDay).ceil();

  DateTime? get displayDueDate => demoReferenceTime == null
      ? dueDate?.toLocal()
      : dueDate?.toUtc().subtract(const Duration(hours: 5));
  String get timeZoneLabel => demoReferenceTime == null
      ? 'Horário do dispositivo'
      : 'Horário do Acre (UTC−5)';
}
