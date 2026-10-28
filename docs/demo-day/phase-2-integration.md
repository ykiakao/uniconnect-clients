# Fase 2 — integração local da base sintética

## Design autorizado e plano executável

Manter a direção visual existente. O único elemento novo é uma identificação persistente nas telas acadêmicas do aluno: “Dados demonstrativos — EduKMais”, com referência fixa de 28/10/2026 às 19h Acre. Sem redesenho, novos controles, alterações de navegação, autenticação ou escrita remota.

Seleção de fonte por `--dart-define=DEMO_SYNTHETIC_DATA=true`, false por padrão, somente para aluno autenticado do tenant edukmais. Os providers acadêmicos escolhem uma única fonte antes da consulta. Falha do asset gera erro recuperável na tela, sem fallback para API. Teacher, outros tenants, sessão e perfil pessoal permanecem atuais.

Os IDs e as datas originais da Fase 1 serão mantidos. Uma cópia byte a byte do JSON entra como asset, com teste de igualdade com o documento canônico. Metadados opcionais nos modelos locais guardam contexto de período/disciplina e referência temporal; os modelos de autenticação não mudam. Histórico separado da média atual; avaliações sem atividade conservam vínculo null.

### Tarefas

- [x] 1. Ler JSON/plano da Fase 1, modelos, providers, telas acadêmicas, sessão e router. Confirmar saída separada suportada por Flutter. Preservar build anterior em `uniconnect_flutter_base/build/web-before-synthetic-20261028` antes de implementar.
- [x] 2. Escrever testes de configuração, carregamento real do JSON, mapeamento, referências, datas, histórico e isolamento de fontes. Validar falhas antes da implementação (5–15 min).
- [x] 3. Criar `features/academic/demo/synthetic_academic_data.dart` e `synthetic_academic_providers.dart`, asset e declaração no pubspec. Acrescentar metadados opcionais em AcademicActivity/SubjectGrade e ramificação mínima nos providers atuais, mantendo caminho API idêntico (5–15 min).
- [x] 4. Criar `shared/widgets/academic_demo_frame.dart`; aplicar em dashboard, atividades, detalhe e notas. Usar referência explícita e data Acre apenas para registros sintéticos, sem mudar o relógio/datas do modo normal. Exibir seis avaliações, agrupadas por contexto, com média das cinco atuais. Não enriquecer perfil/professor nesta fase (5–15 min).
- [x] 5. Validar pesquisa, filtros, push/pop, banner persistente e erros sem mistura; QA em larguras móveis e texto ampliado. Fazer revisão independente e corrigir achados (5–15 min).
- [x] 6. Rodar pub get, analyze, suíte completa e testes com flag real. Gerar web release normal em `build/web-normal` e sintético em `build/web-synthetic`, mantendo `build/web` e backup anterior. Registrar hashes, resultados, arquivos e comandos; parar (5–15 min).

## Implementação e telas

- `syntheticDemoRequestedProvider` lê `bool.fromEnvironment('DEMO_SYNTHETIC_DATA', defaultValue: false)`. A fonte só é habilitada para aluno autenticado com slug `edukmais`. Não há botão, persistência da escolha ou fallback automático.
- `activitiesProvider` e `subjectGradesProvider` mantêm a verificação de sessão e escolhem exclusivamente API ou asset. O caminho HTTP anterior permanece igual. Falha de asset é tratada como erro; repetir consulta invalida também a fonte local, que lê o asset sem cache de falhas.
- `SyntheticAcademicData` valida metadados, IDs, referências e notas, resolve nomes de disciplinas/docentes e conserva IDs, datas e atividades null das avaliações. O JSON em assets é idêntico ao documento da Fase 1. Seus metadados de preparação documental permanecem como proveniência; a flag do aplicativo determina a ativação em runtime.
- Dashboard: 10 atividades, cinco disciplinas nas atividades, quatro prazos futuros, dois em até 24h, quatro encerrados e dois ausentes. A prévia demonstrativa prioriza atividades futuras. Média simples **8,2**, calculada somente das cinco avaliações atuais.
- Atividades e detalhes: dez registros, pesquisa por título/disciplina/docente, filtros de prioridade, ordenação com prazos ausentes ao fim e push/pop com filtros preservados. Instruções, critérios e docentes fictícios vêm do asset.
- Notas: seis avaliações, cinco no período 2026.2 e uma em histórico 2026.1, fora da média atual. Todas mostram disciplina/período; quatro têm atividade correspondente e duas mantêm `activityId: null`, com rótulo “Nota da avaliação”. Não há GPA, ranking ou resultado oficial inventado.
- Aviso “Dados demonstrativos — EduKMais” fixo em dashboard, atividades, detalhes e notas, inclusive loading/erro/ID inexistente. A referência temporal é exibida. SafeArea protege a barra de status; em área muito baixa, o próprio aviso pode rolar dentro de um limite, sem impedir a rolagem do conteúdo.

As datas originais ISO com offset -05:00 são preservadas como instantes. Um getter de apresentação desloca a representação UTC apenas para formatar a hora civil do Acre nos registros sintéticos; não altera `dueDate`. Comparações/rótulos usam a referência explícita da fixture. Registros da API continuam usando relógio e fuso do dispositivo, como antes.

Login, sessão, credenciais, identidade do usuário, tenant, perfil, telas docentes, protótipos, chat, menu inferior de 350 ms, transições e grafo de rotas permaneceram inalterados. Perfil não recebeu matrícula, semestre ou vínculo fictício. As 14 disciplinas e quatro períodos continuam no asset, mas não foi criado um novo histórico curricular completo.

## Arquivos desta fase

Todos os caminhos abaixo são relativos a `uniconnect-clients`:

```text
docs/demo-day/phase-2-integration.md
uniconnect_flutter_base/pubspec.yaml
uniconnect_flutter_base/assets/demo/synthetic-academic-data.json
uniconnect_flutter_base/lib/features/academic/demo/synthetic_academic_data.dart
uniconnect_flutter_base/lib/features/academic/demo/synthetic_academic_providers.dart
uniconnect_flutter_base/lib/features/activities/models/academic_activity.dart
uniconnect_flutter_base/lib/features/activities/providers/activity_provider.dart
uniconnect_flutter_base/lib/features/activities/presentation/activities_page.dart
uniconnect_flutter_base/lib/features/activities/presentation/activity_detail_page.dart
uniconnect_flutter_base/lib/features/activities/widgets/activity_card.dart
uniconnect_flutter_base/lib/features/grades/models/subject_grade.dart
uniconnect_flutter_base/lib/features/grades/providers/grades_provider.dart
uniconnect_flutter_base/lib/features/grades/presentation/grades_page.dart
uniconnect_flutter_base/lib/features/student/presentation/student_dashboard_page.dart
uniconnect_flutter_base/lib/shared/widgets/academic_demo_frame.dart
uniconnect_flutter_base/test/synthetic_academic_data_test.dart
uniconnect_flutter_base/test/synthetic_academic_demo_test.dart
uniconnect_flutter_base/test/activity_detail_page_test.dart
uniconnect_flutter_base/test/grades_page_test.dart
uniconnect_flutter_base/test/demo_responsive_test.dart
```

Nos três testes legados de apresentação/API, a configuração normal passou a ser explícita, preservando todas as assertions. Isso evita que a execução da suíte com flag true inicialize autenticação de plataforma fora do contexto desses testes. Testes novos verificam o modo true com login elegível e a flag real, sem substituir a configuração por override nesse caso. Não foram desabilitados testes.

## Validação técnica

| Verificação | Resultado |
| --- | --- |
| `flutter pub get` | Concluído; nenhuma dependência adicionada, lockfile preservado |
| `flutter analyze` | Sem apontamentos |
| `flutter test --reporter expanded` | **119 testes passaram**, sendo 95 anteriores e 24 novos |
| `flutter test --reporter expanded --dart-define=DEMO_SYNTHETIC_DATA=true` | **119 testes passaram** com a flag compilada ativa |
| Fonte e contratos | Asset igual à Fase 1, dez atividades/seis avaliações, vínculos consistentes, notas válidas, quatro avaliações vinculadas e duas null, períodos e datas Acre |
| Isolamento | Fonte sintética não chama API acadêmica; modo normal não carrega asset; erro não faz fallback; troca de seleção nos testes retorna exclusivamente à API sem alterar identidade |
| Navegação | Login/guard/retorno dos dois perfis preservados pelos testes existentes; busca e prioridade sobrevivem a push/pop do detalhe sintético |
| Estados | Banner em loading/erro/not-found; retry recupera asset após falha com duas tentativas e zero chamadas acadêmicas remotas |
| Responsividade | Quatro telas sintéticas em 320/360/390/430/768 px com texto 2x; aviso permanece visível durante rolagem; matriz anterior também passou |
| QA visual | Capturas em `build/layout-qa/after/synthetic-*.png`, incluindo dashboard 390 px, detalhe 320 px/texto 2x e histórico; inspecionadas |
| Code review independente | Três P2 corrigidos e cobertos: retry da fonte, SafeArea do aviso, estados do detalhe. Revisão final sem findings novos |
| Builds | Dois releases concluídos: `build/web-normal` (38,9 s) e `build/web-synthetic` (36,2 s), com bundles distintos |
| Smoke web local | HTTP 200 para index, bootstrap, main.dart.js e JSON nos dois releases; dez atividades/seis avaliações no asset servido |
| Preservação | Os 42 arquivos de `build/web` coincidem byte a byte com o backup anterior. JSON canônico, asset e cópias nos dois builds idênticos |
| Escopo final | 13 arquivos existentes modificados e sete adicionados; outros 261 arquivos da baseline preservados, incluindo auth, router, menu/transições, professor, perfil, chat, lockfile e documentos da Fase 1 |
| Git | Branch `demo-day-flutter-polish`, HEAD `3c70edc` preservado, sem staged files; `git diff --check` sem erros |

Logs em `uniconnect_flutter_base/build/`: `synthetic-pub-get.log`, `synthetic-analyze.log`, `synthetic-all-tests-normal.log`, `synthetic-all-tests-enabled.log`, `synthetic-build-normal.log` e `synthetic-build-enabled.log`.

Os testes novos verificaram falhas antes da implementação e foram refinados para lidar com IO real de assets no ambiente fake async de widgets. Os logs intermediários RED são históricos; os dois logs de suíte completa acima contêm a validação final.

## Builds e execução local

O build anterior foi copiado antes da implementação para `uniconnect_flutter_base/build/web-before-synthetic-20261028`, com hash de main.dart.js conferido. `build/web` permanece como alternativa anterior. Os releases desta fase usam `--output` suportado pelo Flutter, sem sobrepor essa alternativa.

Comandos de compilação, dentro de `uniconnect_flutter_base`:

```powershell
flutter build web --release --output build/web-normal --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais
flutter build web --release --output build/web-synthetic --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais --dart-define=DEMO_SYNTHETIC_DATA=true
```

Para abrir o demonstrativo, a partir de `SaaS_UniConnect`:

```powershell
cd uniconnect-clients\uniconnect_flutter_base
python -m http.server 8080 --bind 127.0.0.1 --directory build/web-synthetic
```

Abrir **http://127.0.0.1:8080**, recarregar a aba e entrar com a conta de aluno EduKMais já existente/documentada. O login continua real; a flag substitui somente a fonte acadêmica após autenticação elegível. Professor segue o fluxo anterior, sem novos registros ou ações de publicação.

Para retornar ao normal, servir o outro diretório em outra porta/terminal:

```powershell
python -m http.server 8081 --bind 127.0.0.1 --directory build/web-normal
```

Abrir **http://127.0.0.1:8081**. Não há banco ou registros a restaurar; as fontes são escolhidas pelo build. Para voltar ao release anterior preservado, usar `--directory build/web-before-synthetic-20261028`.

## Limites e encerramento

- Fotografia demonstrativa fixa em 28/10/2026 às 19h Acre, indicada nas telas; não avança prazos com o calendário nem muda o relógio normal.
- Perfil pessoal, matrícula, semestre, gestão docente e chat não foram enriquecidos. Dados de currículo anteriores permanecem no JSON; a UI histórica adicionada cobre a avaliação anterior disponível.
- Autenticação ainda depende da API e conexão existentes. Esta fase não repetiu login remoto, não usa credenciais novas e não oferece login offline.
- QA usa testes Flutter e capturas, sem ensaio em celular físico. Smoke dos arquivos web e preservação final concluídos; ele não equivale a um ensaio autenticado completo no navegador.
- Nenhum acesso ao backend, Supabase, SQL, migrations ou Uninorte; sem commit, push ou deploy. Parar após a verificação final desta fase.

Entrega concluída em 28/10/2026, antes das 18h Acre. Builds e cópia anterior disponíveis; nenhuma etapa adicional iniciada.
