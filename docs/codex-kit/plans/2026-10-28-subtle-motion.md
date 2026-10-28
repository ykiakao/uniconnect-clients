# UniConnect — microanimações para a Demo Day

## Direção e escopo aprovados

O pedido atual autoriza microanimações sobre a direção Agenda acadêmica já aprovada. A skill `creative-direction` governa a preservação da identidade; `interface-craft` orienta a execução, sem novo conceito visual.

- Preservar azul/laranja, Inter, largura dos rótulos, geometria responsiva e ícones Material.
- Movimento serve para confirmar seleção e orientar entrada/retorno, sem loops, assets ou decoração nova.
- Manter rotas, chaves de páginas, providers e autenticação; redução de movimento apresenta o estado final diretamente.

Branch `demo-day-flutter-polish`, sem commit/push/deploy. Base sintética não integrada. Dois arquivos de produção previstos: `uniconnect_flutter_base/lib/shared/widgets/bottom_nav.dart` e `uniconnect_flutter_base/lib/core/router/app_route_transition_page.dart`.

## Diagnóstico

NavigationBar usa indicador Material, com duração padrão de 500 ms; as barras pertencem a Scaffolds diferentes e são montadas novamente ao trocar de rota. Só alterar animationDuration não produziria entrada animada no item recém-selecionado. Labels são medidos para caber em 320 px/fonte ampliada; preservar esse cálculo.

AppRouteTransitionPage já faz fade e deslocamento de 8% em 260 ms, reverso 190 ms. Reutilizar o componente para reduzir duração/deslocamento e ignorar efeitos quando disableAnimations ou accessibleNavigation estiver ativo. Não mudar app_router.dart.

Atividades mantém busca/filtros em estado local. Push/pop de detalhe preserva esse estado; context.go entre rotas de topo pode descartá-lo. Esta limitação anterior não será corrigida com ShellRoute, cache de páginas ou novos providers. Os providers acadêmicos atuais não são autoDispose; verificar que as animações não causam novas consultas.

## Plano executável

- [x] 1. Criar `test/subtle_motion_test.dart` antes do código: entrada/seleção intermediária e final, redução de movimento, transição/retorno e interação, estado local preservado em push/pop e contagem de consultas na navegação (5–15 min).
- [x] 2. Em bottom_nav.dart, configurar 200 ms no indicador e animar entrada da cor, destaque e escala de 0,96 a 1 no ícone ativo, sem alterar slots, labels, rotas ou semântica. Reusar animação local, sem repetir por rebuild do provider (5–15 min).
- [x] 3. No helper de páginas, usar 220 ms de entrada e 180 ms no retorno, com deslocamento de 2% horizontal/2,5% vertical e fade; redução de movimento retorna o child diretamente. Sem alterações no grafo GoRouter (5–15 min).
- [x] 4. Rodar testes focados e os 84 existentes; analisar frames de entrada e seleção. Não animar cartões: sua entrada depende de providers e não justifica efeitos adicionais para esta demo (5–15 min).
- [x] 5. Aplicar revisão independente e QA visual; executar flutter analyze, suíte completa e build web release com API_BASE_URL e TENANT_SLUG existentes. Registrar evidências, arquivos, limitações e preservar demais hashes antes de parar (5–15 min).

## Validação e encerramento

Concluído: flutter analyze sem apontamentos; 89 testes passaram (84 existentes e 5 novos); build web release atualizado. Revisão independente sem findings pendentes. Capturas intermediária/final em `build/layout-qa/after/motion-navigation-*.png`, inspecionadas em 320 px. Hashes confirmam somente os dois arquivos produtivos previstos alterados; base sintética, providers, auth, grafo GoRouter, demais fontes, testes anteriores e dependências preservados. Evidências completas na seção 11 de `../DEMO_DAY_2026-10-28.md`. Sem commit/push/deploy; encerramento nesta rodada.
