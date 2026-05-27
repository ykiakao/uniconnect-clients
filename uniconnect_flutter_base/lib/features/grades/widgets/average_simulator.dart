import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class AverageSimulator extends StatefulWidget {
  const AverageSimulator({super.key});

  @override
  State<AverageSimulator> createState() => _AverageSimulatorState();
}

class _AverageSimulatorState extends State<AverageSimulator> {
  final _p1Controller = TextEditingController();
  final _p2Controller = TextEditingController();
  final _workController = TextEditingController();

  double get _average {
    final p1 = double.tryParse(_p1Controller.text.replaceAll(',', '.')) ?? 0;
    final p2 = double.tryParse(_p2Controller.text.replaceAll(',', '.')) ?? 0;
    final work =
        double.tryParse(_workController.text.replaceAll(',', '.')) ?? 0;
    return (p1 * .35) + (p2 * .35) + (work * .30);
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _workController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Simulador de média',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          'P1 e P2 valem 35%; trabalho vale 30%.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.muted,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
                child: _GradeField(
                    label: 'P1',
                    controller: _p1Controller,
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(
                child: _GradeField(
                    label: 'P2',
                    controller: _p2Controller,
                    onChanged: _refresh)),
            const SizedBox(width: 8),
            Expanded(
                child: _GradeField(
                    label: 'Trabalho',
                    controller: _workController,
                    onChanged: _refresh)),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Média prevista: ${_average.toStringAsFixed(1)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
        ),
      ],
    );
  }

  void _refresh(String _) => setState(() {});
}

class _GradeField extends StatelessWidget {
  const _GradeField({
    required this.label,
    required this.controller,
    required this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }
}
