# UniConnect · Clientes

Aplicativo acadêmico Flutter para alunos e professores e painel React para administração institucional. TCC UniConnect — documentação revisada em **13/11/2026** sobre a entrega Android/FCM `d4d8e3d`.

## Arquitetura

| Componente | Tecnologias e responsabilidade |
| --- | --- |
| [Flutter](uniconnect_flutter_base/README.md) | Android e Web; Riverpod, GoRouter e HTTP; sessão e jornadas acadêmicas |
| [Painel administrativo](painel_web/README.md) | React, TypeScript, Vite e shadcn/ui; gestão institucional e plataforma |
| [API em repositório separado](https://github.com/ykiakao/uniconnect-api) | Node.js 22, Express/TypeScript; autenticação, autorização e operações transacionais |
| Supabase Auth e PostgreSQL | Identidade e persistência acadêmica, sob autorização da API |
| Supabase Realtime e Storage | Broadcast privado do chat; arquivos privados com upload/download assinados |
| Firebase FCM | Push Android de **atividade publicada**, independente do chat e das notificações internas |

Os clientes usam `Authorization: Bearer …` e `x-tenant-slug`. O slug identifica contexto; a API confere identidade, papel, matrícula/vínculo e pertencimento ao recurso. Apenas sinais de chat e transferência assinada de arquivos usam transporte direto ao Supabase; o cliente não administra tabelas ou buckets.

## Funcionalidades por perfil

| Perfil | Disponível no código atual |
| --- | --- |
| Aluno | Início, atividades, resposta textual e anexos por versão elegível, histórico, nota/devolutiva publicadas, boletim N1/N2, avisos, notificações internas, chat e perfil acadêmico |
| Professor | Seleção de oferta, rascunhos/materiais, publicação/encerramento de atividades, consulta de entregas e arquivos, correção e publicação de nota, provas presenciais N1/N2, boletim/fechamento, avisos e chat |
| Administração institucional | Usuários, convites, cursos, turmas, períodos, disciplinas, ofertas, matrículas, vínculos docentes, avisos, relatórios e configurações, conforme autorização |
| Administração global | Área `/plataforma`, sessão própria e autorização global mantida no servidor |

Anexos dependem do modo e do Storage configurados no backend. Provas presenciais e atividades legadas sem workflow não recebem anexos. Horários/calendário acadêmico e aplicação da prova final permanecem fora do fluxo Flutter integrado; elegibilidade à final pode aparecer no boletim.

## Preparar um ambiente autorizado

1. Obter acesso a uma base já preparada e contas do ambiente autorizado com o operador, em canal privado.
2. Seguir o [README da API](https://github.com/ykiakao/uniconnect-api) para Node.js 22, `npm ci` e configuração privada do `.env`.
3. Iniciar a API antes dos clientes. Não executar seeds, migrations ou criação de buckets apenas para avaliar esta documentação.
4. Configurar a mesma API e instituição nos clientes. A entrega usou tenant `edukmais` e Supabase TEST `pvacwfypqsstdrfxajkg`; a API pública não significa Supabase de produção.

API pública da entrega: `https://api-uni.juancjc.com.br/api/v1`. Tanto Flutter quanto painel usam essa URL por padrão; **para desenvolvimento local, informe o override explicitamente**.

### Flutter

APK validado com Flutter **3.50.0 / Dart 3.14.0**, Android SDK 36 e JDK 17. Workflow Web fixa Flutter **3.44.0 / Dart 3.12.0**; a resolução compatível e o build Web também foram verificados nesse SDK em cópia temporária. Veja os detalhes do lock e do Android no [README Flutter](uniconnect_flutter_base/README.md).

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_BASE_URL=http://localhost:3333/api/v1 --dart-define=TENANT_SLUG=edukmais
flutter analyze
flutter test
```

Em aparelho físico, `localhost` aponta para o próprio aparelho. Use uma URL HTTPS alcançável, como a API autorizada da entrega; no emulador Android, o host local normalmente é `10.0.2.2`. O backend deve admitir a origem exata do navegador; o fallback de portas locais só existe fora de `production`.

### Painel React

Use Node.js 22 e npm. A configuração Vite é incorporada no build.

```bash
cd painel_web
npm ci
```

Crie um `.env.local` privado com `VITE_API_BASE_URL=http://localhost:3333/api/v1` e `VITE_DEFAULT_TENANT=edukmais`, depois:

```bash
npm run dev
npm test
npm run lint
npm run typecheck
npm run build
```

A API não é escolhida no formulário do painel; o endereço vem da configuração de build. Consulte [execução, sessão e Vercel](painel_web/README.md).

## Integrações e limites

- **Chat:** HTTP persiste mensagens/recibos; Broadcast privado sinaliza mudanças. A reconciliação HTTP existente recupera perdas de sinais; não é substituto de push FCM.
- **Anexos:** PDF, DOCX, PNG e JPEG, até 10.000.000 bytes e cinco anexos por atividade/versão. A API valida bytes, gera caminhos únicos e autoriza URLs temporárias. Não compartilhar ou registrar URLs assinadas. Em `read_only`, o aluno pode confirmar uma nova versão textual sem reenviar arquivos antigos; o histórico é preservado. Configuração ausente/indisponível pode retornar `ATTACHMENT_STORAGE_UNAVAILABLE`; código integrado não garante Storage operacional em qualquer stack.
- **FCM Android:** login/restauração registram dispositivo; o coordenador serializa registro, token refresh e desvinculação antes do logout. Falhas de rede não bloqueiam logout. O toque em `activity_published` abre a atividade após validar sessão/tenant. Não há push de notas ou chat nesta entrega.
- **Backend FCM:** cadastro de tokens em memória, uma instância/processo; reinício exige novo registro do cliente. Sem fila durável, garantia de entrega ou revogação de notificações já em trânsito.
- **Painel:** a revalidação da sessão não rotaciona automaticamente o refresh token; sessão expirada pode exigir novo login. Logout institucional atual é local.
- **Credenciais:** nunca incluir service_role, senhas ou Firebase Admin JSON nos clientes. Configuração Firebase Android versionada é de cliente, não credencial administrativa.

## Build, publicação e evidências de 13/11/2026

[Instruções completas de APK e Web](uniconnect_flutter_base/README.md). O ícone oficial vem de `assets/brand/uniconnect-icone-app.png`; applicationId Android `br.com.uniconnect.app`.

- **Automatizado/local:** 480 testes Flutter aprovados; analyze no SDK 3.50 com zero erros/warnings e 99 infos de depreciação Material. O comando padrão retorna código 1 por esses infos; `--no-fatal-infos` retorna 0 sem ocultá-los. APK release e Web aprovados; Web também compilado no SDK 3.44 após resolução compatível.
- **Dispositivo real:** Samsung Android 16 recebeu push em foreground/background; no APK release, o operador confirmou abertura da atividade correta pelo toque. Login foi realizado antes da atualização e a sessão foi preservada/restaurada no APK final.
- **Integração real:** publicação acadêmica API → FCM → Samsung foi validada anteriormente em TEST. O teste final Firebase → APK reutilizou uma atividade existente sem novas escritas acadêmicas. Anexos também tiveram testes sintéticos reais anteriores em TEST; não foi feita nova auditoria de disponibilidade remota nesta revisão.
- **Não concluído fisicamente:** processo genuinamente encerrado, rotação real do token e supressão após logout. Testes com fakes não substituem esses cenários.

[Flutter Web publicado](https://ykiakao.github.io/uniconnect-clients/). O [workflow](.github/workflows/deploy-flutter-web.yml) é manual: `workflow_dispatch` valida e compila; somente `publish=true` libera o job Pages. Um push de documentação não dispara esse workflow. O [roteiro histórico de Pages](docs/demo-day/github-pages-publication.md) conserva evidências antigas; a configuração atual deve ser conferida no workflow.

Vercel usa Root Directory `painel_web`, build `npm run build`, saída `dist` e o [fallback SPA](painel_web/vercel.json), inclusive para links diretos de convites.

## Colaboração e histórico

Preserve contratos HTTP, providers, regras acadêmicas e controles de acesso. Trabalhe em branch própria a partir da referência acordada com o desenvolvedor; não sobrescreva commits da `main` ou do handoff `handoff/flutter-2026-11-04`.

Preserve as cinco áreas do aluno, as quatro do professor e o Perfil no cabeçalho. A referência visual aprovada usa Inter, azul `#60A5FA`, superfície `#E2E8F0`, texto/fundo escuro `#0F172A` e ícones lineares arredondados; o Flutter usa tokens próprios e Inter local. Mudanças de backend, schema e infraestrutura exigem escopo e autorização específicos.

O diretório [docs/](docs/) conserva planejamento e evidências históricas; números e limitações de cada relatório correspondem à sua data. Esta atualização foi exclusivamente documental, sem reinstalação de dependências, novo ensaio remoto ou deploy manual.
