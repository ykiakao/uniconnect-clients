# UniConnect · Aplicativo Flutter

Cliente acadêmico para alunos e professores. Integra-se à API REST do UniConnect e usa o contexto da instituição em cada sessão. Referência atualizada em **04/11/2026**.

## SDK e dependências

O workflow usa **Flutter 3.44.0**. A instalação local inspecionada usa Flutter 3.44.0 e Dart 3.12.0. O `pubspec.yaml` declara Dart `>=3.4.0 <4.0.0`. O conjunto resolvido no `pubspec.lock` exige Dart `>=3.10.3 <4.0.0` e Flutter `>=3.38.4`.

| Dependência | Versão resolvida | Uso |
| --- | --- | --- |
| `flutter_riverpod` | 3.3.1 | Estado, sessão, dependências e consultas assíncronas |
| `go_router` | 17.2.3 | Rotas, guards e deep links |
| `http` | 1.6.0 | Transporte REST |
| `flutter_secure_storage` | 10.3.1 | Persistência da sessão lembrada |
| `intl` | 0.20.2 | Formatação |
| `google_fonts` | 8.1.0 | Dependência declarada com carregamento remoto desabilitado |

O manifesto também declara `cupertino_icons`, `flutter_test` e `flutter_lints`. Inter é distribuída em assets locais. A aplicação configura o tema claro e utiliza os ícones disponíveis no Flutter.

## Estrutura e sessão

- [`lib/core/`](lib/core/) contém configuração da API, roteamento, cliente HTTP e tema.
- [`lib/features/`](lib/features/) reúne telas, modelos, serviços e providers por área. [`lib/shared/widgets/`](lib/shared/widgets/) concentra os componentes compartilhados.
- [`test/`](test/) contém testes unitários, de serviço e de widget.

O `ApiClient` envia `x-tenant-slug` e adiciona o Bearer nas chamadas protegidas. O app usa `/auth/login`, `/auth/me`, `/auth/refresh` e `/auth/logout`. Quando o usuário escolhe lembrar a sessão, o app persiste o registro de tokens no armazenamento seguro da plataforma. A restauração valida a sessão com a API. O cliente coordena a rotação e pode repetir uma chamada protegida após renovação diante de `401 INVALID_SESSION`. Os guards aguardam a restauração e encaminham o usuário ao destino autorizado para o seu papel.

## Navegação e jornadas

O login fica em `/`, a restauração em `/auth/loading` e o Perfil em `/perfil`, fora da barra principal.

### Aluno

| Destino | Implementação |
| --- | --- |
| `/aluno` | Resumo acadêmico, atalhos, agenda e prévia de entregas pendentes confirmadas pela API |
| `/atividades` e `/atividades/:id` | Pesquisa, filtros, detalhes e entrega textual quando elegível. Envio e reenvio usam `expectedVersion`. O detalhe exibe a nota e a devolutiva publicadas |
| `/chat` | Conversas ilustrativas, com envio e anexos indisponíveis |
| `/notas` | Seleção da oferta e boletim oficial N1/N2, com pontos de trabalhos e provas, média, situação e elegibilidade à final quando retornadas pela API |
| `/academico` | Instituição, matrícula, curso e semestre quando fornecidos. Horários e calendário permanecem sem integração |

Provas presenciais e atividades sem fluxo textual ficam sem formulário de entrega. O app apresenta o boletim do servidor, preservando notas zero, valores nulos e resultados parciais.

### Professor

| Destino | Implementação |
| --- | --- |
| `/professor` | Oferta selecionada, trabalhos publicados, prazos e prévia limitada de entregas e correções |
| `/professor/atividades` | Trabalhos por oferta, edição de rascunho, publicação, encerramento, matrículas e entregas. A correção separa salvamento de publicação e volta ao mesmo trabalho |
| `/professor/criar-atividade` | Formulário legado de criação, inclusive cadastro de prova presencial |
| `/professor/chat` | Destino com aviso de indisponibilidade |
| `/professor/notas` | Pauta de provas N1/N2, lançamento e publicação de notas, boletim e fechamento de etapa |

A seleção por `classId` é compartilhada entre áreas docentes e isolada por sessão, usuário e tenant. Os deep links de oferta são validados. O app protege edições pendentes e descarta resultados de contextos anteriores. Escritas acadêmicas preservam os campos de versão e revisão previstos pela API.

## Execução local

Na pasta do app, com a API ativa e uma conta do ambiente local:

```bash
flutter pub get
flutter devices
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:3333/api/v1 --dart-define=TENANT_SLUG=uniconnect-local
```

- `API_BASE_URL` inclui `/api/v1`. Sem override, o emulador Android usa `http://10.0.2.2:3333/api/v1` e Web/desktop usam `http://localhost:3333/api/v1`. Em aparelho físico, informe o endereço da API alcançável pela rede do aparelho.
- `TENANT_SLUG` configura o contexto inicial de login. O padrão compilado é `edukmais`. No harness local, use `uniconnect-local` e a porta que ele exibir.
- `DEMO_SYNTHETIC_DATA` é `false` por padrão. A opção `true` habilita o acervo demonstrativo para o aluno autenticado do tenant `edukmais`. Use o modo padrão para validar persistência real.

## Testes e evidências

```bash
flutter analyze --no-pub
flutter test --no-pub
flutter test --no-pub test/teacher_work_journey_test.dart test/student_submission_widget_test.dart
```

Os testes cobrem sessão, guards, ofertas, entregas, revisões, provas, boletim e fechamento. Fixtures HTTP e testes de widget verificam o contrato do cliente. No ensaio local com API, GoTrue, PostgREST e PostgreSQL reais, o Flutter Web chegou até a abertura, pelo professor, da mesma entrega reenviada pelo aluno. A evidência consultada não confirma o salvamento e a publicação da correção, a consulta final pelo aluno ou a execução em dispositivo nativo. O app ainda não integra Supabase Realtime nem executa o fluxo de prova final.

A [preparação da Demo Day de 28/10/2026](../docs/codex-kit/DEMO_DAY_2026-10-28.md) e o [roteiro de GitHub Pages](../docs/demo-day/github-pages-publication.md) documentam a demonstração histórica. O [endereço público configurado](https://ykiakao.github.io/uniconnect-clients/) é uma referência de publicação, separada do ambiente local.
