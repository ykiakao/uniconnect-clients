import { BookOpen, GraduationCap, Lock, Pencil, Settings, UserCheck, UserRound, UserX, Users, type LucideIcon } from "lucide-react"

import * as Model from "./users-model"
import type { Actor, ManagedUser } from "./users-model"
import type { Course } from "./users-api"
import { DataTable, type Column } from "@/components/data-table"
import { IconAction } from "@/components/resource/resource-page"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Badge } from "@/components/ui/badge"
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip"
import { cn } from "@/lib/utils"

const ROLE_ICONS: Record<string, LucideIcon> = {
  aluno: GraduationCap,
  professor: BookOpen,
  gestor: Users,
  admin: Settings,
}

// The avatar tone tells the role apart at a glance.
const AVATAR_TONES: Record<string, string> = {
  aluno: "bg-accent text-accent-foreground",
  professor: "bg-secondary text-navy",
  gestor: "bg-primary text-primary-foreground",
  admin: "bg-navy text-white",
}

function initials(name: string) {
  const words = name.trim().split(/\s+/).filter(Boolean)
  if (!words.length) return "?"
  const last = words.length > 1 ? words[words.length - 1][0] : ""
  return `${words[0][0]}${last}`.toUpperCase()
}

function RowLock({ label }: { label: string }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span role="img" aria-label={label} tabIndex={0} className="inline-flex size-8 items-center justify-center text-muted-foreground">
          <Lock className="size-4" />
        </span>
      </TooltipTrigger>
      <TooltipContent>{label}</TooltipContent>
    </Tooltip>
  )
}

type RowCallbacks = {
  onEdit: (user: ManagedUser) => void
  onToggleStatus: (user: ManagedUser) => void
}

function RowActions({ user, actor, onEdit, onToggleStatus }: RowCallbacks & { user: ManagedUser; actor: Actor }) {
  if (Model.isSelf(actor, user)) return <RowLock label="Você não pode alterar o próprio vínculo" />
  if (!Model.canManageUser(actor, user)) return <RowLock label="Sem permissão" />

  const statusVerb = user.active ? "Desativar" : "Reativar"
  const StatusIcon = user.active ? UserX : UserCheck
  return (
    <>
      <IconAction label={`Editar ${user.name}`} tooltip="Editar" onClick={() => onEdit(user)}>
        <Pencil />
      </IconAction>
      <IconAction label={`${statusVerb} ${user.name}`} tooltip={statusVerb} onClick={() => onToggleStatus(user)}>
        <StatusIcon />
      </IconAction>
    </>
  )
}

function Person({ user, actor }: { user: ManagedUser; actor: Actor }) {
  return (
    <div className="flex min-w-0 items-center gap-3">
      <Avatar>
        <AvatarFallback className={cn("text-xs font-semibold", user.active ? AVATAR_TONES[user.role] : "bg-secondary text-muted-foreground")}>
          {initials(user.name)}
        </AvatarFallback>
      </Avatar>
      <div className="grid min-w-0">
        <span className="flex min-w-0 items-center gap-2">
          <span className={cn("truncate font-medium", !user.active && "text-muted-foreground")} title={user.name}>
            {user.name}
          </span>
          {Model.isSelf(actor, user) && <Badge variant="outline">Você</Badge>}
        </span>
        <span className="truncate text-sm text-muted-foreground" title={user.email}>
          {user.email}
        </span>
      </div>
    </div>
  )
}

function RoleLabel({ role }: { role: string }) {
  const Icon = ROLE_ICONS[role] ?? UserRound
  return (
    <span className="inline-flex items-center gap-2">
      <Icon className="size-4 text-muted-foreground" />
      {Model.roleLabel(role)}
    </span>
  )
}

function CourseLabel({ user, courses }: { user: ManagedUser; courses: Course[] }) {
  const course = courses.find((item) => item.id === user.courseId)
  if (course) {
    return (
      <span className="min-w-0 truncate lg:block lg:max-w-44" title={course.name}>
        {course.name}
      </span>
    )
  }
  return <span className="text-muted-foreground">{user.role === Model.STUDENT_ROLE ? "Sem curso" : "—"}</span>
}

type UsersTableProps = RowCallbacks & {
  users: ManagedUser[]
  actor: Actor
  courses: Course[]
  isFetching: boolean
}

export function UsersTable({ users, actor, courses, isFetching, onEdit, onToggleStatus }: UsersTableProps) {
  const columns: Column<ManagedUser>[] = [
    { key: "name", header: "Nome", isPrimary: true, className: "lg:max-w-72", cell: (user) => <Person user={user} actor={actor} /> },
    { key: "role", header: "Perfil", cell: (user) => <RoleLabel role={user.role} /> },
    { key: "course", header: "Curso", cell: (user) => <CourseLabel user={user} courses={courses} /> },
    {
      key: "status",
      header: "Status",
      cell: (user) => (user.active ? <Badge className="bg-success-tint text-success">Ativo</Badge> : <Badge variant="secondary">Inativo</Badge>),
    },
    {
      key: "actions",
      header: "Ações",
      isActions: true,
      className: "lg:w-24",
      cell: (user) => (
        <div className="flex items-center justify-end gap-1">
          <RowActions user={user} actor={actor} onEdit={onEdit} onToggleStatus={onToggleStatus} />
        </div>
      ),
    },
  ]
  return <DataTable label="Usuários da instituição" columns={columns} rows={users} getRowKey={(user) => user.id} isFetching={isFetching} />
}
