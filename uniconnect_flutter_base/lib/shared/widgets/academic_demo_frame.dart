import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/academic/demo/synthetic_academic_providers.dart';

class AcademicDemoFrame extends ConsumerWidget {
  const AcademicDemoFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(syntheticDemoEnabledProvider)) return child;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label:
          'Ambiente de demonstração. Dados acadêmicos fictícios da EduKMais.',
      child: child,
    );
  }
}
