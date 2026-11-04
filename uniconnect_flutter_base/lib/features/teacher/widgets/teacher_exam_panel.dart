import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../shared/widgets/app_card.dart';
import '../services/teacher_academic_service.dart';
import '../services/teacher_assessment.dart';
import '../providers/teacher_review_provider.dart';
import '../providers/teacher_activity_provider.dart';
import 'academic_page_controls.dart';

class TeacherExamPanel extends ConsumerStatefulWidget {
  const TeacherExamPanel(
      {super.key, required this.examId, required this.service});

  final String examId;
  final TeacherAcademicService service;

  @override
  ConsumerState<TeacherExamPanel> createState() => _TeacherExamPanelState();
}

class _TeacherExamPanelState extends ConsumerState<TeacherExamPanel> {
  int _page = 1;
  bool _busy = false;
  String? _message;
  late Future<ExamRoster> _roster = widget.service.roster(widget.examId);

  void _load(int page) => setState(() {
        _page = page;
        _roster = widget.service.roster(widget.examId, page: page);
      });

  Future<void> _run(Future<bool> Function() action, String success) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (await action() && mounted) {
        _message = success;
        _load(_page);
      }
    } catch (error) {
      if (!mounted) return;
      _message = error is ApiException && error.statusCode == 409
          ? 'Conflito de revisão ou estado. Confira a pauta atualizada antes de tentar novamente. ${error.message}'
          : teacherReviewError(error);
      _load(_page);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<T?> _showExamDialog<T>(WidgetBuilder builder) {
    final session = ref.read(teacherNotesSessionProvider);
    return showDialog<T>(
      context: context,
      builder: (context) => Consumer(builder: (context, ref, _) {
        if (ref.watch(teacherNotesSessionProvider) == session) {
          return builder(context);
        }
        return AlertDialog(
          content: const Text('A sessão mudou. Retorne à tela Notas.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      }),
    );
  }

  Future<String?> _askPoints(
      ExamRoster roster, ExamStudent student, bool correction) {
    final form = GlobalKey<FormState>();
    var points = student.grade?.points.replaceAll('.', ',') ?? '';
    return _showExamDialog<String>(
      (context) => AlertDialog(
        title: Text(
            correction ? 'Corrigir nota publicada' : 'Salvar nota em rascunho'),
        content: SingleChildScrollView(
            child: Form(
          key: form,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(student.name),
            if (correction)
              const Text('A correção será publicada ao confirmar.'),
            TextFormField(
              key: const ValueKey('exam-points-input'),
              initialValue: points,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText:
                      'Pontos (máximo ${roster.maxPoints.replaceAll('.', ',')})'),
              onChanged: (value) => points = value,
              validator: (value) =>
                  academicPointsError(value ?? '', roster.maxPoints),
            ),
          ]),
        )),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(context, points);
            },
            child: Text(correction ? 'Confirmar correção' : 'Salvar rascunho'),
          ),
        ],
      ),
    );
  }

  Future<bool> _edit(
      ExamRoster roster, ExamStudent student, bool correction) async {
    final points = await _askPoints(roster, student, correction);
    if (points == null || !mounted) return false;
    if (correction) {
      await widget.service.publish(roster, student, points: points);
    } else {
      await widget.service.save(roster, student, points);
    }
    return true;
  }

  Future<bool> _publish(ExamRoster roster, ExamStudent student) async {
    final confirmed = await _showExamDialog<bool>(
      (context) => AlertDialog(
        title: const Text('Publicar nota da prova?'),
        content: Text(
            '${student.name} verá a nota de ${student.grade!.points.replaceAll('.', ',')} pontos.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar publicação')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;
    await widget.service.publish(roster, student);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Pauta da prova'),
      if (_message != null) Text(_message!),
      TextButton.icon(
        onPressed: _busy ? null : () => _load(_page),
        icon: const Icon(Icons.refresh),
        label: const Text('Atualizar pauta'),
      ),
      FutureBuilder<ExamRoster>(
        future: _roster,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const LinearProgressIndicator();
          }
          if (snapshot.hasError) {
            return Text(teacherReviewError(snapshot.error!));
          }
          final roster = snapshot.requireData;
          return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                    '${roster.stage} • Máximo: ${roster.maxPoints.replaceAll('.', ',')} pontos'),
                if (roster.opened) const Text('Pauta aberta'),
                if (!roster.opened)
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () => _run(() async {
                              await widget.service.activate(roster);
                              return true;
                            }, 'Pauta aberta pela API.'),
                    child: const Text('Abrir pauta'),
                  ),
                if (roster.students.rows.isEmpty)
                  const Text('Nenhum aluno elegível nesta página.'),
                for (final student in roster.students.rows)
                  AppCard(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(student.name),
                        Text(student.grade == null
                            ? 'Sem nota'
                            : '${student.grade!.points.replaceAll('.', ',')} pontos • ${student.grade!.published ? 'Publicada' : 'Rascunho'}'),
                        if (roster.opened)
                          Wrap(children: [
                            if (student.grade?.published == true)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () => _edit(roster, student, true),
                                        'Correção publicada pela API.'),
                                child: const Text('Corrigir nota publicada'),
                              )
                            else ...[
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => _run(
                                        () => _edit(roster, student, false),
                                        'Rascunho salvo pela API.'),
                                child: Text(student.grade == null
                                    ? 'Lançar nota'
                                    : 'Editar rascunho'),
                              ),
                              if (student.grade != null)
                                TextButton(
                                  onPressed: _busy
                                      ? null
                                      : () => _run(
                                          () => _publish(roster, student),
                                          'Nota publicada pela API.'),
                                  child: const Text('Publicar nota'),
                                ),
                            ],
                          ]),
                      ])),
                AcademicPageControls(
                    page: roster.students, onPage: _busy ? null : _load),
              ]);
        },
      ),
    ]);
  }
}
