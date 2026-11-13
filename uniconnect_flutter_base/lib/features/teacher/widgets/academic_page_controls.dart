import 'package:flutter/material.dart';
import '../services/teacher_academic_service.dart';

class AcademicPageControls extends StatelessWidget {
  const AcademicPageControls(
      {super.key, required this.page, required this.onPage});

  final AcademicPage<Object?> page;
  final ValueChanged<int>? onPage;

  @override
  Widget build(BuildContext context) {
    if (page.page == 1 && !page.hasNext) return const SizedBox.shrink();
    return Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
      TextButton(
        onPressed: page.page > 1 && onPage != null
            ? () => onPage!(page.page - 1)
            : null,
        child: const Text('Anterior'),
      ),
      Text('Página ${page.page}'),
      TextButton(
        onPressed: page.hasNext && onPage != null
            ? () => onPage!(page.page + 1)
            : null,
        child: const Text('Próxima'),
      ),
    ]);
  }
}
