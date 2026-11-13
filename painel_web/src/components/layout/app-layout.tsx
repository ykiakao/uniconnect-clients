import { LogOut } from "lucide-react"
import { NavLink, Outlet, useLocation } from "react-router"

import { NAV_GROUPS, NAV_ITEMS } from "./navigation"
import { SidebarBrand } from "./sidebar-brand"
import { Button } from "@/components/ui/button"
import { Separator } from "@/components/ui/separator"
import {
  Sidebar,
  SidebarContent,
  SidebarFooter,
  SidebarGroup,
  SidebarGroupContent,
  SidebarGroupLabel,
  SidebarInset,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
  SidebarProvider,
  SidebarTrigger,
  useSidebar,
} from "@/components/ui/sidebar"
import { useAuth, useSession } from "@/features/auth/use-auth"
import { formatAdminRole, formatStatus } from "@/lib/format"

function AppSidebar() {
  const { logout } = useAuth()
  const { user, tenant } = useSession()
  const { pathname } = useLocation()
  const { setOpenMobile } = useSidebar()

  return (
    <Sidebar>
      <SidebarBrand />
      <SidebarContent>
        {NAV_GROUPS.map((group) => (
          <SidebarGroup key={group.label ?? "inicio"}>
            {group.label && <SidebarGroupLabel>{group.label}</SidebarGroupLabel>}
            <SidebarGroupContent>
              <SidebarMenu>
                {group.items.map((item) => (
                  <SidebarMenuItem key={item.path}>
                    <SidebarMenuButton asChild isActive={pathname === item.path}>
                      <NavLink to={item.path} onClick={() => setOpenMobile(false)}>
                        <item.icon />
                        <span>{item.label}</span>
                      </NavLink>
                    </SidebarMenuButton>
                  </SidebarMenuItem>
                ))}
              </SidebarMenu>
            </SidebarGroupContent>
          </SidebarGroup>
        ))}
      </SidebarContent>
      <SidebarFooter className="gap-3 border-t border-sidebar-border p-4">
        <div className="grid min-w-0 text-sm">
          <span className="truncate font-medium" title={`${user.name} (${tenant.name})`}>
            {user.name} <span className="font-normal text-muted-foreground">({tenant.name})</span>
          </span>
          <span className="text-muted-foreground">{formatAdminRole(user.role)}</span>
          <span className="truncate text-muted-foreground" title={user.email}>
            {user.email}
          </span>
        </div>
        <Button variant="outline" onClick={logout}>
          <LogOut />
          Sair
        </Button>
      </SidebarFooter>
    </Sidebar>
  )
}

export function AppLayout() {
  const { refresh, error } = useAuth()
  const { tenant } = useSession()
  const { pathname } = useLocation()
  const title = NAV_ITEMS.find((item) => item.path === pathname)?.label ?? "Painel"

  return (
    <SidebarProvider>
      <AppSidebar />
      <SidebarInset className="min-w-0">
        <header className="flex h-16 shrink-0 items-center gap-2 border-b px-4 md:px-6">
          <SidebarTrigger className="-ml-1" aria-label="Alternar menu" />
          <Separator orientation="vertical" className="mr-2 data-vertical:h-4 data-vertical:self-center" />
          <div className="grid min-w-0">
            <h1 className="truncate text-lg font-semibold">{title}</h1>
            <p className="truncate text-sm text-muted-foreground">
              {tenant.slug} · {formatStatus(tenant.status)}
            </p>
          </div>
          <Button variant="outline" className="ml-auto hidden sm:inline-flex" onClick={() => void refresh()}>
            Atualizar sessão
          </Button>
        </header>
        <main className="flex min-w-0 flex-1 flex-col gap-6 p-4 md:p-6">
          {error && (
            <p role="status" className="text-sm text-destructive">
              {error}
            </p>
          )}
          <Outlet />
        </main>
      </SidebarInset>
    </SidebarProvider>
  )
}
