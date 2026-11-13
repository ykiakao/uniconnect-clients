# UniConnect · Clientes

UniConnect é um SaaS acadêmico multi-instituição desenvolvido como TCC. Este repositório reúne o aplicativo de alunos e professores e o MVP de administração institucional. O backend Express fica no repositório separado `uniconnect-api`. Referência técnica atualizada em **04/11/2026**.

## Arquitetura e tecnologias

| Componente | Stack confirmada | Responsabilidade |
| --- | --- | --- |
| [Aplicativo Flutter](uniconnect_flutter_base/README.md) | Flutter 3.44.0 no workflow, Dart, Riverpod, GoRouter e `package:http` | Navegação, sessão e jornadas acadêmicas de aluno e professor |
| [Painel administrativo](painel_web/README.md) | React, TypeScript, Vite e shadcn/ui | Login institucional, restauração de sessão e gestão de usuários |
| API e dados | REST JSON em `/api/v1`, Express, Supabase Auth (GoTrue) e PostgreSQL | Autorizar o acesso e persistir os registros acadêmicos |

Os clientes acessam a API por HTTP. O cabeçalho `x-tenant-slug` identifica a instituição e `Authorization: Bearer …` acompanha as chamadas protegidas. A API valida a sessão, o papel e o vínculo institucional e acadêmico. Configurar o slug no cliente não concede acesso a uma oferta.

```text
uniconnect_flutter_base/  App Flutter, testes e assets
painel_web/              Painel administrativo em React com shadcn/ui
docs/                    Planejamento, referências e evidências de demonstração
.github/workflows/       Validação e publicação do Flutter Web
```

## Funcionalidades por perfil

- **Aluno** — Início com agenda e prévia de pendências, Atividades com pesquisa, filtros e entrega textual versionada, Notas com boletim N1/N2 por oferta e Acadêmico com os dados institucionais fornecidos na sessão. A nota individual e a devolutiva publicadas aparecem no detalhe da atividade. O Perfil tem entrada independente.
- **Professor** — Início com resumo da oferta, Atividades com rascunho, publicação, encerramento, entregas e correção, e Notas com provas presenciais N1/N2, boletim e fechamento de etapa. A seleção da oferta por `classId` é compartilhada e validada. O formulário legado também permite cadastrar provas.
- **Administração institucional** — O painel chama `POST /auth/admin/login` e `GET /auth/admin/me` para autenticar e restaurar a sessão. URL da API e slug são configuráveis no formulário. Usuários, convites, estrutura acadêmica, matrículas, avisos e relatórios estão integrados à API. A administração global da plataforma fica em `/plataforma` e exige uma conta em `PLATFORM_ADMIN_AUTH_USER_IDS`.

O Chat do aluno é demonstrativo e o destino docente informa indisponibilidade. Horários e calendário acadêmico ainda não têm integração no Flutter. A elegibilidade à prova final pode vir no boletim, mas a aplicação da prova final está fora do fluxo disponível.

## Executar e testar

Para o Flutter, use o SDK do workflow como referência e tenha um dispositivo ou navegador configurado. Inicie a API local antes do login e use o slug do ambiente. Se o harness imprimir uma porta dinâmica, substitua `3333` pela porta exibida.

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=http://127.0.0.1:3333/api/v1 --dart-define=TENANT_SLUG=uniconnect-local
flutter analyze --no-pub
flutter test --no-pub
```

Para o painel, em outro terminal, use Node.js 22. Abra o endereço exibido pelo Vite e informe o slug e uma conta com papel administrativo no ambiente escolhido. A URL da API fica em Configuração avançada ou na variável `VITE_API_BASE_URL`.

```bash
cd painel_web
npm install
npm run dev
npm test
```

Os testes Flutter cobrem serviços e widgets com respostas controladas. Os testes do painel simulam HTTP e armazenamento. Na validação local com serviços reais, o Flutter Web comprovou login, seleção de oferta, criação e publicação do trabalho, consulta pelo aluno, envio, reenvio e abertura da mesma entrega pelo professor. A conclusão do ciclo de devolutiva e o login administrativo real do painel não estão comprovados na evidência consultada. O ensaio local não qualifica homologação ou produção.

A [demonstração Flutter Web no GitHub Pages](https://ykiakao.github.io/uniconnect-clients/) tem um [roteiro de publicação, validação e recuperação](docs/demo-day/github-pages-publication.md). O workflow está configurado para um build demonstrativo e referencia uma URL de API própria. A configuração por si só não confirma a disponibilidade pública atual.

## Colaboração no redesign

- Trabalhe em branch própria, a partir do handoff `handoff/flutter-2026-11-04`. Preserve os contratos HTTP, os providers, as regras acadêmicas e os controles de acesso.
- Preserve as cinco áreas do aluno, as quatro do professor e o Perfil no cabeçalho. Use os componentes compartilhados e mantenha claros os estados de carregamento, vazio, erro e sucesso.
- A direção visual aprovada para o redesign usa Inter, azul `#60A5FA`, superfície `#E2E8F0`, texto e fundo escuro `#0F172A` e ícones lineares arredondados. Essa é a referência de design. O Flutter atual usa seus próprios tokens e Inter local.
- Alinhe qualquer mudança de backend ou banco antes de implementá-la. Use somente credenciais autorizadas para o ambiente de teste e mantenha segredos fora do Git.
