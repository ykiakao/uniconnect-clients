import { Link } from "react-router"

import { NAV_ITEMS } from "@/components/layout/navigation"
import { Card, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useSession } from "@/features/auth/use-auth"
import { formatAdminRole, formatPlan, formatStatus } from "@/lib/format"

function HeroMetric({ label, value, detail }: { label: string; value: string; detail: string }) {
  return (
    <div className="grid gap-1">
      <span className="text-xs font-medium uppercase tracking-wide text-white/70">{label}</span>
      <strong className="text-2xl font-semibold">{value}</strong>
      <span className="text-sm text-white/70">{detail}</span>
    </div>
  )
}

export function DashboardPage() {
  const { user, tenant } = useSession()
  const firstName = user.name.split(" ")[0] ?? user.name
  const modules = NAV_ITEMS.filter((item) => item.path !== "/")

  return (
    <>
      <section className="grid gap-6 rounded-xl bg-navy p-6 text-white">
        <h2 className="text-xl font-semibold">Olá, {firstName}</h2>
        <div className="grid gap-6 sm:grid-cols-3">
          <HeroMetric label="Instituição" value={tenant.name} detail={formatPlan(tenant.plan)} />
          <HeroMetric
            label="Usuários ativos"
            value={String(tenant.activeUsers ?? "—")}
            detail="Vinculados à instituição"
          />
          <HeroMetric label="Perfil" value={formatAdminRole(user.role)} detail={formatStatus(tenant.status)} />
        </div>
      </section>

      <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-3" aria-label="Módulos do painel">
        {modules.map((item) => (
          <Link key={item.path} to={item.path} className="min-w-0 rounded-xl focus-visible:ring-3 focus-visible:ring-ring/50 focus-visible:outline-none">
            <Card className="h-full transition-colors hover:border-primary">
              <CardHeader>
                <CardTitle className="flex flex-wrap items-center gap-2">
                  <item.icon className="size-5 text-muted-foreground" />
                  {item.label}
                </CardTitle>
                <CardDescription>{item.description}</CardDescription>
              </CardHeader>
            </Card>
          </Link>
        ))}
      </section>
    </>
  )
}
