# UniConnect

UniConnect é uma plataforma acadêmica mobile-first pensada para operar como SaaS para instituições de ensino.

O produto centraliza a rotina de alunos e professores em um app mobile, com atividades, notas, chat, perfil acadêmico e contexto da instituição assinante. A arquitetura está sendo evoluída para suportar multi-tenant, autenticação real, dados persistentes e assinatura por instituição.

## Visão do Produto

O UniConnect não é apenas um aplicativo instalado uma vez. Ele é uma plataforma em evolução contínua, contratada por assinatura, com suporte para múltiplas instituições, usuários e fluxos acadêmicos.

## Estrutura do Projeto

```txt
uniconnect-app/
  api_backend/
    API backend do SaaS
  painel_web/
    Espaço reservado para painel administrativo web
  uniconnect_flutter_base/
    App Flutter mobile-first
```

## Aplicações

### Mobile App

Local: `uniconnect_flutter_base/`

App Flutter usado por alunos e professores. Hoje contém a experiência principal do MVP: login, dashboard, atividades, notas, chat, perfil e contexto da instituição.

Principais tecnologias:

- Flutter
- Dart
- Riverpod
- GoRouter
- Material Design 3

Como rodar:

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run
```

### API Backend

Local: `api_backend/`

API inicial em Node.js e TypeScript. Ela já nasce com rotas versionadas, healthcheck, autenticação mockada e contexto de tenant por header.

Principais tecnologias:

- Node.js
- TypeScript
- Express
- Zod
- Helmet
- CORS

Como rodar:

```bash
cd api_backend
npm install
copy .env.example .env
npm run dev
```

URL local:

```txt
http://localhost:3333/api/v1
```

### Painel Web

Local: `painel_web/`

Espaço reservado para o painel administrativo da instituição. A ideia é concentrar fluxos de gestão, como usuários, cursos, turmas, relatórios, assinaturas e configurações.

## Login de Teste

No app e na API mockada:

- `aluno@uni.com`
- `professor@uni.com`
- Senha: `123456`

Tenant demo:

```txt
Universidade Norte
slug: universidade-norte
```

## Roadmap Técnico

- Conectar o Flutter à API.
- Persistir sessão local no app.
- Adicionar banco PostgreSQL.
- Implementar JWT e refresh token.
- Criar cadastro de instituições, cursos, turmas e usuários.
- Adicionar permissões por perfil.
- Criar módulo de assinaturas.
- Evoluir o painel web administrativo.

## Modelo SaaS

Cada instituição será tratada como um tenant isolado, com seus próprios usuários, dados acadêmicos e configurações. O modelo comercial pode evoluir para planos por instituição, por curso ou por quantidade de usuários ativos.
