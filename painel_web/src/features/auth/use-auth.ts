import { createContext, useCallback, useContext } from "react"

import type { AdminSession, LoginValues } from "./session"
import { ApiRequestError, apiRequest, type ApiRequestOptions } from "@/lib/api-client"

export type AuthState = {
  status: "restoring" | "anonymous" | "authenticated"
  session: AdminSession | null
  error: string
  apiBaseUrl: string
  tenantSlug: string
}

export type AuthContextValue = AuthState & {
  login: (values: LoginValues) => Promise<void>
  logout: () => void
  refresh: () => Promise<void>
}

export const AuthContext = createContext<AuthContextValue | null>(null)

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) throw new Error("useAuth must be used inside AuthProvider")
  return context
}

export function useSession() {
  const { session } = useAuth()
  if (!session) throw new Error("useSession requires an authenticated session")
  return session
}

type RequestOptions = Pick<ApiRequestOptions, "method" | "body">

/** Authenticated requests for the current tenant; a 401 revalidates the session. */
export function useApi() {
  const { refresh } = useAuth()
  const { apiBaseUrl, tenantSlug, accessToken } = useSession()

  return useCallback(
    async <T,>(path: string, options: RequestOptions = {}) => {
      try {
        return await apiRequest<T>(path, { ...options, baseUrl: apiBaseUrl, tenantSlug, accessToken })
      } catch (error) {
        if (error instanceof ApiRequestError && error.status === 401) void refresh()
        throw error
      }
    },
    [apiBaseUrl, tenantSlug, accessToken, refresh],
  )
}
