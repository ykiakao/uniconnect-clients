# UniConnect Painel Web

Painel administrativo web do SaaS acadêmico UniConnect, voltado para coordenadores, gestores acadêmicos e administradores da instituição. O app Flutter atende alunos e professores.

## Stack

* React, TypeScript e Vite
* Tailwind CSS e [shadcn/ui](https://ui.shadcn.com) (Radix, estilo Vega)
* TanStack Query, React Hook Form e React Router
* Vitest e Testing Library

A identidade UniConnect fica em `src/index.css`: as cores do design kit são aplicadas às variáveis do shadcn/ui, com a fonte Inter. Espaçamentos e raios seguem o padrão do shadcn/ui. Os logos ficam em `public/brand`.

## Estrutura

| Caminho | Finalidade |
| ----- | ---------- |
| `src/components/ui` | Componentes do shadcn/ui |
| `src/components/layout` | Menu lateral, topo e rotas de navegação |
| `src/components/data-table.tsx` | Tabela responsiva: vira cartões abaixo de 1024 px |
| `src/components/resource` | Base das telas de cadastro (lista, filtros, formulário, exclusão) |
| `src/features/auth` | Login, sessão, recuperação de senha, ativação e convites |
| `src/features/users` | Gestão de usuários |
| `src/features/academic` | Cursos, turmas, períodos, disciplinas, ofertas, matrículas, vínculos e atividades |
| `src/features/invites`, `notices`, `reports`, `institution` | Convites, avisos, relatórios, assinatura e configurações |
| `src/features/platform` | Administração global em `/plataforma`, com login e sessão próprios |
| `src/features/dashboard` | Visão geral da instituição |
| `src/lib` | Cliente da API e formatadores |

## Executando

Suba a API em outro terminal:

```bash
cd ../uniconnect-api
npm run dev
```

Inicie o painel:

```bash
cd painel_web
npm install
npm run dev
```

| Variável | Padrão | Finalidade |
| ----- | ---------- | ---------- |
| `VITE_API_BASE_URL` | `http://localhost:3333/api/v1` | Endereço da API |
| `VITE_DEFAULT_TENANT` | `universidade-norte` | Instituição sugerida no login |

## Comandos

| Comando | Finalidade |
| ----- | ---------- |
| `npm run dev` | Desenvolvimento |
| `npm test` | Testes |
| `npm run typecheck` | Verificação de tipos |
| `npm run build` | Build de produção em `dist/` |
| `npm run preview` | Serve o build localmente |

## Integração com a API

O painel consome a API via HTTP e envia o header `x-tenant-slug` em todas as chamadas. Ele não importa código do backend por caminho local.

1. O administrador entra com `POST /auth/admin/login`.
2. A sessão é restaurada com `GET /auth/admin/me`.
3. As telas usam as rotas de `/tenants/:slug`.

## Acesso administrativo

O painel não aceita alunos ou professores. A API libera o acesso somente para usuários vinculados ao tenant com os perfis `admin`, `coordinator` ou `owner`.

Contas de apresentação são fornecidas pelo responsável em canal privado. Não registrar credenciais de acesso neste repositório.
