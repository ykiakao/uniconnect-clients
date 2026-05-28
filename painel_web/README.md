# UniConnect Painel Web

Base reservada para o painel administrativo web do SaaS acadêmico UniConnect.

![Web](https://img.shields.io/badge/Web-Admin-blue)
![TypeScript](https://img.shields.io/badge/TypeScript-Planned-blue)
![React](https://img.shields.io/badge/React-Planned-61DAFB)
![REST](https://img.shields.io/badge/API-REST-green)
![SaaS](https://img.shields.io/badge/SaaS-Backoffice-purple)

---

## Sobre o Projeto

Este diretório representa a futura aplicação web administrativa do UniConnect.

Enquanto o app mobile atende o uso diário de alunos e professores, o painel web será voltado para coordenadores, gestores acadêmicos e administradores da instituição.

---

## Responsabilidades do Painel

* Gerenciar instituições
* Gerenciar usuários
* Cadastrar cursos
* Cadastrar turmas
* Associar professores, alunos e turmas
* Acompanhar relatórios acadêmicos
* Configurar dados da instituição
* Gerenciar assinatura e plano
* Consumir a API `uniconnect-api` via HTTP

---

## Tecnologias Sugeridas

Esta frente ainda não foi implementada. Stack recomendada:

* React ou Next.js
* TypeScript
* Tailwind CSS ou design system próprio
* TanStack Query
* React Hook Form
* Zod
* Integração REST com `uniconnect-api`

---

## Estrutura do Repositório

| Pasta | Finalidade |
| ----- | ---------- |
| `/` | Placeholder documentado do painel web |

Estrutura sugerida para implementação futura:

| Pasta | Finalidade |
| ----- | ---------- |
| `src/app` | Rotas e layout base |
| `src/features` | Funcionalidades administrativas |
| `src/shared` | Componentes compartilhados |
| `src/services` | Cliente HTTP e integrações |
| `src/styles` | Estilos globais e tokens visuais |

---

## Requisitos

Quando o painel for implementado, os requisitos esperados serão:

* Node.js
* npm
* Git
* API `uniconnect-api` em execução

---

## Integração com a API

O painel deve consumir a API em:

```text
http://localhost:3333/api/v1
```

Header de tenant esperado:

```http
x-tenant-slug: universidade-norte
Accept: application/json
```

O painel deve consumir a API via HTTP. Ele não deve importar código do backend por caminho local.

---

## Fluxo Principal Previsto

1. O administrador acessa o painel web.
2. O painel autentica o usuário com perfil administrativo.
3. O tenant da instituição é carregado.
4. O administrador gerencia cursos, turmas, usuários e relatórios.
5. A API centraliza as regras e dados do SaaS.

---

## Roadmap do Painel

* Definir stack final
* Criar scaffold inicial
* Implementar autenticação de administrador
* Criar layout base com navegação lateral
* Consumir endpoints de tenant e usuários
* Adicionar telas de cursos e turmas
* Adicionar relatórios acadêmicos
* Adicionar gestão de assinatura

---

## Arquivos da Entrega

Atualmente esta pasta contém:

* `README.md`

O código-fonte do painel será adicionado em uma próxima etapa.

---

## Contato

Painel planejado como backoffice administrativo do ecossistema UniConnect.
