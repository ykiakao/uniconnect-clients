import 'package:flutter/material.dart';
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
        DropdownButtonFormField<String>(
          initialValue: _stage,
          decoration: const InputDecoration(labelText: 'Etapa acadêmica'),
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
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration:
              const InputDecoration(labelText: 'Categoria da avaliação'),
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
        TextFormField(
          key: const ValueKey('assessment-max-points'),
          initialValue: _points,
          enabled: widget.enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Pontuação máxima',
            helperText: 'Até $_maximum pontos por item',
          ),
          onChanged: (value) {
            _points = value;
            _emit();
          },
          validator: (value) => academicPointsError(value ?? '', _maximum),
        ),
      ],
    ]);
  }
}
