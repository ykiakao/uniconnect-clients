import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/teacher_activity_provider.dart';
import '../providers/teacher_offering_selection.dart';
import '../../../shared/widgets/app_button_styles.dart';

class TeacherOfferingPicker extends ConsumerStatefulWidget {
  const TeacherOfferingPicker({
    super.key,
    this.enabled = true,
    this.confirmChange,
  });

  final bool enabled;
  final Future<bool> Function()? confirmChange;

  @override
  ConsumerState<TeacherOfferingPicker> createState() =>
      _TeacherOfferingPickerState();
}

class _TeacherOfferingPickerState extends ConsumerState<TeacherOfferingPicker> {
  int _attempt = 0;
  bool _changing = false;

  Future<void> _select(String? classId) async {
    if (classId == null ||
        _changing ||
        classId == ref.read(selectedTeacherClassIdProvider)) {
      return;
    }
    final session = ref.read(teacherNotesSessionProvider);
    final original = ref.read(teacherOfferingSelectionProvider).classId;
    setState(() {
      _changing = true;
      _attempt++;
    });
    try {
      final confirm = widget.confirmChange;
      if (confirm != null && !await confirm()) return;
      if (!mounted ||
          ref.read(teacherNotesSessionProvider) != session ||
          ref.read(teacherOfferingSelectionProvider).classId != original) {
        return;
      }
      ref.read(teacherOfferingSelectionProvider.notifier).select(classId);
    } finally {
      if (mounted) setState(() => _changing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final offers = ref.watch(teacherOfferingsProvider);
    final selected = ref.watch(selectedTeacherClassIdProvider);
    final revoked = ref.watch(teacherOfferingSelectionProvider).revoked;
    final rows = offers.isLoading || offers.hasError
        ? const []
        : offers.value ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey((selected, _attempt)),
          initialValue: selected,
          isExpanded: true,
          itemHeight: null,
          decoration: const InputDecoration(labelText: 'Disciplina'),
          items: [
            for (final row in rows)
              DropdownMenuItem<String>(
                value: row.id,
                child: Text(row.label,
                    maxLines: 2, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged:
              widget.enabled && !_changing && rows.isNotEmpty ? _select : null,
        ),
        const SizedBox(height: AppSpacing.xs),
        if (offers.isLoading)
          const Text('Carregando ofertas autorizadas...')
        else if (offers.hasError) ...[
          const Text('Não foi possível carregar as ofertas.'),
          TextButton(
            style: AppButtonStyles.link,
            onPressed: widget.enabled
                ? () => ref.invalidate(teacherOfferingsProvider)
                : null,
            child: const Text('Tentar novamente'),
          ),
        ] else if (rows.isEmpty)
          const Text(
              'Nenhuma oferta ativa autorizada. Solicite o vínculo à instituição.')
        else if (selected == null && !revoked)
          const Text('Selecione uma disciplina para continuar.'),
        if (revoked)
          const Text('A oferta selecionada não está mais disponível.'),
      ],
    );
  }
}
