# UniConnect Mobile

Aplicativo mobile-first do SaaS acadêmico UniConnect.

O app Flutter é a experiência principal para alunos e professores. Ele centraliza rotina acadêmica, atividades, notas, chat, perfil e contexto da instituição assinante. A API backend fica em `../api_backend` e será responsável por autenticação, multi-tenant, dados acadêmicos e assinaturas.

## Produto

UniConnect é uma plataforma acadêmica mobile-first para instituições de ensino. Cada instituição opera como um tenant com usuários, cursos, turmas, atividades, notas e configurações próprias.

## Tecnologias

- Flutter
- Dart
- GoRouter
- Riverpod
- Material Design 3

## Como rodar o app

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run
```

Para rodar no navegador como servidor web:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

## Como rodar com a API

Em outro terminal:

```bash
cd api_backend
npm install
copy .env.example .env
npm run dev
```

API local:

```txt
http://localhost:3333/api/v1
```

## Estrutura

```txt
lib/
  core/
    constants/
    router/
    theme/
  features/
    activities/
    auth/
    chat/
    grades/
    profile/
    student/
    teacher/
    tenant/
  shared/


## Login de teste

Use a senha `123456` com um dos e-mails abaixo:

- `aluno@uni.com`
- `professor@uni.com`

O tenant demo é `Universidade Norte`, com slug `universidade-norte`.

## Próximos passos do app

- Criar camada de cliente HTTP.
- Trocar `MockAuthService` por chamadas para a API.
- Persistir sessão local.
- Adicionar seleção/descoberta de instituição.
- Preparar build Android/iOS.
