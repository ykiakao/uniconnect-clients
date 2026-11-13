# UniConnect · Painel administrativo React

Painel para coordenação, gestão acadêmica e administração institucional; alunos e professores usam o Flutter. Documentação revisada em **13/11/2026**. [Visão geral dos clientes](../README.md) e [API](https://github.com/ykiakao/uniconnect-api).

## Tecnologias, estrutura e capacidades

React 19, TypeScript, Vite 8, Tailwind CSS, shadcn/ui/Radix, TanStack Query, React Hook Form e React Router. Vitest e Testing Library nos testes; oxlint no lint.

| Caminho | Finalidade |
| --- | --- |
| `src/components/ui`, `layout`, `resource` | Componentes, menu, formulários e listas responsivas |
| `src/features/auth` | Login, restauração, recuperação, ativação e sessão institucional |
| `src/features/users`, `academic` | Usuários, cursos, turmas, períodos, disciplinas, ofertas, matrículas e vínculos |
| `src/features/invites`, `notices`, `reports`, `institution` | Convites, avisos, relatórios e configurações institucionais |
| `src/features/platform` | Administração global em `/plataforma`, login e sessão próprios |
| `src/features/dashboard`, `src/lib` | Visão geral, cliente HTTP e formatação |

Cores e componentes ficam em `src/index.css`; fonte Inter, logos em `public/brand`. A tabela responsiva vira cartões abaixo de 1024 px. Nenhuma mudança visual faz parte desta atualização.

O painel integra a API real e respeita permissões por recurso. Não oferece administração direta de Supabase, Storage ou Firebase e não é o cliente de notificações Android.

## Pré-requisitos e instalação

Use **Node.js 22 e npm**; mantenha o lockfile. A API precisa estar ativa e a base autorizada já preparada. Não executar seeds/migrations para iniciar o painel.

Na pasta `painel_web`:

```bash
npm ci
```

Crie um `.env.local` privado, sem sobrescrever configuração existente:

```dotenv
VITE_API_BASE_URL=http://localhost:3333/api/v1
VITE_DEFAULT_TENANT=edukmais
```

| Variável | Padrão real no código | Uso |
| --- | --- | --- |
| `VITE_API_BASE_URL` | `https://api-uni.juancjc.com.br/api/v1` | Base fixa da API, incluindo `/api/v1` |
| `VITE_DEFAULT_TENANT` | `universidade-norte` | Slug inicialmente sugerido no login; usar `edukmais` para o cenário TEST da entrega |

As variáveis Vite são públicas e incorporadas no build: nunca usar senhas, JWTs, service_role ou Firebase Admin JSON. Alterar uma variável na Vercel exige novo build para mudar o frontend. O endereço da API é fixado em configuração, não escolhido no formulário; o slug ainda precisa corresponder ao vínculo autorizado.

Para API local, use outro terminal **na raiz do repositório uniconnect-api**, seguindo seu README:

```bash
npm run dev
```

Depois, na pasta do painel:

```bash
npm run dev
```

Abra a URL impressa pelo Vite (normalmente porta 5173). A allowlist CORS da API deve conter a origem usada. Se apontar para a API pública, confirme com o operador o projeto Supabase efetivo antes de autenticar; o ambiente da entrega foi TEST, sem autorização para modificar produção.

## Comandos verificados no package.json

| Comando | Script real / finalidade |
| --- | --- |
| `npm run dev` | `vite`: servidor de desenvolvimento |
| `npm test` | `vitest run`: testes automatizados com respostas/armazenamento controlados |
| `npm run lint` | `oxlint` |
| `npm run typecheck` | `tsc -b --noEmit` |
| `npm run build` | `tsc -b && vite build`: produção em `dist/` |
| `npm run preview` | `vite preview`: serve o build local |

Esses comandos foram conferidos nos scripts reais. Não foram reinstaladas dependências nem reexecutadas as suítes nesta atualização exclusivamente documental; não interpretar a lista como novo resultado de testes.

## Autenticação, permissões e limites de sessão

1. Login institucional: `POST /api/v1/auth/admin/login`, com e-mail/senha e `x-tenant-slug`.
2. Restauração/revalidação: `GET /api/v1/auth/admin/me`, com Bearer e tenant.
3. Recursos institucionais usam `/api/v1/tenants/:slug`; o servidor valida papel e vínculo.
4. Contas admitidas incluem os papéis administrativos `admin`, `gestor`, `coordinator` e `owner`, conforme representação da API. Alunos/professores não ganham acesso administrativo.

A opção lembrar usa `localStorage`; caso contrário, `sessionStorage`. Não compartilhar o perfil do navegador nem capturar tokens em logs. A área global possui sessão própria e exige autorização global configurada no backend.

**Limitação atual:** o método `refresh()` do painel reconsulta `/auth/admin/me`; ele **não** chama `/auth/admin/refresh` nem rotaciona o par de tokens. Embora a resposta de login possa incluir refresh token/expiração, não há renovação automática completa nesta UI. Após expiração, pode ser necessário entrar novamente. Em falha temporária durante sessão ativa, o estado pode ser preservado; respostas de sessão inválida/sem vínculo podem removê-lo. `useApi` revalida ao receber 401, mas não repete automaticamente a operação original após rotação.

O logout institucional atual limpa sessão e cache locais; não chama logout remoto. Não afirmar revogação de JWT por essa ação. Senhas de contas de avaliação são fornecidas pelo operador em canal privado; nenhuma credencial deve ser documentada.

## Implantação Vercel e convites

Configuração do projeto da entrega:

- **Root Directory: `painel_web`**.
- Install Command: `npm ci`.
- Build Command: `npm run build`.
- Output Directory: `dist`.
- Definir `VITE_API_BASE_URL` e `VITE_DEFAULT_TENANT` no ambiente de build apropriado.
- Preservar [vercel.json](vercel.json), que reescreve rotas para `/index.html`; isso permite abrir/recarregar rotas SPA como `/convites/:token`.

Domínio de referência: [painel-admin-uc.vercel.app](https://painel-admin-uc.vercel.app). O token do convite é uma capacidade sensível: enviar apenas pelo canal privado do destinatário, sem URLs reais de convite no README, screenshots públicas ou analytics.

Um 404 da Vercel ao abrir uma rota profunda exige conferir projeto, Root Directory, revisão e presença do fallback no build implantado; não demonstra sozinho falha do endpoint de convites. Rewrites não substituem validação de validade, papel e tenant feita pela API.

Para avaliação, testar login autorizado, consulta institucional, convite sintético aprovado, abertura direta/reload da rota e expiração de sessão. Operações que criam usuários/convites/matrículas exigem autorização da base escolhida. Esta revisão não executou implantação ou mudanças na Vercel.
