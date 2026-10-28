import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/section_header.dart';
import '../../auth/providers/auth_provider.dart';
import '../../tenant/providers/tenant_provider.dart';

class TeacherDashboardPage extends ConsumerWidget {
  const TeacherDashboardPage({super.key});

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você será desconectado e voltará para a tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              context.go(AppRoutes.login);
            },
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final tenant = ref.watch(currentTenantProvider);

    return Scaffold(
      appBar: AppHeader(
        title: 'Área do professor',
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
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
                  Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AppBadge(label: user?.roleLabel ?? 'Professor'),
                        FilledButton.tonalIcon(
                          onPressed: () => context.push(AppRoutes.profile),
                          icon: const Icon(Icons.person_outline),
                          label: const Text('Ver perfil'),
                        ),
                      ]),
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
            const SectionHeader(
              title: 'Área de trabalho docente',
              subtitle: 'Consulte a disponibilidade de cada ferramenta',
            ),
            LayoutBuilder(builder: (context, constraints) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final twoColumns = constraints.maxWidth >= 560 * scale;
              const tools = [
                _TeacherWorkspaceCard(
                  title: 'Turmas e disciplinas',
                  icon: Icons.groups_outlined,
                  description:
                      'O vínculo disponível aparece acima. A consulta de turmas ainda não está integrada nesta tela.',
                  status: 'Consulta indisponível',
                ),
                _TeacherWorkspaceCard(
                  title: 'Atividades acadêmicas',
                  icon: Icons.assignment_outlined,
                  description:
                      'Conheça o formulário demonstrativo. Nenhuma atividade será publicada ou salva.',
                  status: 'Demonstração',
                  route: AppRoutes.teacherCreateActivity,
                ),
                _TeacherWorkspaceCard(
                  title: 'Lançamento de notas',
                  icon: Icons.grading_outlined,
                  description:
                      'Veja a apresentação de avaliações com dados ilustrativos e publicação bloqueada.',
                  status: 'Demonstração',
                  route: AppRoutes.teacherGrades,
                ),
                _TeacherWorkspaceCard(
                  title: 'Comunicação com alunos',
                  icon: Icons.forum_outlined,
                  description:
                      'Envio de mensagens e comunicados ainda indisponível. Nenhum envio é simulado.',
                  status: 'Indisponível',
                ),
              ];
              if (!twoColumns) {
                return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: tools);
              }
              return Column(children: [
                for (var index = 0; index < tools.length; index += 2)
                  IntrinsicHeight(
                      child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: tools[index]),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: tools[index + 1]),
                    ],
                  )),
              ]);
            }),
          ],
        )),
      ),
    );
  }
}

class _TeacherWorkspaceCard extends StatelessWidget {
  const _TeacherWorkspaceCard(
      {required this.title,
      required this.icon,
      required this.description,
      required this.status,
      this.route});

  final String title;
  final IconData icon;
  final String description;
  final String status;
  final String? route;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: route == null ? AppColors.border : AppColors.primary,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
              child: Text(title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700))),
        ]),
        const SizedBox(height: AppSpacing.sm),
        Align(
            alignment: Alignment.centerLeft,
            child: AppBadge(
                label: status,
                tone: route == null
                    ? AppBadgeTone.neutral
                    : AppBadgeTone.warning)),
        const SizedBox(height: AppSpacing.sm),
        Text(description, style: const TextStyle(color: AppColors.muted)),
        if (route != null) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                minimumSize: const Size(0, 48)),
            onPressed: () => context.push(route!),
            icon: const Icon(Icons.visibility_outlined),
            label: const Text('Ver protótipo'),
          ),
        ],
      ]),
    );
  }
}
