import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';

class StudentAcademicPage extends ConsumerWidget {
  const StudentAcademicPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final institution = user?.tenant;
    final semester = user?.semester;
    final details = [
      (
        'Instituição',
        institution?.id.isNotEmpty == true ? institution?.name : null
      ),
      ('Matrícula', user?.registration),
      ('Curso', user?.course),
      ('Semestre do curso', semester == null ? null : '$semesterº semestre'),
    ];
    return Scaffold(
      appBar: const AppHeader(title: 'Acadêmico', showProfile: true),
      bottomNavigationBar: const UniBottomNav(currentIndex: 4),
      body: SafeArea(
        child: AcademicContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              const SectionHeader(title: 'Vínculo acadêmico'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (label, value) in details)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Text(
                            '$label: ${value == null || value.trim().isEmpty ? 'Não informado' : value.trim()}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Quadro de horários e calendário'),
              const AppCard(
                child: Text(
                    'Horários e calendário acadêmico ainda indisponíveis.'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
