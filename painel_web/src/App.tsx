import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { BrowserRouter, Navigate, Route, Routes } from "react-router"

import { AppLayout } from "@/components/layout/app-layout"
import { AppShellSkeleton } from "@/components/loading-skeletons"
import { Toaster } from "@/components/ui/sonner"
import { TooltipProvider } from "@/components/ui/tooltip"
import {
  AssignmentsPage,
  ClassesPage,
  CoursesPage,
  EnrollmentsPage,
  OfferingsPage,
  PeriodsPage,
  SubjectsPage,
} from "@/features/academic/academic-pages"
import { ActivitiesPage } from "@/features/academic/activities-page"
import { AuthProvider } from "@/features/auth/auth-provider"
import { LoginPage } from "@/features/auth/login-page"
import { InviteAcceptPage, RecoverPasswordPage, SetPasswordPage } from "@/features/auth/public-pages"
import { useAuth } from "@/features/auth/use-auth"
import { DashboardPage } from "@/features/dashboard/dashboard-page"
import { BillingPage, SettingsPage } from "@/features/institution/institution-pages"
import { InvitesPage } from "@/features/invites/invites-page"
import { NoticesPage } from "@/features/notices/notices-page"
import { PlatformApp } from "@/features/platform/platform-app"
import { ReportsPage } from "@/features/reports/reports-page"
import { UsersPage } from "@/features/users/users-page"

const queryClient = new QueryClient({
  defaultOptions: { queries: { retry: false, refetchOnWindowFocus: false } },
})

function ProtectedRoutes() {
  const { status } = useAuth()

  if (status === "restoring") return <AppShellSkeleton />
  if (status === "anonymous") return <LoginPage />

  return (
    <Routes>
      <Route element={<AppLayout />}>
        <Route index element={<DashboardPage />} />
        <Route path="usuarios" element={<UsersPage />} />
        <Route path="convites" element={<InvitesPage />} />
        <Route path="cursos" element={<CoursesPage />} />
        <Route path="turmas" element={<ClassesPage />} />
        <Route path="periodos" element={<PeriodsPage />} />
        <Route path="disciplinas" element={<SubjectsPage />} />
        <Route path="ofertas" element={<OfferingsPage />} />
        <Route path="matriculas" element={<EnrollmentsPage />} />
        <Route path="professores-turma" element={<AssignmentsPage />} />
        <Route path="atividades" element={<ActivitiesPage />} />
        <Route path="avisos" element={<NoticesPage />} />
        <Route path="relatorios" element={<ReportsPage />} />
        <Route path="assinatura" element={<BillingPage />} />
        <Route path="configuracoes" element={<SettingsPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  )
}

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <TooltipProvider>
          <BrowserRouter>
            <Routes>
              <Route path="recuperar-senha" element={<RecoverPasswordPage />} />
              <Route path="password/reset" element={<SetPasswordPage kind="reset" />} />
              <Route path="accounts/activate" element={<SetPasswordPage kind="activate" />} />
              <Route path="convites/:code" element={<InviteAcceptPage />} />
              <Route path="plataforma/*" element={<PlatformApp />} />
              <Route path="*" element={<ProtectedRoutes />} />
            </Routes>
          </BrowserRouter>
          <Toaster theme="light" />
        </TooltipProvider>
      </AuthProvider>
    </QueryClientProvider>
  )
}
