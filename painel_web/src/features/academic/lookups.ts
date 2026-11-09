import { useQuery } from "@tanstack/react-query"

import type { FieldOption } from "@/components/resource/resource-model"
import { useApi, useSession } from "@/features/auth/use-auth"

const LOOKUP_LIMIT = 100

export type Course = { id: string; name: string; description?: string }
export type ClassRow = { id: string; name: string; courseId: string; teacherId?: string }
export type Subject = { id: string; name: string; code: string; courseId: string; status: string }
export type Period = { id: string; name: string; code: string; status: string; startDate?: string; endDate?: string }
type Person = { id: string; name: string }

export const toOptions = (rows: { id: string; name: string }[]): FieldOption[] =>
  rows.map((row) => ({ value: row.id, label: row.name }))
export const nameOf = (rows: { id: string; name: string }[], id?: string) => rows.find((row) => row.id === id)?.name ?? "—"

function useLookup<T>(resource: string) {
  const api = useApi()
  const { tenantSlug } = useSession()
  const path = `/tenants/${encodeURIComponent(tenantSlug)}/${resource}${resource.includes("?") ? "&" : "?"}page=1&limit=${LOOKUP_LIMIT}`
  const query = useQuery({
    queryKey: ["lookup", tenantSlug, path],
    queryFn: async () => (await api<{ data: T[] }>(path)).data ?? [],
  })
  return query.data ?? []
}

export const useCourses = () => useLookup<Course>("courses")
export const usePeriods = () => useLookup<Period>("academic-periods")
export const useSubjects = () => useLookup<Subject>("subjects")
export const useStudents = () => useLookup<Person>("users?role=aluno")
export const useTeachers = () => useLookup<Person>("users?role=professor")

/** The API lists classes per course, so all courses are read in parallel. */
export function useAllClasses() {
  const api = useApi()
  const { tenantSlug } = useSession()
  const courses = useCourses()
  const base = `/tenants/${encodeURIComponent(tenantSlug)}/courses`
  const query = useQuery({
    queryKey: ["lookup", tenantSlug, "all-classes", courses.map((course) => course.id)],
    enabled: courses.length > 0,
    queryFn: async () => {
      const pages = await Promise.all(
        courses.map((course) => api<{ data: ClassRow[] }>(`${base}/${encodeURIComponent(course.id)}/classes?page=1&limit=${LOOKUP_LIMIT}`)),
      )
      return pages.flatMap((page) => page.data ?? [])
    },
  })
  return query.data ?? []
}
