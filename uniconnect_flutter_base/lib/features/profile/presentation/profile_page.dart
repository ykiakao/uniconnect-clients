import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../teacher/providers/teacher_activity_provider.dart';
import '../../../shared/widgets/app_button_styles.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sair da conta?'),
        content: const Text(
          'Você será desconectado e voltará à tela de login.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Sair'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
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
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpacing.md),
                const Text(
                    'Notificações e lembretes ainda não estão integrados neste aplicativo.',
                    style: TextStyle(color: AppColors.muted)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(LucideIcons.bell),
                  title: const Text('Notificações'),
                  value: false,
                  onChanged: null,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(LucideIcons.calendarCheck),
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
      body: SafeArea(
        child: AcademicContent(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.pageHorizontal,
            AppSpacing.md,
            AppSpacing.pageHorizontal,
            AppSpacing.xl,
          ),
          children: [
            AppCard(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primaryTint,
                    child: Text(
                      _initials(user?.name),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: AppColors.primary,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'Usuário',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w700,
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
                          ? const Icon(LucideIcons.graduationCap)
                          : Text(
                              user.tenant.initials,
                              style: const TextStyle(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w700,
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
                                  fontWeight: FontWeight.w700,
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
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
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
                  if (user?.role == UserRole.student) ...[
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
                ],
              ),
            ),
            if (user?.role == UserRole.teacher) const _TeacherClasses(),
            const SizedBox(height: AppSpacing.lg),
            SecondaryButton(
              onPressed: () => _showSettings(context),
              icon: LucideIcons.settings,
              label: 'Configurações',
            ),
            const SizedBox(height: AppSpacing.md),
            DestructiveButton(
              subtle: true,
              onPressed: () => _handleLogout(context, ref),
              icon: LucideIcons.logOut,
              label: 'Sair',
            ),
          ],
        )),
      ),
    );
  }
}

String _initials(String? name) {
  final parts =
      (name ?? '').trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  final first = parts.first[0];
  final last = parts.length > 1 ? parts.last[0] : '';
  return (first + last).toUpperCase();
}

class _ProfileInfo extends StatelessWidget {
  const _ProfileInfo({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Expanded(
              child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          )),
        ],
      ),
    );
  }
}

/// Classes the teacher is assigned to, as returned by the API.
class _TeacherClasses extends ConsumerWidget {
  const _TeacherClasses();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final muted = text.bodyMedium?.copyWith(color: AppColors.inkMuted);
    return AppCard(
      icon: LucideIcons.bookOpen,
      title: 'Turmas e disciplinas',
      child: ref.watch(teacherOfferingsProvider).when(
            loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Carregando turmas'),
            error: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Não foi possível carregar as turmas.', style: muted),
                TextButton(
                  style: AppButtonStyles.link,
                  onPressed: () => ref.invalidate(teacherOfferingsProvider),
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
            data: (offerings) => offerings.isEmpty
                ? Text('Nenhuma turma ativa vinculada ao seu perfil.',
                    style: muted)
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final offering in offerings)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xxs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(LucideIcons.dot,
                                    size: 18, color: AppColors.primary),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Expanded(
                                  child: Text(offering.label,
                                      style: text.bodyMedium)),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
    );
  }
}
