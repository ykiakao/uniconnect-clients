# Demo Day Flutter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `.codex-kit/skills/executing-plans/` to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Polir a consulta acadêmica dos dois perfis e remover ambiguidades que prejudiquem a demonstração.

**Architecture:** Reutilizar telas, tema, Riverpod e GoRouter existentes. Sem contratos, endpoints ou dependências novas; correções pontuais de apresentação dos dados e proteção da navegação.

**Tech Stack:** Flutter 3.44.0, Dart 3.12.0, Riverpod, GoRouter, flutter_test.

Design: `docs/codex-kit/specs/2026-10-28-demo-day-polish.md`. Sem commits, push ou deploy por instrução do usuário. Executar inline; solicitar revisão independente ao final.

### 1. Base e regressões (5–15 min)

- [x] Executar `flutter pub get` e suíte atual (`flutter test`), preservando dependências fixadas.
- [x] Em `test/demo_day_test.dart` e `test/academic_api_service_test.dart`, registrar regressões: dashboard sem GPA fixo, erro recuperável, notas sem premiação/créditos fictícios e zero visível, perfil sem fallback acadêmico, guard de detalhes por perfil, data ausente sem prazo inventado, protótipos sem publicação falsa.
- [x] Rodar os novos testes e registrar falhas correspondentes antes de alterar código de produção.

### 2. Dashboard do aluno (5–15 min)

- [x] Modificar `lib/features/student/presentation/student_dashboard_page.dart`: usar usuário e instituição da sessão, curso/semestre apenas se fornecidos; atalhos reais para atividades e notas; agenda ordenada com datas futuras, disciplinas derivadas explicitamente das atividades, loading/erro/vazio via provider.
- [x] Reutilizar `AppCard`, `ActivityCard`, `SectionHeader`, estados compartilhados e tokens; limitar a largura do conteúdo com um shell compartilhado pequeno em `lib/shared/widgets/academic_content.dart`.
- [x] Validar dashboard com provider de dados, vazio, erro e recuperação, sem chamadas reais na suíte.

### 3. Professor e perfil (5–15 min)

- [x] Em `lib/features/teacher/presentation/teacher_dashboard_page.dart`, polir identificação, instituição e vínculo existente; explicar ausência de turmas e gestão; adicionar acesso ao perfil implementado.
- [x] Em `lib/features/profile/presentation/profile_page.dart`, adaptar retorno/nav ao perfil, remover valores acadêmicos inventados, explicar configurações não integradas e preservar logout.
- [x] Em `lib/core/router/app_router.dart` e `test/app_router_guard_test.dart`, proteger também `/atividades/<id>` contra acesso do professor.
- [x] Testar a navegação docente, dados opcionais ausentes, logout/cancelamento e bloqueio de rotas.

### 4. Consulta e estados honestos (5–15 min)

- [x] Em `lib/features/grades/presentation/grades_page.dart`, manter consulta e simulador; mostrar notas por atividade sem alegar aprovação, CR oficial, progresso ou premiação; remover controles PDF/filtro sem implementação; erro com retry e vazio explicativo.
- [x] Em `lib/features/activities/presentation/{activities_page,activity_detail_page}.dart`, melhorar textos, vazio, data explícita e retry do provider fonte; aplicar shell responsivo.
- [x] Em `lib/features/activities/models/academic_activity.dart` e `lib/features/academic/services/academic_api_service.dart`, permitir data ausente e ordenar datas ausentes ao final; não gerar prazo artificial. Testar com HTTP mock do contrato existente.
- [x] Em `lib/features/auth/presentation/login_page.dart`, ajustar linguagem acadêmica e autofill mantendo login e tratamento de erros.

### 5. Protótipos acessíveis e responsividade (5–15 min)

- [x] Em `lib/features/chat/presentation/chat_page.dart` e `lib/features/teacher/presentation/{create_activity_page,teacher_grades_page}.dart`, rotular dados/protótipos e desabilitar envio/publicação/busca sem integração. Preservar telas existentes, sem recriá-las.
- [x] Ajustar `lib/shared/widgets/{section_header,error_state_widget,empty_state_widget,bottom_nav}.dart` apenas onde a revisão identificar problemas de largura ou estado; aplicar contraste sem trocar a identidade.
- [x] Testar telas em larguras 320/375/430/768/1024/1440, texto ampliado e navegação completa via router com sessão simulada restrita aos testes. Capturar screenshots locais de QA se viável.

### 6. Revisão e entrega (5–15 min)

- [x] Rodar `dart format` somente nos arquivos Dart alterados, `flutter analyze`, `flutter test` e `flutter build web` com API/tenant já documentados.
- [x] Aplicar `requesting-code-review`, `visual-quality-review` e `verification-before-completion`; corrigir achados relevantes antes de fechar.
- [x] Registrar evidências e instruções de demo em `docs/codex-kit/DEMO_DAY_2026-10-28.md`, incluindo limitações e arquivos modificados.
- [x] Confirmar `git diff --check`, status final e ausência de alterações fora deste repositório. Parar com relatório, sem commit/push/deploy.
