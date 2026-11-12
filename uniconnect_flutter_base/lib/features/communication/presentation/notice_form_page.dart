import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/academic_content.dart';
import '../../../shared/widgets/app_badge.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_header.dart';
import '../../../shared/widgets/status_banner.dart';
import '../../auth/models/app_user.dart';
import '../../auth/providers/auth_provider.dart';
import '../../teacher/providers/teacher_activity_provider.dart';
import '../../teacher/providers/teacher_offering_selection.dart';
import '../models/communication_models.dart';
import '../providers/communication_providers.dart';

const _titleLimit = 200;
const _contentLimit = 10000;

/// Teachers write a notice for one of their classes.
class NoticeFormPage extends ConsumerStatefulWidget {
  const NoticeFormPage({super.key});

  @override
  ConsumerState<NoticeFormPage> createState() => _NoticeFormPageState();
}

class _NoticeFormPageState extends ConsumerState<NoticeFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _content = TextEditingController();
  NoticePriority _priority = NoticePriority.medium;
  String? _classId;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool publish}) async {
    final classId = _classId ?? ref.read(selectedTeacherClassIdProvider);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (classId == null) {
      setState(() => _error = 'Escolha a turma que vai receber o aviso.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(communicationServiceProvider).createClassNotice(
            classId: classId,
            title: _title.text.trim(),
            content: _content.text.trim(),
            priority: _priority,
            publish: publish,
          );
      ref.invalidate(noticesProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(publish
              ? 'Aviso publicado para a turma.'
              : 'Rascunho salvo em Meus avisos.')));
      context.go(AppRoutes.notices);
    } catch (error) {
      if (mounted) setState(() => _error = communicationErrorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, int limit, String field) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Informe $field.';
    if (text.length > limit) return 'Use até $limit caracteres.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(currentUserProvider)?.role != UserRole.teacher) {
      return const Scaffold(
        appBar:
            AppHeader(title: 'Novo aviso', fallbackRoute: AppRoutes.notices),
        body: Center(child: Text('Área exclusiva do professor')),
      );
    }
    final offerings = ref.watch(teacherOfferingsProvider);
    final selected = _classId ?? ref.watch(selectedTeacherClassIdProvider);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: const AppHeader(
          title: 'Novo aviso', fallbackRoute: AppRoutes.notices),
      body: SafeArea(
        child: AcademicContent(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageHorizontal,
                AppSpacing.pageTop,
                AppSpacing.pageHorizontal,
                AppSpacing.pageBottom,
              ),
              children: [
                Text('Aviso da turma', style: text.titleLarge),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                    'Os alunos matriculados na turma escolhida recebem o aviso quando ele for publicado.',
                    style:
                        text.bodyMedium?.copyWith(color: AppColors.inkMuted)),
                const SizedBox(height: AppSpacing.lg),
                offerings.when(
                  loading: () => const LinearProgressIndicator(
                      semanticsLabel: 'Carregando turmas'),
                  error: (_, __) => const StatusBanner(
                    title: 'Turmas indisponíveis',
                    message: 'Não foi possível carregar suas turmas agora.',
                    tone: AppBadgeTone.danger,
                  ),
                  data: (items) => DropdownButtonFormField<String>(
                    initialValue:
                        items.any((o) => o.id == selected) ? selected : null,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Turma'),
                    items: [
                      for (final offer in items)
                        DropdownMenuItem(
                          value: offer.id,
                          child: Text(offer.label,
                              overflow: TextOverflow.ellipsis),
                        ),
                    ],
                    validator: (value) =>
                        value == null ? 'Escolha a turma.' : null,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() => _classId = value),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _title,
                  enabled: !_saving,
                  maxLength: _titleLimit,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(labelText: 'Título'),
                  validator: (value) =>
                      _required(value, _titleLimit, 'o título'),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextFormField(
                  controller: _content,
                  enabled: !_saving,
                  minLines: 5,
                  maxLines: 10,
                  maxLength: _contentLimit,
                  decoration: const InputDecoration(
                    labelText: 'Mensagem',
                    alignLabelWithHint: true,
                  ),
                  validator: (value) =>
                      _required(value, _contentLimit, 'a mensagem'),
                ),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<NoticePriority>(
                  initialValue: _priority,
                  decoration: const InputDecoration(labelText: 'Prioridade'),
                  items: [
                    for (final priority in NoticePriority.values)
                      DropdownMenuItem(
                          value: priority, child: Text(priority.label)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _priority = value ?? NoticePriority.medium),
                ),
                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  StatusBanner(
                    title: 'Não foi possível salvar',
                    message: _error!,
                    tone: AppBadgeTone.danger,
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'Publicar aviso',
                  icon: LucideIcons.send,
                  isLoading: _saving,
                  onPressed: _saving ? null : () => _submit(publish: true),
                ),
                const SizedBox(height: AppSpacing.xs),
                SecondaryButton(
                  label: 'Salvar rascunho',
                  icon: LucideIcons.save,
                  onPressed: _saving ? null : () => _submit(publish: false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
