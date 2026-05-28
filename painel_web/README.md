# UniConnect Painel Web

Painel administrativo web do SaaS acadêmico UniConnect.

## Sobre o Projeto

Este diretório contém a primeira versão do painel administrativo do UniConnect.

Enquanto o app mobile atende o uso diário de alunos e professores, o painel web é voltado para coordenadores, gestores acadêmicos e administradores da instituição.

O MVP atual usa HTML, CSS e JavaScript sem dependências de build. Ele já consome a API `uniconnect-api` para login administrativo real, restauração de sessão protegida e contexto do tenant.

## Responsabilidades do Painel

* Autenticar usuários administrativos via API UniConnect
* Exibir contexto da instituição atual
* Mostrar indicadores administrativos iniciais
* Preparar navegação para usuários, cursos, turmas, relatórios e assinatura
* Consumir a API `uniconnect-api` via HTTP

## Tecnologias Utilizadas no MVP

* HTML
* CSS responsivo
* JavaScript
* Fetch API
* Local/session storage

Stack recomendada para evolução:

* React ou Next.js
* TypeScript
* Tailwind CSS ou design system próprio
* TanStack Query
* React Hook Form
* Zod

## Estrutura do Repositório

| Arquivo | Finalidade |
| ----- | ---------- |
| `index.html` | Entrada do painel |
| `styles.css` | Layout, tema e responsividade |
| `app.js` | Login, sessão, navegação e integração REST |
| `server.mjs` | Servidor estático local sem dependências |

## Executando

Suba a API em outro terminal:

```bash
cd ../uniconnect-api
npm run dev
```

Sirva o painel na origem liberada pelo CORS da API:

```bash
cd painel_web
node server.mjs
```

Acesse:

```text
http://127.0.0.1:8080
```

## Integração com a API

O painel consome a API em:

```text
http://localhost:3333/api/v1
```

Header de tenant esperado:

```http
x-tenant-slug: universidade-norte
Accept: application/json
```

O painel consome a API via HTTP. Ele não importa código do backend por caminho local.

## Fluxo Principal

1. O administrador acessa o painel web.
2. O painel autentica o usuário via `POST /auth/admin/login`.
3. O tenant da instituição é carregado pela resposta da API.
4. A sessão é restaurada com `GET /auth/admin/me`.
5. Os módulos administrativos ficam preparados para endpoints futuros.

## Acesso Administrativo

O painel web não deve aceitar alunos ou professores. A API libera o acesso somente para usuários vinculados ao tenant com um destes perfis:

* `admin`
* `coordinator`
* `owner`

Usuários esperados no seed, depois de criados no Supabase Auth:

| Perfil | E-mail | Senha |
| ------ | ------ | ----- |
| Coordenador | `coordenador@uni.com` | `123456` |
| Mantenedor | `dono@uni.com` | `123456` |

## Roadmap do Painel

* Criar endpoints administrativos de usuários
* Adicionar telas de cursos e turmas
* Adicionar relatórios acadêmicos
* Adicionar gestão de assinatura
* Evoluir para React/Next.js se o painel crescer

## Arquivos da Entrega

Atualmente esta pasta contém:

* `README.md`
* `index.html`
* `styles.css`
* `app.js`
* `server.mjs`
