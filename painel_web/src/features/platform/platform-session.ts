import { ApiRequestError, apiRequest } from "@/lib/api-client"
import { DEFAULT_API_BASE_URL, safeAuthError } from "@/features/auth/session"

export const PLATFORM_STORAGE_KEY = "uniconnect.platform.session"

export type PlatformSession = { accessToken: string; apiBaseUrl: string }
export type PlatformRestore = { session: PlatformSession | null; error: string }

export function clearPlatformSession() {
  sessionStorage.removeItem(PLATFORM_STORAGE_KEY)
}

function readPlatformSession(): PlatformSession | null {
  const raw = sessionStorage.getItem(PLATFORM_STORAGE_KEY)
  if (!raw) return null
  try {
    const parsed = JSON.parse(raw) as Partial<PlatformSession>
    return typeof parsed.accessToken === "string" && parsed.accessToken ? { accessToken: parsed.accessToken, apiBaseUrl: DEFAULT_API_BASE_URL } : null
  } catch {
    return null
  }
}

/** Global access is broader than a tenant's, so the token never outlives the tab. */
export async function platformLogin(email: string, password: string): Promise<PlatformSession> {
  const { accessToken } = await apiRequest<{ accessToken?: unknown }>("/auth/platform/login", {
    baseUrl: DEFAULT_API_BASE_URL,
    method: "POST",
    body: { email: email.trim(), password },
  })
  if (typeof accessToken !== "string" || !accessToken) {
    throw new ApiRequestError(403, "FORBIDDEN", "Acesso restrito à administração da plataforma.")
  }
  const session = { accessToken, apiBaseUrl: DEFAULT_API_BASE_URL }
  sessionStorage.setItem(PLATFORM_STORAGE_KEY, JSON.stringify(session))
  return session
}

export async function restorePlatformSession(): Promise<PlatformRestore> {
  const session = readPlatformSession()
  if (!session) {
    clearPlatformSession()
    return { session: null, error: "" }
  }
  try {
    await apiRequest("/auth/platform/me", { baseUrl: session.apiBaseUrl, accessToken: session.accessToken })
    return { session, error: "" }
  } catch (error) {
    if (error instanceof ApiRequestError && (error.status === 401 || error.status === 403)) clearPlatformSession()
    return { session: null, error: safeAuthError(error) }
  }
}
