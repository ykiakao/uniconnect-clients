import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
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
        title: 'Dashboard do professor',
        actions: [
          IconButton(
            tooltip: 'Sair',
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          AppCard(
            backgroundColor: AppColors.primary,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Olá, ${user?.name.split(' ').first ?? 'Marina'}',
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tenant == null
                            ? 'Publique, priorize e acompanhe suas turmas.'
                            : '${tenant.name} • ${tenant.planLabel}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: .82),
                            ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.workspace_premium_outlined,
                      color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          const Row(
            children: [
              Expanded(child: _TeacherMetric(label: 'Turmas', value: '4')),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: _TeacherMetric(label: 'Alunos', value: '128')),
              SizedBox(width: AppSpacing.xs),
              Expanded(child: _TeacherMetric(label: 'Pendências', value: '7')),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          const SectionHeader(
            title: 'Ações rápidas',
            subtitle: 'Ferramentas essenciais para o MVP do professor',
          ),
          _TeacherActionCard(
            icon: Icons.add_task,
            color: AppColors.primary,
            title: 'Criar atividade',
            description: 'Publique prazo, peso e instruções para uma turma.',
            buttonLabel: 'Publicar atividade',
            onTap: () => context.push(AppRoutes.teacherCreateActivity),
          ),
          _TeacherActionCard(
            icon: Icons.groups_outlined,
            color: AppColors.success,
            title: 'Visualizar turmas',
            description: 'Acompanhe Engenharia 4A, Sistemas 2B e ADS 1C.',
            buttonLabel: 'Abrir turmas',
            onTap: () {},
          ),
          _TeacherActionCard(
            icon: Icons.grade_outlined,
            color: AppColors.secondary,
            title: 'Lançar notas',
            description: 'Atualize P1, P2 e situação dos estudantes.',
            buttonLabel: 'Abrir notas',
            onTap: () => context.push(AppRoutes.teacherGrades),
          ),
          _TeacherActionCard(
            icon: Icons.campaign_outlined,
            color: AppColors.info,
            title: 'Enviar comunicados',
            description: 'Informe mudanças de sala, material novo ou avisos.',
            buttonLabel: 'Novo comunicado',
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Comunicado mockado enviado.')),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TeacherMetric extends StatelessWidget {
  const _TeacherMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _TeacherActionCard extends StatelessWidget {
  const _TeacherActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      accentColor: color,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.muted,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onTap,
                    child: Text(buttonLabel),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
