# GitHub Pages — preparação da Demo Day

## Escopo aprovado e plano executável

### Continuação autorizada: commit e push da branch

O responsável autorizou revisar, commitar e enviar a Demo Day **somente** para
`demo-day-flutter-polish`, mantendo a `main` intacta. Não acionar `publish=true`.
Essa autorização substitui a parada antes de commit/push da preparação abaixo.

Plano desta continuação:

1. Conferir branch, arquivos sensíveis e backup; guardar o backup fora de `build/`.
2. Revisar a seleção completa e obter revisão independente; executar novamente
   os testes se houver ajuste necessário na seleção.
3. Criar o commit e enviar exclusivamente `HEAD:refs/heads/demo-day-flutter-polish`.
4. Acompanhar a validação no Actions, conferir o workflow remoto e parar antes
   de qualquer publicação manual.

Auditoria anterior ao commit:

- O backup publicado foi conferido arquivo a arquivo (40 SHA-256) e copiado para
  `uniconnect_flutter_base/.codex_tmp/demo-day-backup-20261028/`, ignorado pelo Git
  e preservado em caso de `flutter clean`.
- Foram encontradas tabelas antigas de credenciais em três README (raiz, Flutter
  e painel web). Elas foram substituídas por orientação de acesso em canal privado.
  Valores reutilizados em quatro arquivos de testes passaram a usar fixtures
  claramente fictícias. Nenhuma conta, senha no servidor ou implementação de
  autenticação foi alterada.
- Esses valores já constavam no histórico anterior; esta limpeza não reescreve
  histórico nem revoga acessos. A rotação das credenciais antigas deve ser avaliada
  pelo responsável fora desta etapa, sem reproduzi-las em logs ou documentação.
- `.env`, chaves, builds, backups e logs locais não fazem parte da seleção.
  O JSON acadêmico permanece inalterado e explicitamente sintético.
- Nova análise estática limpa e **121 testes aprovados em cada modo** após a
  limpeza. Revisão independente da seleção completa de 66 arquivos sem bloqueios.
- O workflow está registrado e ativo no GitHub (ID `354165779`). A consulta
  pública do ambiente `github-pages` mostrou políticas personalizadas com
  **somente `main`** permitida. Antes de publicar pela branch da demo, o responsável
  deve adicionar `demo-day-flutter-polish` em **Settings > Environments >
  github-pages > Deployment branches and tags**, preservando a regra de `main`.
  A configuração não foi alterada. A consulta pública de Pages retornou 404;
  confirmar **Source: GitHub Actions** na interface autenticada.

As evidências de commit, push e Actions serão informadas ao final desta
continuação; nenhum `workflow_dispatch` com `publish=true` será executado.

Preparar apenas a publicação do frontend sintético EduKMais na branch
`demo-day-flutter-polish`. Sem alterar aplicação, autenticação, dados, backend,
Supabase ou animações. Não executar commit, push, merge ou deploy nesta etapa.

1. Inspecionar workflow, configuração pública da API, base path e assets;
   registrar a versão anterior e preservar os builds locais.
2. Ajustar o workflow para validar e compilar a demonstração; exigir acionamento
   manual explícito para publicar e guardar artefatos de cada execução.
3. Executar análise, testes nos dois modos e build release isolado para Pages;
   conferir caminhos, JSON, rotas e integridade dos builds anteriores.
4. Realizar revisão independente e registrar evidências, passos de publicação,
   recuperação da versão anterior e limitações.

## Diagnóstico inicial

- O workflow local publica após push na `main`, usa Flutter stable sem versão
  fixada e não define `DEMO_SYNTHETIC_DATA=true`.
- O base path existente `/uniconnect-clients/` está correto. O template web usa
  `$FLUTTER_BASE_HREF`; não precisa de alteração.
- A `main` remota estava em `5a66943d73854a9eda5ae7225211a203886395f5`, com a
  última execução bem-sucedida observada
  [40253593660](https://github.com/ykiakao/uniconnect-clients/actions/runs/40253593660).
  Esse estado remoto não foi alterado.
- A configuração remota aponta para `https://api-uni.juancjc.com.br/api/v1`;
  a configuração local já usa `https://uniconnect-api-ht5x.onrender.com/api/v1`.
  Em 28/10/2026, o preflight de login do domínio personalizado respondeu HTTP 403
  (Cloudflare), sem autorização CORS. O endereço Render respondeu HTTP 204 e
  autorizou a origem `https://ykiakao.github.io`, POST e os cabeçalhos do login.
  A preparação mantém o endereço Render validado, sem mudar contratos da API.
- O preflight não valida credenciais nem comprova um login autenticado. Nenhuma
  senha, sessão ou token foi utilizado nas verificações remotas.
- Os diretórios locais `build/web`, `build/web-normal`, `build/web-synthetic` e
  `build/web-before-synthetic-20261028` tiveram hashes registrados antes da
  preparação. O novo build usará `build/web-pages`.

## Configuração preparada

Arquivo: `.github/workflows/deploy-flutter-web.yml`.

- Push em `main` ou `demo-day-flutter-polish`: somente análise, testes, build e
  upload de artefatos; não publica a aplicação.
- Execução manual: `publish` é booleano e começa em `false`. Apenas
  `workflow_dispatch` com `publish=true` permite o job `deploy`, após o sucesso
  do job `build`.
- Flutter **3.44.0 stable**, igual ao SDK validado localmente.
- `API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1`,
  `TENANT_SLUG=edukmais`, `DEMO_SYNTHETIC_DATA=true` e
  `--base-href /uniconnect-clients/`.
- Saída isolada: `uniconnect_flutter_base/build/web-pages`. `404.html` recebe
  uma cópia de `index.html`, preservando o fallback existente de rotas.
- O workflow verifica base path, fallback, recursos essenciais e cópia exata
  do JSON sintético com 10 atividades e 6 avaliações antes do upload.
- Artefato regular `demo-day-pages-<SHA>-<tentativa>`, retido por 30 dias, além
  do artefato `github-pages` consumido pelo deploy. Salvar uma cópia externa se
  precisar de retenção maior.
- `contents: read` na validação. `pages: write` e `id-token: write` somente no
  job de publicação, protegido pelo ambiente `github-pages`.
- As configurações compiladas são públicas: URL, slug e flag não são segredos.
  Nenhuma credencial foi adicionada; o token de publicação é o fornecido pelo
  GitHub Actions/OIDC. Não é necessário configurar senha da API no workflow.

Estas mudanças estão apenas na branch de trabalho. O workflow antigo da `main`
remota continua publicando automaticamente se alguém fizer push naquela branch.
Não fazer push ou merge na `main` como parte deste procedimento.

## Comandos locais de validação

Executar dentro de `uniconnect_flutter_base`:

```powershell
flutter pub get
flutter analyze
flutter test
flutter test --dart-define=DEMO_SYNTHETIC_DATA=true
flutter build web --release --output build/web-pages --base-href /uniconnect-clients/ --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais --dart-define=DEMO_SYNTHETIC_DATA=true
Copy-Item -LiteralPath build/web-pages/index.html -Destination build/web-pages/404.html
```

Os logs desta preparação ficam em `build/pages-preparation/` (ignorado pelo Git).
O ZIP anterior também fica nesse diretório; não usar `flutter clean` antes de
guardar a cópia fora de `build/`.

## Publicar — somente após autorização

1. Guardar `uniconnect_flutter_base/build/pages-preparation/published-before.zip`
   fora do diretório `build/`, junto com `published-before-sha256.json` e o SHA
   remoto anterior registrado acima. A cópia coletada contém 40 arquivos do site
   atual, incluindo `index.html`, fallback, JavaScript, fontes e renderizadores;
   o inventário de assets é idêntico ao build anterior conhecido. O ZIP foi
   verificado. Os três arquivos opcionais de `experimental_webparagraph` não
   existem no site atual e não foram incluídos.
2. Em **Settings > Pages > Build and deployment**, confirmar **Source: GitHub
   Actions**. Em **Settings > Environments > github-pages**, confirmar que as
   regras permitem publicar a branch `demo-day-flutter-polish`. Essas configurações
   administrativas não foram alteradas. A verificação posterior do ambiente
   confirmou apenas `main` permitida: adicionar a branch da demo antes de publicar,
   conforme a continuação autorizada acima.
3. Revisar todas as alterações acumuladas da demo com `git status --short` e
   `git diff --stat`. O commit precisa incluir também os arquivos Flutter,
   `pubspec.yaml`, assets JSON e testes da demo que já estavam modificados ou não
   rastreados; publicar apenas o YAML não leva esses refinamentos para o GitHub.
   Não incluir `.env`, credenciais ou diretórios de build.
4. Depois de autorização para commit e push, registrar os arquivos revisados em
   um commit na branch `demo-day-flutter-polish` e executar, da raiz deste repo:

   ```powershell
   git branch --show-current
   git add -- .github/workflows/deploy-flutter-web.yml README.md painel_web/README.md docs/codex-kit docs/demo-day uniconnect_flutter_base
   git diff --cached --stat
   git diff --cached --check
   git commit -m "Prepare UniConnect Demo Day synthetic Pages release"
   git push origin demo-day-flutter-polish
   ```

   A branch exibida deve ser `demo-day-flutter-polish`. Os diretórios no `git add`
   abrangem as mudanças acumuladas desta demo; revisar a seleção antes do commit,
   removendo do stage qualquer arquivo fora do escopo aprovado. Builds e `.env`
   permanecem ignorados. O push dispara somente
   validação no workflow novo; acompanhar **Actions > Deploy Flutter Web** e
   baixar o artefato regular. Não prosseguir se a validação falhar.
5. Depois de autorização para publicar, em **Actions > Deploy Flutter Web >
   Run workflow**, selecionar **demo-day-flutter-polish** e marcar **publish**.
   Se o novo campo ainda não aparecer na interface, usar GitHub CLI instalado e
   autenticado com permissão de escrita:

   ```powershell
   gh workflow run deploy-flutter-web.yml --repo ykiakao/uniconnect-clients --ref demo-day-flutter-polish -f publish=true
   gh run list --repo ykiakao/uniconnect-clients --workflow deploy-flutter-web.yml --branch demo-day-flutter-polish --limit 5
   gh run watch ID_DA_NOVA_EXECUCAO --repo ykiakao/uniconnect-clients
   ```

   Para uma execução manual que só valida, trocar por `-f publish=false`.
   O arquivo precisa existir na branch padrão para registrar `workflow_dispatch`;
   o workflow anterior já existe nela. O parâmetro `--ref` escolhe a versão da
   branch da demo, sem exigir merge na `main`.
6. Conferir os jobs `build` e `deploy`, o SHA executado e a URL exibida pelo deploy:
   <https://ykiakao.github.io/uniconnect-clients/>. Abrir em janela privada e fazer
   o smoke manual: login de aluno e professor com contas existentes; 10 atividades,
   6 avaliações e média atual 8,2 no aluno EduKMais; identificação de demonstração
   acessível no perfil; troca de abas, retorno, logout e recarregamento de rota.
   Não publicar credenciais nem registrar tokens em capturas ou logs.

O acionamento manual por branch e o uso de `--ref` seguem a
[documentação oficial do GitHub](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow).
As permissões e dependência entre build/deploy seguem a
[configuração oficial de Pages](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).

## Recuperação e limites operacionais

- Nenhuma publicação foi feita nesta etapa; a versão atual permanece no ar.
  Os quatro builds locais anteriores também devem permanecer byte a byte iguais.
- O run anterior `40253593660` não retornou artefatos disponíveis na consulta.
  Por isso foi guardada a cópia pública do site, sem depender da retenção antiga.
- Para retornar ao código anterior após uma publicação autorizada, abrir esse
  run e usar **Re-run all jobs**, somente com autorização de nova publicação.
  Isso recompila o SHA anterior e executa o workflow histórico (que já inclui
  deploy); não altera a `main`. É uma reconstrução, não restauração byte a byte:
  o SDK histórico era `stable` sem pin e sua API personalizada respondeu 403 no
  preflight atual. Validar esse endereço e o smoke antes de escolher esse caminho.
- Para restauração exata dos arquivos publicados anteriormente, conservar o ZIP
  e seus hashes. O workflow preparado aqui não tem uma ação automática de rollback
  nem consome ZIP local; a republicação desse pacote exige preparar e revisar uma
  execução de restauração, com autorização específica. Não substituir o pacote
  anterior nem forçar push para recuperar a versão.
- A execução hospedada do Actions, as regras do ambiente e um login real com
  credenciais não foram testados nesta etapa. O CORS do Render foi verificado,
  mas não garante disponibilidade futura nem validade das contas.
- GitHub Pages é hospedagem estática: o fallback conserva o comportamento
  existente; uma URL interna pode receber HTTP 404 antes de o Flutter carregar.
- Backend, Supabase, autenticação e dados acadêmicos não foram alterados. Não há
  migrations ou mudanças de configuração privada necessárias.

## Evidências e revisão

Verificado localmente em 28/10/2026:

| Verificação | Resultado |
| --- | --- |
| `flutter pub get` | Sucesso; sem alteração do lockfile |
| `flutter analyze` | Nenhum problema |
| `flutter test` | **121 aprovados** no modo normal |
| `flutter test --dart-define=DEMO_SYNTHETIC_DATA=true` | **121 aprovados** no modo sintético |
| Build web release com os defines e base path acima | Sucesso, **44 arquivos**, incluindo `404.html` |
| YAML do workflow | Parseado com o pacote YAML do SDK, sem adicionar dependências; gate manual, SDK, caminhos, flags e permissões conferidos |
| Verificação de artefato do próprio workflow | Executada localmente com sucesso |
| HTTP local com prefixo `/uniconnect-clients/` | **9 recursos retornaram 200**, incluindo bootstrap, JavaScript, manifest, JSON, índice, fallback e ícone |
| JSON empacotado | Idêntico ao asset e à base documentada; **10 atividades, 6 avaliações, 5 atuais e média 8,2** |
| Inventário Flutter | JSON presente em `AssetManifest.bin`; URL Render presente no JavaScript compilado |
| Preservação | Hashes de todos os arquivos dos **4 builds anteriores** idênticos aos registrados antes da preparação |
| Versão publicada anterior | Cópia local com **40 arquivos**, ZIP íntegro e inventário de assets conferido |
| Escopo desta rodada | Snapshot de 234 arquivos confirmou mudanças apenas no workflow, dois README e este roteiro; branch preservada e stage vazio |
| Configuração/segredos | Nenhuma nova credencial ou chave; configurações públicas, `.env` e build ignorados; checagem de padrões e `git diff --check` sem problemas |

Pacote preparado:
`uniconnect_flutter_base/build/uniconnect-pages-demo-day.zip` (14.754.395 bytes).
SHA-256:
`4e93c895f8650ad8300cfd0286968edddf174581f455e39f0eec2d4b3968898f`.
O ZIP contém os arquivos do site diretamente na raiz, sem pasta externa.
Não enviar builds ou backups ao Git; o workflow recria e guarda os artefatos.

O build emitiu apenas a mensagem informativa do dry run Wasm e de redução de
fontes. A saída release é JavaScript, sem troca de renderizador ou ajustes no app.
Um script auxiliar de leitura de YAML foi retirado da extensão `.dart` após a
primeira análise incluí-lo indevidamente; a análise final acima passou sem
supressões, alteração de dependências ou desativação de testes.

Revisão independente concluída por `demo_code_review`: **sem bloqueios ou ajustes
necessários** no workflow e no roteiro final. Conferidos gate manual, permissões,
isolamento do build, retenção de artefatos, branch selecionada, preservação e
limites da recuperação. Aprovação restrita à preparação local; nenhum deploy foi
executado pelo revisor.

Estado: **preparação local validada; publicação não executada**. Antes de publicar,
confirmar permissões/regras do GitHub, guardar o backup fora de `build/` e aprovar
commit, push e acionamento manual. O smoke autenticado em produção continua como
verificação obrigatória da publicação autorizada.
