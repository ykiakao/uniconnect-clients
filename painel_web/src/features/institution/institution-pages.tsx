import { Badge } from "@/components/ui/badge"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useSession } from "@/features/auth/use-auth"
import { formatAdminRole, formatPlan, formatStatus } from "@/lib/format"

function InfoList({ items }: { items: [string, string][] }) {
  return (
    <dl className="grid gap-4 sm:grid-cols-2">
      {items.map(([label, value]) => (
        <div key={label} className="grid min-w-0 gap-1">
          <dt className="text-sm text-muted-foreground">{label}</dt>
          <dd className="font-medium break-words">{value}</dd>
        </div>
      ))}
    </dl>
  )
}

function ReadOnlyCard({ title, description, items }: { title: string; description: string; items: [string, string][] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex flex-wrap items-center gap-2">
          {title}
          <Badge variant="secondary">Somente leitura</Badge>
        </CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent>
        <InfoList items={items} />
      </CardContent>
    </Card>
  )
}

export function BillingPage() {
  const { tenant } = useSession()
  return (
    <ReadOnlyCard
      title="Assinatura"
      description="Plano e situação atuais da instituição."
      items={[
        ["Plano", formatPlan(tenant.plan)],
        ["Situação", formatStatus(tenant.status)],
        ["Usuários ativos", String(tenant.activeUsers ?? "—")],
      ]}
    />
  )
}

export function SettingsPage() {
  const { tenant, user } = useSession()
  return (
    <>
      <ReadOnlyCard
        title="Instituição"
        description="Dados usados para identificar a instituição."
        items={[
          ["Nome", tenant.name],
          ["Identificador", tenant.slug],
        ]}
      />
      <ReadOnlyCard
        title="Sessão"
        description="Conta em uso neste navegador."
        items={[
          ["Nome", user.name],
          ["E-mail", user.email],
          ["Perfil", formatAdminRole(user.role)],
        ]}
      />
    </>
  )
}
