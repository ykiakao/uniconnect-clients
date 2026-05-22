import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject_grade.dart';

final subjectGradesProvider = Provider<List<SubjectGrade>>((ref) {
  return const [
    SubjectGrade(
      subject: 'Arquitetura de Sistemas',
      p1: 8.8,
      p2: 9.1,
      work: 9.4,
      status: 'Aprovado',
    ),
    SubjectGrade(
      subject: 'Calculo III',
      p1: 7.2,
      p2: 8.0,
      work: 8.6,
      status: 'Em curso',
    ),
    SubjectGrade(
      subject: 'Inteligência Artificial',
      p1: 9.5,
      p2: 0,
      work: 8.7,
      status: 'Em curso',
    ),
  ];
});
