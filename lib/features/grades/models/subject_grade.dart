class SubjectGrade {
  const SubjectGrade({
    required this.subject,
    required this.p1,
    required this.p2,
    required this.work,
    required this.status,
  });

  final String subject;
  final double p1;
  final double p2;
  final double work;
  final String status;

  double get finalAverage => (p1 * .35) + (p2 * .35) + (work * .30);
}
