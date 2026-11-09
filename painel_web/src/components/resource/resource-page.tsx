import { useState, type ReactNode } from "react"
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query"
import { Pencil, Plus, Trash2 } from "lucide-react"
import { useSearchParams } from "react-router"
import { toast } from "sonner"

import * as R from "./resource-model"
import type { FieldOption, FormValues, ResourceField, RowData } from "./resource-model"
import { ResourceFormDialog } from "./resource-form-dialog"
import { DataTable, type Column } from "@/components/data-table"
import { TableSkeleton } from "@/components/loading-skeletons"
import { FormError, ListPagination, StateMessage } from "@/components/page-states"
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { useApi, useSession } from "@/features/auth/use-auth"
import { errorMessage, type PageMeta } from "@/features/users/users-model"

const ALL = "__all"

export type ResourceFilter = { name: string; label: string; options: FieldOption[] }

export type ResourceConfig<T extends { id: string }> = {
  label: string
  newLabel?: string
  editTitle: string
  /** Relative to /tenants/:slug. */
  basePath: string
  itemPath?: (row: T) => string
  updateMethod: "PUT" | "PATCH"
  updateMode: "full" | "changed"
  updateExtras?: (row: T) => RowData
  canDelete?: boolean
  canEditRow?: (row: T) => boolean
  emptyMessage: string
  rowName: (row: T) => string
  columns: Column<T>[]
  fields: ResourceField[]
  filters?: ResourceFilter[]
  listParams?: Record<string, string>
  rowActions?: (row: T) => ReactNode
}

export const resourceKey = (slug: string) => ["resource", slug] as const

export function useInvalidateResources() {
  const client = useQueryClient()
  const { tenantSlug } = useSession()
  return () =>
    Promise.all([
      client.invalidateQueries({ queryKey: resourceKey(tenantSlug) }),
      client.invalidateQueries({ queryKey: ["lookup", tenantSlug] }),
    ])
}

export function IconAction({ label, tooltip, onClick, children }: { label: string; tooltip: string; onClick: () => void; children: ReactNode }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <Button
          variant="ghost"
          size="icon-sm"
          aria-label={label}
          className="max-lg:h-9 max-lg:min-w-0 max-lg:flex-1 max-lg:gap-1.5 max-lg:border-border max-lg:bg-background max-lg:px-3"
          onClick={onClick}
        >
          {children}
          <span className="lg:hidden">{tooltip}</span>
        </Button>
      </TooltipTrigger>
      <TooltipContent className="max-lg:hidden">{tooltip}</TooltipContent>
    </Tooltip>
  )
}

function FilterSelect({ filter, value, onChange }: { filter: ResourceFilter; value: string; onChange: (value: string) => void }) {
  const id = `filter-${filter.name}`
  return (
    <div className="grid gap-2 sm:w-56">
      <Label htmlFor={id}>{filter.label}</Label>
      <Select value={value || ALL} onValueChange={(next) => onChange(next === ALL ? "" : next)}>
        <SelectTrigger id={id} className="w-full">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          <SelectItem value={ALL}>Todos</SelectItem>
          {filter.options.map((option) => (
            <SelectItem key={option.value} value={option.value}>
              {option.label}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )
}

type DialogState<T> = { kind: "create" } | { kind: "edit"; row: T } | { kind: "delete"; row: T } | null

function DeleteDialog({ name, onConfirm, onClose }: { name: string; onConfirm: () => Promise<void>; onClose: () => void }) {
  const [isPending, setIsPending] = useState(false)
  const [submitError, setSubmitError] = useState("")

  async function confirm() {
    setIsPending(true)
    setSubmitError("")
    try {
      await onConfirm()
    } catch (error) {
      setSubmitError(errorMessage(error))
      setIsPending(false)
    }
  }

  return (
    <AlertDialog open onOpenChange={(open) => !open && onClose()}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Excluir registro</AlertDialogTitle>
          <AlertDialogDescription>{name} será removido. Essa ação não pode ser desfeita.</AlertDialogDescription>
        </AlertDialogHeader>
        <FormError message={submitError} />
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <Button variant="destructive" disabled={isPending} onClick={() => void confirm()}>
            Excluir
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

export function ResourcePage<T extends { id: string }>({ config, toolbar }: { config: ResourceConfig<T>; toolbar?: ReactNode }) {
  const api = useApi()
  const invalidate = useInvalidateResources()
  const { tenantSlug } = useSession()
  const [params, setParams] = useSearchParams()
  const [dialog, setDialog] = useState<DialogState<T>>(null)

  const tenantPath = `/tenants/${encodeURIComponent(tenantSlug)}`
  const basePath = `${tenantPath}${config.basePath}`
  const itemPath = (row: T) => `${tenantPath}${config.itemPath?.(row) ?? `${config.basePath}/${encodeURIComponent(row.id)}`}`
  const filterValues = Object.fromEntries((config.filters ?? []).map((filter) => [filter.name, params.get(filter.name) ?? ""]))
  const requestedPage = Number(params.get("pagina"))
  const page = Number.isSafeInteger(requestedPage) && requestedPage >= 1 ? requestedPage : 1
  const listPath = R.buildListPath(basePath, { page, filters: { ...filterValues, ...config.listParams } })

  const list = useQuery({
    queryKey: [...resourceKey(tenantSlug), listPath],
    queryFn: () => api<{ data: T[]; meta?: PageMeta }>(listPath),
    placeholderData: keepPreviousData,
  })

  const updateParams = (changes: Record<string, string>) => {
    const next = new URLSearchParams(params)
    Object.entries(changes).forEach(([key, value]) => (value ? next.set(key, value) : next.delete(key)))
    setParams(next, { replace: true })
  }
  const closeDialog = () => setDialog(null)

  async function create(values: FormValues) {
    await api(basePath, { method: "POST", body: R.toFullPayload(config.fields, values, "create") })
    await invalidate()
    toast.success("Registro criado.")
    closeDialog()
  }

  async function update(row: T, values: FormValues) {
    const body =
      config.updateMode === "full" ? R.toFullPayload(config.fields, values, "edit") : R.toChangedPayload(config.fields, values, row)
    if (!Object.keys(body).length) {
      closeDialog()
      return
    }
    await api(itemPath(row), { method: config.updateMethod, body: { ...body, ...config.updateExtras?.(row) } })
    await invalidate()
    toast.success("Alterações salvas.")
    closeDialog()
  }

  async function remove(row: T) {
    await api(itemPath(row), { method: "DELETE" })
    await invalidate()
    toast.success("Registro excluído.")
    closeDialog()
  }

  const actionsColumn: Column<T> = {
    key: "actions",
    header: "Ações",
    isActions: true,
    className: "lg:w-28",
    cell: (row) => (
      <div className="flex items-center justify-end gap-1">
        {config.rowActions?.(row)}
        {(config.canEditRow?.(row) ?? true) && (
          <IconAction label={`Editar ${config.rowName(row)}`} tooltip="Editar" onClick={() => setDialog({ kind: "edit", row })}>
            <Pencil />
          </IconAction>
        )}
        {config.canDelete && (
          <IconAction label={`Excluir ${config.rowName(row)}`} tooltip="Excluir" onClick={() => setDialog({ kind: "delete", row })}>
            <Trash2 />
          </IconAction>
        )}
      </div>
    ),
  }

  const rows = list.data?.data ?? []

  function renderResults() {
    if (list.isError) {
      return <StateMessage role="alert" message={errorMessage(list.error)} action={{ label: "Tentar novamente", onClick: () => void list.refetch() }} />
    }
    if (list.isPending) return <TableSkeleton label={`Carregando ${config.label.toLowerCase()}...`} columns={[...config.columns, actionsColumn]} />
    if (!rows.length) return <StateMessage role="status" message={config.emptyMessage} />
    return (
      <>
        <DataTable label={config.label} columns={[...config.columns, actionsColumn]} rows={rows} getRowKey={(row) => row.id} isFetching={list.isFetching} />
        {list.data?.meta && <ListPagination meta={list.data.meta} onPage={(next) => updateParams({ pagina: next > 1 ? String(next) : "" })} />}
      </>
    )
  }

  return (
    <>
      <div className="flex flex-col gap-4 sm:flex-row sm:flex-wrap sm:items-end sm:justify-between">
        <div className="flex flex-col gap-4 sm:flex-row sm:flex-wrap">
          {toolbar}
          {config.filters?.map((filter) => (
            <FilterSelect key={filter.name} filter={filter} value={filterValues[filter.name]} onChange={(value) => updateParams({ [filter.name]: value, pagina: "" })} />
          ))}
        </div>
        {config.newLabel && (
          <Button onClick={() => setDialog({ kind: "create" })}>
            <Plus />
            {config.newLabel}
          </Button>
        )}
      </div>

      <Card className="gap-0 py-0">{renderResults()}</Card>

      {dialog?.kind === "create" && (
        <ResourceFormDialog title={config.newLabel ?? ""} fields={config.fields} mode="create" row={null} onSubmit={create} onClose={closeDialog} />
      )}
      {dialog?.kind === "edit" && (
        <ResourceFormDialog title={config.editTitle} fields={config.fields} mode="edit" row={dialog.row} onSubmit={(values) => update(dialog.row, values)} onClose={closeDialog} />
      )}
      {dialog?.kind === "delete" && <DeleteDialog name={config.rowName(dialog.row)} onConfirm={() => remove(dialog.row)} onClose={closeDialog} />}
    </>
  )
}
