# UniConnect Mobile

Aplicativo Flutter mobile-first responsável pela experiência principal de alunos e professores no SaaS acadêmico UniConnect.

![Flutter](https://img.shields.io/badge/Flutter-Mobile-blue)
![Dart](https://img.shields.io/badge/Dart-%3E%3D3.4-blue)
![Riverpod](https://img.shields.io/badge/State-Riverpod-purple)
![GoRouter](https://img.shields.io/badge/Router-GoRouter-green)
![REST](https://img.shields.io/badge/API-REST-green)

---

## Sobre o Projeto

Este app centraliza a rotina acadêmica em uma interface mobile. Alunos conseguem acompanhar atividades, notas, chat e perfil. Professores acessam ações rápidas para publicar atividades, lançar notas e enviar comunicados.

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
* Google Fonts
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

## Fluxo Principal

1. O usuário acessa a tela de login.
2. O app envia as credenciais para a API.
3. A API retorna usuário, perfil, token e tenant.
4. O app persiste a sessão localmente.
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
* Criar testes para fluxos críticos
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
