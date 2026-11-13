# Acabamento visual comercial — 28/10/2026

Direção aprovada pelo pedido atual: manter a identidade e a navegação; retirar banners e referência fixa visível. Transparência em uma seção textual discreta do perfil e contexto semântico nas páginas acadêmicas, sem reservar altura. O relógio interno e os dados permanecem intactos. Retirar somente o cartão docente “Sobre este ambiente”, mantendo os estados/avisos das ferramentas não integradas.

Plano executável, com `writing-plans`, TDD, revisão independente e verificação final:

- [x] Atualizar testes de identificação/ausência do banner, perfil nos dois modos e remoção do cartão; reproduzir falhas antes da implementação.
- [x] Simplificar `academic_demo_frame.dart` para contexto semântico sem UI; acrescentar explicação explícita no perfil apenas com fonte sintética ativa; remover o cartão docente e seu espaço associado.
- [x] Revisar screenshots em mobile/texto ampliado e verificar 10 atividades, 6 avaliações e média 8,2 pelos testes existentes.
- [x] Executar analyze, suíte Flutter nos dois modos e build web sintético em saída própria; confirmar hashes dos dados, autenticação, animações e builds anteriores.
- [x] Registrar evidências, revisar o código e encerrar sem commit/push/deploy.

## Resultado

Removido somente o cartão docente “Sobre este ambiente” e seu espaçamento. As quatro ferramentas, disponibilidade, atalhos e limites de publicação permanecem iguais.

As páginas acadêmicas não reservam altura para banner ou referência de data/hora. No modo sintético, `AcademicDemoFrame` fornece apenas um contexto semântico explícito para leitores de tela, com descendentes independentes. No modo normal, retorna o conteúdo diretamente.

O perfil sintético apresenta texto discreto “Ambiente de demonstração”, seguido de “Dados acadêmicos fictícios da EduKMais, usados para apresentação. Não representam registros reais da sua conta.” Não há novo cartão ou painel. As identificações curtas preexistentes nos dashboards foram preservadas. A data de referência continua somente no cenário interno; prazos das atividades continuam exibidos como antes.

### Arquivos

- `uniconnect_flutter_base/lib/shared/widgets/academic_demo_frame.dart`
- `uniconnect_flutter_base/lib/features/profile/presentation/profile_page.dart`
- `uniconnect_flutter_base/lib/features/teacher/presentation/teacher_dashboard_page.dart`
- `uniconnect_flutter_base/test/synthetic_academic_demo_test.dart`
- `uniconnect_flutter_base/test/demo_day_test.dart`
- Este documento.

### Validação final

- `flutter analyze`: sem apontamentos.
- Suíte normal: **121 testes passaram**.
- Suíte com `DEMO_SYNTHETIC_DATA=true`: **121 testes passaram**.
- Nenhum teste desabilitado: expectativas de banners/cartão atualizadas para o novo requisito, com contexto semântico, perfil nos dois modos e ausência de referência visual verificados. Dois testes de perfil adicionados.
- 10 atividades, 6 avaliações e média simples atual 8,2 confirmadas pelos testes e pelo asset do release. Cópias documental, asset e asset publicado no build são idênticas.
- Responsividade: quatro telas acadêmicas nas cinco larguras 320/360/390/430/768, texto 2x e perfil 320/texto 2x. Capturas em `build/layout-qa/after/`, incluindo `synthetic-dashboard-390.png`, `synthetic-detail-320-text200.png` e `commercial-profile-320-text200.png`, inspecionadas.
- Revisão independente sem findings relevantes. Semântica real e ausência de altura reservada cobertas por testes.
- Web release sintético atualizado em `uniconnect_flutter_base/build/web-synthetic`, com API_BASE_URL/TENANT_SLUG existentes e `DEMO_SYNTHETIC_DATA=true`.
- Hashes confirmaram alterações somente nos cinco arquivos de código/testes listados. JSON, providers, modelos, autenticação, API, menu, transições, rotas, dependências e builds anteriores (`web`, `web-normal`, backup) preservados.
- Branch `demo-day-flutter-polish` preservada, sem staged files; `git diff --check` sem erros. Nenhum acesso ao Supabase/backend, commit, push ou deploy.

Logs finais em `uniconnect_flutter_base/build/`: `commercial-analyze.log`, `commercial-tests-normal.log`, `commercial-tests-synthetic.log`, `commercial-build-synthetic.log`. `commercial-red.log` registra as falhas esperadas antes da alteração.

Para abrir o release, dentro de `uniconnect_flutter_base`: `python -m http.server 8080 --bind 127.0.0.1 --directory build/web-synthetic`. Acessar http://127.0.0.1:8080 e recarregar a aba.

Acabamento concluído; nenhuma melhoria adicional iniciada.
