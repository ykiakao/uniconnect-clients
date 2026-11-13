import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../services/teacher_assessment.dart';

class AssessmentFields extends StatefulWidget {
  const AssessmentFields(
      {super.key,
      this.initial,
      this.plan,
      required this.enabled,
      required this.onChanged});

  final TeacherAssessment? initial;

  /// Other items already planned in the offering, without the one being
  /// edited. Null while unknown: the form then shows only the stage cap.
  final List<TeacherAssessment>? plan;
  final bool enabled;
  final ValueChanged<TeacherAssessment?> onChanged;

  @override
  State<AssessmentFields> createState() => _AssessmentFieldsState();
}

class _AssessmentFieldsState extends State<AssessmentFields> {
  late bool _linked = widget.initial != null;
  late String _stage = widget.initial?.stage ?? 'N1';
  late String _category = widget.initial?.category ?? 'activity';
  late String _points = widget.initial?.maxPoints.replaceAll('.', ',') ?? '';

  String get _maximum => academicCategoryMaximum(_category);

  String get _categoryName => _category == 'exam' ? 'provas' : 'atividades';

  /// Points left in the stage, or null when the plan is unknown.
  int? get _remaining {
    final plan = widget.plan;
    return plan == null
        ? null
        : remainingPointsInCents(plan, _stage, _category);
  }

  String get _availability {
    final remaining = _remaining;
    if (remaining == null) return 'Até $_maximum pontos por item';
    if (remaining == 0) {
      return 'Não há pontos disponíveis para $_categoryName na $_stage '
          '(limite de $_maximum).';
    }
    return 'Disponível para $_categoryName na $_stage: '
        '${formatPointsCents(remaining)} de $_maximum pontos';
  }

  String? _validatePoints(String? value) {
    final error = academicPointsError(value ?? '', _maximum);
    if (error != null) return error;
    final remaining = _remaining;
    final cents = academicPointsInCents(value ?? '');
    if (remaining != null && cents != null && cents > remaining) {
      return remaining == 0
          ? 'A $_stage já usa os $_maximum pontos de $_categoryName.'
          : 'Restam ${formatPointsCents(remaining)} pontos para '
              '$_categoryName na $_stage.';
    }
    return null;
  }

  void _emit() {
    widget.onChanged(_linked
        ? TeacherAssessment(
            stage: _stage, category: _category, maxPoints: _points)
        : null);
  }

  /// Label above the field with a fixed gap below, like the rest of the
  /// activity form: floating labels clipped on the border of stacked fields.
  Widget _labeled(String label, Widget field) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Semantics(label: label, child: field),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Vincular ao boletim N1/N2'),
        value: _linked,
        onChanged: widget.enabled
            ? (value) {
                setState(() => _linked = value);
                _emit();
              }
            : null,
      ),
      if (_linked) ...[
        const SizedBox(height: AppSpacing.sm),
        _labeled(
          'Etapa acadêmica',
          DropdownButtonFormField<String>(
            initialValue: _stage,
            items: const [
              DropdownMenuItem(value: 'N1', child: Text('N1')),
              DropdownMenuItem(value: 'N2', child: Text('N2')),
            ],
            onChanged: widget.enabled
                ? (value) {
                    setState(() => _stage = value!);
                    _emit();
                  }
                : null,
          ),
        ),
        _labeled(
          'Categoria da avaliação',
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: const [
              DropdownMenuItem(value: 'activity', child: Text('Atividade')),
              DropdownMenuItem(value: 'exam', child: Text('Prova')),
            ],
            onChanged: widget.enabled
                ? (value) {
                    setState(() => _category = value!);
                    _emit();
                  }
                : null,
          ),
        ),
        _labeled(
          'Pontuação máxima',
          TextFormField(
            key: const ValueKey('assessment-max-points'),
            initialValue: _points,
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autovalidateMode: AutovalidateMode.onUserInteraction,
            decoration: InputDecoration(
              hintText:
                  'Ex.: ${_remaining == null ? _maximum : formatPointsCents(_remaining!)}',
              helperText: _availability,
              helperMaxLines: 2,
              errorMaxLines: 2,
            ),
            onChanged: (value) {
              _points = value;
              _emit();
            },
            validator: _validatePoints,
          ),
        ),
      ],
    ]);
  }
}
