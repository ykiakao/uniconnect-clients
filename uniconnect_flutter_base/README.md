# UniConnect Mobile

Aplicativo Flutter mobile-first do UniConnect, responsavel pela experiencia de alunos e professores.

## Tecnologias

* Flutter
* Dart
* Riverpod
* GoRouter
* Material Design 3
* Google Fonts
* Intl
* HTTP
* Flutter Secure Storage

## Estrutura

| Caminho | Finalidade |
| --- | --- |
| `lib/core/config` | Configuracoes do app, incluindo URL da API |
| `lib/core/network` | Cliente HTTP |
| `lib/core/router` | Rotas do app |
| `lib/core/theme` | Tema visual |
| `lib/features/auth` | Login, sessao e usuario atual |
| `lib/features/tenant` | Contexto da instituicao |
| `lib/features/student` | Dashboard do aluno |
| `lib/features/teacher` | Dashboard e acoes do professor |
| `lib/features/activities` | Atividades academicas |
| `lib/features/grades` | Notas |
| `lib/features/chat` | Chat academico |
| `lib/features/profile` | Perfil |
| `lib/shared/widgets` | Componentes compartilhados |

## Instalacao

```bash
flutter pub get
```

## Execucao

```bash
flutter run
```

Servidor web local:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

## URL da API

A URL da API fica centralizada em:

```text
lib/core/config/api_config.dart
```

Padrao local:

```text
http://localhost:3333/api/v1
```

Para usar outra URL:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3333/api/v1
```

O backend fica no repositorio separado `uniconnect-api`.

## Login de Teste

| Perfil | Email | Senha |
| --- | --- | --- |
| Aluno | `aluno@uni.com` | `123456` |
| Professor | `professor@uni.com` | `123456` |

Tenant demo:

| Campo | Valor |
| --- | --- |
| Nome | Universidade Norte |
| Slug | `universidade-norte` |
| Plano | Growth |
| Status | Teste ativo |

## Validacao

```bash
flutter analyze
flutter test
```
