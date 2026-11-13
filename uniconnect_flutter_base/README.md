# UniConnect · Aplicativo Flutter

Cliente Android/Web para alunos e professores, integrado à API REST UniConnect. Estado documentado em **13/11/2026**, entrega Android/FCM `d4d8e3d`. Veja [visão geral](../README.md) e [backend](https://github.com/ykiakao/uniconnect-api).

## Pré-requisitos e versões

| Item | Estado verificado |
| --- | --- |
| APK release da entrega | Flutter 3.50.0, Dart 3.14.0 |
| Workflow Web | Flutter 3.44.0, Dart 3.12.0; build compatível verificado separadamente |
| Manifesto Dart | `>=3.4.0 <4.0.0`; não representa sozinho o mínimo das dependências resolvidas |
| Lock publicado | Dart `>=3.13.0 <4.0.0`, Flutter `>=3.44.0` |
| Android | SDK compile/target 36, minSdk 24; JDK 17; Gradle 9.3.1, AGP 9.1.1 e Kotlin 2.3.20 |
| Identidade Android | applicationId `br.com.uniconnect.app`; namespace Kotlin `com.example.uniconnect` |

Para reproduzir o APK, prefira o SDK 3.50 validado. No SDK 3.44, `flutter pub get` precisa resolver novamente os pacotes compatíveis com Dart 3.12; não usar `--enforce-lockfile` nesse cenário. O build Web dessa resolução foi aprovado em cópia temporária. Não atualizar Gradle/AGP/Kotlin para seguir o README.

Dependências incluem Riverpod, GoRouter, HTTP, secure storage, Realtime Client, file picker, url launcher, `firebase_core 5.1.0` e `firebase_messaging 17.0.1`. Não há `flutter_local_notifications`. Inter é asset local e carregamento remoto de fontes está desativado.

## Estrutura, sessão e autorização

- [lib/core/](lib/core/): configuração, cliente HTTP, rotas, tema e coordenadores FCM.
- [lib/features/](lib/features/): autenticação, atividades, notas, comunicação e demais jornadas.
- [lib/shared/widgets/](lib/shared/widgets/) e [test/](test/): componentes e testes.
- [android/](android/), [web/](web/) e [assets/](assets/): plataformas e identidade.

Login, restauração, renovação e logout usam `/auth/login`, `/auth/me`, `/auth/refresh` e `/auth/logout`. O `ApiClient` envia Bearer e `x-tenant-slug`. A sessão lembrada usa armazenamento seguro da plataforma; o app coordena rotação e pode repetir uma chamada após `401 INVALID_SESSION`. Guards aguardam restauração/renovação. O servidor continua responsável pela autorização efetiva.

## Funcionalidades e navegação

| Perfil / destino | Fluxo |
| --- | --- |
| Aluno: `/aluno` | Resumo, agenda e pendências disponibilizadas pela API |
| `/atividades`, `/atividades/:id` | Pesquisa/filtros, materiais, resposta textual e anexos elegíveis, reenvio/histórico, nota e devolutiva publicadas |
| `/notas`, `/academico` | Boletim N1/N2 por oferta e dados institucionais; preserva zero, nulos e resultados parciais |
| `/chat`, `/chat/:id` | Conversas e mensagens via HTTP, sinais Realtime privados e recibos |
| Professor: `/professor`, `/professor/atividades` | Seleção de oferta, rascunhos, materiais, publicação, encerramento, entregas e correção/publicação |
| `/professor/notas` | Provas presenciais N1/N2, notas, boletim e fechamento |
| `/professor/chat`, `/professor/chat/:id` | Conversas e mensagens autorizadas |
| `/avisos`, `/notificacoes`, `/perfil` | Comunicação interna e perfil conforme papel; Perfil fora da barra principal |

A seleção docente por `classId` é compartilhada e isolada por sessão/tenant. Escritas usam versões/revisões previstas pela API. O formulário legado `/professor/criar-atividade` continua disponível. Horários/calendário acadêmico e aplicação da prova final não estão integrados; elegibilidade à final pode ser mostrada.

## Configuração e execução

Na pasta `uniconnect_flutter_base`:

```bash
flutter --version
flutter doctor
flutter pub get
flutter devices
```

Use base autorizada e contas fornecidas pelo operador, sem seeds/migrations para executar o app.

| Configuração de build | Comportamento |
| --- | --- |
| `API_BASE_URL` | Inclui `/api/v1`; padrão atual `https://api-uni.juancjc.com.br/api/v1` em todas as plataformas |
| `TENANT_SLUG` | Instituição inicial; padrão `edukmais`, sem conceder autorização |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY` | Projeto e chave pública do Realtime, correspondentes à API; nunca service_role. O código atual contém defaults públicos do TEST; para outra base, configurar ambos explicitamente |
| `DEMO_SYNTHETIC_DATA` | `false` por padrão; `true` habilita acervo demonstrativo em contexto suportado, sem comprovar persistência real |

Web local, com API na mesma máquina:

```bash
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3333/api/v1 --dart-define=TENANT_SLUG=edukmais
```

Android físico, com API pública autorizada (escolha o ID mostrado por `flutter devices`):

```bash
flutter run -d <ID_DO_DISPOSITIVO> --dart-define=API_BASE_URL=https://api-uni.juancjc.com.br/api/v1 --dart-define=TENANT_SLUG=edukmais
```

Substitua o marcador de dispositivo; não cole literalmente. No Android físico, `localhost` é o aparelho. No emulador, use `http://10.0.2.2:3333/api/v1` para a API do host. Para aparelho físico com API local, configure endereço alcançável e transporte permitido pelo Android; a URL HTTPS validada evita depender dessa configuração.

As variáveis `--dart-define` são incorporadas na compilação; alterar uma variável no servidor não recompila o app. CORS deve admitir a origem exata do Web. A configuração de API não habilita nem cria Storage, Realtime ou contas.

## Chat — Supabase Realtime privado

O app obtém descritor autorizado em `GET /tenants/:slug/conversations/:id/realtime`, autentica o canal com o JWT da sessão e assina `private: true`. Eventos `message.created` e `conversation.read` são sinais: histórico e comandos permanecem na API. A reconciliação HTTP existente, por sequência e periodicamente, recupera sinais perdidos; o texto não é enviado diretamente por Broadcast.

Configuração do projeto e chave pública precisam corresponder ao backend e às policies já autorizadas. A assinatura é removida no logout/perda de acesso; renovação atualiza o JWT do socket. Falha Realtime permite recuperação HTTP. Não confundir essa reconciliação do chat com notificações push FCM. [Contrato do backend](https://github.com/ykiakao/uniconnect-api/blob/main/docs/chat-realtime.md).

## Anexos acadêmicos

Professor: materiais de apoio e consulta de arquivos durante correção. Aluno: leitura de materiais e anexos por versão elegível. A API autoriza contexto e gera caminhos únicos; o app usa descritor assinado para transferir bytes diretamente ao Storage privado e só vincula arquivos `ready`.

PDF, DOCX, PNG e JPEG, até **10.000.000 bytes**, até **5 anexos** por atividade/versão. O servidor valida conteúdo real; documentos ativos/complexos podem ser recusados. Upload confirmado não equivale a submissão acadêmica. Não enviar Bearer UniConnect à URL do Storage nem registrar URL/token assinado.

Correções F1/F2 reconhecem `ready` e consultam estado após timeout, sem presumir cancelamento. Em `read_only` (F3), não há reenvio automático dos arquivos antigos: é possível confirmar conscientemente uma versão textual sem anexos; versões anteriores conservam seus arquivos. Provas presenciais e atividades legadas sem workflow não recebem anexos.

Disponibilidade depende de modo, migration/RPCs, bucket privado, limites e permissões no ambiente da API. Uma validação anterior em TEST não comprova a configuração atual de qualquer stack. [Contrato, estados e recuperação](https://github.com/ykiakao/uniconnect-api/blob/main/docs/academic-attachments-api.md).

## Firebase FCM Android e ícone

[google-services.json](android/app/google-services.json), [firebase_options.dart](lib/firebase_options.dart) e [firebase.json](firebase.json) são configurações cliente do Firebase `uniconnect-b9c75`, cadastrado para `br.com.uniconnect.app`. Não são credenciais Firebase Admin. Outro projeto exige configuração cliente correspondente e autorização própria; não colocar JSON de conta de serviço ou chave privilegiada no app.

A inicialização Firebase está condicionada ao Android; não há FCM Web/iOS nesta entrega. Em Android 13+, conceda a permissão de notificações no aparelho. O coordenador compartilhado Riverpod:

1. Obtém o token FCM compatível com Firebase Admin e registra após login/restauração.
2. Acompanha `onTokenRefresh`, evita registros repetidos e serializa registro/desvinculação.
3. Tenta desvincular antes do logout remoto; falhas de Firebase/rede não impedem logout.
4. Mantém isolamento de usuário/tenant e descarta navegação pendente após troca de contexto.

**Evento push implementado e validado: `activity_published`.** Em foreground há callback/log genérico de recebimento, sem novo banner local. Em background, o sistema mostra a notificação; o toque abre `/atividades/:id` após sessão/tenant válidos e nova consulta à API. Mensagem sem payload acadêmico apropriado não comprova navegação. Não há push de notas ou chat.

O backend guarda dispositivos em memória: reinício da API exige novo registro, sem fila durável. Desvinculação não recolhe notificações já entregues ou em trânsito. Rede indisponível pode impedir a desvinculação remota; não prometer supressão absoluta após logout.

Ícone fonte oficial: [assets/brand/uniconnect-icone-app.png](assets/brand/uniconnect-icone-app.png); launcher Android em cinco densidades, 48/72/96/144/192 px, sem distorção. Não foi adicionado gerador de ícones. Namespace e assinatura existentes foram preservados. O release atual usa a assinatura de desenvolvimento configurada no projeto; não é uma preparação de assinatura para loja.

## Testes e builds

```bash
flutter analyze
flutter test
flutter test test/auth_controller_test.dart
flutter test test/push_registration_coordinator_test.dart test/push_notification_navigation_test.dart test/push_notification_navigation_provider_test.dart
```

A suíte inclui serviços, widgets, autenticação, autorização de navegação, anexos e concorrência FCM com fakes. No SDK 3.50, o analyze completo apresenta **99 infos de depreciação Material**, sem erros/warnings; o comando padrão retorna 1. `flutter analyze --no-fatal-infos` retorna 0 mantendo os infos visíveis. Não equivale a uma análise completamente limpa.

Build APK release (PowerShell; crase no final da linha é continuação):

```powershell
flutter build apk --release `
  --dart-define=API_BASE_URL=https://api-uni.juancjc.com.br/api/v1 `
  --dart-define=TENANT_SLUG=edukmais
```

Saída: `build/app/outputs/flutter-apk/app-release.apk`. Instalação de atualização autorizada e com assinatura compatível: `adb install -r build/app/outputs/flutter-apk/app-release.apk`. Não desinstalar/limpar dados para contornar incompatibilidade de assinatura.

Build Web genérico:

```bash
flutter build web --release --dart-define=API_BASE_URL=https://api-uni.juancjc.com.br/api/v1 --dart-define=TENANT_SLUG=edukmais
```

Saída: `build/web`. Para GitHub Pages, acrescente `--base-href /uniconnect-clients/`; o [workflow](../.github/workflows/deploy-flutter-web.yml) usa `build/web-pages`, configura Realtime por repository variables públicas e gera fallback `404.html`. A publicação é manual, somente com `publish=true`. [Roteiro histórico](../docs/demo-day/github-pages-publication.md).

## Evidências e limitações da entrega

Em 13/11/2026: **480 testes Flutter aprovados**, APK release e Web compilados; build Web também aprovado no SDK 3.44 após resolução compatível em cópia temporária. No Samsung Android 16, o release preservou/restaurou a sessão do aluno, recebeu push em foreground/background e o operador confirmou a atividade correta por toque. O teste final usou Firebase diretamente e uma atividade existente; a integração acadêmica API → FCM já havia sido testada em TEST.

Não foram concluídos fisicamente: processo genuinamente encerrado, rotação real do token e supressão após logout. Login novo não foi repetido após instalar o release; a sessão autenticada anterior foi restaurada. Testes automatizados não comprovam esses cenários reais. A disponibilidade pública atual do Storage não foi reauditada nesta revisão documental.

A [Demo Day de 28/10](../docs/codex-kit/DEMO_DAY_2026-10-28.md) e demais documentos históricos permanecem como evidência da época, não como estado atual. Esta atualização não executou testes remotos, seeds, migrations ou deploy.
