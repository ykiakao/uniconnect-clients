# Notificações push (FCM) — dependências de backend

Data: 12/11/2026. Branch: `handoff/flutter-2026-11-04`.

## Situação

- A API já persiste notificações internas (`notifications`) para os eventos
  `notice_published`, `activity_published`, `activity_result_published`,
  `message_received` e `activity_due_soon`, com destinatário e tenant.
- O app consome `GET /tenants/:slug/notifications`, `GET .../unread-count` e
  `POST .../:id/read`: sino com contador e central de notificações.
- **Não existe** na API nenhum endpoint de token de dispositivo, preferência
  de notificação ou envio servidor → FCM. O projeto Flutter não tem Firebase
  configurado (`firebase_options`, `google-services.json`,
  `GoogleService-Info.plist`).

Por isso o push não foi implementado no app: registrar tokens ou enviar
mensagens a partir do cliente seria inseguro e fora do contrato.

## O que o backend precisa disponibilizar

### 1. Tokens de dispositivo

| Operação | Rota sugerida | Corpo |
|---|---|---|
| Registrar/atualizar | `PUT /tenants/:slug/devices/:installationId` | `{token, platform: 'android'\|'ios'\|'web', appVersion}` |
| Revogar (logout, desinstalação) | `DELETE /tenants/:slug/devices/:installationId` | — |

- `installationId`: UUID gerado e guardado pelo app por instalação.
- O token pertence ao usuário autenticado e ao tenant do Bearer; reenviar o
  mesmo token para outro usuário deve transferir (não duplicar) o registro.
- Logout chama o `DELETE` antes de descartar a sessão.
- Tokens rejeitados pelo FCM (`UNREGISTERED`, `INVALID_ARGUMENT`) devem ser
  removidos pelo servidor.

### 2. Preferências (tela Configurações)

`GET`/`PUT /tenants/:slug/notification-preferences` com
`{notices, messages, activities, results, dueReminders}` (booleanos). O
servidor respeita as preferências antes de enviar.

### 3. Envio servidor → FCM

- Disparado pela mesma transação/fila que já cria a notificação interna,
  somente para o destinatário dela (mesmo tenant, participante autorizado).
- Idempotência por `notification.id` (campo `data.notificationId`), para o
  app não exibir duplicadas.
- Payload sem conteúdo sensível: título genérico + `data` com
  `notificationId`, `type`, `resourceType`, `resourceId`. O app abre o
  recurso consultando a API autenticada (o mesmo fluxo da central).
- Credencial de serviço do Firebase somente no servidor.

### 4. Configuração do Firebase (alinhar antes de publicar)

- Projeto Firebase, apps Android/iOS/Web e arquivos de configuração.
- iOS: chave APNs e capability de push. Web: chave VAPID e service worker.

## O que o app fará quando os contratos existirem

Permissão de notificação, registro/atualização/revogação do token,
recebimento em primeiro plano/segundo plano/fechado, abertura do aviso,
mensagem, atividade ou nota ao tocar, e integração com Configurações.
