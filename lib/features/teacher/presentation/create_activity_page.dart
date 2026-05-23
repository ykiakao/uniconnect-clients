import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_header.dart';

class CreateActivityPage extends StatefulWidget {
  const CreateActivityPage({super.key});

  @override
  State<CreateActivityPage> createState() => _CreateActivityPageState();
}

class _CreateActivityPageState extends State<CreateActivityPage> {
  final _subjectController =
      TextEditingController(text: 'Arquitetura de Sistemas');
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dueController = TextEditingController();
  final _weightController = TextEditingController();
  String? _subjectError;
  String? _titleError;
  String? _descriptionError;
  String? _dueError;
  String? _weightError;

  @override
  void dispose() {
    _subjectController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _dueController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _publish() {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));

    setState(() {
      _subjectError = _subjectController.text.trim().isEmpty
          ? 'Informe a disciplina'
          : null;
      _titleError =
          _titleController.text.trim().isEmpty ? 'Informe o título' : null;
      _descriptionError = _descriptionController.text.trim().length < 10
          ? 'Descreva a atividade com pelo menos 10 caracteres'
          : null;
      _dueError = _dueController.text.trim().isEmpty ? 'Informe o prazo' : null;
      _weightError = weight == null || weight <= 0
          ? 'Informe um peso maior que zero'
          : null;
    });

    if (_subjectError != null ||
        _titleError != null ||
        _descriptionError != null ||
        _dueError != null ||
        _weightError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revise os campos destacados.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Atividade publicada com sucesso.')),
    );
    _titleController.clear();
    _descriptionController.clear();
    _dueController.clear();
    _weightController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const AppHeader(
        title: 'Criar atividade',
        fallbackRoute: AppRoutes.teacherDashboard,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            'Nova atividade',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'A publicação entra no quadro de prioridades dos alunos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _subjectController,
            onChanged: (_) => _clearError(() => _subjectError = null),
            decoration: InputDecoration(
              labelText: 'Disciplina',
              errorText: _subjectError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _titleController,
            onChanged: (_) => _clearError(() => _titleError = null),
            decoration: InputDecoration(
              labelText: 'Título',
              errorText: _titleError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => _clearError(() => _descriptionError = null),
            decoration: InputDecoration(
              labelText: 'Descrição',
              errorText: _descriptionError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _dueController,
            onChanged: (_) => _clearError(() => _dueError = null),
            decoration: InputDecoration(
              labelText: 'Prazo',
              prefixIcon: const Icon(Icons.event_outlined),
              errorText: _dueError,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            onChanged: (_) => _clearError(() => _weightError = null),
            decoration: InputDecoration(
              labelText: 'Peso da nota',
              prefixIcon: const Icon(Icons.percent),
              errorText: _weightError,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            onPressed: _publish,
            icon: Icons.publish_outlined,
            label: 'Publicar atividade',
          ),
        ],
      ),
    );
  }

  void _clearError(VoidCallback update) {
    setState(update);
  }
}
