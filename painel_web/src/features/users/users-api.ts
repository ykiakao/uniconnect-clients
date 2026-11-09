import { keepPreviousData, useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import * as Model from "./users-model"
import type { ManagedUser, PageMeta, UserFilters, UserFormValues } from "./users-model"
import { useApi, useSession } from "@/features/auth/use-auth"

type UsersPage = { data: ManagedUser[]; meta: PageMeta }
export type Course = { id: string; name: string }
export type SaveUserInput = { original: ManagedUser | null; values: UserFormValues }

const usersKey = (slug: string) => ["users", slug] as const

function useTenantPaths() {
  const { tenantSlug } = useSession()
  const encoded = encodeURIComponent(tenantSlug)
  return { tenantSlug, usersPath: `/tenants/${encoded}/users`, coursesPath: `/tenants/${encoded}/courses` }
}

export function useUsersQuery(filters: UserFilters) {
  const api = useApi()
  const { tenantSlug } = useTenantPaths()
  return useQuery({
    queryKey: [...usersKey(tenantSlug), "list", filters],
    queryFn: () => api<UsersPage>(Model.buildListPath(tenantSlug, filters)),
    placeholderData: keepPreviousData,
  })
}

export function useRoleCountsQuery(search: string) {
  const api = useApi()
  const { tenantSlug } = useTenantPaths()
  return useQuery({
    queryKey: [...usersKey(tenantSlug), "counts", search],
    queryFn: async () => {
      const roles: Model.RoleFilter[] = ["", ...Model.ROLE_OPTIONS.map((option) => option.value)]
      const pages = await Promise.all(
        roles.map((role) => api<UsersPage>(Model.buildListPath(tenantSlug, { page: 1, limit: 1, search, role }))),
      )
      return Object.fromEntries(roles.map((role, index) => [role, pages[index].meta?.total ?? 0]))
    },
  })
}

export function useCoursesQuery() {
  const api = useApi()
  const { tenantSlug, coursesPath } = useTenantPaths()
  return useQuery({
    queryKey: ["courses", tenantSlug],
    queryFn: async () => (await api<{ data: Course[] }>(`${coursesPath}?page=1&limit=100`)).data ?? [],
  })
}

/** Resolves to false when an edit changed nothing, so no request was sent. */
export function useSaveUserMutation() {
  const api = useApi()
  const client = useQueryClient()
  const { tenantSlug, usersPath } = useTenantPaths()

  return useMutation({
    mutationFn: async ({ original, values }: SaveUserInput) => {
      if (!original) {
        await api(usersPath, { method: "POST", body: Model.toCreatePayload(values) })
        return true
      }
      const userPath = `${usersPath}/${encodeURIComponent(original.id)}`
      const profile = Model.toProfilePatch(original, values)
      const roleChanged = values.role !== original.role
      const profileChanged = Object.keys(profile).length > 0
      // Role goes first: the profile rules depend on the current role.
      if (roleChanged) await api(`${userPath}/role`, { method: "PATCH", body: { role: values.role } })
      if (profileChanged) await api(`${userPath}/profile`, { method: "PATCH", body: profile })
      return roleChanged || profileChanged
    },
    onSettled: () => client.invalidateQueries({ queryKey: usersKey(tenantSlug) }),
  })
}

export function useSetUserActiveMutation() {
  const api = useApi()
  const client = useQueryClient()
  const { tenantSlug, usersPath } = useTenantPaths()

  return useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) =>
      api(`${usersPath}/${encodeURIComponent(id)}/status`, { method: "PATCH", body: { active } }),
    onSuccess: () => client.invalidateQueries({ queryKey: usersKey(tenantSlug) }),
  })
}
