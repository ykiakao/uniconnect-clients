import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/network/api_client.dart';
import '../../academic/providers/academic_records_providers.dart';
import '../../auth/models/app_user.dart';
import '../../teacher/providers/class_students_provider.dart';
import '../../teacher/providers/teacher_activity_provider.dart';
import '../../teacher/services/teacher_activity_service.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';

Future<void> showNewConversationSheet(BuildContext context,
        {bool isTeacher = true}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => FractionallySizedBox(
        heightFactor: .85,
        child: isTeacher
            ? const NewConversationSheet()
            : const StudentNewConversationSheet(),
      ),
    );

typedef StudentClass = ({String classId, String subject, String period});

/// Classes the student is attending now, from the academic history.
final studentClassesProvider =
    FutureProvider.autoDispose<List<StudentClass>>((ref) async {
  final history = await ref.watch(academicHistoryProvider.future);
  final seen = <String>{};
  final classes = <StudentClass>[];
  for (final period in history.periods) {
    for (final subject in period.subjects) {
      final classId = subject.classId;
      final active = subject.status == null || subject.status == 'in_progress';
      if (classId == null || !active || !seen.add(classId)) continue;
      classes.add((
        classId: classId,
        subject: subject.title,
        period: period.period.label
      ));
    }
  }
  return List.unmodifiable(classes);
}, retry: (_, __) => null);

/// Student picks one of the subjects in progress; the conversation is with
/// the active teacher of that class.
class StudentNewConversationSheet extends ConsumerStatefulWidget {
  const StudentNewConversationSheet({super.key});

  @override
  ConsumerState<StudentNewConversationSheet> createState() =>
      _StudentNewConversationSheetState();
}

class _StudentNewConversationSheetState
    extends ConsumerState<StudentNewConversationSheet> {
  String? _opening;
  String? _error;

  Future<void> _open(StudentClass item) async {
    if (_opening != null) return;
    setState(() {
      _opening = item.classId;
      _error = null;
    });
    try {
      final service = ref.read(communicationServiceProvider);
      final teacherId = await service.classTeacherId(item.classId);
      if (teacherId == null) {
        throw const ApiException(
            'Esta disciplina não tem professor ativo para conversar.');
      }
      final conversation = await service.createConversation(
          classId: item.classId, participantId: teacherId);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      final router = GoRouter.maybeOf(context);
      Navigator.of(context).pop();
      router?.push('${chatRouteFor(UserRole.student)}/'
          '${Uri.encodeComponent(conversation.id)}');
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _opening = null;
          _error = communicationErrorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final classes = ref.watch(studentClassesProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
          AppSpacing.pageHorizontal, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nova conversa', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
              'Escolha a disciplina para falar com o professor dela. Se a conversa já existir, ela será aberta.',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: classes.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(
                      semanticsLabel: 'Carregando disciplinas')),
              error: (error, _) => Column(
                children: [
                  Text(communicationErrorText(error)),
                  TextButton(
                    style: AppButtonStyles.link,
                    onPressed: () => ref.invalidate(academicHistoryProvider),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
              data: (items) => items.isEmpty
                  ? Center(
                      child: Text('Nenhuma disciplina em andamento.',
                          style: text.bodyMedium
                              ?.copyWith(color: AppColors.inkMuted)))
                  : ListView(
                      children: [
                        for (final item in items)
                          AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm),
                            onTap: _opening == null ? () => _open(item) : null,
                            child: Row(
                              children: [
                                const IconTile(
                                    icon: LucideIcons.bookOpen, size: 36),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(item.subject,
                                          style: text.titleSmall),
                                      Text(
                                          'Professor da disciplina • ${item.period}',
                                          style: text.bodySmall?.copyWith(
                                              color: AppColors.inkMuted)),
                                    ],
                                  ),
                                ),
                                if (_opening == item.classId)
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  )
                                else
                                  const Icon(LucideIcons.messageSquarePlus,
                                      size: 20, color: AppColors.primary),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Teacher picks an offering and a student; the API creates the
/// conversation or returns the existing one.
class NewConversationSheet extends ConsumerStatefulWidget {
  const NewConversationSheet({super.key});

  @override
  ConsumerState<NewConversationSheet> createState() =>
      _NewConversationSheetState();
}

class _NewConversationSheetState extends ConsumerState<NewConversationSheet> {
  String? _classId;
  String? _opening;
  String? _error;

  Future<void> _open(String classId, ClassStudent student) async {
    if (_opening != null) return;
    setState(() {
      _opening = student.id;
      _error = null;
    });
    try {
      final conversation = await ref
          .read(communicationServiceProvider)
          .createConversation(classId: classId, participantId: student.id);
      if (!mounted) return;
      ref.invalidate(conversationsProvider);
      final router = GoRouter.maybeOf(context);
      Navigator.of(context).pop();
      router?.push('${chatRouteFor(UserRole.teacher)}/'
          '${Uri.encodeComponent(conversation.id)}');
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _opening = null;
          _error = communicationErrorText(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final offerings = ref.watch(teacherOfferingsProvider);
    final classId = _classId;
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.pageHorizontal, 0,
          AppSpacing.pageHorizontal, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Nova conversa', style: text.titleLarge),
          const SizedBox(height: AppSpacing.xxs),
          Text(
              'Escolha a turma e o aluno. Se a conversa já existir, ela será aberta.',
              style: text.bodySmall?.copyWith(color: AppColors.inkMuted)),
          const SizedBox(height: AppSpacing.md),
          offerings.when(
            loading: () => const LinearProgressIndicator(
                semanticsLabel: 'Carregando turmas'),
            error: (error, _) => Text(communicationErrorText(error)),
            data: (items) => DropdownButtonFormField<String>(
              initialValue: classId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Turma'),
              items: [
                for (final TeacherOffering offer in items)
                  DropdownMenuItem(
                    value: offer.id,
                    child: Text(offer.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: _opening != null
                  ? null
                  : (value) => setState(() {
                        _classId = value;
                        _error = null;
                      }),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(_error!,
                style: text.bodySmall?.copyWith(color: AppColors.danger)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Expanded(
            child: classId == null
                ? Center(
                    child: Text('Selecione uma turma para ver os alunos.',
                        style: text.bodyMedium
                            ?.copyWith(color: AppColors.inkMuted)))
                : ref.watch(classStudentsProvider(classId)).when(
                      loading: () => const Center(
                          child: CircularProgressIndicator(
                              semanticsLabel: 'Carregando alunos')),
                      error: (error, _) => Column(
                        children: [
                          Text(communicationErrorText(error)),
                          TextButton(
                            style: AppButtonStyles.link,
                            onPressed: () =>
                                ref.invalidate(classStudentsProvider(classId)),
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                      data: (students) => students.isEmpty
                          ? Center(
                              child: Text('Nenhum aluno nesta turma.',
                                  style: text.bodyMedium
                                      ?.copyWith(color: AppColors.inkMuted)))
                          : ListView(
                              children: [
                                for (final student in students)
                                  AppCard(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.md,
                                        vertical: AppSpacing.sm),
                                    onTap: _opening == null
                                        ? () => _open(classId, student)
                                        : null,
                                    child: Row(
                                      children: [
                                        const IconTile(
                                            icon: LucideIcons.userRound,
                                            size: 36),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Text(student.name,
                                              style: text.titleSmall),
                                        ),
                                        if (_opening == student.id)
                                          const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        else
                                          const Icon(
                                              LucideIcons.messageSquarePlus,
                                              size: 20,
                                              color: AppColors.primary),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                    ),
          ),
        ],
      ),
    );
  }
}
