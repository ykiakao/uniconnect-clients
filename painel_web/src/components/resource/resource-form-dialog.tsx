import { useState } from "react"
import { Controller, useForm, type Control, type FieldErrors, type Resolver, type UseFormRegister } from "react-hook-form"

import * as R from "./resource-model"
import type { FormMode, FormValues, ResourceField } from "./resource-model"
import { FormError, FormField } from "@/components/page-states"
import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { errorMessage } from "@/features/users/users-model"

// Radix Select cannot hold an empty value.
const NO_VALUE = "__none"

function buildResolver(fields: ResourceField[], mode: FormMode): Resolver<FormValues> {
  return (values) => {
    const entries = Object.entries(R.validate(fields, values, mode))
    if (!entries.length) return { values, errors: {} }
    const errors = Object.fromEntries(entries.map(([name, message]) => [name, { type: "validate", message }]))
    return { values: {}, errors: errors as FieldErrors<FormValues> }
  }
}

type FieldControlProps = {
  field: ResourceField
  values: FormValues
  register: UseFormRegister<FormValues>
  control: Control<FormValues>
  isInvalid: boolean
}

function FieldControl({ field, values, register, control, isInvalid }: FieldControlProps) {
  const id = `resource-${field.name}`
  if (field.type === "select") {
    const options = R.resolveOptions(field, values)
    return (
      <Controller
        control={control}
        name={field.name}
        render={({ field: input }) => (
          <Select value={input.value || NO_VALUE} onValueChange={(value) => input.onChange(value === NO_VALUE ? "" : value)}>
            <SelectTrigger id={id} className="w-full" aria-invalid={isInvalid}>
              <SelectValue />
            </SelectTrigger>
            <SelectContent>
              {!field.required && <SelectItem value={NO_VALUE}>Nenhum</SelectItem>}
              {field.required && !input.value && <SelectItem value={NO_VALUE}>Selecione</SelectItem>}
              {options.map((option) => (
                <SelectItem key={option.value} value={option.value}>
                  {option.label}
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        )}
      />
    )
  }
  if (field.type === "textarea") return <Textarea id={id} rows={4} placeholder={field.placeholder} aria-invalid={isInvalid} {...register(field.name)} />
  return (
    <Input
      id={id}
      type={field.type === "date" ? "date" : "text"}
      maxLength={field.maxLength}
      placeholder={field.placeholder}
      autoComplete="off"
      aria-invalid={isInvalid}
      {...register(field.name)}
    />
  )
}

type ResourceFormDialogProps = {
  title: string
  fields: ResourceField[]
  mode: FormMode
  row: object | null
  onSubmit: (values: FormValues) => Promise<void>
  onClose: () => void
}

export function ResourceFormDialog({ title, fields, mode, row, onSubmit, onClose }: ResourceFormDialogProps) {
  const [submitError, setSubmitError] = useState("")
  const { register, control, handleSubmit, watch, formState } = useForm<FormValues>({
    defaultValues: R.initialValues(fields, row),
    resolver: buildResolver(fields, mode),
  })
  const values = watch()
  const { errors, isSubmitting } = formState

  const submit = handleSubmit(async (formValues) => {
    setSubmitError("")
    try {
      await onSubmit(formValues)
    } catch (error) {
      setSubmitError(errorMessage(error))
    }
  })

  return (
    <Dialog open onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[calc(100svh-2rem)] overflow-y-auto">
        <DialogHeader>
          <DialogTitle>{title}</DialogTitle>
          <DialogDescription>Preencha os campos e salve para confirmar.</DialogDescription>
        </DialogHeader>
        <form id="resource-form" noValidate className="grid gap-4" onSubmit={submit}>
          <FormError message={submitError} />
          {fields
            .filter((field) => R.isFieldActive(field, values, mode))
            .map((field) => (
              <FormField key={field.name} id={`resource-${field.name}`} label={field.label} hint={field.hint} error={errors[field.name]?.message}>
                <FieldControl field={field} values={values} register={register} control={control} isInvalid={Boolean(errors[field.name])} />
              </FormField>
            ))}
        </form>
        <DialogFooter>
          <Button variant="outline" onClick={onClose}>
            Cancelar
          </Button>
          <Button type="submit" form="resource-form" disabled={isSubmitting}>
            Salvar
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  )
}
