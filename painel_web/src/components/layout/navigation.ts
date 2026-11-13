import {
  BookOpen,
  CalendarDays,
  ChartColumn,
  ClipboardList,
  CreditCard,
  GraduationCap,
  House,
  Library,
  Mail,
  Megaphone,
  Presentation,
  Settings,
  UserPlus,
  Users,
  type LucideIcon,
} from "lucide-react"

export type NavItem = { path: string; label: string; icon: LucideIcon; description: string }
export type NavGroup = { label?: string; items: NavItem[] }

export const NAV_GROUPS: NavGroup[] = [
  { items: [{ path: "/", label: "Dashboard", icon: House, description: "Visão geral da instituição." }] },
  {
    label: "Pessoas",
    items: [
      { path: "/usuarios", label: "Usuários", icon: Users, description: "Perfis, vínculos e status de acesso." },
      { path: "/convites", label: "Convites", icon: Mail, description: "Convide pessoas para criar o próprio acesso." },
    ],
  },
  {
    label: "Estrutura acadêmica",
    items: [
      { path: "/cursos", label: "Cursos", icon: GraduationCap, description: "Catálogo de cursos da instituição." },
      { path: "/turmas", label: "Turmas", icon: BookOpen, description: "Turmas de cada curso e professor responsável." },
      { path: "/periodos", label: "Períodos letivos", icon: CalendarDays, description: "Calendário e vigência dos períodos." },
      { path: "/disciplinas", label: "Disciplinas", icon: Library, description: "Disciplinas de cada curso." },
      { path: "/ofertas", label: "Ofertas", icon: Presentation, description: "Disciplinas ofertadas em cada período." },
    ],
  },
  {
    label: "Vínculos",
    items: [
      { path: "/matriculas", label: "Matrículas", icon: UserPlus, description: "Alunos matriculados em cada turma." },
      { path: "/professores-turma", label: "Professores por turma", icon: Users, description: "Professores vinculados às turmas." },
    ],
  },
  {
    label: "Acompanhamento",
    items: [
      { path: "/atividades", label: "Atividades e notas", icon: ClipboardList, description: "Atividades por turma e notas lançadas." },
      { path: "/avisos", label: "Avisos", icon: Megaphone, description: "Comunicados para a instituição, cursos e turmas." },
      { path: "/relatorios", label: "Relatórios", icon: ChartColumn, description: "Indicadores e engajamento da instituição." },
    ],
  },
  {
    label: "Instituição",
    items: [
      { path: "/assinatura", label: "Assinatura", icon: CreditCard, description: "Plano e situação atuais." },
      { path: "/configuracoes", label: "Configurações", icon: Settings, description: "Dados da instituição e da sessão." },
    ],
  },
]

export const NAV_ITEMS = NAV_GROUPS.flatMap((group) => group.items)
