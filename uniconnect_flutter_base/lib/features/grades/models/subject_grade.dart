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
    required this.p1,
    required this.p2,
    required this.work,
    required this.status,
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
  final double p1;
  final double p2;
  final double work;
  final String status;

  double get finalAverage => (p1 * .35) + (p2 * .35) + (work * .30);
}
