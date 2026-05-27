# UniConnect

Plataforma acadêmica mobile-first estruturada como SaaS para instituições de ensino.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue)
![Node.js](https://img.shields.io/badge/Node.js-API-green)
![TypeScript](https://img.shields.io/badge/TypeScript-Backend-blue)
![SaaS](https://img.shields.io/badge/Architecture-SaaS-purple)

---

## Sobre o Projeto

O UniConnect centraliza a rotina acadêmica de alunos, professores e gestores em um ecossistema único composto por aplicativo mobile, API backend e futuro painel web administrativo.

A proposta é entregar uma plataforma contratada por assinatura, onde cada instituição opera como um tenant isolado, com seus próprios usuários, cursos, turmas, atividades, notas e configurações.

---

## Responsabilidades da Plataforma

* Disponibilizar um app mobile para alunos e professores
* Centralizar atividades, notas, chat e perfil acadêmico
* Suportar múltiplas instituições no modelo multi-tenant
* Expor uma API REST para autenticação e dados acadêmicos
* Preparar um painel web para gestão institucional
* Evoluir para assinatura por instituição, curso ou usuários ativos

---

## Tecnologias Utilizadas

| Camada | Tecnologias |
| ------ | ----------- |
| Mobile | Flutter, Dart, Riverpod, GoRouter, Material Design 3, Google Fonts, Intl |
| Backend | Node.js, TypeScript, Express, Zod, Helmet, CORS, Dotenv, TSX |
| Painel Web | React ou Next.js, TypeScript, Tailwind CSS, TanStack Query, React Hook Form, Zod |
| Arquitetura | Monorepo, REST API, multi-tenant, SaaS mobile-first |

---

## Estrutura do Repositório

| Serviço | Pasta | Descrição |
| ------- | ----- | --------- |
| App Mobile | `uniconnect_flutter_base/` | Aplicativo Flutter usado por alunos e professores |
| API Backend | `api_backend/` | Backend REST inicial do SaaS |
| Painel Web | `painel_web/` | Base reservada para o painel administrativo |

Principais pastas:

| Pasta | Finalidade |
| ----- | ---------- |
| `api_backend/src` | Código-fonte da API |
| `api_backend/src/modules` | Módulos de domínio da API |
| `uniconnect_flutter_base/lib/features` | Funcionalidades do app Flutter |
| `uniconnect_flutter_base/lib/core` | Rotas, tema e constantes do app |
| `painel_web` | Documentação e futuro scaffold do painel |

---

## Requisitos

Antes de executar o projeto, instale:

* Git
* Flutter
* Dart SDK
* Node.js
* npm

---

## Executando o App Mobile

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run
```

Para rodar no navegador como servidor web:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

---

## Executando a API

```bash
cd api_backend
npm install
copy .env.example .env
npm run dev
```

A API ficará disponível em:

```text
http://localhost:3333/api/v1
```

---

## Login de Teste

| Perfil | E-mail | Senha |
| ------ | ------ | ----- |
| Aluno | `aluno@uni.com` | `123456` |
| Professor | `professor@uni.com` | `123456` |

Tenant demo:

| Campo | Valor |
| ----- | ----- |
| Nome | Universidade Norte |
| Slug | `universidade-norte` |
| Plano | Growth |
| Status | Teste ativo |

---

## Rotas Iniciais da API

| Método | Endpoint | Descrição |
| ------ | -------- | --------- |
| GET | `/api/v1/health` | Verifica a disponibilidade da API |
| GET | `/api/v1/tenants/current` | Retorna o tenant atual |
| POST | `/api/v1/auth/login` | Realiza login mockado |
| GET | `/api/v1/auth/me` | Retorna usuário e tenant atuais |

---

## Fluxo Principal

1. O usuário acessa o app mobile.
2. O app autentica o usuário no tenant da instituição.
3. A API retorna usuário, perfil e contexto institucional.
4. O app direciona o usuário para o dashboard correto.
5. Alunos e professores consomem atividades, notas, chat e perfil.

---

## Roadmap Técnico

* Conectar o Flutter à API
* Persistir sessão local no app
* Adicionar PostgreSQL
* Implementar JWT e refresh token
* Criar cadastro de instituições, cursos, turmas e usuários
* Adicionar permissões por perfil
* Criar módulo de assinaturas
* Evoluir o painel web administrativo

---

## Arquivos da Entrega

Este repositório contém:

* `README.md`
* `.gitignore`
* `api_backend/`
* `painel_web/`
* `uniconnect_flutter_base/`

As pastas `node_modules/`, `build/`, `.dart_tool/` e arquivos `.env` locais não devem ser enviados para o GitHub.

---

## Contato

Projeto acadêmico em evolução para validação de uma plataforma SaaS mobile-first voltada à gestão e experiência acadêmica.
