import { useState } from "react"

import { nameOf, toOptions, useAllClasses, useCourses, usePeriods, useStudents, useSubjects, useTeachers } from "./lookups"
import type { ClassRow, Course, Period, Subject } from "./lookups"
import type { Column } from "@/components/data-table"
import { ResourcePage, type ResourceConfig } from "@/components/resource/resource-page"
import type { FieldOption, ResourceField } from "@/components/resource/resource-model"
import { Badge } from "@/components/ui/badge"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"

const CODE_FIELD: ResourceField = {
  name: "code",
  label: "Código",
  required: true,
  maxLength: 64,
  pattern: { regex: /^[a-zA-Z0-9._-]+$/, message: "Use apenas letras, números, ponto, hífen e sublinhado." },
}

const labels = (entries: Record<string, string>): FieldOption[] =>
  Object.entries(entries).map(([value, label]) => ({ value, label }))

const PERIOD_STATUS = { planned: "Planejado", active: "Ativo", closed: "Encerrado", archived: "Arquivado" }
const SIMPLE_STATUS = { active: "Ativo", inactive: "Inativo" }
const OFFERING_STATUS = { active: "Ativa", closed: "Encerrada", archived: "Arquivada" }
const ENROLLMENT_STATUS = { active: "Ativa", completed: "Concluída", cancelled: "Cancelada", suspended: "Suspensa" }

function StatusBadge({ status, names }: { status: string; names: Record<string, string> }) {
  const label = names[status] ?? status
  return status === "active" ? <Badge className="bg-success-tint text-success">{label}</Badge> : <Badge variant="secondary">{label}</Badge>
}

const Truncated = ({ value }: { value: string }) => (
  <span className="min-w-0 truncate lg:block lg:max-w-56" title={value}>
    {value}
  </span>
)

const statusColumn = <T extends { status: string }>(names: Record<string, string>): Column<T> => ({
  key: "status",
  header: "Status",
  className: "lg:w-28",
  cell: (row) => <StatusBadge status={row.status} names={names} />,
})

const statusField = (names: Record<string, string>, defaultValue = "active"): ResourceField => ({
  name: "status",
  label: "Status",
  type: "select",
  required: true,
  defaultValue,
  options: labels(names),
})

export function CoursesPage() {
  const config: ResourceConfig<Course> = {
    label: "Cursos",
    newLabel: "Novo curso",
    editTitle: "Editar curso",
    basePath: "/courses",
    updateMethod: "PUT",
    updateMode: "full",
    canDelete: true,
    emptyMessage: "Nenhum curso cadastrado ainda.",
    rowName: (row) => row.name,
    columns: [
      { key: "name", header: "Nome", isPrimary: true, cell: (row) => <span className="font-medium">{row.name}</span> },
      {
        key: "description",
        header: "Descrição",
        cell: (row) => <span className="min-w-0 text-muted-foreground lg:whitespace-normal">{row.description || "—"}</span>,
      },
    ],
    fields: [
      { name: "name", label: "Nome", required: true, placeholder: "Ex.: Engenharia de Software" },
      { name: "description", label: "Descrição", type: "textarea", placeholder: "Descreva brevemente o curso" },
    ],
  }
  return <ResourcePage config={config} />
}

export function ClassesPage() {
  const courses = useCourses()
  const [selected, setSelected] = useState("")
  const courseId = selected || courses[0]?.id

  const courseSelect = (
    <div className="grid gap-2 sm:w-64">
      <Label htmlFor="class-course">Curso</Label>
      <Select value={courseId ?? ""} onValueChange={setSelected}>
        <SelectTrigger id="class-course" className="w-full">
          <SelectValue placeholder="Selecione" />
        </SelectTrigger>
        <SelectContent>
          {courses.map((course) => (
            <SelectItem key={course.id} value={course.id}>
              {course.name}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  )

  if (!courseId) return courseSelect

  const config: ResourceConfig<ClassRow> = {
    label: "Turmas",
    newLabel: "Nova turma",
    editTitle: "Editar turma",
    basePath: `/courses/${encodeURIComponent(courseId)}/classes`,
    itemPath: (row) => `/classes/${encodeURIComponent(row.id)}`,
    updateMethod: "PUT",
    updateMode: "full",
    canDelete: true,
    emptyMessage: "Nenhuma turma neste curso.",
    rowName: (row) => row.name,
    columns: [
      { key: "name", header: "Nome", isPrimary: true, cell: (row) => <span className="font-medium">{row.name}</span> },
    ],
    fields: [{ name: "name", label: "Nome", required: true, placeholder: "Ex.: Turma A - Noite" }],
  }
  return <ResourcePage key={courseId} config={config} toolbar={courseSelect} />
}

export function PeriodsPage() {
  const config: ResourceConfig<Period> = {
    label: "Períodos letivos",
    newLabel: "Novo período",
    editTitle: "Editar período",
    basePath: "/academic-periods",
    updateMethod: "PATCH",
    updateMode: "changed",
    emptyMessage: "Nenhum período cadastrado ainda.",
    rowName: (row) => row.name,
    filters: [{ name: "status", label: "Status", options: labels(PERIOD_STATUS) }],
    columns: [
      { key: "name", header: "Nome", isPrimary: true, cell: (row) => <span className="font-medium">{row.name}</span> },
      { key: "code", header: "Código", cell: (row) => row.code },
      { key: "dates", header: "Vigência", cell: (row) => `${row.startDate ?? "—"} a ${row.endDate ?? "—"}` },
      statusColumn(PERIOD_STATUS),
    ],
    fields: [
      { ...CODE_FIELD, placeholder: "Ex.: 2026.1" },
      { name: "name", label: "Nome", required: true, maxLength: 200, placeholder: "Ex.: 1º semestre de 2026" },
      { name: "startDate", label: "Início", type: "date", clearable: true },
      { name: "endDate", label: "Fim", type: "date", clearable: true },
      statusField(PERIOD_STATUS, "planned"),
    ],
  }
  return <ResourcePage config={config} />
}

export function SubjectsPage() {
  const courses = useCourses()
  const config: ResourceConfig<Subject> = {
    label: "Disciplinas",
    newLabel: "Nova disciplina",
    editTitle: "Editar disciplina",
    basePath: "/subjects",
    updateMethod: "PATCH",
    updateMode: "changed",
    emptyMessage: "Nenhuma disciplina encontrada.",
    rowName: (row) => row.name,
    filters: [
      { name: "courseId", label: "Curso", options: toOptions(courses) },
      { name: "status", label: "Status", options: labels(SIMPLE_STATUS) },
    ],
    columns: [
      { key: "name", header: "Nome", isPrimary: true, cell: (row) => <span className="font-medium">{row.name}</span> },
      { key: "code", header: "Código", cell: (row) => row.code },
      { key: "course", header: "Curso", cell: (row) => <Truncated value={nameOf(courses, row.courseId)} /> },
      statusColumn(SIMPLE_STATUS),
    ],
    fields: [
      { name: "courseId", label: "Curso", type: "select", required: true, options: toOptions(courses) },
      { ...CODE_FIELD, placeholder: "Ex.: CALC-101" },
      { name: "name", label: "Nome", required: true, maxLength: 200, placeholder: "Ex.: Cálculo I" },
      statusField(SIMPLE_STATUS),
    ],
  }
  return <ResourcePage config={config} />
}

type Offering = { id: string; name: string; courseId: string; subjectId: string; periodId: string; status: string }

export function OfferingsPage() {
  const courses = useCourses()
  const subjects = useSubjects()
  const periods = usePeriods()
  const config: ResourceConfig<Offering> = {
    label: "Ofertas",
    newLabel: "Nova oferta",
    editTitle: "Editar oferta",
    basePath: "/offerings",
    updateMethod: "PATCH",
    updateMode: "changed",
    emptyMessage: "Nenhuma oferta encontrada.",
    rowName: (row) => row.name,
    filters: [
      { name: "courseId", label: "Curso", options: toOptions(courses) },
      { name: "periodId", label: "Período", options: toOptions(periods) },
    ],
    columns: [
      { key: "name", header: "Nome", isPrimary: true, cell: (row) => <Truncated value={row.name} /> },
      { key: "subject", header: "Disciplina", cell: (row) => <Truncated value={nameOf(subjects, row.subjectId)} /> },
      { key: "period", header: "Período", cell: (row) => <Truncated value={nameOf(periods, row.periodId)} /> },
      statusColumn(OFFERING_STATUS),
    ],
    fields: [
      { name: "courseId", label: "Curso", type: "select", required: true, options: toOptions(courses) },
      {
        name: "subjectId",
        label: "Disciplina",
        type: "select",
        required: true,
        hint: "Escolha o curso para ver as disciplinas.",
        options: (values) => toOptions(subjects.filter((subject) => subject.courseId === values.courseId)),
      },
      { name: "periodId", label: "Período", type: "select", required: true, options: toOptions(periods) },
      { name: "name", label: "Nome", required: true, maxLength: 200, placeholder: "Ex.: Cálculo I - 2026.1" },
      statusField(OFFERING_STATUS),
    ],
  }
  return <ResourcePage config={config} />
}

type Enrollment = { id: string; classId: string; studentId: string; status: string }

export function EnrollmentsPage() {
  const classes = useAllClasses()
  const students = useStudents()
  const config: ResourceConfig<Enrollment> = {
    label: "Matrículas",
    newLabel: "Nova matrícula",
    editTitle: "Alterar matrícula",
    basePath: "/enrollments",
    updateMethod: "PATCH",
    updateMode: "changed",
    emptyMessage: "Nenhuma matrícula encontrada.",
    rowName: (row) => nameOf(students, row.studentId),
    filters: [
      { name: "classId", label: "Turma", options: toOptions(classes) },
      { name: "status", label: "Status", options: labels(ENROLLMENT_STATUS) },
    ],
    columns: [
      { key: "student", header: "Aluno", isPrimary: true, cell: (row) => <span className="font-medium">{nameOf(students, row.studentId)}</span> },
      { key: "class", header: "Turma", cell: (row) => <Truncated value={nameOf(classes, row.classId)} /> },
      statusColumn(ENROLLMENT_STATUS),
    ],
    fields: [
      { name: "classId", label: "Turma", type: "select", required: true, createOnly: true, options: toOptions(classes) },
      { name: "studentId", label: "Aluno", type: "select", required: true, createOnly: true, options: toOptions(students) },
      statusField(ENROLLMENT_STATUS),
    ],
  }
  return <ResourcePage config={config} />
}

type Assignment = { id: string; classId: string; teacherId: string; status: string }

export function AssignmentsPage() {
  const classes = useAllClasses()
  const teachers = useTeachers()
  const config: ResourceConfig<Assignment> = {
    label: "Professores por turma",
    newLabel: "Vincular professor",
    editTitle: "Alterar vínculo",
    basePath: "/teaching-assignments",
    updateMethod: "PATCH",
    updateMode: "changed",
    emptyMessage: "Nenhum vínculo encontrado.",
    rowName: (row) => nameOf(teachers, row.teacherId),
    filters: [
      { name: "classId", label: "Turma", options: toOptions(classes) },
      { name: "status", label: "Status", options: labels(SIMPLE_STATUS) },
    ],
    columns: [
      { key: "teacher", header: "Professor", isPrimary: true, cell: (row) => <span className="font-medium">{nameOf(teachers, row.teacherId)}</span> },
      { key: "class", header: "Turma", cell: (row) => <Truncated value={nameOf(classes, row.classId)} /> },
      statusColumn(SIMPLE_STATUS),
    ],
    fields: [
      { name: "classId", label: "Turma", type: "select", required: true, createOnly: true, options: toOptions(classes) },
      { name: "teacherId", label: "Professor", type: "select", required: true, createOnly: true, options: toOptions(teachers) },
      statusField(SIMPLE_STATUS),
    ],
  }
  return <ResourcePage config={config} />
}
