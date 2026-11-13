import 'package:flutter/material.dart';
import '../../../core/theme/app_spacing.dart';
import '../services/teacher_assessment.dart';

class AssessmentFields extends StatefulWidget {
  const AssessmentFields(
      {super.key,
      this.initial,
      required this.enabled,
      required this.onChanged});

  final TeacherAssessment? initial;
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

  String get _maximum => _category == 'exam' ? '7,00' : '3,00';

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
            decoration: InputDecoration(
              hintText: 'Ex.: $_maximum',
              helperText: 'Até $_maximum pontos por item',
            ),
            onChanged: (value) {
              _points = value;
              _emit();
            },
            validator: (value) => academicPointsError(value ?? '', _maximum),
          ),
        ),
      ],
    ]);
  }
}
