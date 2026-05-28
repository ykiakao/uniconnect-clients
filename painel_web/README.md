# UniConnect Painel Web

Base reservada para o futuro painel administrativo web do UniConnect.

## Objetivo

O painel sera voltado para coordenadores, gestores academicos e administradores da instituicao.

## Responsabilidades Previstas

* Gerenciar instituicoes
* Gerenciar usuarios
* Cadastrar cursos
* Cadastrar turmas
* Associar professores, alunos e turmas
* Acompanhar relatorios academicos
* Configurar dados da instituicao
* Gerenciar assinatura e plano

## Tecnologias Sugeridas

* React ou Next.js
* TypeScript
* Tailwind CSS ou design system proprio
* TanStack Query
* React Hook Form
* Zod
* Integracao REST com o repositorio `uniconnect-api`

## Integracao com a API

Repositorio da API:

```text
uniconnect-api
```

URL local prevista:

```text
http://localhost:3333/api/v1
```

Header de tenant esperado:

```http
x-tenant-slug: universidade-norte
Accept: application/json
```

O painel deve consumir a API via HTTP. Ele nao deve importar codigo do backend por caminho local.
