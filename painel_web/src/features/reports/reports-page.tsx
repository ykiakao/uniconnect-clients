import { useQuery } from "@tanstack/react-query"

import { ChartSkeleton, MetricCardsSkeleton } from "@/components/loading-skeletons"
import { StateMessage } from "@/components/page-states"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useApi, useSession } from "@/features/auth/use-auth"
import { errorMessage } from "@/features/users/users-model"

type Summary = { totalUsers: number; totalCourses: number; totalClasses: number; activeStudents: number }
type Engagement = { labels: string[]; values: number[] }

function Metric({ label, value }: { label: string; value: number }) {
  return (
    <Card>
      <CardHeader>
        <CardDescription>{label}</CardDescription>
        <CardTitle className="text-3xl tabular-nums">{value}</CardTitle>
      </CardHeader>
    </Card>
  )
}

function EngagementChart({ data }: { data: Engagement }) {
  const max = Math.max(...data.values, 1)
  return (
    <ul className="flex h-48 items-end gap-2" aria-label="Engajamento por dia">
      {data.labels.map((label, index) => (
        <li key={label} className="flex h-full min-w-0 flex-1 flex-col items-center justify-end gap-2">
          <span className="text-xs tabular-nums text-muted-foreground">{data.values[index]}</span>
          <span className="w-full rounded-t-md bg-primary" style={{ height: `${(data.values[index] / max) * 100}%` }} />
          <span className="max-w-full truncate text-xs text-muted-foreground" title={label}>
            {label.slice(5)}
          </span>
        </li>
      ))}
    </ul>
  )
}

export function ReportsPage() {
  const api = useApi()
  const { tenantSlug } = useSession()
  const base = `/tenants/${encodeURIComponent(tenantSlug)}/reports`
  const summary = useQuery({ queryKey: ["reports", tenantSlug, "summary"], queryFn: () => api<Summary>(`${base}/summary`) })
  const engagement = useQuery({ queryKey: ["reports", tenantSlug, "engagement"], queryFn: () => api<Engagement>(`${base}/engagement`) })

  if (summary.isError) return <StateMessage role="alert" message={errorMessage(summary.error)} action={{ label: "Tentar novamente", onClick: () => void summary.refetch() }} />

  return (
    <>
      {summary.isPending ? (
        <MetricCardsSkeleton label="Carregando relatórios..." />
      ) : (
        <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" aria-label="Resumo da instituição">
          <Metric label="Usuários" value={summary.data.totalUsers} />
          <Metric label="Alunos ativos" value={summary.data.activeStudents} />
          <Metric label="Cursos" value={summary.data.totalCourses} />
          <Metric label="Turmas" value={summary.data.totalClasses} />
        </section>
      )}
      <Card>
        <CardHeader>
          <CardTitle>Engajamento</CardTitle>
          <CardDescription>Atividade registrada por dia na instituição.</CardDescription>
        </CardHeader>
        <CardContent>
          {engagement.isError && <StateMessage role="alert" message={errorMessage(engagement.error)} />}
          {engagement.isPending && <ChartSkeleton label="Carregando engajamento..." />}
          {engagement.data && engagement.data.labels.length === 0 && <StateMessage role="status" message="Sem atividade registrada no período." />}
          {engagement.data && engagement.data.labels.length > 0 && <EngagementChart data={engagement.data} />}
        </CardContent>
      </Card>
    </>
  )
}
