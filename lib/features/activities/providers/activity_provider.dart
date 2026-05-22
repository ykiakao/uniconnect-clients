import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/academic_activity.dart';

final activitiesProvider = Provider<List<AcademicActivity>>((ref) {
  return [
    AcademicActivity(
      id: 'arquitetura-trabalho',
      subject: 'Arquitetura de Sistemas',
      title: 'Trabalho vence em 2 dias',
      description:
          'Documentar a arquitetura de microserviços, filas e contratos da API.',
      dueLabel: '22/11 às 23:59',
      dueDate: DateTime(2026, 11, 22, 23, 59),
      teacher: 'Prof. Marina Costa',
      priority: ActivityPriority.critical,
      status: ActivityStatus.inProgress,
      criteria: const [
        'Diagrama de componentes',
        'Justificativa técnica',
        'Documentação da API',
      ],
      attachments: const ['Roteiro.pdf', 'Template.docx'],
    ),
    AcademicActivity(
      id: 'ia-prova',
      subject: 'Inteligência Artificial',
      title: 'Prova amanhã',
      description: 'Avaliação sobre busca heurística e redes neurais.',
      dueLabel: 'Amanhã, 19:00',
      dueDate: DateTime(2026, 11, 20, 19),
      teacher: 'Prof. Renato Lima',
      priority: ActivityPriority.critical,
      status: ActivityStatus.pending,
      criteria: const ['Capítulos 4 a 7', 'Lista de revisão'],
      attachments: const ['Plano de estudos.pdf'],
    ),
    AcademicActivity(
      id: 'redes-lab',
      subject: 'Redes de Computadores',
      title: 'Laboratório de roteamento',
      description: 'Configurar rotas estáticas e validar conectividade.',
      dueLabel: 'Vence em 5 dias',
      dueDate: DateTime(2026, 11, 25, 23, 59),
      teacher: 'Prof. Ana Paula',
      priority: ActivityPriority.medium,
      status: ActivityStatus.pending,
      criteria: const ['Topologia', 'Print dos testes', 'Relatório curto'],
      attachments: const ['Topologia.pkt'],
    ),
    AcademicActivity(
      id: 'sala-calculo',
      subject: 'Cálculo III',
      title: 'Mudança de sala',
      description: 'A aula de sexta foi remanejada para o laboratório B204.',
      dueLabel: 'Sexta, 08:00',
      dueDate: DateTime(2026, 11, 21, 8),
      teacher: 'Prof. Helena Rocha',
      priority: ActivityPriority.medium,
      status: ActivityStatus.pending,
      criteria: const ['Chegar com 10 minutos de antecedência'],
      attachments: const [],
    ),
    AcademicActivity(
      id: 'ux-material',
      subject: 'Design de Interfaces',
      title: 'Novo material disponível',
      description: 'Slides sobre heurísticas de Nielsen adicionados ao AVA.',
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
