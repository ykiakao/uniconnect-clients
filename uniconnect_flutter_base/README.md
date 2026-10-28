# UniConnect Mobile

Aplicativo Flutter mobile-first responsável pela experiência principal de alunos e professores no SaaS acadêmico UniConnect.

O app mobile é o cliente Flutter de um SaaS acadêmico multi-tenant. Suporta múltiplas instituições através de contexto de tenant isolado.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.4-blue)
![Riverpod](https://img.shields.io/badge/State-Riverpod-purple)
![GoRouter](https://img.shields.io/badge/Router-GoRouter-green)
![REST](https://img.shields.io/badge/API-REST-green)

---

## Sobre o Projeto

Este app centraliza a rotina acadêmica em uma interface mobile. Alunos consultam atividades, detalhes, notas e perfil. Professores consultam identidade, instituição e vínculo acadêmico disponível. Chat, criação de atividades e lançamento docente de notas são protótipos identificados, sem envio ou publicação.

Preparação da Demo Day de 28/10/2026: [relatório, validação e roteiro de execução](../docs/codex-kit/DEMO_DAY_2026-10-28.md).

O aplicativo consome a API do repositório `uniconnect-api` via HTTP e mantém a URL centralizada para facilitar troca entre ambiente local e produção.

---

## Responsabilidades do App

* Autenticar aluno ou professor no tenant da instituição
* Exibir dashboard específico por perfil
* Listar atividades acadêmicas
* Apresentar notas e simulações de média
* Disponibilizar chat acadêmico
* Exibir perfil do usuário e instituição
* Consumir a API backend sem dependência de caminho local

---

## Tecnologias Utilizadas

* Flutter
* Dart
* Riverpod
* GoRouter
* Material Design 3
* Fonte Inter local
* Intl
* HTTP
* Flutter Secure Storage

---

## Estrutura do Repositório

| Pasta | Finalidade |
| ----- | ---------- |
| `lib/core/config` | Configuração da URL da API |
| `lib/core/constants` | Constantes de rotas |
| `lib/core/network` | Cliente HTTP |
| `lib/core/router` | Configuração de navegação |
| `lib/core/tenant` | Configuração do tenant ativo |
| `lib/core/theme` | Tema, cores e espaçamentos |
| `lib/features/activities` | Atividades acadêmicas |
| `lib/features/auth` | Login e usuário atual |
| `lib/features/chat` | Mensagens do chat |
| `lib/features/grades` | Notas e simulador de média |
| `lib/features/profile` | Perfil e configurações |
| `lib/features/student` | Dashboard do aluno |
| `lib/features/teacher` | Dashboard e ações do professor |
| `lib/features/tenant` | Contexto da instituição |
| `lib/shared/widgets` | Componentes compartilhados |

---

## Requisitos

Antes de executar o projeto, instale:

* Flutter
* Dart SDK
* Git
* Android Studio ou emulador configurado
* API `uniconnect-api` em execução para autenticação real

---

## Instalação

```bash
flutter pub get
```

---

## Executando o Projeto

Rodar no dispositivo/emulador:

```bash
flutter run
```

Rodar no navegador como servidor web:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

Rodar apontando para uma API específica:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3333/api/v1
```

Rodar apontando para a API publicada no Render e para o tenant EduKMais:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080 --dart-define=API_BASE_URL=https://uniconnect-api-ht5x.onrender.com/api/v1 --dart-define=TENANT_SLUG=edukmais
```

Para testes no emulador Android, o app usa por padrão:

```text
http://10.0.2.2:3333/api/v1
```

Esse endereço aponta do emulador para a máquina host. Para celular físico, use o IP local do computador:

```bash
flutter run --dart-define=API_BASE_URL=http://SEU_IP_LOCAL:3333/api/v1
```

---

## Integração com a API

A URL da API fica centralizada em:

```text
lib/core/config/api_config.dart
```

URL local padrão:

```text
http://localhost:3333/api/v1
```

O backend fica no repositório separado:

```text
uniconnect-api
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

Veja o [roteiro de publicacao, validacao e recuperacao](../docs/demo-day/github-pages-publication.md)
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

## Fluxo Principal

1. O usuário acessa a tela de login.
2. O app envia as credenciais para a API.
3. A API retorna usuário, perfil, token e tenant.
4. O app mantém a sessão em memória e só a persiste quando “Lembrar de mim” está selecionado.
5. A navegação direciona para o dashboard correto.
6. O usuário acessa atividades, notas, chat e perfil.

---

## Testes e Validação

Analisar o projeto:

```bash
flutter analyze
```

Executar testes:

```bash
flutter test
```

Formatar código:

```bash
dart format lib test
```

---

## Próximos Passos

* Adicionar seleção ou descoberta de instituição
* Implementar push notifications
* Preparar builds Android e iOS
* Expandir cobertura de autenticação, guards de perfil e contexto multi-tenant
* Configurar URL de produção por pipeline de build

---

## Arquivos da Entrega

Este app contém:

* `README.md`
* `pubspec.yaml`
* `pubspec.lock`
* código-fonte em `lib/`
* testes em `test/`
* projetos nativos em `android/`, `ios/`, `web/`, `linux/`, `macos/` e `windows/`

As pastas `build/` e `.dart_tool/` não devem ser enviadas para o GitHub.

---

## Contato

Aplicativo acadêmico desenvolvido como experiência mobile principal do ecossistema UniConnect.
