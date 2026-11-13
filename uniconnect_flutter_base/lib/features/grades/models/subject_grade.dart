class SubjectGrade {
  const SubjectGrade({
    this.id,
    this.disciplineName,
    this.periodLabel,
    this.isHistorical = false,
    this.activityId,
    this.feedback,
    required this.subject,
    required this.code,
    required this.teacher,
    required this.grade,
  });

  final String subject;
  final String? id;
  final String? disciplineName;
  final String? periodLabel;
  final bool isHistorical;
  final String? activityId;
  final String? feedback;
  final String code;
  final String teacher;
  final double? grade;
}
