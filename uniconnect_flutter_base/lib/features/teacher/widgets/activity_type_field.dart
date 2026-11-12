import 'package:flutter/material.dart';

/// Activity types the app offers. The API stores free text, so a value
/// outside this list (created elsewhere) is kept and shown as is.
const activityTypeOptions = <(String, String)>[
  ('assignment', 'Trabalho'),
  ('exercise', 'Lista de exercícios'),
  ('project', 'Projeto'),
  ('report', 'Relatório'),
  ('presentation', 'Apresentação'),
];

String activityTypeLabel(String type) {
  for (final (value, label) in activityTypeOptions) {
    if (value == type) return label;
  }
  return type;
}

/// Dropdown bound to [controller], whose text stays the API value.
class ActivityTypeField extends StatelessWidget {
  const ActivityTypeField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.labelText,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? labelText;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final current = value.text.trim();
        final options = [
          ...activityTypeOptions,
          if (current.isNotEmpty &&
              activityTypeOptions.every((option) => option.$1 != current))
            (current, current),
        ];
        return Semantics(
          label: labelText ?? 'Tipo',
          child: DropdownButtonFormField<String>(
            key: ValueKey(current),
            initialValue: current.isEmpty ? null : current,
            isExpanded: true,
            decoration: InputDecoration(labelText: labelText),
            items: [
              for (final (option, label) in options)
                DropdownMenuItem(value: option, child: Text(label)),
            ],
            validator: (selected) =>
                selected == null || selected.isEmpty ? 'Escolha o tipo.' : null,
            onChanged: enabled
                ? (selected) {
                    if (selected == null || selected == controller.text) return;
                    controller.text = selected;
                    onChanged?.call();
                  }
                : null,
          ),
        );
      },
    );
  }
}
