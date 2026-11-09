import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react"
import { useQueryClient } from "@tanstack/react-query"

import {
  DEFAULT_API_BASE_URL,
  DEFAULT_TENANT,
  clearStoredSession,
  performLogin,
  validateStoredSession,
  type AdminSession,
  type LoginValues,
  type ValidationOutcome,
} from "./session"
import { AuthContext, type AuthState } from "./use-auth"

const INITIAL_STATE: AuthState = {
  status: "restoring",
  session: null,
  error: "",
  apiBaseUrl: DEFAULT_API_BASE_URL,
  tenantSlug: DEFAULT_TENANT,
}

export function AuthProvider({ children }: { children: ReactNode }) {
  const queryClient = useQueryClient()
  const [state, setState] = useState<AuthState>(INITIAL_STATE)
  const sessionRef = useRef<AdminSession | null>(null)
  const pendingRef = useRef<Promise<void> | null>(null)
  // Bumped by login and logout so an older validation cannot overwrite them.
  const epochRef = useRef(0)

  const applyOutcome = useCallback((outcome: ValidationOutcome) => {
    if (outcome.kind === "kept") {
      setState((previous) => ({ ...previous, error: outcome.error }))
      return
    }
    if (outcome.kind === "verified") {
      sessionRef.current = outcome.session
      setState({
        status: "authenticated",
        session: outcome.session,
        error: "",
        apiBaseUrl: outcome.session.apiBaseUrl,
        tenantSlug: outcome.session.tenantSlug,
      })
      return
    }
    sessionRef.current = null
    setState((previous) => ({
      ...previous,
      status: "anonymous",
      session: null,
      error: outcome.error,
      ...(outcome.kind === "denied" ? { apiBaseUrl: outcome.apiBaseUrl, tenantSlug: outcome.tenantSlug } : {}),
    }))
    queryClient.clear()
  }, [queryClient])

  const refresh = useCallback(() => {
    if (pendingRef.current) return pendingRef.current
    const epoch = epochRef.current
    const run: Promise<void> = validateStoredSession(sessionRef.current)
      .then((outcome) => {
        if (epoch === epochRef.current) applyOutcome(outcome)
      })
      .finally(() => {
        if (pendingRef.current === run) pendingRef.current = null
      })
    pendingRef.current = run
    return run
  }, [applyOutcome])

  useEffect(() => {
    void refresh()
  }, [refresh])

  const login = useCallback(async (values: LoginValues) => {
    const session = await performLogin(values)
    epochRef.current += 1
    pendingRef.current = null
    sessionRef.current = session
    setState({
      status: "authenticated",
      session,
      error: "",
      apiBaseUrl: session.apiBaseUrl,
      tenantSlug: session.tenantSlug,
    })
  }, [])

  const logout = useCallback(() => {
    epochRef.current += 1
    pendingRef.current = null
    sessionRef.current = null
    clearStoredSession()
    setState((previous) => ({ ...previous, status: "anonymous", session: null, error: "" }))
    queryClient.clear()
  }, [queryClient])

  const value = useMemo(() => ({ ...state, login, logout, refresh }), [state, login, logout, refresh])

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}
