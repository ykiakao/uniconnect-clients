import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../widgets/teacher_offering_picker.dart';
import '../providers/teacher_offering_selection.dart';
import '../widgets/teacher_work_overview.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você será desconectado e voltará para a tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tenant = ref.watch(currentTenantProvider);
    final classId = ref.watch(selectedTeacherClassIdProvider);

    return Scaffold(
      appBar: AppHeader(
        title: 'Área do professor',
        showProfile: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 0, isTeacher: true),
      body: SafeArea(
        child: AcademicContent(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            AppCard(
              backgroundColor: AppColors.primary,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.school_outlined,
                      color: Colors.white, size: 30),
                  const SizedBox(height: AppSpacing.sm),
                  const Text('Olá, professor',
                      style: TextStyle(color: Colors.white)),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'UniConnect • Área do professor',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    user?.name ?? 'Professor',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    tenant != null && tenant.id.isNotEmpty
                        ? tenant.name
                        : 'Instituição não informada',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                  if (tenant?.slug == 'edukmais') ...[
                    const SizedBox(height: AppSpacing.sm),
                    const Text('Ambiente de demonstração',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700)),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(user?.email ?? 'E-mail não informado',
                      style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: AppSpacing.md),
                  AppBadge(label: user?.roleLabel ?? 'Professor'),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const SectionHeader(
                title: 'Resumo acadêmico',
                subtitle: 'Sua identidade e seu vínculo institucional'),
            if (user?.course case final course? when course.isNotEmpty) ...[
              AppCard(
                child: Row(
                  children: [
                    const Icon(
                      Icons.menu_book_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vínculo acadêmico',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            course,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              const AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.menu_book_outlined, color: AppColors.primary),
                    SizedBox(height: AppSpacing.sm),
                    Text('Vínculo acadêmico não informado',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: AppSpacing.xs),
                    Text('Nenhum curso ou turma foi informado no seu perfil.',
                        style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            const SectionHeader(title: 'Turmas e disciplinas'),
            const TeacherOfferingPicker(),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                FilledButton(
                  onPressed: classId == null
                      ? null
                      : () => GoRouter.maybeOf(context)
                          ?.push(AppRoutes.teacherCreateActivity),
                  child: const Text('Criar atividade'),
                ),
                OutlinedButton(
                  onPressed: classId == null
                      ? null
                      : () => GoRouter.maybeOf(context)?.go(
                            Uri(
                                path: AppRoutes.teacherGrades,
                                queryParameters: {
                                  'classId': classId,
                                  'modo': 'provas',
                                }).toString(),
                          ),
                  child: const Text('Lançar notas de prova'),
                ),
                TextButton(
                  onPressed: () => GoRouter.maybeOf(context)
                      ?.go(AppRoutes.teacherActivities),
                  child: const Text('Ver trabalhos e entregas'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (classId != null)
              TeacherWorkOverview(key: ValueKey(classId), classId: classId),
          ],
        )),
      ),
    );
  }
}
