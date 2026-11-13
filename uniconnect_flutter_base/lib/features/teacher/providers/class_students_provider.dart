import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'teacher_activity_provider.dart';

const _maxStudentPages = 10;

typedef ClassStudent = ({String id, String name});

/// Students of one of the teacher's offerings, from the class report card.
final classStudentsProvider = FutureProvider.autoDispose
    .family<List<ClassStudent>, String>((ref, classId) async {
  final service = ref.watch(teacherAcademicServiceProvider);
  final students = <ClassStudent>[];
  for (var page = 1; page <= _maxStudentPages; page++) {
    final result = await service.summary(classId, page: page);
    students.addAll(
        result.rows.map((row) => (id: row.studentId, name: row.studentName)));
    if (!result.hasNext) break;
  }
  students.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return List.unmodifiable(students);
}, retry: (_, __) => null);

/// Name of a student of [classId]. While names load, the identifier; when
/// the class list does not include the student, a short readable label.
String classStudentName(WidgetRef ref, String? classId, String studentId) {
  if (classId == null) return studentId;
  final students = ref.watch(classStudentsProvider(classId)).asData?.value;
  if (students == null) return studentId;
  final name = students
      .where((student) => student.id == studentId)
      .firstOrNull
      ?.name
      .trim();
  if (name != null && name.isNotEmpty) return name;
  final short = studentId.length > 8 ? studentId.substring(0, 8) : studentId;
  return 'não identificado na turma (ID $short)';
}
