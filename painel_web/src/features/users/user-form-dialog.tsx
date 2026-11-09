import { useState } from "react"
import { Controller, useForm, type FieldErrors, type Resolver } from "react-hook-form"
import { toast } from "sonner"

import * as Model from "./users-model"
import type { Actor, ManagedUser, UserFormMode, UserFormValues } from "./users-model"
import { useSaveUserMutation, useSetUserActiveMutation, type Course } from "./users-api"
import {
  AlertDialog,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
} from "@/components/ui/alert-dialog"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { FormError, FormField } from "@/components/page-states"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { PLACEHOLDERS } from "@/lib/placeholders"

// Radix Select cannot hold an empty value.
const NO_COURSE = "__none"

function buildResolver(mode: UserFormMode): Resolver<UserFormValues> {
  return (values) => {
    const entries = Object.entries(Model.validateUserForm(values, mode))
    if (!entries.length) return { values, errors: {} }
    const errors = Object.fromEntries(entries.map(([name, message]) => [name, { type: "validate", message }]))
    return { values: {}, errors: errors as FieldErrors<UserFormValues> }
  }
}

function initialValues(user: ManagedUser | null, role: string): UserFormValues {
  return {
    name: user?.name ?? "",
    email: user?.email ?? "",
    password: "",
    role: user?.role ?? role,
    courseId: user?.courseId ?? "",
    registration: user?.registration ?? "",
    semester: user?.semester === undefined ? "" : String(user.semester),
  }
}

type UserFormDialogProps = {
  user: ManagedUser | null
  actor: Actor
  courses: Course[]
  coursesFailed: boolean
  onClose: () => void
}

export function UserFormDialog({ user, actor, courses, coursesFailed, onClose }: UserFormDialogProps) {
  const mode: UserFormMode = user ? "edit" : "create"
  const isCreate = mode === "create"
  const assignable = Model.ROLE_OPTIONS.filter((option) => Model.assignableRoles(actor.role).includes(option.value))
  const save = useSaveUserMutation()
  const [submitError, setSubmitError] = useState("")
  const { register, control, handleSubmit, watch, formState } = useForm<UserFormValues>({
    defaultValues: initialValues(user, assignable[0]?.value ?? ""),
    resolver: buildResolver(mode),
  })
  const { errors } = formState
  const isStudent = watch("role") === Model.STUDENT_ROLE

  const onSubmit = handleSubmit(async (values) => {
    setSubmitError("")
    try {
      const changed = await save.mutateAsync({ original: user, values })
      if (changed) toast.success(isCreate ? "Usuário criado." : "Alterações salvas.")
      onClose()
    } catch (error) {
      setSubmitError(Model.errorMessage(error))
    }
  })

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[calc(100svh-2rem)] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{isCreate ? "Novo usuário" : "Editar usuário"}</DialogTitle>
          <DialogDescription>
            {isCreate ? "Defina os dados de acesso e o perfil da pessoa." : "Atualize os dados e o perfil desta pessoa."}
          </DialogDescription>
        </DialogHeader>
        <form id="user-form" noValidate className="grid gap-4" onSubmit={onSubmit}>
          <FormError message={submitError} />
          <FormField id="user-name" label="Nome completo" error={errors.name?.message}>
            <Input id="user-name" maxLength={200} autoComplete="off" placeholder={PLACEHOLDERS.personName} aria-invalid={Boolean(errors.name)} {...register("name")} />
          </FormField>
          <FormField
            id="user-email"
            label="E-mail institucional"
            error={errors.email?.message}
            hint={isCreate ? undefined : "O e-mail identifica a conta e não pode ser alterado aqui."}
          >
            <Input id="user-email" type="email" autoComplete="off" placeholder={PLACEHOLDERS.email} readOnly={!isCreate} aria-invalid={Boolean(errors.email)} {...register("email")} />
          </FormField>
          {isCreate && (
            <FormField
              id="user-password"
              label="Senha inicial"
              error={errors.password?.message}
              hint="Mínimo de 8 caracteres. Se a pessoa já tiver conta, a senha atual dela continua valendo."
            >
              <Input id="user-password" type="password" autoComplete="new-password" placeholder="Defina uma senha inicial" aria-invalid={Boolean(errors.password)} {...register("password")} />
            </FormField>
          )}
          <FormField id="user-role" label="Perfil" error={errors.role?.message}>
            <Controller
              control={control}
              name="role"
              render={({ field }) => (
                <Select value={field.value} onValueChange={field.onChange}>
                  <SelectTrigger id="user-role" className="w-full">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    {assignable.map((option) => (
                      <SelectItem key={option.value} value={option.value}>
                        {option.label}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              )}
            />
          </FormField>
          {isStudent && (
            <>
              <FormField id="user-course" label="Curso" hint={coursesFailed ? "Não foi possível carregar os cursos." : undefined}>
                <Controller
                  control={control}
                  name="courseId"
                  render={({ field }) => (
                    <Select value={field.value || NO_COURSE} onValueChange={(value) => field.onChange(value === NO_COURSE ? "" : value)}>
                      <SelectTrigger id="user-course" className="w-full">
                        <SelectValue />
                      </SelectTrigger>
                      <SelectContent>
                        <SelectItem value={NO_COURSE}>Sem curso</SelectItem>
                        {courses.map((course) => (
                          <SelectItem key={course.id} value={course.id}>
                            {course.name}
                          </SelectItem>
                        ))}
                      </SelectContent>
                    </Select>
                  )}
                />
              </FormField>
              <div className="grid gap-4 sm:grid-cols-2">
                <FormField id="user-registration" label="Matrícula" error={errors.registration?.message}>
                  <Input id="user-registration" maxLength={50} autoComplete="off" placeholder="Ex.: 2026001234" aria-invalid={Boolean(errors.registration)} {...register("registration")} />
                </FormField>
                <FormField id="user-semester" label="Semestre" error={errors.semester?.message}>
                  <Input id="user-semester" type="number" min={1} max={30} inputMode="numeric" placeholder="Ex.: 3" aria-invalid={Boolean(errors.semester)} {...register("semester")} />
                </FormField>
              </div>
            </>
          )}
        </form>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="user-form" disabled={save.isPending}>
            {isCreate ? "Criar usuário" : "Salvar alterações"}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}

export function DeactivateUserDialog({ user, onClose }: { user: ManagedUser; onClose: () => void }) {
  const setActive = useSetUserActiveMutation()
  const [submitError, setSubmitError] = useState("")

  async function confirm() {
    setSubmitError("")
    try {
      await setActive.mutateAsync({ id: user.id, active: false })
      toast.success("Acesso desativado.")
      onClose()
    } catch (error) {
      setSubmitError(Model.errorMessage(error))
    }
  }

  return (
    <AlertDialog open onOpenChange={(open) => !open && onClose()}>
      <AlertDialogContent>
        <AlertDialogHeader>
          <AlertDialogTitle>Desativar acesso</AlertDialogTitle>
          <AlertDialogDescription>
            {user.name} deixa de entrar nesta instituição. O histórico é mantido, e você pode reativar o acesso depois.
          </AlertDialogDescription>
        </AlertDialogHeader>
        <FormError message={submitError} />
        <AlertDialogFooter>
          <AlertDialogCancel>Cancelar</AlertDialogCancel>
          <Button variant="destructive" disabled={setActive.isPending} onClick={() => void confirm()}>
            Desativar acesso
          </Button>
        </AlertDialogFooter>
      </AlertDialogContent>
    </AlertDialog>
  )
}
