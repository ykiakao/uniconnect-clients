# UniConnect Clients

Clientes do UniConnect organizados em um repositório próprio para app Flutter mobile-first e futuro painel web administrativo.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue)
![Dart](https://img.shields.io/badge/Dart-App-blue)
![Web](https://img.shields.io/badge/Web-Admin-61DAFB)
![REST](https://img.shields.io/badge/API-REST-green)
![SaaS](https://img.shields.io/badge/Architecture-SaaS-purple)

---

## Sobre o Projeto

O UniConnect Clients reúne as interfaces usadas por alunos, professores e, futuramente, gestores acadêmicos.

Este repositório mantém o aplicativo Flutter e a base reservada para o painel web. A API backend foi separada no repositório `uniconnect-api`, reforçando que os clientes devem consumir dados apenas via HTTP.

---

## Responsabilidades dos Clientes

* Disponibilizar o app mobile para alunos e professores
* Autenticar usuários consumindo a API UniConnect
* Exibir dashboards por perfil
* Centralizar atividades, notas, chat e perfil acadêmico no app
* Preparar o painel web para gestão institucional
* Manter a URL da API configurável por ambiente
* Evitar dependência direta de código backend local

---

## Tecnologias Utilizadas

| Camada | Tecnologias |
| ------ | ----------- |
| Mobile | Flutter, Dart, Riverpod, GoRouter, Material Design 3, Google Fonts, Intl |
| Rede | HTTP, API REST |
| Sessão | Flutter Secure Storage |
| Painel Web | React ou Next.js, TypeScript, Tailwind CSS, TanStack Query, React Hook Form, Zod |
| Arquitetura | Clientes desacoplados, REST API, SaaS mobile-first |

---

## Estrutura do Repositório

| Serviço | Pasta | Descrição |
| ------- | ----- | --------- |
| App Mobile | `uniconnect_flutter_base/` | Aplicativo Flutter usado por alunos e professores |
| Painel Web | `painel_web/` | Base reservada para o painel administrativo |

Principais pastas:

| Pasta | Finalidade |
| ----- | ---------- |
| `uniconnect_flutter_base/lib/core` | Rotas, tema, rede e configuração da API |
| `uniconnect_flutter_base/lib/features` | Funcionalidades do app Flutter |
| `uniconnect_flutter_base/lib/shared` | Componentes compartilhados |
| `uniconnect_flutter_base/test` | Testes do app Flutter |
| `painel_web` | Documentação e futuro scaffold do painel |

---

## Requisitos

Antes de executar o projeto, instale:

* Git
* Flutter
* Dart SDK
* Android Studio ou emulador configurado
* API `uniconnect-api` em execução para login real

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

## Configurando a API

A URL da API fica centralizada em:

```text
uniconnect_flutter_base/lib/core/config/api_config.dart
```

URL local padrão:

```text
http://localhost:3333/api/v1
```

Para rodar apontando para outra API:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3333/api/v1
```

Para rodar apontando para a API publicada no Render e para o tenant EduKMais:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais
```

---

## Deploy Web para Apresentacao

O app Flutter Web e publicado pelo GitHub Actions em GitHub Pages.

No GitHub, configure o repositorio em **Settings > Pages > Build and deployment**
com:

```text
Source: GitHub Actions
```

Pushes para `main` ou `demo-day-flutter-polish` apenas validam e geram o build
sintetico. A publicacao exige **Actions > Deploy Flutter Web > Run workflow**,
selecionando a branch e habilitando `publish` explicitamente.

Veja o [roteiro de publicacao, validacao e recuperacao](docs/demo-day/github-pages-publication.md)
antes de executar commit, push ou deploy.

Link esperado da apresentacao:

```text
https://ykiakao.github.io/uniconnect-clients/
```

---

## Login de Teste

As contas de apresentação são fornecidas pelo responsável em canal privado.
Não registrar e-mails de acesso, senhas ou tokens neste repositório.

Tenant demo:

| Campo | Valor |
| ----- | ----- |
| Nome | EduKMais |
| Slug | `edukmais` |
| Plano | Growth |
| Status | Teste ativo |

---

## Validação

```bash
cd uniconnect_flutter_base
flutter analyze
flutter test
```

---

## Integração com o Backend

O backend fica no repositório:

```text
uniconnect-api
```

Os clientes devem consumir a API somente por HTTP. Não deve existir importação local, script compartilhado ou dependência direta de pastas backend.

---

## Roadmap Técnico

### Concluído

* App Flutter mobile-first
* Login real via API
* Sessão local persistida no app
* Configuração central da URL da API
* Repositório de clientes separado do backend
* Base documentada para o painel web

### Pendente

* Evoluir o painel web administrativo
* Adicionar seleção ou descoberta de instituição
* Preparar builds Android, iOS e web
* Criar testes para fluxos críticos de autenticação
* Configurar pipeline de CI/CD

---

## Arquivos da Entrega

Este repositório contém:

* `README.md`
* `.gitignore`
* `uniconnect_flutter_base/`
* `painel_web/`

As pastas `build/`, `.dart_tool/`, `node_modules/` e arquivos `.env` locais não devem ser enviados para o GitHub.

---

## Contato

Clientes acadêmicos em evolução como experiência mobile e administrativa do ecossistema UniConnect.
