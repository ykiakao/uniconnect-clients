# Layout Corrections Implementation Plan

> **For agentic workers:** Use `.codex-kit/skills/executing-plans/` inline and `systematic-debugging` for each reproduced issue. No commits/push/deploy.

**Goal:** Corrigir geometria e acesso ao conteúdo sem mudar identidade, dados ou comportamento acadêmico.

**Architecture:** Manter as telas, providers, modelos e serviços atuais. Usar constraints e alturas intrínsecas por linha no workspace docente; somente estado de rolagem local na tabela.

**Tech Stack:** Flutter, Material 3, flutter_test, Inter local.

Direção já aprovada: mesma paleta, tipografia, raios e hierarquia da rodada anterior. Este pedido autoriza somente correções de layout. Branch `demo-day-flutter-polish` com alterações anteriores preservadas em `uniconnect_flutter_base/build/layout-before/` como `.dart.snapshot`.

## Diagnóstico a comprovar antes de corrigir

- `AppCard`: Stack usa constraints frouxas para o conteúdo e não recorta a faixa lateral na borda arredondada; texto curto pode encolher um cartão em uma Column.
- Workspace docente: Wrap dá altura independente para cada item e o ícone acima do título aumenta espaço vertical; TextButton adiciona padding que desloca o ícone em relação à descrição.
- Protótipos: não usam o shell de largura máxima já usado nas demais telas; labels longos e descrição multilinha precisam ser inspecionados com fonte ampliada.
- Tabela: largura fixa 680, sem scrollbar persistente ou indicação de rolagem; nomes têm ellipsis sem forma de ler o trecho omitido.
- Perfil: painel de configurações usa Column não rolável dentro do limite padrão do bottom sheet, vulnerável em telas baixas com texto grande.
- Aluno: verificar cabeçalhos com ação em Row, badges truncados, métricas e navegação inferior por medidas e capturas, corrigindo apenas problemas comprovados.

## Tarefas atômicas

### 1. Reproduzir e medir (5–15 min)

- [x] Criar `test/layout_quality_test.dart` com fontes locais, snapshots e medidas: alinhamento de bordas/alturas de pares docentes, ícones/botões alinhados ao texto, largura dos cartões e campos, acesso à última coluna da tabela, bottom sheet com texto ampliado e labels da navegação.
- [x] Exercitar 320/360/390/430/768 px, fontes 1x/1.5x/2x e textos longos apenas como fixtures de testes. Capturar estado antes da correção em `build/layout-qa/before/`.
- [x] Registrar falhas esperadas e suas medidas antes de mudar produção.

### 2. Cartões compartilhados e docente (5–15 min)

- [x] Em `lib/shared/widgets/app_card.dart`, corrigir expansão dentro da largura disponível e recorte da faixa conforme os testes.
- [x] Em `lib/features/teacher/presentation/teacher_dashboard_page.dart`, trocar Wrap por linhas responsivas de altura derivada do conteúdo, preservar duas colunas somente com largura suficiente para a escala de texto e padronizar estrutura ícone/título/badge/descrição/ação. Sem alturas fixas nem novos callbacks.
- [x] Rodar testes de geometria e navegação docente; medir novamente alturas e alinhamentos.

### 3. Protótipos docentes (5–15 min)

- [x] Aplicar `AcademicContent` em `create_activity_page.dart` e `teacher_grades_page.dart`; campos uniformes, labels legíveis e espaçamento pelos tokens existentes.
- [x] Na tabela, usar controller de rolagem descartado corretamente, scrollbar persistente, largura mínima adaptada à escala e instrução de rolagem quando necessária. Permitir nomes completos e preservar todas as linhas/valores.
- [x] Validar leitura da última coluna e publicação desabilitada; capturar formulário e tabela em 320/390/768 e fonte ampliada.

### 4. Aluno, perfil e navegação (5–15 min)

- [x] Corrigir somente falhas reproduzidas em `section_header.dart`, `app_badge.dart`, `activity_card.dart`, `profile_page.dart` e `bottom_nav.dart`. Manter cálculos, rotas, rótulos e fontes de dados.
- [x] Testar rolagem até o último elemento acima da navegação, textos longos e o painel de configurações; confirmar estados desabilitados.

### 5. QA e fechamento (5–15 min)

- [x] Capturar `build/layout-qa/after/` e comparar screenshots e métricas com before; não usar somente ausência de exceções como evidência.
- [x] Aplicar `requesting-code-review` independente e `visual-quality-review`; corrigir achados relevantes.
- [x] Executar `flutter analyze`, suíte completa e build web release com configuração existente. Verificar login/navegação pelos testes de ambos os perfis, sem mexer na autenticação.
- [x] Atualizar `docs/codex-kit/DEMO_DAY_2026-10-28.md` com problemas, causas, arquivos, resultados e comando da demo. Confirmar branch, HEAD, `git diff --check` e ausência de staged files; parar com relatório.

## Fechamento e evidencias

- Oito arquivos de apresentacao alterados em relacao ao snapshot; demais fontes preservadas. Nenhuma correcao local necessaria em app_badge/activity_card.
- RED de geometria, tabela e simulador registrados em build/*.log; 22 testes de layout e 84 testes totais aprovados.
- 74 capturas before e 93 after, com comparacao visual e medidas. Revisao independente sem findings pendentes.
- Analise estatica sem apontamentos; build web release atualizado. Detalhes e limites na secao 10 de ../DEMO_DAY_2026-10-28.md.
