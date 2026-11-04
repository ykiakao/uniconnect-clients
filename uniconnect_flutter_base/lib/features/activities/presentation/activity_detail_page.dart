import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/bottom_nav.dart';
import '../../../shared/widgets/error_state_widget.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/academic_demo_frame.dart';
import '../../academic/demo/synthetic_academic_providers.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../shared/widgets/empty_state_widget.dart';
import '../models/academic_activity.dart';
import '../providers/activity_provider.dart';
import '../providers/student_submission_provider.dart';
import '../widgets/student_submission_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  const ActivityDetailPage({super.key, required this.activityId});

  final String activityId;

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  (String, int, String?, String?, String?)? _lastVerifiedScope;

  @override
  Widget build(BuildContext context) {
    final activityId = widget.activityId;
    final user = ref.watch(currentUserProvider);
    final controller = ref.watch(authControllerProvider.notifier);
    final generation = ref.watch(
        authControllerProvider.select((_) => controller.sessionGeneration));
    final scope =
        (activityId, generation, user?.id, user?.tenant.id, user?.tenant.slug);
    final activityAsync = ref.watch(activityByIdProvider(activityId));
    if (!activityAsync.isLoading && activityAsync.asData != null) {
      _lastVerifiedScope = scope;
    }

    final sameScope = _lastVerifiedScope == scope;
    final refreshError = activityAsync.error;
    final preserveOnRefreshError = sameScope &&
        refreshError is ApiException &&
        ![401, 403, 404].contains(refreshError.statusCode);
    return activityAsync.when(
      skipLoadingOnRefresh: sameScope,
      skipError: preserveOnRefreshError,
      loading: () => const Scaffold(
        appBar: AppHeader(
          title: 'Atividade',
          fallbackRoute: AppRoutes.activities,
        ),
        body: SafeArea(
            child: AcademicDemoFrame(
                child: Center(child: CircularProgressIndicator()))),
      ),
      error: (error, stack) => Scaffold(
        appBar: const AppHeader(
          title: 'Atividade',
          fallbackRoute: AppRoutes.activities,
        ),
        body: SafeArea(
            child: AcademicDemoFrame(
                child: ErrorStateWidget(
          error: submissionErrorText(error),
          onRetry: () {
            invalidateSyntheticAcademicData(ref);
            ref.invalidate(activitiesProvider);
            ref.invalidate(activityByIdProvider(activityId));
          },
        ))),
      ),
      data: (activity) {
        if (activity == null) {
          return const Scaffold(
            appBar: AppHeader(
              title: 'Atividade',
              fallbackRoute: AppRoutes.activities,
            ),
            body: SafeArea(
                child: AcademicDemoFrame(
                    child: EmptyStateWidget(
              icon: Icons.search_off_outlined,
              title: 'Atividade não encontrada',
              subtitle:
                  'Volte à lista para consultar as atividades disponíveis.',
            ))),
          );
        }

        return _ActivityDetailContent(
            activity: activity,
            activityIsCurrent:
                !activityAsync.hasError && !activityAsync.isLoading,
            refreshError: activityAsync.hasError
                ? submissionErrorText(activityAsync.error!)
                : null);
      },
    );
  }
}

class _ActivityDetailContent extends ConsumerWidget {
  const _ActivityDetailContent(
      {required this.activity,
      required this.activityIsCurrent,
      this.refreshError});

  final AcademicActivity activity;
  final bool activityIsCurrent;
  final String? refreshError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(activityClockProvider);
    return Scaffold(
      appBar: const AppHeader(
        title: 'Detalhes da atividade',
        fallbackRoute: AppRoutes.activities,
      ),
      bottomNavigationBar: const UniBottomNav(currentIndex: 1),
      body: SafeArea(
          child: AcademicDemoFrame(
        child: AcademicContent(
            child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            refreshError == null
                ? const SizedBox.shrink()
                : Text('Não foi possível atualizar a atividade. $refreshError',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
            Text(
              activity.subject.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .8,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              activity.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            _InfoPill(
              icon: Icons.event_outlined,
              label: 'Prazo',
              value: activity.dueDate == null
                  ? activity.dueLabelAt(now)
                  : '${DateFormat('dd/MM/yyyy • HH:mm').format(activity.displayDueDate!)}\n${activity.dueLabelAt(now)} • ${activity.timeZoneLabel}',
            ),
            const SizedBox(height: AppSpacing.lg),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Instruções da atividade'),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    [activity.description, activity.instructions]
                            .where((s) => s.isNotEmpty)
                            .join('\n\n')
                            .isEmpty
                        ? 'Nenhuma instrução foi informada para esta atividade.'
                        : [activity.description, activity.instructions]
                            .where((s) => s.isNotEmpty)
                            .join('\n\n'),
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.muted,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final criterion in activity.criteria)
                    _ChecklistItem(text: criterion),
                  if (activity.criteria.isEmpty)
                    const Text(
                      'Os criterios de avaliacao nao foram informados para esta atividade.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                ],
              ),
            ),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _SectionLabel('Material de apoio'),
                  const SizedBox(height: AppSpacing.md),
                  if (activity.attachments.isEmpty)
                    const Text(
                      'Nenhum material anexo para esta atividade.',
                      style: TextStyle(color: AppColors.muted),
                    )
                  else
                    ...activity.attachments.map(
                      (attachment) => _MaterialItem(
                        icon: Icons.insert_drive_file_outlined,
                        title: attachment,
                        subtitle: 'Material da atividade',
                      ),
                    ),
                ],
              ),
            ),
            StudentSubmissionPanel(
                key: ValueKey(activity.id),
                activity: activity,
                activityIsCurrent: activityIsCurrent),
            AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.person_outline, color: Colors.white),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionLabel('Professor responsável'),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          activity.teacher,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        )),
      )),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialItem extends StatelessWidget {
  const _MaterialItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: .5,
          ),
    );
  }
}
