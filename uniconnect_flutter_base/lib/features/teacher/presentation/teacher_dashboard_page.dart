import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/quick_action_grid.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../widgets/teacher_offering_picker.dart';
import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../widgets/teacher_work_overview.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

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
    // Hidden only when the API confirms the teacher has no class.
    final hasClasses =
        ref.watch(teacherOfferingsProvider).asData?.value.isEmpty != true;
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppHeader(
        title: 'Área do professor',
        showProfile: true,
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(LucideIcons.logOut),
          ),
        ],
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 0, isTeacher: true),
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
              Text('UniConnect • Área do professor',
                  style: text.labelMedium?.copyWith(color: AppColors.primary)),
              const SizedBox(height: AppSpacing.xxs),
              Text('Olá, professor',
                  style: text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
              Text(user?.name ?? 'Professor',
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const IconTile(
                          icon: LucideIcons.graduationCap,
                          color: Colors.white,
                          background: Color(0x26FFFFFF),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tenant != null && tenant.id.isNotEmpty
                                    ? tenant.name
                                    : 'Instituição não informada',
                                style: text.titleLarge
                                    ?.copyWith(color: Colors.white),
                              ),
                              Text(user?.email ?? 'E-mail não informado',
                                  style: text.bodySmall?.copyWith(
                                      color: const Color(0xCCFFFFFF))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        AppBadge(label: user?.roleLabel ?? 'Professor'),
                        if (tenant?.slug == 'edukmais')
                          const AppBadge(
                            label: 'Ambiente de demonstração',
                            tone: AppBadgeTone.neutral,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              QuickActionGrid(items: [
                // Class-scoped shortcuts only when the teacher has classes.
                if (hasClasses) ...[
                  (
                    icon: LucideIcons.squarePlus,
                    label: 'Criar atividade',
                    onTap: () => GoRouter.maybeOf(context)
                        ?.push(AppRoutes.teacherCreateActivity),
                  ),
                  (
                    icon: LucideIcons.clipboardCheck,
                    label: 'Avaliar entregas',
                    onTap: () => GoRouter.maybeOf(context)
                        ?.go(AppRoutes.teacherActivities),
                  ),
                  (
                    icon: LucideIcons.graduationCap,
                    label: 'Consultar notas',
                    onTap: () =>
                        GoRouter.maybeOf(context)?.go(AppRoutes.teacherGrades),
                  ),
                ],
                (
                  icon: LucideIcons.bell,
                  label: 'Avisos da turma',
                  onTap: () =>
                      GoRouter.maybeOf(context)?.push(AppRoutes.notices),
                ),
              ]),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                  title: 'Resumo acadêmico',
                  subtitle: 'Sua identidade e seu vínculo institucional'),
              if (user?.course case final course? when course.isNotEmpty)
                AppCard(
                  icon: LucideIcons.bookOpen,
                  title: 'Vínculo acadêmico',
                  child: Text(course,
                      style:
                          text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                )
              else
                AppCard(
                  icon: LucideIcons.bookOpen,
                  title: 'Vínculo acadêmico não informado',
                  child: Text(
                      'Nenhum curso ou turma foi informado no seu perfil.',
                      style:
                          text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                ),
              const SizedBox(height: AppSpacing.lg),
              const SectionHeader(
                  title: 'Turmas e disciplinas',
                  subtitle: 'Escolha a turma para ver trabalhos e entregas'),
              const TeacherOfferingPicker(),
              const SizedBox(height: AppSpacing.md),
              if (classId != null)
                TeacherWorkOverview(key: ValueKey(classId), classId: classId),
            ],
          ),
        ),
      ),
    );
  }
}
