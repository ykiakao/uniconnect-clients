import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_back_button.dart';

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
      appBar: AppBar(
        leading: const AppBackButton(fallbackRoute: AppRoutes.teacherDashboard),
        title: const Text('Criar atividade'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 18),
          TextField(
            controller: _subjectController,
            decoration: const InputDecoration(labelText: 'Disciplina'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descriptionController,
            minLines: 3,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Descrição'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _dueController,
            decoration: const InputDecoration(
              labelText: 'Prazo',
              prefixIcon: Icon(Icons.event_outlined),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weightController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Peso da nota',
              prefixIcon: Icon(Icons.percent),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _publish,
            icon: const Icon(Icons.publish_outlined),
            label: const Text('Publicar atividade'),
          ),
          const SizedBox(height: 10),
          const AppBackTextButton(fallbackRoute: AppRoutes.teacherDashboard),
        ],
      ),
    );
  }
}
