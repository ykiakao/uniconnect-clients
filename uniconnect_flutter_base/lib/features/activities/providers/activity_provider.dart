import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/academic_activity.dart';

final activitiesProvider = Provider<List<AcademicActivity>>((ref) {
  return [
    AcademicActivity(
      id: 'arquitetura-trabalho',
      subject: 'Arquitetura de Software',
      title: 'Entrega Projeto Final - IA',
      description:
          'Nesta atividade, você deverá analisar o cenário de transição de um sistema monolítico para uma arquitetura baseada em microserviços. O foco principal deve ser a implementação de padrões de resiliência.',
      dueLabel: 'Hoje até 23:59',
      dueDate: DateTime(2026, 10, 25, 23, 59),
      teacher: 'Dr. Ricardo Mendes',
      priority: ActivityPriority.critical,
      status: ActivityStatus.inProgress,
      criteria: const [
        'Diagrama de componentes',
        'Justificativa técnica',
        'Documentação da API',
      ],
      attachments: const ['Material de Apoio.pdf'],
    ),
    AcademicActivity(
      id: 'ia-prova',
      subject: 'Humanas',
      title: 'Resenha Crítica: Sociologia',
      description: 'Produzir uma resenha crítica sobre o texto indicado.',
      dueLabel: 'Hoje, 19:00',
      dueDate: DateTime(2026, 10, 24, 19),
      teacher: 'Prof. Helena Souza',
      priority: ActivityPriority.critical,
      status: ActivityStatus.pending,
      criteria: const ['Leitura obrigatória', 'Referências ABNT'],
      attachments: const ['Texto-base.pdf'],
    ),
    AcademicActivity(
      id: 'redes-lab',
      subject: 'Sistemas • Infraestrutura',
      title: 'Laboratório de Redes',
      description: 'Configurar rotas estáticas e validar conectividade.',
      dueLabel: 'Vence em 3 dias',
      dueDate: DateTime(2026, 10, 27, 23, 59),
      teacher: 'Prof. Ana Paula',
      priority: ActivityPriority.medium,
      status: ActivityStatus.pending,
      criteria: const ['Topologia', 'Print dos testes', 'Relatório curto'],
      attachments: const ['Topologia.pkt'],
    ),
    AcademicActivity(
      id: 'sala-calculo',
      subject: 'Cálculo III',
      title: 'Estudo Dirigido: Cálculo III',
      description: 'Resolver a lista preparatória da avaliação.',
      dueLabel: 'Vence em 3 dias',
      dueDate: DateTime(2026, 10, 27, 8),
      teacher: 'Prof. Helena Rocha',
      priority: ActivityPriority.medium,
      status: ActivityStatus.pending,
      criteria: const ['Entregar respostas comentadas'],
      attachments: const [],
    ),
    AcademicActivity(
      id: 'ux-material',
      subject: 'Programação • Opcional',
      title: 'Exercícios Python (Recursão)',
      description: 'Slides e lista prática adicionados ao AVA.',
      dueLabel: 'Sem prazo crítico',
      dueDate: DateTime(2026, 12, 5),
      teacher: 'Prof. Caio Mendes',
      priority: ActivityPriority.low,
      status: ActivityStatus.pending,
      criteria: const ['Leitura recomendada'],
      attachments: const ['Heuristicas.pdf'],
    ),
  ];
});

final activityByIdProvider =
    Provider.family<AcademicActivity?, String>((ref, id) {
  for (final activity in ref.watch(activitiesProvider)) {
    if (activity.id == id) return activity;
  }
  return null;
});
