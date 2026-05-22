import 'package:flutter/material.dart';

import '../../../shared/widgets/app_card.dart';

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
      appBar: AppBar(title: const Text('Lançamento de notas')),
      body: ListView(
        padding: const EdgeInsets.all(18),
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
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notas salvas com sucesso.')),
              );
            },
            icon: const Icon(Icons.save_outlined),
            label: const Text('Salvar notas'),
          ),
        ],
      ),
    );
  }
}
