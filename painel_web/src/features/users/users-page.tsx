import { useEffect, useState } from "react"
import { Plus, Search } from "lucide-react"
import { useSearchParams } from "react-router"
import { toast } from "sonner"

import * as Model from "./users-model"
import type { ManagedUser, RoleFilter, UserFilters } from "./users-model"
import { useCoursesQuery, useRoleCountsQuery, useSetUserActiveMutation, useUsersQuery } from "./users-api"
import { UsersTable } from "./users-table"
import { DeactivateUserDialog, UserFormDialog } from "./user-form-dialog"
import { TableSkeleton } from "@/components/loading-skeletons"
import { ListPagination, StateMessage } from "@/components/page-states"
import { Button } from "@/components/ui/button"
import { Card } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group"
import { useSession } from "@/features/auth/use-auth"

const SEARCH_DEBOUNCE_MS = 300
const ALL_ROLES = "all"
const LOADING_COLUMNS = [
  { key: "name", header: "Nome", isPrimary: true },
  { key: "role", header: "Perfil" },
  { key: "course", header: "Curso" },
  { key: "status", header: "Status" },
  { key: "actions", header: "Ações", isActions: true },
]

type DialogState = { kind: "create" } | { kind: "edit"; user: ManagedUser } | { kind: "deactivate"; user: ManagedUser } | null

function RoleChips({ value, counts, onChange }: { value: RoleFilter; counts?: Record<string, number>; onChange: (role: RoleFilter) => void }) {
  const chips = [
    { value: ALL_ROLES, label: "Todos", count: counts?.[""] },
    ...Model.ROLE_OPTIONS.map((option) => ({ value: option.value as string, label: option.plural, count: counts?.[option.value] })),
  ]
  return (
    <ToggleGroup
      type="single"
      variant="outline"
      size="sm"
      spacing={2}
      className="flex-wrap"
      aria-label="Filtrar por perfil"
      value={value || ALL_ROLES}
      onValueChange={(next) => {
        if (next) onChange(next === ALL_ROLES ? "" : (next as RoleFilter))
      }}
    >
      {chips.map((chip) => (
        <ToggleGroupItem
          key={chip.value}
          value={chip.value}
          className="rounded-full data-[state=on]:bg-primary data-[state=on]:text-primary-foreground"
        >
          {chip.label}
          {chip.count !== undefined && <span className="font-normal tabular-nums">{chip.count}</span>}
        </ToggleGroupItem>
      ))}
    </ToggleGroup>
  )
}

export function UsersPage() {
  const { user: actor } = useSession()
  const [params, setParams] = useSearchParams()
  const filters = Model.parseFilters(params)
  // Text being typed and not yet in the URL; otherwise the input shows the URL's search.
  const [draft, setDraft] = useState<string | null>(null)
  const [dialog, setDialog] = useState<DialogState>(null)

  const users = useUsersQuery(filters)
  const counts = useRoleCountsQuery(filters.search)
  const courses = useCoursesQuery()
  const setActive = useSetUserActiveMutation()
  const canCreate = Model.assignableRoles(actor.role).length > 0

  const updateFilters = (patch: Partial<UserFilters>) => {
    setParams(Model.filtersToParams({ ...filters, page: 1, ...patch }), { replace: true })
  }

  // Depends on the URL too, so a filter changed during the wait is kept.
  useEffect(() => {
    if (draft === null) return
    const current = Model.parseFilters(params)
    if (draft === current.search) {
      setDraft(null)
      return
    }
    const timer = setTimeout(() => setParams(Model.filtersToParams({ ...current, page: 1, search: draft }), { replace: true }), SEARCH_DEBOUNCE_MS)
    return () => clearTimeout(timer)
  }, [draft, params, setParams])

  const clearFilters = () => {
    setDraft(null)
    updateFilters({ search: "", role: "" })
  }

  const reactivate = async (user: ManagedUser) => {
    try {
      await setActive.mutateAsync({ id: user.id, active: true })
      toast.success("Acesso reativado.")
    } catch (error) {
      toast.error(Model.errorMessage(error))
    }
  }

  const closeDialog = () => setDialog(null)
  const list = users.data?.data ?? []
  const isFiltered = Boolean(filters.search.trim() || filters.role)

  function renderResults() {
    if (users.isError) {
      return (
        <StateMessage
          role="alert"
          message={Model.errorMessage(users.error)}
          action={{ label: "Tentar novamente", onClick: () => void users.refetch() }}
        />
      )
    }
    if (users.isPending) return <TableSkeleton label="Carregando usuários..." columns={LOADING_COLUMNS} />
    if (!list.length) {
      return isFiltered ? (
        <StateMessage role="status" message="Nenhum usuário encontrado com esses filtros." action={{ label: "Limpar filtros", onClick: clearFilters }} />
      ) : (
        <StateMessage role="status" message="Nenhum usuário cadastrado ainda." />
      )
    }
    return (
      <>
        <UsersTable
          users={list}
          actor={actor}
          courses={courses.data ?? []}
          isFetching={users.isFetching}
          onEdit={(user) => setDialog({ kind: "edit", user })}
          onToggleStatus={(user) => (user.active ? setDialog({ kind: "deactivate", user }) : void reactivate(user))}
        />
        {users.data?.meta && <ListPagination meta={users.data.meta} onPage={(page) => updateFilters({ page })} />}
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
            aria-label="Buscar por nome ou e-mail"
            placeholder="Buscar por nome ou e-mail"
            className="pl-8"
            value={draft ?? filters.search}
            onChange={(event) => setDraft(event.target.value)}
          />
        </div>
        {canCreate && (
          <Button onClick={() => setDialog({ kind: "create" })}>
            <Plus />
            Novo usuário
          </Button>
        )}
      </div>

      <Card className="gap-0 py-0">
        <div className="border-b p-4">
          <RoleChips value={filters.role} counts={counts.data} onChange={(role) => updateFilters({ role })} />
        </div>
        {renderResults()}
      </Card>

      {(dialog?.kind === "create" || dialog?.kind === "edit") && (
        <UserFormDialog
          user={dialog.kind === "edit" ? dialog.user : null}
          actor={actor}
          courses={courses.data ?? []}
          coursesFailed={courses.isError}
          onClose={closeDialog}
        />
      )}
      {dialog?.kind === "deactivate" && <DeactivateUserDialog user={dialog.user} onClose={closeDialog} />}
    </>
  )
}
