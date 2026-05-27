import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject_grade.dart';

final subjectGradesProvider = Provider<List<SubjectGrade>>((ref) {
  return const [
    SubjectGrade(
      subject: 'Cálculo Diferencial III',
      code: 'MAT-204',
      teacher: 'Prof. Ricardo Silva',
      p1: 9.5,
      p2: 9.2,
      work: 9.8,
      status: 'Aprovado',
    ),
    SubjectGrade(
      subject: 'Arquitetura de Sistemas',
      code: 'SIS-102',
      teacher: 'Prof. Amanda Costa',
      p1: 8.8,
      p2: 9.1,
      work: 8.4,
      status: 'Aprovado',
    ),
    SubjectGrade(
      subject: 'Estrutura de Dados',
      code: 'COMP-301',
      teacher: 'Prof. Helena Souza',
      p1: 9.2,
      p2: 9.0,
      work: 9.4,
      status: 'Aprovado',
    ),
    SubjectGrade(
      subject: 'Inteligência Artificial',
      code: 'IA-500',
      teacher: 'Prof. Marcus Weber',
      p1: 0,
      p2: 0,
      work: 0,
      status: 'Em curso',
    ),
  ];
});
