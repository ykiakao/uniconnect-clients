// Configuração de tenant do UniConnect.
//
// O UniConnect é um SaaS multi-tenant. Cada instituição possui seu
// próprio slug que identifica o contexto no backend.
//
// O tenant demo abaixo é o padrão atual enquanto o app não implementa
// seleção dinâmica de instituição.
//
// TODO(produto): seleção manual de instituição pelo usuário
// TODO(produto): descoberta por domínio de e-mail
// TODO(produto): convite institucional / código de acesso
// TODO(produto): resolução por subdomínio ou QR Code

const String kDemoTenantSlug = String.fromEnvironment(
  'TENANT_SLUG',
  defaultValue: 'edukmais',
);

/// Retorna o slug do tenant ativo.
/// Por enquanto retorna o tenant demo.
/// No futuro, resolverá o tenant a partir da sessão autenticada
/// ou da configuração do ambiente.
String getActiveTenantSlug() {
  return kDemoTenantSlug;
}
