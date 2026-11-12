import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/section_header.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../academic/presentation/academic_records_section.dart';
import '../../academic/presentation/academic_term_section.dart';
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
        LucideIcons.landmark,
        'Instituição',
        institution?.id.isNotEmpty == true ? institution?.name : null
      ),
      (LucideIcons.userRound, 'Matrícula', user?.registration),
      (LucideIcons.graduationCap, 'Curso', user?.course),
      (
        LucideIcons.calendarDays,
        'Semestre do curso',
        semester == null ? null : '$semesterº semestre'
      ),
    ];
    final text = Theme.of(context).textTheme;
    final isDemo = ref.watch(syntheticDemoEnabledProvider);
    return Scaffold(
      appBar: const AppHeader(title: 'Acadêmico', showProfile: true),
      bottomNavigationBar: const UniBottomNav(currentIndex: 4),
      body: SafeArea(
        child: AcademicContent(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.pageHorizontal,
              AppSpacing.pageTop,
              AppSpacing.pageHorizontal,
              AppSpacing.pageBottom,
            ),
            children: [
              const SectionHeader(title: 'Vínculo acadêmico'),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (icon, label, value) in details)
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Row(
                          children: [
                            IconTile(icon: icon, size: 36),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text.rich(TextSpan(children: [
                                TextSpan(
                                  text: '$label: ',
                                  style: text.bodyMedium
                                      ?.copyWith(color: AppColors.inkMuted),
                                ),
                                TextSpan(
                                  text: value == null || value.trim().isEmpty
                                      ? 'Não informado'
                                      : value.trim(),
                                  style: text.titleSmall,
                                ),
                              ])),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (!isDemo) ...[
                const AcademicRecordsSection(),
                const SizedBox(height: AppSpacing.md),
              ],
              const AcademicTermSection(),
            ],
          ),
        ),
      ),
    );
  }
}
