import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../academic/demo/synthetic_academic_providers.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  void _handleLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você será desconectado e voltará à tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authControllerProvider.notifier).logout();
              if (!context.mounted) return;
              Navigator.pop(dialogContext);
              context.go(AppRoutes.login);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SingleChildScrollView(
          child: StatefulBuilder(
        builder: (context, setState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configurações',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                    'Notificações e lembretes ainda não estão integrados neste aplicativo.',
                    style: TextStyle(color: AppColors.muted)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.notifications_outlined),
                  title: const Text('Notificações'),
                  value: false,
                  onChanged: null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.event_available_outlined),
                  title: const Text('Lembretes de atividades'),
                  value: false,
                  onChanged: null,
                ),
                const SizedBox(height: AppSpacing.sm),
                PrimaryButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  label: 'Concluir',
                ),
              ],
            ),
          ),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isTeacher = user?.role == UserRole.teacher;

    return Scaffold(
      appBar: AppHeader(
        title: 'Perfil',
        fallbackRoute:
            isTeacher ? AppRoutes.teacherDashboard : AppRoutes.studentDashboard,
      ),
      bottomNavigationBar:
          isTeacher ? null : const UniBottomNav(currentIndex: 4),
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
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person, color: Colors.white, size: 34),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        Text(
                          user?.email ?? 'E-mail não informado',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.muted,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            if (user != null) ...[
              AppCard(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.secondarySoft,
                      child: user.tenant.id.isEmpty
                          ? const Icon(Icons.school_outlined)
                          : Text(
                              user.tenant.initials,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.tenant.id.isNotEmpty
                                ? user.tenant.name
                                : 'Instituição não informada',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            'Instituição vinculada à sua conta',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: AppColors.muted,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            if (ref.watch(syntheticDemoEnabledProvider))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Ambiente de demonstração',
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: AppColors.muted,
                            )),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                        'Dados acadêmicos fictícios da EduKMais, usados para apresentação. Não representam registros reais da sua conta.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.muted,
                            )),
                  ],
                ),
              ),
            AppCard(
              child: Column(
                children: [
                  if (user != null) ...[
                    _ProfileInfo(
                      label: 'Perfil',
                      value: user.roleLabel,
                    ),
                    const Divider(height: AppSpacing.lg),
                  ],
                  _ProfileInfo(
                    label: 'Curso',
                    value: user?.course?.trim().isNotEmpty == true
                        ? user!.course!
                        : 'Não informado',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _ProfileInfo(
                    label: 'Matrícula',
                    value: user?.registration?.trim().isNotEmpty == true
                        ? user!.registration!
                        : 'Não informado',
                  ),
                  const Divider(height: AppSpacing.lg),
                  _ProfileInfo(
                    label: 'Semestre',
                    value: user?.semester?.toString() ?? 'Não informado',
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              onPressed: () => _showSettings(context),
              icon: Icons.settings_outlined,
              label: 'Configurações',
            ),
            const SizedBox(height: AppSpacing.md),
            DestructiveButton(
              onPressed: () => _handleLogout(context, ref),
              icon: Icons.logout,
              label: 'Sair',
            ),
          ],
        )),
      ),
    );
  }
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Expanded(
              child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w800),
          )),
        ],
      ),
    );
  }
}
