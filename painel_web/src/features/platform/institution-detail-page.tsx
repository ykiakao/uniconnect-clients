import { useState, type ReactNode } from "react"
import { useQuery, useQueryClient } from "@tanstack/react-query"
import { ArrowLeft, RefreshCw } from "lucide-react"
import { Link, useParams } from "react-router"
import { toast } from "sonner"

import { INSTITUTIONS_PATH, NAME_FIELD, OperationalBadge, type Institution } from "./institutions-page"
import { usePlatformApi } from "./use-platform"
import { PLACEHOLDERS } from "@/lib/placeholders"
import { DataTable, type Column } from "@/components/data-table"
import { LinesSkeleton, SectionsSkeleton, TableSkeleton } from "@/components/loading-skeletons"
import { FormError, StateMessage } from "@/components/page-states"
import { ResourceFormDialog } from "@/components/resource/resource-form-dialog"
import type { FormValues, ResourceField } from "@/components/resource/resource-model"
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Card, CardAction, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { ApiRequestError } from "@/lib/api-client"
import { errorMessage } from "@/features/users/users-model"

type Provision = { id: string; state: string; createdAt: string; updatedAt: string }
type Responsible = { responsibleUserId: string; version: number }
type AuditEntry = { id: string; action: string; createdAt?: string; targetUserId?: string | null }
type FormKind = "edit" | "provision" | "bootstrap" | "designate" | "replace"
type FormSpec = { title: string; fields: ResourceField[]; path: string; body: (values: FormValues) => Record<string, unknown>; success: string; row?: object }

const EMAIL_FIELD: ResourceField = {
  name: "email",
  label: "E-mail",
  required: true,
  maxLength: 254,
  placeholder: PLACEHOLDERS.email,
  pattern: { regex: /^[^\s@]+@[^\s@]+\.[^\s@]+$/, message: "Informe um e-mail válido." },
}
const UUID_FIELD: ResourceField = {
  name: "administratorId",
  label: "ID do administrador",
  required: true,
  placeholder: "Cole o ID do administrador",
  hint: "ID do vínculo administrativo já existente nesta instituição.",
  pattern: { regex: /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i, message: "Informe um ID válido." },
}
const PERSON_FIELDS = [{ ...NAME_FIELD, placeholder: PLACEHOLDERS.personName }, EMAIL_FIELD]
const PROVISION_LABELS: Record<string, string> = {
  pending: "Pendente",
  invite_requested: "Convite solicitado",
  awaiting_confirmation: "Aguardando confirmação",
  ready: "Pronto",
  needs_review: "Requer revisão",
}
const dateFormat = new Intl.DateTimeFormat("pt-BR", { dateStyle: "short", timeStyle: "short" })
const formatDate = (value?: string) => (value ? dateFormat.format(new Date(value)) : "—")
const person = (values: FormValues) => ({ name: values.name.trim(), email: values.email.trim() })

function Section({ title, description, action, children }: { title: string; description: string; action?: ReactNode; children: ReactNode }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>{title}</CardTitle>
        <CardDescription>{description}</CardDescription>
        {action && <CardAction className="flex flex-wrap justify-end gap-2">{action}</CardAction>}
      </CardHeader>
      <CardContent>{children}</CardContent>
    </Card>
  )
}

function SuspendDialog({ name, onConfirm, onClose }: { name: string; onConfirm: () => Promise<void>; onClose: () => void }) {
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
          <AlertDialogTitle>Suspender instituição</AlertDialogTitle>
          <AlertDialogDescription>Ninguém de {name} conseguirá acessar o painel ou o app enquanto ela estiver suspensa. Você pode reativá-la depois.</AlertDialogDescription>
        </AlertDialogHeader>
        <FormError message={submitError} />
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <Button variant="destructive" disabled={isPending} onClick={() => void confirm()}>
            Suspender instituição
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}

export function InstitutionDetailPage() {
  const { id = "" } = useParams()
  const api = usePlatformApi()
  const client = useQueryClient()
  const base = `${INSTITUTIONS_PATH}/${encodeURIComponent(id)}`
  const [form, setForm] = useState<{ kind: FormKind; key: string } | null>(null)
  const [isSuspending, setIsSuspending] = useState(false)
  const key = (suffix: string) => ["platform", "institution", id, suffix]

  const institution = useQuery({ queryKey: key("detail"), queryFn: () => api<Institution>(base) })
  const provisions = useQuery({ queryKey: key("provisions"), queryFn: () => api<{ data: Provision[] }>(`${base}/admin-provisioning?page=1&limit=20`) })
  const audit = useQuery({ queryKey: key("audit"), queryFn: () => api<{ data: AuditEntry[] }>(`${base}/audit?page=1&limit=20`) })
  const responsible = useQuery({
    queryKey: key("responsible"),
    queryFn: async () => {
      try {
        return await api<Responsible | null>(`${base}/responsible`)
      } catch (error) {
        if (error instanceof ApiRequestError && error.status === 404) return null
        throw error
      }
    },
  })

  const refresh = () => client.invalidateQueries({ queryKey: ["platform"] })
  const idempotent = () => ({ "Idempotency-Key": crypto.randomUUID() })
  const openForm = (kind: FormKind) => setForm({ kind, key: crypto.randomUUID() })

  if (institution.isError) return <StateMessage role="alert" message={errorMessage(institution.error)} action={{ label: "Tentar novamente", onClick: () => void institution.refetch() }} />
  if (institution.isPending) return <SectionsSkeleton label="Carregando instituição..." />

  const data = institution.data
  const current = responsible.data ?? null
  const specs: Record<FormKind, FormSpec> = {
    edit: { title: "Editar instituição", fields: [NAME_FIELD], path: base, body: (values) => ({ name: values.name.trim(), expectedVersion: data.version }), success: "Instituição atualizada.", row: data },
    provision: { title: "Convidar administrador", fields: PERSON_FIELDS, path: `${base}/admin-provisioning`, body: person, success: "Convite solicitado." },
    bootstrap: { title: "Criar vínculo do administrador", fields: PERSON_FIELDS, path: `${base}/bootstrap-admin`, body: person, success: "Administrador vinculado." },
    designate: { title: "Definir responsável", fields: [UUID_FIELD], path: `${base}/responsible/designate`, body: (values) => ({ administratorId: values.administratorId.trim(), expectedVersion: 0 }), success: "Responsável definido." },
    replace: { title: "Substituir responsável", fields: PERSON_FIELDS, path: `${base}/responsible/replace`, body: (values) => ({ ...person(values), expectedVersion: current?.version }), success: "Responsável substituído." },
  }

  async function submitForm(kind: FormKind, idempotencyKey: string, values: FormValues) {
    const spec = specs[kind]
    await api(spec.path, { method: kind === "edit" ? "PATCH" : "POST", body: spec.body(values), headers: { "Idempotency-Key": idempotencyKey } })
    await refresh()
    toast.success(spec.success)
    setForm(null)
  }

  async function changeStatus(operation: "suspend" | "reactivate", success: string) {
    await api(`${base}/${operation}`, { method: "POST", body: { expectedVersion: data.version }, headers: idempotent() })
    await refresh()
    toast.success(success)
    setIsSuspending(false)
  }

  async function reactivate() {
    try {
      await changeStatus("reactivate", "Instituição reativada.")
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  async function resumeProvision(provisionId: string) {
    try {
      await api(`${base}/admin-provisioning/${encodeURIComponent(provisionId)}/resume`, { method: "POST", body: {} })
      await refresh()
      toast.success("Provisionamento atualizado.")
    } catch (error) {
      toast.error(errorMessage(error))
    }
  }

  const provisionColumns: Column<Provision>[] = [
    { key: "state", header: "Situação", isPrimary: true, cell: (row) => <Badge variant="secondary">{PROVISION_LABELS[row.state] ?? row.state}</Badge> },
    { key: "updated", header: "Atualizado em", cell: (row) => formatDate(row.updatedAt) },
    {
      key: "actions",
      header: "Ações",
      isActions: true,
      className: "lg:w-32",
      cell: (row) => (
        <div className="flex justify-end">
          {row.state !== "ready" && (
            <Button variant="ghost" size="sm" onClick={() => void resumeProvision(row.id)}>
              <RefreshCw />
              Retomar
            </Button>
          )}
        </div>
      ),
    },
  ]
  const auditColumns: Column<AuditEntry>[] = [
    { key: "action", header: "Ação", isPrimary: true, cell: (row) => <span className="font-medium">{row.action}</span> },
    { key: "date", header: "Data", cell: (row) => formatDate(row.createdAt) },
  ]

  function renderProvisions() {
    if (provisions.isError) return <StateMessage role="alert" message={errorMessage(provisions.error)} />
    if (provisions.isPending) return <TableSkeleton label="Carregando convites..." columns={provisionColumns} rows={2} />
    if (!provisions.data.data.length) return <StateMessage role="status" message="Nenhum convite de administrador." />
    return <DataTable label="Provisionamentos" columns={provisionColumns} rows={provisions.data.data} getRowKey={(row) => row.id} />
  }

  function renderResponsible() {
    if (responsible.isError) return <StateMessage role="alert" message={errorMessage(responsible.error)} />
    if (responsible.isPending) return <LinesSkeleton label="Carregando responsável..." lines={1} />
    if (!current) return <StateMessage role="status" message="Nenhum responsável definido." />
    return <p className="text-sm break-all">{current.responsibleUserId}</p>
  }

  function renderAudit() {
    if (audit.isError) return <StateMessage role="alert" message={errorMessage(audit.error)} />
    if (audit.isPending) return <TableSkeleton label="Carregando auditoria..." columns={auditColumns} rows={3} />
    if (!audit.data.data.length) return <StateMessage role="status" message="Nenhum evento registrado." />
    return <DataTable label="Auditoria" columns={auditColumns} rows={audit.data.data} getRowKey={(row) => row.id} />
  }

  const spec = form ? specs[form.kind] : null

  return (
    <>
      <Button variant="ghost" className="self-start" asChild>
        <Link to="/plataforma">
          <ArrowLeft />
          Voltar para instituições
        </Link>
      </Button>

      <Section
        title={data.name}
        description={`Identificador: ${data.slug}`}
        action={
          <>
            <Button variant="outline" onClick={() => openForm("edit")}>
              Editar
            </Button>
            {data.operationalStatus === "active" ? (
              <Button variant="destructive" onClick={() => setIsSuspending(true)}>
                Suspender
              </Button>
            ) : (
              <Button variant="outline" onClick={() => void reactivate()}>
                Reativar
              </Button>
            )}
          </>
        }
      >
        <OperationalBadge status={data.operationalStatus} />
      </Section>

      <Section
        title="Administradores"
        description="O convite cria a conta. Depois de pronta, crie o vínculo com a instituição."
        action={
          <>
            <Button variant="outline" onClick={() => openForm("bootstrap")}>
              Criar vínculo
            </Button>
            <Button onClick={() => openForm("provision")}>Convidar</Button>
          </>
        }
      >
        {renderProvisions()}
      </Section>

      <Section
        title="Responsável"
        description="Pessoa que responde pela instituição na plataforma."
        action={<Button variant="outline" onClick={() => openForm(current ? "replace" : "designate")}>{current ? "Substituir" : "Definir"}</Button>}
      >
        {renderResponsible()}
      </Section>

      <Section title="Auditoria" description="Últimas ações administrativas nesta instituição.">
        {renderAudit()}
      </Section>

      {form && spec && (
        <ResourceFormDialog title={spec.title} fields={spec.fields} mode="edit" row={spec.row ?? null} onSubmit={(values) => submitForm(form.kind, form.key, values)} onClose={() => setForm(null)} />
      )}
      {isSuspending && <SuspendDialog name={data.name} onConfirm={() => changeStatus("suspend", "Instituição suspensa.")} onClose={() => setIsSuspending(false)} />}
    </>
  )
}
