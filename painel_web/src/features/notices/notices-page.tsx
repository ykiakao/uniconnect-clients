import { Archive, Send } from "lucide-react"
import { toast } from "sonner"

import { IconAction, ResourcePage, useInvalidateResources, type ResourceConfig } from "@/components/resource/resource-page"
import { Badge } from "@/components/ui/badge"
import { toOptions, useAllClasses, useCourses } from "@/features/academic/lookups"
import { useApi, useSession } from "@/features/auth/use-auth"
import { errorMessage } from "@/features/users/users-model"

type Notice = { id: string; title: string; content: string; state: string; priority: string; audienceType: string; revision: number }

const STATE_LABELS: Record<string, string> = { draft: "Rascunho", published: "Publicado", archived: "Arquivado" }
const AUDIENCE_LABELS: Record<string, string> = { institution: "Instituição", course: "Curso", class: "Turma" }
const PRIORITY_OPTIONS = [
  { value: "low", label: "Baixa" },
  { value: "medium", label: "Média" },
  { value: "high", label: "Alta" },
]
const AUDIENCE_OPTIONS = Object.entries(AUDIENCE_LABELS).map(([value, label]) => ({ value, label }))

export function NoticesPage() {
  const api = useApi()
  const invalidate = useInvalidateResources()
  const { tenantSlug } = useSession()
  const courses = useCourses()
  const classes = useAllClasses()
  const base = `/tenants/${encodeURIComponent(tenantSlug)}/notices`

  async function transition(row: Notice, operation: "publish" | "archive", success: string) {
    try {
      await api(`${base}/${encodeURIComponent(row.id)}/${operation}`, { method: "POST", body: { expectedRevision: row.revision } })
      await invalidate()
      toast.success(success)
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const config: ResourceConfig<Notice> = {
    label: "Avisos",
    newLabel: "Novo aviso",
    editTitle: "Editar aviso",
    basePath: "/notices",
    listParams: { view: "managed" },
    updateMethod: "PUT",
    updateMode: "changed",
    updateExtras: (row) => ({ expectedRevision: row.revision }),
    canEditRow: (row) => row.state !== "archived",
    emptyMessage: "Nenhum aviso criado ainda.",
    rowName: (row) => row.title,
    columns: [
      { key: "title", header: "Título", isPrimary: true, cell: (row) => <span className="font-medium">{row.title}</span> },
      { key: "audience", header: "Público", cell: (row) => AUDIENCE_LABELS[row.audienceType] ?? row.audienceType },
      { key: "state", header: "Situação", cell: (row) => <Badge variant="secondary">{STATE_LABELS[row.state] ?? row.state}</Badge> },
    ],
    fields: [
      { name: "title", label: "Título", required: true, maxLength: 200, placeholder: "Ex.: Calendário de provas" },
      { name: "content", label: "Mensagem", type: "textarea", required: true, maxLength: 10000, placeholder: "Escreva a mensagem do aviso" },
      { name: "priority", label: "Prioridade", type: "select", required: true, defaultValue: "medium", options: PRIORITY_OPTIONS },
      { name: "audienceType", label: "Público", type: "select", required: true, createOnly: true, defaultValue: "institution", options: AUDIENCE_OPTIONS },
      { name: "courseId", label: "Curso", type: "select", required: true, createOnly: true, options: toOptions(courses), visibleWhen: (values) => values.audienceType === "course" },
      { name: "classId", label: "Turma", type: "select", required: true, createOnly: true, options: toOptions(classes), visibleWhen: (values) => values.audienceType === "class" },
    ],
    rowActions: (row) => (
      <>
        {row.state === "draft" && (
          <IconAction label={`Publicar ${row.title}`} tooltip="Publicar" onClick={() => void transition(row, "publish", "Aviso publicado.")}>
            <Send />
          </IconAction>
        )}
        {row.state === "published" && (
          <IconAction label={`Arquivar ${row.title}`} tooltip="Arquivar" onClick={() => void transition(row, "archive", "Aviso arquivado.")}>
            <Archive />
          </IconAction>
        )}
      </>
    ),
  }
  return <ResourcePage config={config} />
}
