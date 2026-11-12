import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_button_styles.dart';
import '../../../shared/widgets/app_card.dart';
import '../../auth/models/app_user.dart';
import '../../teacher/providers/class_students_provider.dart';
import '../../teacher/providers/teacher_activity_provider.dart';
import '../../teacher/services/teacher_activity_service.dart';
import '../providers/communication_providers.dart';
import 'communication_ui.dart';

Future<void> showNewConversationSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const FractionallySizedBox(
        heightFactor: .85,
        child: NewConversationSheet(),
      ),
    );

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
