export class ApiRequestError extends Error {
  readonly status: number | null
  readonly code: string | null

  constructor(status: number | null, code: string | null, message: string) {
    super(message)
    this.status = status
    this.code = code
  }
}

// Only the API's reviewed public messages may appear verbatim.
const PUBLIC_ERROR_MESSAGES = new Map<string, string[]>([
  ["400:TENANT_REQUIRED", ["Instituição não informada"]],
  ["401:INVALID_CREDENTIALS", ["E-mail ou senha incorretos"]],
  ["401:INVALID_SESSION", ["Sessao invalida ou expirada."]],
  ["403:ADMIN_ACCESS_REQUIRED", [
    "Acesso administrativo restrito a coordenadores e mantenedores.",
    "Sessao sem permissao administrativa.",
  ]],
  ["403:USER_NOT_LINKED_TO_TENANT", ["Usuário não vinculado à instituição."]],
  ["403:USER_INACTIVE", ["Vinculo institucional desativado."]],
  ["403:TENANT_SUSPENDED", ["A instituicao esta suspensa."]],
  ["404:TENANT_NOT_FOUND", ["Instituição não encontrada"]],
  ["503:DEPENDENCY_UNAVAILABLE", [
    "O servico de dados esta temporariamente indisponivel. Tente novamente mais tarde.",
  ]],
])

const STATUS_FALLBACKS: Record<number, string> = {
  400: "Não foi possível validar os dados da solicitação.",
  401: "Não foi possível autenticar. Confira as credenciais ou entre novamente.",
  403: "Você não tem permissão para acessar o painel nesta instituição.",
  404: "Instituição ou recurso não encontrado.",
  408: "A solicitação demorou demais. Tente novamente.",
  429: "Limite de solicitações atingido. Tente novamente mais tarde.",
}

type ErrorEnvelope = { code?: unknown; message?: unknown } | undefined

function toHttpError(status: number, envelope?: ErrorEnvelope) {
  const code =
    typeof envelope?.code === "string" && /^[A-Z][A-Z0-9_]{0,63}$/.test(envelope.code) ? envelope.code : null
  const message = envelope?.message
  const publicMessages = PUBLIC_ERROR_MESSAGES.get(`${status}:${code}`)
  if (typeof message === "string" && publicMessages?.includes(message)) {
    return new ApiRequestError(status, code, message)
  }
  const fallback =
    status >= 500
      ? "A API está temporariamente indisponível. Tente novamente mais tarde."
      : (STATUS_FALLBACKS[status] ?? "Não foi possível concluir a solicitação.")
  return new ApiRequestError(status, code, fallback)
}

export type ApiRequestOptions = {
  baseUrl: string
  tenantSlug?: string
  accessToken?: string
  method?: "GET" | "POST" | "PATCH" | "PUT" | "DELETE"
  body?: unknown
  headers?: Record<string, string>
}

export async function apiRequest<T>(path: string, options: ApiRequestOptions): Promise<T> {
  const { baseUrl, tenantSlug, accessToken, method = "GET", body, headers } = options
  let response: Response
  try {
    response = await fetch(`${baseUrl}${path}`, {
      method,
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        ...(tenantSlug ? { "x-tenant-slug": tenantSlug } : {}),
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        ...headers,
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    })
  } catch {
    throw new ApiRequestError(null, null, "Não foi possível conectar à API. Verifique a conexão e tente novamente.")
  }

  if (response.status === 204) return undefined as T

  let payload: { error?: ErrorEnvelope } & Record<string, unknown>
  try {
    payload = await response.json()
  } catch {
    if (!response.ok) throw toHttpError(response.status)
    throw new ApiRequestError(response.status, null, "A API retornou uma resposta inválida. Tente novamente.")
  }

  if (!response.ok) throw toHttpError(response.status, payload?.error)
  return payload as T
}
