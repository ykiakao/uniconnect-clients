import { useCallback, useEffect, useMemo, useState } from "react"
import { useQuery } from "@tanstack/react-query"
import { Building2, ChartColumn, LogOut } from "lucide-react"
import { useForm } from "react-hook-form"
import { Link, NavLink, Navigate, Outlet, Route, Routes, useLocation } from "react-router"

import { InstitutionDetailPage } from "./institution-detail-page"
import { InstitutionsPage } from "./institutions-page"
import { clearPlatformSession, platformLogin, restorePlatformSession, type PlatformSession } from "./platform-session"
import { PlatformContext, usePlatform, usePlatformApi } from "./use-platform"
import { AppShellSkeleton, MetricCardsSkeleton } from "@/components/loading-skeletons"
import { FormError, FormField, StateMessage } from "@/components/page-states"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Separator } from "@/components/ui/separator"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
  useSidebar,
} from "@/components/ui/sidebar"
import { SidebarBrand } from "@/components/layout/sidebar-brand"
import { safeAuthError } from "@/features/auth/session"
import { errorMessage } from "@/features/users/users-model"
import { PLACEHOLDERS } from "@/lib/placeholders"

const NAV = [
  { path: "/plataforma", label: "Instituições", icon: Building2 },
  { path: "/plataforma/relatorios", label: "Relatório global", icon: ChartColumn },
]

function PlatformLogin({ initialError, onLogin }: { initialError: string; onLogin: (session: PlatformSession) => void }) {
  const [submitError, setSubmitError] = useState("")
  const { register, handleSubmit, formState } = useForm({ defaultValues: { email: "", password: "" } })
  const error = submitError || initialError

  const onSubmit = handleSubmit(async ({ email, password }) => {
    setSubmitError("")
    try {
      onLogin(await platformLogin(email, password))
    } catch (caught) {
      setSubmitError(safeAuthError(caught))
    }
  })

  return (
    <main className="flex min-h-svh flex-col items-center justify-center gap-6 bg-card p-6">
      <div className="flex w-full max-w-md flex-col gap-6">
        <img src="/brand/uniconnect-logo-vertical.png" alt="UniConnect" className="mx-auto h-24 w-auto" />
        <Card className="bg-background">
          <CardHeader>
            <CardTitle className="text-xl">Administração da plataforma</CardTitle>
            <CardDescription>Acesso exclusivo para a equipe que gerencia todas as instituições.</CardDescription>
          </CardHeader>
          <CardContent>
            <form className="grid gap-4" onSubmit={onSubmit}>
              <FormError message={error} />
              <FormField id="platform-email" label="E-mail">
                <Input id="platform-email" type="email" placeholder={PLACEHOLDERS.email} required autoComplete="email" {...register("email", { required: true })} />
              </FormField>
              <FormField id="platform-password" label="Senha">
                <Input id="platform-password" type="password" placeholder={PLACEHOLDERS.currentPassword} required autoComplete="current-password" {...register("password", { required: true })} />
              </FormField>
              <Button type="submit" disabled={formState.isSubmitting}>
                {formState.isSubmitting ? "Entrando..." : "Entrar"}
              </Button>
            </form>
          </CardContent>
        </Card>
        <p className="text-center text-sm text-muted-foreground">
          É de uma instituição?{" "}
          <Link to="/" className="font-medium text-primary hover:underline">
            Portal da coordenação
          </Link>
        </p>
      </div>
    </main>
  )
}

function PlatformSidebar() {
  const { logout } = usePlatform()
  const { pathname } = useLocation()
  const { setOpenMobile } = useSidebar()
  const isActive = (path: string) => (path === "/plataforma" ? pathname === path || pathname.includes("/instituicoes/") : pathname === path)

  return (
    <Sidebar>
      <SidebarBrand subtitle="Administração da plataforma" />
      <SidebarContent>
        <SidebarGroup>
          <SidebarGroupContent>
            <SidebarMenu>
              {NAV.map((item) => (
                <SidebarMenuItem key={item.path}>
                  <SidebarMenuButton asChild isActive={isActive(item.path)}>
                    <NavLink to={item.path} end onClick={() => setOpenMobile(false)}>
                      <item.icon />
                      <span>{item.label}</span>
                    </NavLink>
                  </SidebarMenuButton>
                </SidebarMenuItem>
              ))}
            </SidebarMenu>
          </SidebarGroupContent>
        </SidebarGroup>
      </SidebarContent>
      <SidebarFooter className="p-4">
        <Button variant="outline" onClick={logout}>
          <LogOut />
          Sair
        </Button>
      </SidebarFooter>
    </Sidebar>
  )
}

function PlatformLayout() {
  const { pathname } = useLocation()
  const title = pathname.endsWith("/relatorios") ? "Relatório global" : "Instituições"
  return (
    <SidebarProvider>
      <PlatformSidebar />
      <SidebarInset className="min-w-0">
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4 md:px-6">
          <SidebarTrigger className="-ml-1" aria-label="Alternar menu" />
          <Separator orientation="vertical" className="mr-2 data-vertical:h-4 data-vertical:self-center" />
          <h1 className="truncate text-lg font-semibold">{title}</h1>
        </header>
        <main className="flex min-w-0 flex-1 flex-col gap-6 p-4 md:p-6">
          <Outlet />
        </main>
      </SidebarInset>
    </SidebarProvider>
  )
}

function GlobalReportPage() {
  const api = usePlatformApi()
  const report = useQuery({ queryKey: ["platform", "report"], queryFn: () => api<Record<string, unknown>>("/admin/reports/global") })

  if (report.isError) return <StateMessage role="alert" message={errorMessage(report.error)} action={{ label: "Tentar novamente", onClick: () => void report.refetch() }} />
  if (report.isPending) return <MetricCardsSkeleton label="Carregando relatório..." />

  const LABELS: Record<string, string> = { totalTenants: "Instituições", totalUsers: "Usuários", totalCourses: "Cursos", totalClasses: "Turmas", activeStudents: "Alunos ativos" }
  const metrics = Object.entries(report.data).filter(([, value]) => typeof value === "number") as [string, number][]
  if (!metrics.length) return <StateMessage role="status" message="Sem indicadores disponíveis." />
  return (
    <section className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4" aria-label="Indicadores globais">
      {metrics.map(([key, value]) => (
        <Card key={key}>
          <CardHeader>
            <CardDescription>{LABELS[key] ?? key}</CardDescription>
            <CardTitle className="text-3xl tabular-nums">{value}</CardTitle>
          </CardHeader>
        </Card>
      ))}
    </section>
  )
}

export function PlatformApp() {
  const [status, setStatus] = useState<"restoring" | "ready">("restoring")
  const [session, setSession] = useState<PlatformSession | null>(null)
  const [restoreError, setRestoreError] = useState("")

  useEffect(() => {
    let isCurrent = true
    void restorePlatformSession().then((result) => {
      if (!isCurrent) return
      setSession(result.session)
      setRestoreError(result.error)
      setStatus("ready")
    })
    return () => {
      isCurrent = false
    }
  }, [])

  const logout = useCallback(() => {
    clearPlatformSession()
    setSession(null)
  }, [])
  const value = useMemo(() => (session ? { session, logout } : null), [session, logout])

  if (status === "restoring") return <AppShellSkeleton />
  if (!value) return <PlatformLogin initialError={restoreError} onLogin={setSession} />

  return (
    <PlatformContext.Provider value={value}>
      <Routes>
        <Route element={<PlatformLayout />}>
          <Route index element={<InstitutionsPage />} />
          <Route path="instituicoes/:id" element={<InstitutionDetailPage />} />
          <Route path="relatorios" element={<GlobalReportPage />} />
          <Route path="*" element={<Navigate to="/plataforma" replace />} />
        </Route>
      </Routes>
    </PlatformContext.Provider>
  )
}
