// Pure rules for the Usuários screen: no DOM and no network access here.
export const PAGE_SIZE = 20
export const GENERIC_ERROR = "Não foi possível concluir a solicitação. Tente novamente."
export const STUDENT_ROLE = "aluno"

const MIN_PASSWORD_LENGTH = 8
const MAX_NAME_LENGTH = 200
const MAX_REGISTRATION_LENGTH = 50
const MAX_SEMESTER = 30
const MANAGER_MIN_RANK = 1
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

export type UserRole = "aluno" | "professor" | "gestor" | "admin"
export type RoleFilter = UserRole | ""

export type ManagedUser = {
  id: string
  name: string
  email: string
  role: string
  active: boolean
  courseId?: string
  registration?: string
  semester?: number
}
export type Actor = { id: string; email: string; role: string }
export type UserFilters = { search: string; role: RoleFilter; page: number; limit?: number }
export type PageMeta = { page: number; limit: number; total: number }
export type UserFormMode = "create" | "edit"
export type UserFormValues = {
  name: string
  email: string
  password: string
  role: string
  courseId: string
  registration: string
  semester: string
}
export type UserFormErrors = Partial<Record<keyof UserFormValues, string>>
export type CreateUserPayload = {
  name: string
  email: string
  password: string
  role: string
  courseId?: string
  registration?: string
  semester?: number
}
export type ProfilePatch = Partial<{
  name: string
  courseId: string | null
  registration: string | null
  semester: number | null
}>

export const ROLE_OPTIONS: { value: UserRole; label: string; plural: string }[] = [
  { value: "aluno", label: "Aluno", plural: "Alunos" },
  { value: "professor", label: "Professor", plural: "Professores" },
  { value: "gestor", label: "Coordenador", plural: "Coordenadores" },
  { value: "admin", label: "Administrador", plural: "Administradores" },
]

// Mirrors uniconnect-api/src/shared/roles.ts. The API still enforces it.
const ROLE_RANK: Record<string, number> = {
  student: 0,
  aluno: 0,
  teacher: 0,
  professor: 0,
  coordinator: 1,
  gestor: 1,
  admin: 2,
  owner: 3,
}

const ERROR_MESSAGES: Record<string, string> = {
  USER_ALREADY_EXISTS: "Esta pessoa já está vinculada à instituição.",
  ROLE_CHANGE_FORBIDDEN: "Seu perfil não permite conceder ou alterar este papel.",
  SELF_CHANGE_FORBIDDEN: "Você não pode alterar o próprio vínculo.",
  ROLE_INTEGRITY_CONFLICT: "Este papel está ligado a registros acadêmicos e não pode ser alterado.",
  ROLE_CHANGE_CONFLICT: "Este vínculo mudou enquanto você editava. Atualize a lista e tente novamente.",
  USER_NOT_FOUND: "Usuário não encontrado. Atualize a lista.",
  COURSE_NOT_FOUND: "O curso selecionado não existe mais. Escolha outro.",
  DATABASE_MIGRATION_REQUIRED: "A gestão de usuários depende de uma atualização pendente do banco.",
}

const text = (value: unknown) => String(value ?? "").trim()
const rankOf = (role: string) => ROLE_RANK[role] ?? -1
const isRole = (value: string | null): value is UserRole => ROLE_OPTIONS.some((option) => option.value === value)

export function roleLabel(role: string) {
  return ROLE_OPTIONS.find((option) => option.value === role)?.label ?? "Usuário"
}

export function buildListPath(tenantSlug: string, filters: UserFilters) {
  const params = new URLSearchParams({ page: String(filters.page), limit: String(filters.limit ?? PAGE_SIZE) })
  const search = text(filters.search)
  if (search) params.set("search", search)
  if (filters.role) params.set("role", filters.role)
  return `/tenants/${encodeURIComponent(tenantSlug)}/users?${params}`
}

export function parseFilters(params: URLSearchParams): UserFilters {
  const role = params.get("perfil")
  const page = Number(params.get("pagina"))
  return {
    search: params.get("q") ?? "",
    role: isRole(role) ? role : "",
    page: Number.isSafeInteger(page) && page >= 1 ? page : 1,
  }
}

export function filtersToParams({ search, role, page }: UserFilters) {
  const entries: [string, string][] = []
  if (search) entries.push(["q", search])
  if (role) entries.push(["perfil", role])
  if (page > 1 || entries.length) entries.push(["pagina", String(page)])
  return new URLSearchParams(page > 1 ? entries : entries.filter(([key]) => key !== "pagina"))
}

export function assignableRoles(actorRole: string): UserRole[] {
  const actorRank = rankOf(actorRole)
  if (actorRank < MANAGER_MIN_RANK) return []
  return ROLE_OPTIONS.filter((option) => rankOf(option.value) < actorRank).map((option) => option.value)
}

export function isSelf(actor: Actor, target: Pick<ManagedUser, "id" | "email">) {
  return actor.id === target.id || text(actor.email).toLowerCase() === text(target.email).toLowerCase()
}

export function canManageUser(actor: Actor, target: Pick<ManagedUser, "id" | "email" | "role">) {
  return !isSelf(actor, target) && rankOf(actor.role) >= MANAGER_MIN_RANK && rankOf(target.role) < rankOf(actor.role)
}

function semesterError(value: string) {
  const raw = text(value)
  if (!raw) return null
  const semester = Number(raw)
  return /^\d+$/.test(raw) && semester >= 1 && semester <= MAX_SEMESTER
    ? null
    : `Informe um semestre de 1 a ${MAX_SEMESTER}.`
}

export function validateUserForm(values: UserFormValues, mode: UserFormMode): UserFormErrors {
  const name = text(values.name)
  const isCreate = mode === "create"
  const isStudent = values.role === STUDENT_ROLE
  const checks: [keyof UserFormValues, string | null][] = [
    ["name", !name ? "Informe o nome." : name.length > MAX_NAME_LENGTH ? "Use um nome menor." : null],
    ["role", !values.role ? "Escolha um perfil." : null],
    ["email", isCreate && !EMAIL_PATTERN.test(text(values.email)) ? "Informe um e-mail válido." : null],
    [
      "password",
      isCreate && String(values.password ?? "").length < MIN_PASSWORD_LENGTH
        ? `Use pelo menos ${MIN_PASSWORD_LENGTH} caracteres.`
        : null,
    ],
    [
      "registration",
      isStudent && text(values.registration).length > MAX_REGISTRATION_LENGTH ? "Use uma matrícula menor." : null,
    ],
    ["semester", isStudent ? semesterError(values.semester) : null],
  ]
  return Object.fromEntries(checks.filter(([, message]) => message)) as UserFormErrors
}

function studentFields(values: UserFormValues) {
  const semester = text(values.semester)
  return {
    courseId: text(values.courseId) || null,
    registration: text(values.registration) || null,
    semester: semester ? Number(semester) : null,
  }
}

export function toCreatePayload(values: UserFormValues): CreateUserPayload {
  const base = {
    name: text(values.name),
    email: text(values.email).toLowerCase(),
    password: String(values.password),
    role: values.role,
  }
  if (values.role !== STUDENT_ROLE) return base
  const filled = Object.entries(studentFields(values)).filter(([, value]) => value !== null)
  return { ...base, ...Object.fromEntries(filled) }
}

export function toProfilePatch(original: ManagedUser, values: UserFormValues): ProfilePatch {
  const next: ProfilePatch = {
    name: text(values.name),
    ...(values.role === STUDENT_ROLE ? studentFields(values) : {}),
  }
  const changed = Object.entries(next).filter(
    ([key, value]) => (original[key as keyof ManagedUser] ?? null) !== value,
  )
  return Object.fromEntries(changed)
}

export function pageInfo({ page, limit, total }: PageMeta) {
  return {
    page,
    total,
    from: total === 0 ? 0 : (page - 1) * limit + 1,
    to: Math.min(page * limit, total),
    hasPrev: page > 1,
    hasNext: page * limit < total,
  }
}

export function errorMessage(error: unknown) {
  if (typeof error !== "object" || error === null || !("status" in error)) return GENERIC_ERROR
  const { status, code, message } = error as { status: number | null; code?: string | null; message?: string }
  if (code && ERROR_MESSAGES[code]) return ERROR_MESSAGES[code]
  if (status === 403) return "Você não tem permissão para fazer esta alteração."
  return message || GENERIC_ERROR
}
