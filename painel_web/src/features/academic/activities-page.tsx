import { useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { ListChecks } from "lucide-react"

import { useAllClasses, type ClassRow } from "./lookups"
import { LOOKUP_PAGE_SIZE, fetchAllPages, type PageResult } from "@/lib/fetch-all-pages"
import { DataTable, type Column } from "@/components/data-table"
import { TableSkeleton } from "@/components/loading-skeletons"
import { StateMessage } from "@/components/page-states"
import { IconAction } from "@/components/resource/resource-page"
import { Badge } from "@/components/ui/badge"
import { Card } from "@/components/ui/card"
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { useApi, useSession } from "@/features/auth/use-auth"
import { errorMessage } from "@/features/users/users-model"

type Activity = { id: string; title: string; type: string; dueDate?: string; state?: string }
type Grade = { studentId: string; studentName: string; grade: number | null; feedback?: string }

const STATE_LABELS: Record<string, string> = { draft: "Rascunho", published: "Publicada", closed: "Encerrada" }
const dateFormat = new Intl.DateTimeFormat("pt-BR", { dateStyle: "short" })
const formatDate = (value?: string) => (value ? dateFormat.format(new Date(value)) : "—")

function useTenantBase() {
  const { tenantSlug } = useSession()
  return `/tenants/${encodeURIComponent(tenantSlug)}`
}

function GradesDialog({ activity, onClose }: { activity: Activity; onClose: () => void }) {
  const api = useApi()
  const base = useTenantBase()
  const grades = useQuery({
    queryKey: ["grades", activity.id],
    queryFn: async () => (await api<{ data: Grade[] }>(`${base}/activities/${encodeURIComponent(activity.id)}/grades`)).data ?? [],
  })
  const columns: Column<Grade>[] = [
    { key: "student", header: "Aluno", isPrimary: true, cell: (row) => <span className="font-medium">{row.studentName}</span> },
    { key: "grade", header: "Nota", cell: (row) => row.grade ?? "—" },
    { key: "feedback", header: "Devolutiva", cell: (row) => <span className="min-w-0 lg:whitespace-normal">{row.feedback || "—"}</span> },
  ]

  function renderBody() {
    if (grades.isError) return <StateMessage role="alert" message={errorMessage(grades.error)} />
    if (grades.isPending) return <TableSkeleton label="Carregando notas..." columns={columns} rows={4} />
    if (!grades.data.length) return <StateMessage role="status" message="Nenhuma nota lançada nesta atividade." />
    return <DataTable label="Notas" columns={columns} rows={grades.data} getRowKey={(row) => row.studentId} />
  }

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[calc(100svh-2rem)] overflow-y-auto sm:max-w-2xl">
        <DialogHeader>
          <DialogTitle>{activity.title}</DialogTitle>
          <DialogDescription>Notas lançadas pelo professor da turma.</DialogDescription>
        </DialogHeader>
        {renderBody()}
      </DialogContent>
    </Dialog>
  )
}

function ActivitiesList({ classRow }: { classRow: ClassRow }) {
  const api = useApi()
  const base = useTenantBase()
  const [selected, setSelected] = useState<Activity | null>(null)
  const activities = useQuery({
    queryKey: ["activities", classRow.id],
    queryFn: () => fetchAllPages<Activity>((page) => api<PageResult<Activity>>(`${base}/classes/${encodeURIComponent(classRow.id)}/activities?page=${page}&limit=${LOOKUP_PAGE_SIZE}`)),
  })
  const columns: Column<Activity>[] = [
    { key: "title", header: "Atividade", isPrimary: true, cell: (row) => <span className="font-medium">{row.title}</span> },
    { key: "due", header: "Prazo", cell: (row) => formatDate(row.dueDate) },
    { key: "state", header: "Situação", cell: (row) => <Badge variant="secondary">{STATE_LABELS[row.state ?? ""] ?? row.state ?? "—"}</Badge> },
    {
      key: "actions",
      header: "Ações",
      isActions: true,
      className: "lg:w-16",
      cell: (row) => (
        <div className="flex justify-end">
          <IconAction label={`Ver notas de ${row.title}`} tooltip="Ver notas" onClick={() => setSelected(row)}>
            <ListChecks />
          </IconAction>
        </div>
      ),
    },
  ]

  function renderBody() {
    if (activities.isError) {
      return <StateMessage role="alert" message={errorMessage(activities.error)} action={{ label: "Tentar novamente", onClick: () => void activities.refetch() }} />
    }
    if (activities.isPending) return <TableSkeleton label="Carregando atividades..." columns={columns} />
    if (!activities.data.length) return <StateMessage role="status" message="Nenhuma atividade nesta turma." />
    return <DataTable label="Atividades" columns={columns} rows={activities.data} getRowKey={(row) => row.id} />
  }

  return (
    <>
      <Card className="gap-0 py-0">{renderBody()}</Card>
      {selected && <GradesDialog activity={selected} onClose={() => setSelected(null)} />}
    </>
  )
}

export function ActivitiesPage() {
  const classes = useAllClasses()
  const [selectedId, setSelectedId] = useState("")
  const classRow = classes.find((item) => item.id === selectedId) ?? classes[0]

  return (
    <>
      <div className="grid gap-2 sm:max-w-md">
        <Label htmlFor="activities-class">Turma</Label>
        <Select value={classRow?.id ?? ""} onValueChange={setSelectedId}>
          <SelectTrigger id="activities-class" className="w-full">
            <SelectValue placeholder="Selecione" />
          </SelectTrigger>
          <SelectContent>
            {classes.map((item) => (
              <SelectItem key={item.id} value={item.id}>
                {item.name}
              </SelectItem>
            ))}
          </SelectContent>
        </Select>
      </div>
      {classRow && <ActivitiesList key={classRow.id} classRow={classRow} />}
    </>
  )
}
