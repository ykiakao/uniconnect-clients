# Final Refinement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `.codex-kit/skills/executing-plans/` task-by-task. No commits, push or deploy.

**Goal:** Recuperar a composição acadêmica antiga com dados verificáveis e uma área docente visualmente completa.

**Architecture:** Reutilizar providers, widgets, router e contratos existentes. Somente apresentação e campos opcionais do modelo local de notas para conservar informações que a API já envia.

**Tech Stack:** Flutter, Dart, Riverpod, GoRouter, flutter_test, Inter local.

Design e diagnóstico: `docs/codex-kit/specs/2026-10-28-final-refinement.md`.

### 1. Regressões e métricas do aluno (5–15 min)

- [x] Adicionar `test/final_refinement_test.dart`: totais/média derivados de providers, três situações de prazo, atividades vencidas continuam visíveis e ausência de GPA/entrega presumida. Executar `flutter test test/final_refinement_test.dart` e observar as falhas antes de implementar.
- [x] Adicionar `lib/shared/widgets/academic_metric_grid.dart`: métricas em Wrap com colunas calculadas por largura e escala de texto. Valores e rótulos vêm dos widgets consumidores, sem buscar dados.
- [x] Incrementar `lib/features/student/presentation/student_dashboard_page.dart`: manter cabeçalho/instituição/atalhos/refresh; acrescentar média simples via `subjectGradesProvider`, métricas das atividades e quadro separado de prazos. Usar “Atividades acadêmicas” e mostrar registros mesmo vencidos. Carregamento/erro/ausência de notas ficam independentes da agenda.
- [x] Validar `flutter test test/final_refinement_test.dart test/demo_day_test.dart`.

### 2. Área de trabalho docente (5–15 min)

- [x] Em `teacher_dashboard_page.dart`, recuperar saudação e contexto institucional, manter identidade/perfil/vínculo e explicar limites. Acrescentar cartões Turmas e disciplinas, Atividades acadêmicas, Lançamento de notas e Comunicação com alunos.
- [x] Atividades e notas têm links “Ver protótipo” para rotas existentes; turmas/comunicação ficam informativas, indisponíveis, sem callbacks vazios. Publicação/envio continuam desabilitados.
- [x] Estender `test/demo_navigation_test.dart` para abrir os dois protótipos e retornar ao dashboard antes do perfil/logout. Atualizar expectativas docentes apenas conforme o novo escopo autorizado, preservando assertivas contra métricas e escrita falsa.
- [x] Rodar `flutter test test/teacher_dashboard_page_test.dart test/demo_navigation_test.dart`.

### 3. Notas e prazos (5–15 min)

- [x] Acrescentar campos opcionais `activityId` e `feedback` em `subject_grade.dart` e mapeá-los em `academic_api_service.dart`. Não mudar URLs, parâmetros ou regras existentes. Adicionar teste HTTP que confira conservação desses campos.
- [x] Em `grades_page.dart`, enriquecer cartão azul e cartões de avaliação com ícone, nota destacada, feedback e disciplina somente quando houver associação exata de activityId com atividade disponível. Manter simulador, erro, retry, vazio e zero.
- [x] Em `activities_page.dart`, separar grupo de prazos encerrados dos futuros preservando seleção/filtros. Em `activity_card.dart`, usar badge neutro para prazo encerrado e exibir a data real, sem alterar prioridade no serviço.
- [x] Rodar `flutter test test/academic_api_service_test.dart test/final_refinement_test.dart test/demo_day_test.dart`.

### 4. QA, review e entrega (5–15 min)

- [x] Executar suíte responsiva com capturas para todas as telas alteradas; verificar 320/375/430/768/1024/1440, texto 1.5x, estados vazios e ausência de envio no chat. Comparar capturas atuais com snapshot anterior.
- [x] Aplicar `requesting-code-review` com revisor independente e `visual-quality-review`; corrigir achados relevantes.
- [x] Formatar somente arquivos tocados nesta rodada; executar `flutter analyze`, `flutter test` e build web release com API publicada/tenant atual. Sem dependências novas; `pub get` somente se necessário.
- [x] Acrescentar seção de refinamento ao relatório `docs/codex-kit/DEMO_DAY_2026-10-28.md`, com diagnóstico, comparação, arquivos, evidências e comando da demo.
- [x] Verificar `git diff --check`, branch preservada e nenhuma alteração staged. Parar com relatório final.
