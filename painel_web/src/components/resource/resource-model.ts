// Pure rules shared by the configuration-driven management screens.
export const PAGE_SIZE = 20

export type FieldOption = { value: string; label: string }
export type FormValues = Record<string, string>
export type FormMode = "create" | "edit"
export type RowData = Record<string, unknown>

export type ResourceField = {
  name: string
  label: string
  type?: "text" | "textarea" | "date" | "select"
  required?: boolean
  maxLength?: number
  placeholder?: string
  hint?: string
  options?: FieldOption[] | ((values: FormValues) => FieldOption[])
  defaultValue?: string
  /** Only sent and shown when creating. */
  createOnly?: boolean
  /** An emptied value is sent as null on partial updates. */
  clearable?: boolean
  pattern?: { regex: RegExp; message: string }
  visibleWhen?: (values: FormValues) => boolean
}

const text = (value: unknown) => String(value ?? "").trim()

export function resolveOptions(field: ResourceField, values: FormValues) {
  return typeof field.options === "function" ? field.options(values) : (field.options ?? [])
}

export function buildListPath(path: string, { page, filters }: { page: number; filters?: Record<string, string> }) {
  const params = new URLSearchParams({ page: String(page), limit: String(PAGE_SIZE) })
  Object.entries(filters ?? {})
    .filter(([, value]) => value)
    .forEach(([key, value]) => params.set(key, value))
  return `${path}?${params}`
}

export function isFieldActive(field: ResourceField, values: FormValues, mode: FormMode) {
  if (mode === "edit" && field.createOnly) return false
  return field.visibleWhen?.(values) ?? true
}

export function initialValues(fields: ResourceField[], row: object | null): FormValues {
  const source = (row ?? {}) as RowData
  return Object.fromEntries(fields.map((field) => [field.name, String(source[field.name] ?? field.defaultValue ?? "")]))
}

function fieldError(field: ResourceField, value: string) {
  if (!value) return field.required ? "Campo obrigatório." : null
  if (field.maxLength && value.length > field.maxLength) return `Use no máximo ${field.maxLength} caracteres.`
  if (field.pattern && !field.pattern.regex.test(value)) return field.pattern.message
  return null
}

export function validate(fields: ResourceField[], values: FormValues, mode: FormMode): Record<string, string> {
  const entries = fields
    .filter((field) => isFieldActive(field, values, mode))
    .map((field) => [field.name, fieldError(field, text(values[field.name]))] as const)
    .filter(([, message]) => message)
  return Object.fromEntries(entries) as Record<string, string>
}

export function toFullPayload(fields: ResourceField[], values: FormValues, mode: FormMode): RowData {
  const entries = fields
    .filter((field) => isFieldActive(field, values, mode))
    .map((field) => [field.name, text(values[field.name])] as const)
    .filter(([, value]) => value)
  return Object.fromEntries(entries)
}

export function toChangedPayload(fields: ResourceField[], values: FormValues, original: object): RowData {
  const source = original as RowData
  const entries = fields
    .filter((field) => isFieldActive(field, values, "edit"))
    .filter((field) => text(values[field.name]) !== text(source[field.name]))
    .map((field) => [field.name, text(values[field.name]) || (field.clearable ? null : undefined)] as const)
    .filter(([, value]) => value !== undefined)
  return Object.fromEntries(entries)
}
