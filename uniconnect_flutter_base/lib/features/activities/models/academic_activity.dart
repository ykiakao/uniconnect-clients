enum ActivityPriority { critical, medium, low }

enum ActivityStatus { pending, inProgress, done }

class AcademicActivity {
  const AcademicActivity({
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
  final DateTime dueDate;
  final String teacher;
  final ActivityPriority priority;
  final ActivityStatus status;
  final List<String> criteria;
  final List<String> attachments;
}
