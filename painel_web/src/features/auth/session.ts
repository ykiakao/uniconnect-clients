import { ApiRequestError, apiRequest } from "@/lib/api-client"

export const STORAGE_KEY = "uniconnect.admin.session"
export const DEFAULT_API_BASE_URL: string = import.meta.env.VITE_API_BASE_URL ?? "http://localhost:3333/api/v1"
export const DEFAULT_TENANT: string = import.meta.env.VITE_DEFAULT_TENANT ?? "universidade-norte"

const ADMIN_ROLES = new Set(["admin", "gestor", "coordinator", "owner"])

export type AdminUser = { id: string; name: string; email: string; role: string; tenantSlug: string }
export type Tenant = { id: string; name: string; slug: string; status?: string; plan?: string; activeUsers?: number }
export type AdminSession = {
  accessToken: string
  refreshToken?: string
  expiresAt?: string
  user: AdminUser
  tenant: Tenant
  apiBaseUrl: string
  tenantSlug: string
}
export type LoginValues = {
  apiBaseUrl: string
  tenantSlug: string
  email: string
  password: string
  remember: boolean
}
export type ValidationOutcome =
  | { kind: "anonymous"; error: "" }
  | { kind: "verified"; session: AdminSession }
  | { kind: "kept"; error: string }
  | { kind: "denied"; error: string; apiBaseUrl: string; tenantSlug: string }

type StoredSession = Partial<AdminSession> & { accessToken?: unknown }
type LoginPayload = { accessToken?: unknown; refreshToken?: string; expiresAt?: string; user?: unknown; tenant?: unknown }

const isRecord = (value: unknown): value is Record<string, unknown> =>
  value !== null && typeof value === "object" && !Array.isArray(value)
const isNonEmptyString = (value: unknown): value is string => typeof value === "string" && value.trim().length > 0

function isAdminUser(user: unknown): user is AdminUser {
  return (
    isRecord(user) &&
    typeof user.role === "string" &&
    ADMIN_ROLES.has(user.role) &&
    ["id", "name", "email", "tenantSlug"].every((key) => isNonEmptyString(user[key]))
  )
}

function isTenantOf(tenant: unknown, user: AdminUser, expectedSlug: string): tenant is Tenant {
  return (
    isRecord(tenant) &&
    ["id", "name", "slug"].every((key) => isNonEmptyString(tenant[key])) &&
    tenant.slug === expectedSlug &&
    user.tenantSlug === tenant.slug
  )
}

export function clearStoredSession() {
  localStorage.removeItem(STORAGE_KEY)
  sessionStorage.removeItem(STORAGE_KEY)
}

export function saveStoredSession(session: AdminSession, remember: boolean) {
  clearStoredSession()
  const storage = remember ? localStorage : sessionStorage
  storage.setItem(STORAGE_KEY, JSON.stringify(session))
}

function getStoredSession(): StoredSession | null {
  const raw = localStorage.getItem(STORAGE_KEY) ?? sessionStorage.getItem(STORAGE_KEY)
  if (!raw) return null
  try {
    return JSON.parse(raw) as StoredSession
  } catch {
    clearStoredSession()
    return null
  }
}

export function safeAuthError(error: unknown) {
  return error instanceof ApiRequestError ? error.message : "Não foi possível concluir a autenticação."
}

function isTemporarySessionError(error: unknown) {
  if (!(error instanceof ApiRequestError)) return false
  const { status } = error
  return status === null || status === 408 || status === 429 || status >= 500 || (status >= 200 && status < 300)
}

function rejectsSavedSession(error: unknown) {
  return (
    error instanceof ApiRequestError &&
    (error.status === 401 ||
      (error.status === 403 &&
        ["ADMIN_ACCESS_REQUIRED", "USER_INACTIVE", "USER_NOT_LINKED_TO_TENANT"].includes(error.code ?? "")))
  )
}

export async function performLogin(values: LoginValues): Promise<AdminSession> {
  const { apiBaseUrl, tenantSlug, email, password, remember } = values
  const payload = await apiRequest<LoginPayload>("/auth/admin/login", {
    baseUrl: apiBaseUrl,
    tenantSlug,
    method: "POST",
    body: { email, password },
  })

  const { accessToken, user, tenant } = payload ?? {}
  if (!isNonEmptyString(accessToken) || !isAdminUser(user) || !isTenantOf(tenant, user, tenantSlug)) {
    throw new ApiRequestError(403, "ADMIN_ACCESS_REQUIRED", "Acesso restrito a coordenadores e mantenedores da instituição.")
  }

  const session: AdminSession = {
    accessToken,
    refreshToken: payload.refreshToken,
    expiresAt: payload.expiresAt,
    user,
    tenant,
    apiBaseUrl,
    tenantSlug,
  }
  saveStoredSession(session, remember)
  return session
}

export async function validateStoredSession(current: AdminSession | null): Promise<ValidationOutcome> {
  const stored = getStoredSession()
  if (!stored || !isNonEmptyString(stored.accessToken)) {
    clearStoredSession()
    return { kind: "anonymous", error: "" }
  }

  const apiBaseUrl = stored.apiBaseUrl ?? DEFAULT_API_BASE_URL
  const tenantSlug = stored.tenantSlug ?? stored.tenant?.slug ?? DEFAULT_TENANT
  try {
    const payload = await apiRequest<Record<string, unknown>>("/auth/admin/me", {
      baseUrl: apiBaseUrl,
      tenantSlug,
      accessToken: stored.accessToken,
    })
    const { tenant, ...user } = payload ?? {}
    if (!isAdminUser(user) || !isTenantOf(tenant, user, tenantSlug)) {
      throw new ApiRequestError(403, "ADMIN_ACCESS_REQUIRED", "Sessão sem permissão administrativa.")
    }
    return {
      kind: "verified",
      session: { ...stored, accessToken: stored.accessToken, user, tenant, apiBaseUrl, tenantSlug },
    }
  } catch (error) {
    const message = safeAuthError(error)
    if (current && isTemporarySessionError(error)) return { kind: "kept", error: message }
    if (rejectsSavedSession(error)) clearStoredSession()
    return { kind: "denied", error: message, apiBaseUrl, tenantSlug }
  }
}
