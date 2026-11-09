import { useState } from "react"
import { keepPreviousData, useQuery, useQueryClient } from "@tanstack/react-query"
import { ChevronRight, Plus, Search } from "lucide-react"
import { Link } from "react-router"
import { toast } from "sonner"

import { usePlatformApi } from "./use-platform"
import { DataTable, type Column } from "@/components/data-table"
import { TableSkeleton } from "@/components/loading-skeletons"
import { ListPagination, StateMessage } from "@/components/page-states"
import { ResourceFormDialog } from "@/components/resource/resource-form-dialog"
import { PAGE_SIZE, type FormValues, type ResourceField } from "@/components/resource/resource-model"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { errorMessage, type PageMeta } from "@/features/users/users-model"

export type Institution = {
  id: string
  name: string
  slug: string
  operationalStatus: "active" | "suspended"
  version: number
  createdAt: string
  updatedAt: string
}

export const INSTITUTIONS_PATH = "/platform/institutions"
export const NAME_FIELD: ResourceField = { name: "name", label: "Nome", required: true, maxLength: 200, placeholder: "Ex.: Universidade Exemplo" }
const SLUG_FIELD: ResourceField = {
  name: "slug",
  label: "Identificador",
  required: true,
  maxLength: 63,
  placeholder: "Ex.: universidade-exemplo",
  hint: "Usado no login da instituição. Não pode ser alterado depois.",
  pattern: { regex: /^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/, message: "Use letras minúsculas, números e hífens, começando por letra." },
}
const ALL = "all"

export function OperationalBadge({ status }: { status: Institution["operationalStatus"] }) {
  return status === "active" ? <Badge className="bg-success-tint text-success">Ativa</Badge> : <Badge variant="destructive">Suspensa</Badge>
}

export function InstitutionsPage() {
  const api = usePlatformApi()
  const client = useQueryClient()
  const [search, setSearch] = useState("")
  const [status, setStatus] = useState("")
  const [page, setPage] = useState(1)
  const [isCreating, setIsCreating] = useState(false)
  const [idempotencyKey, setIdempotencyKey] = useState("")

  const params = new URLSearchParams({ page: String(page), limit: String(PAGE_SIZE) })
  if (search.trim()) params.set("search", search.trim())
  if (status) params.set("operationalStatus", status)
  const list = useQuery({
    queryKey: ["platform", "institutions", params.toString()],
    queryFn: () => api<{ data: Institution[]; meta: PageMeta }>(`${INSTITUTIONS_PATH}?${params}`),
    placeholderData: keepPreviousData,
  })

  function openCreate() {
    // One key per opened form, so retrying the same submission cannot create twice.
    setIdempotencyKey(crypto.randomUUID())
    setIsCreating(true)
  }

  async function create(values: FormValues) {
    await api(INSTITUTIONS_PATH, {
      method: "POST",
      body: { name: values.name.trim(), slug: values.slug.trim() },
      headers: { "Idempotency-Key": idempotencyKey },
    })
    await client.invalidateQueries({ queryKey: ["platform"] })
    toast.success("Instituição criada.")
    setIsCreating(false)
  }

  const columns: Column<Institution>[] = [
    { key: "name", header: "Nome", isPrimary: true, cell: (row) => <span className="font-medium">{row.name}</span> },
    { key: "slug", header: "Identificador", cell: (row) => row.slug },
    { key: "status", header: "Situação", className: "lg:w-32", cell: (row) => <OperationalBadge status={row.operationalStatus} /> },
    {
      key: "actions",
      header: "Ações",
      isActions: true,
      className: "lg:w-32",
      cell: (row) => (
        <div className="flex justify-end">
          <Button variant="ghost" size="sm" asChild>
            <Link to={`/plataforma/instituicoes/${row.id}`} aria-label={`Gerenciar ${row.name}`}>
              Gerenciar
              <ChevronRight />
            </Link>
          </Button>
        </div>
      ),
    },
  ]

  function renderResults() {
    if (list.isError) return <StateMessage role="alert" message={errorMessage(list.error)} action={{ label: "Tentar novamente", onClick: () => void list.refetch() }} />
    if (list.isPending) return <TableSkeleton label="Carregando instituições..." columns={columns} />
    if (!list.data.data.length) return <StateMessage role="status" message="Nenhuma instituição encontrada." />
    return (
      <>
        <DataTable label="Instituições" columns={columns} rows={list.data.data} getRowKey={(row) => row.id} isFetching={list.isFetching} />
        <ListPagination meta={list.data.meta} onPage={setPage} />
      </>
    )
  }

  return (
    <>
      <div className="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative w-full sm:max-w-sm" role="search">
          <Search className="pointer-events-none absolute top-1/2 left-2.5 size-4 -translate-y-1/2 text-muted-foreground" />
          <Input
            type="search"
            aria-label="Buscar instituição"
            placeholder="Buscar por nome"
            className="pl-8"
            maxLength={100}
            value={search}
            onChange={(event) => {
              setSearch(event.target.value)
              setPage(1)
            }}
          />
        </div>
        <Button onClick={openCreate}>
          <Plus />
          Nova instituição
        </Button>
      </div>
      <Card className="gap-0 py-0">
        <div className="border-b p-4">
          <ToggleGroup
            type="single"
            variant="outline"
            spacing={2}
            className="flex-wrap"
            aria-label="Filtrar por situação"
            value={status || ALL}
            onValueChange={(next) => {
              if (!next) return
              setStatus(next === ALL ? "" : next)
              setPage(1)
            }}
          >
            {[
              [ALL, "Todas"],
              ["active", "Ativas"],
              ["suspended", "Suspensas"],
            ].map(([value, label]) => (
              <ToggleGroupItem key={value} value={value} className="rounded-full data-[state=on]:bg-primary data-[state=on]:text-primary-foreground">
                {label}
              </ToggleGroupItem>
            ))}
          </ToggleGroup>
        </div>
        {renderResults()}
      </Card>
      {isCreating && (
        <ResourceFormDialog title="Nova instituição" fields={[NAME_FIELD, SLUG_FIELD]} mode="create" row={null} onSubmit={create} onClose={() => setIsCreating(false)} />
      )}
    </>
  )
}
