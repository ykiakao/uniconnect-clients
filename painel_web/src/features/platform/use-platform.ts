import { createContext, useCallback, useContext } from "react"

import type { PlatformSession } from "./platform-session"
import { ApiRequestError, apiRequest, type ApiRequestOptions } from "@/lib/api-client"

export type PlatformContextValue = { session: PlatformSession; logout: () => void }
export const PlatformContext = createContext<PlatformContextValue | null>(null)

export function usePlatform() {
  const context = useContext(PlatformContext)
  if (!context) throw new Error("usePlatform must be used inside PlatformApp")
  return context
}

type RequestOptions = Pick<ApiRequestOptions, "method" | "body" | "headers">

/** Requests carry no tenant header: platform access is not tied to an institution. */
export function usePlatformApi() {
  const { session, logout } = usePlatform()
  return useCallback(
    async <T,>(path: string, options: RequestOptions = {}) => {
      try {
        return await apiRequest<T>(path, { ...options, baseUrl: session.apiBaseUrl, accessToken: session.accessToken })
      } catch (error) {
        if (error instanceof ApiRequestError && error.status === 401) logout()
        throw error
      }
    },
    [session, logout],
  )
}
