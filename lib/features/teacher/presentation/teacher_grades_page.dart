import 'package:flutter/material.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../shared/widgets/app_buttons.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/app_header.dart';

class TeacherGradesPage extends StatelessWidget {
  const TeacherGradesPage({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('Lucas Oliveira', '8.8', '9.1', 'Aprovado'),
      ('Bianca Souza', '7.4', '8.0', 'Em curso'),
      ('Rafael Martins', '6.5', '7.2', 'Recuperação'),
      ('Amanda Lima', '9.2', '9.6', 'Aprovado'),
    ];

    return Scaffold(
      appBar: const AppHeader(
        title: 'Lançamento de notas',
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
          AppCard(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Aluno')),
                  DataColumn(label: Text('P1')),
                  DataColumn(label: Text('P2')),
                  DataColumn(label: Text('Status')),
                ],
                rows: rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          DataCell(Text(row.$1)),
                          DataCell(Text(row.$2)),
                          DataCell(Text(row.$3)),
                          DataCell(Text(row.$4)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notas salvas com sucesso.')),
              );
            },
            icon: Icons.save_outlined,
            label: 'Salvar notas',
          ),
        ],
      ),
    );
  }
}
