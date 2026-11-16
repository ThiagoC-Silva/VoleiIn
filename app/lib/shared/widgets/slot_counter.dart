import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'form_fields.dart';

/// Contador de vagas (design-system.md, 7.3; gamesNew.png): o botão − em
/// `surfaceHigh`, o número no centro em Bebas Neue, editável pelo teclado
/// numérico, e o botão + em `primary`. Fica vazio até a pessoa escolher, e o
/// − para em [min].
class SlotCounterField extends StatelessWidget {
  const SlotCounterField({
    required this.label,
    required this.controller,
    required this.decreaseLabel,
    required this.increaseLabel,
    this.min = 1,
    this.helperText,
    this.validator,
    this.onChanged,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController controller;

  /// Rótulos dos botões para o TalkBack (S60).
  final String decreaseLabel;
  final String increaseLabel;

  /// O menor valor que o − alcança: 1 na criação (RN06), as vagas ocupadas
  /// na edição (RN59).
  final int min;
  final String? helperText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final bool enabled;

  int? get _value => int.tryParse(controller.text);

  void _set(int value) {
    controller.text = '$value';
    onChanged?.call(controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, _, _) {
        final value = _value;
        final canDecrease = enabled && value != null && value > min;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldLabel(label),
            FormField<String>(
              validator: (_) => validator?.call(controller.text),
              builder: (field) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: field.hasError
                            ? theme.colorScheme.error
                            : theme.colorScheme.outline,
                        width: field.hasError ? 2 : 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: decreaseLabel,
                          style: IconButton.styleFrom(
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHigh,
                            foregroundColor: theme.colorScheme.onSurface,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Symbols.remove),
                          onPressed: canDecrease
                              ? () {
                                  _set(value - 1);
                                  field.didChange(controller.text);
                                }
                              : null,
                        ),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            enabled: enabled,
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            style: theme.textTheme.displaySmall?.copyWith(
                              fontSize: 28,
                            ),
                            decoration: const InputDecoration(
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              disabledBorder: InputBorder.none,
                              isDense: true,
                            ),
                            onChanged: (text) {
                              onChanged?.call(text);
                              field.didChange(text);
                            },
                          ),
                        ),
                        IconButton(
                          tooltip: increaseLabel,
                          style: IconButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            minimumSize: const Size(48, 48),
                          ),
                          icon: const Icon(Symbols.add),
                          onPressed: enabled
                              ? () {
                                  _set(
                                    value == null || value < min
                                        ? min
                                        : value + 1,
                                  );
                                  field.didChange(controller.text);
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                  if (field.errorText != null)
                    FieldErrorText(field.errorText!)
                  else if (helperText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        helperText!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
