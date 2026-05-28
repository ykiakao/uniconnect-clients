# UniConnect Clients

Repositorio dos clientes do UniConnect. Ele contem o app Flutter mobile-first e a base reservada para o futuro painel web administrativo.

A API Node.js/TypeScript fica em outro repositorio: `uniconnect-api`.

## Projetos

| Caminho | Descricao |
| --- | --- |
| `uniconnect_flutter_base/` | App Flutter usado por alunos e professores |
| `painel_web/` | Base documentada para o futuro painel administrativo |

## Tecnologias

| Frente | Stack |
| --- | --- |
| App mobile | Flutter, Dart, Riverpod, GoRouter, Material Design 3, HTTP, Flutter Secure Storage |
| Painel web | React ou Next.js, TypeScript, Tailwind CSS, TanStack Query, React Hook Form, Zod |
| Integracao | API REST externa do repositorio `uniconnect-api` |

## Rodando o App Flutter

```bash
cd uniconnect_flutter_base
flutter pub get
flutter run
```

Rodar como servidor web:

```bash
flutter run -d web-server --web-hostname 127.0.0.1 --web-port 8080
```

## Configurando a URL da API

O app usa `lib/core/config/api_config.dart` como ponto central de configuracao.

URL local padrao:

```text
http://localhost:3333/api/v1
```

Para trocar em tempo de execucao:

```bash
flutter run --dart-define=API_BASE_URL=http://localhost:3333/api/v1
```

Quando houver URL de producao, use o mesmo `--dart-define` ou ajuste o pipeline de build para injetar `API_BASE_URL`.

## Validacao

```bash
cd uniconnect_flutter_base
flutter analyze
flutter test
```

## Painel Web

`painel_web/` ainda e uma base reservada. Quando for implementado, ele deve consumir a mesma API REST do repositorio `uniconnect-api`.

## Separacao de Responsabilidades

Este repositorio nao deve conter backend Node/Express, scripts Supabase ou dependencias internas da API.

O app Flutter e o painel web devem consumir a API somente via HTTP.
