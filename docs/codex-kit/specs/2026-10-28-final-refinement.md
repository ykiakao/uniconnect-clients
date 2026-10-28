# Refinamento final — direção aprovada e diagnóstico

Escopo aprovado no pedido anexado pelo usuário: recuperar a composição antiga, preservar a rodada anterior e priorizar o professor. Manter branch `demo-day-flutter-polish`, sem commits/push/deploy; exclusivamente cliente Flutter e documentação desta demo.

## Inspeção

- Relatório anterior lido. Alterações anteriores continuam sem commit e foram copiadas, antes deste refinamento, para `uniconnect_flutter_base/build/final-refinement-before/` (inclui capturas anteriores disponíveis).
- Histórico visual localizado em `HEAD:.../student_dashboard_page.dart` e em `edfb47c^:.../teacher_dashboard_page.dart`. Não restaurar arquivos inteiros. Screenshots antigos do usuário não foram anexados ao contexto acessível; usar histórico local e capturas da rodada anterior.
- Tema: azul #004A99, laranja #F58220, Inter local, Material 3, AppCard/AppBadge/SectionHeader e shell de 720 px. Login, router, guards e providers existentes serão preservados.
- Implementado: login/sessão, consulta de atividades e notas do aluno, perfil e logout. Protótipos: chat, criar atividade e lançar notas; bloqueios de escrita mantidos.

## Diagnóstico somente leitura da API publicada

Autenticação feita com contas demo já documentadas; demais chamadas somente GET dos endpoints existentes. Sem Supabase direto ou alterações de registros. Nenhum token ou dado pessoal registrado.

| Informação | Classificação | Decisão |
| --- | --- | --- |
| Nome, e-mail, instituição, perfil e curso | Disponíveis e exibidos nos dois perfis | Manter fontes da sessão |
| Matrícula e semestre | Ausentes nas respostas das contas atuais; campos opcionais do modelo | Manter “Não informado”, sem números fictícios |
| 3 cursos institucionais | Disponíveis, não utilizados como vínculos | Catálogo não comprova atribuição ao usuário |
| 2 turmas na consulta do aluno | Disponíveis; nome aproveitado pelo adaptador como disciplina | Descrever contagem como disciplinas identificadas nas atividades, não matrícula confirmada |
| 4 atividades do aluno | Disponíveis e exibidas | Usar totais e datas reais; situação de entrega não fornecida |
| 4 prazos encerrados | Disponíveis: 07, 10, 14 e 17/10/2026 UTC | Separar encerrados de próximos, sem alterar regra de prioridade do serviço |
| 2 notas do aluno | Disponíveis e exibidas | Média simples não oficial; contagem de avaliações |
| Feedback e activityId das notas | Disponíveis, ainda não exibidos integralmente | Conservar no modelo; mostrar feedback e disciplina por associação exata de ID quando disponível |
| CR/GPA oficial, ranking, conclusão curricular e aprovação | Ausentes de contrato confiável | Não restaurar |
| Turmas na consulta do professor | Nenhuma retornada pelos endpoints atuais | Não apresentar listas institucionais como atribuições docentes |
| Curso do professor | Disponível no perfil | Destacar vínculo real, sem inventar métricas de turmas/alunos |
| Conversas, alunos/notas do protótipo docente | Dados locais de demonstração | Manter rótulos e ações de escrita desabilitadas |

Regra atual de prioridade: `remaining.inHours <= 24` é crítica, incluindo diferenças negativas. As quatro atividades vencidas satisfazem essa regra. Problema comprovado: a apresentação mistura prazo passado com urgência futura. Corrigir agrupamento e badge de apresentação, preservando a regra e os filtros existentes.

## Direção criativa

1. **Panorama acadêmico (recomendado e solicitado):** recuperar saudação, cartão azul de indicadores calculados, quadro de prazos e cartões de atividades. Professor usa mesma hierarquia com vínculo real e área de trabalho rotulada. Inter, azul institucional e laranja para atenção; ícones Material acadêmicos; sem fotos ou animações novas. Recusa métricas sem fonte. Risco: densidade em telas estreitas; mitigar com métricas adaptáveis e QA a 1.5x.
2. **Agenda compacta (conservador):** manter a organização da primeira rodada e acrescentar somente contagens. Mesma tipografia/paleta/assets e interações. Menor risco, mas não satisfaz a riqueza visual solicitada.
3. **Painel acadêmico dividido (expressivo):** múltiplas colunas e timeline em telas grandes. Mesma marca, tipografia mais hierárquica, ícones e navegação existentes. Recusa efeitos decorativos; maior risco de layout e execução, adiado.

Aplicar opção 1 conforme aprovação explícita do usuário. Primeira impressão: identidade, panorama do aluno ou vínculo do docente e ações realmente disponíveis. A composição é acadêmica por suas disciplinas, avaliações e datas, sem indicadores de SaaS genéricos. Assets serão os ícones existentes e os próprios registros acadêmicos, sem conteúdo decorativo.

Aceitação: valores de loading/erro/ausência não são zero; prazos próximos/encerrados/ausentes separados; professor tem quatro áreas visuais com disponibilidade explícita e links somente para protótipos existentes; média simples não oficial; zero válido; nenhum envio falso; mobile sem overflow, layout desktop contido. Próxima skill: `interface-craft`.
