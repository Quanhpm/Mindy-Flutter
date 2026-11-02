import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/i18n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/button.dart';
import 'code_editing.dart';
import 'code_models.dart';

/// Kết quả sheet: giá trị đã đọc theo kiểu + chữ đã gõ (để mở lại sheet vẫn còn).
typedef CustomInput = ({List<Object?> args, List<String> texts});

/// Sheet nhập một bộ input cho "Chạy thử" (giống web). Server kiểm tra lại kiểu (422 CODE_CUSTOM_INPUT_INVALID).
class CodeCustomInputSheet extends ConsumerStatefulWidget {
  const CodeCustomInputSheet({super.key, required this.signature, this.initial = const []});
  final CodeSignature signature;
  final List<String> initial;

  @override
  ConsumerState<CodeCustomInputSheet> createState() => _CodeCustomInputSheetState();
}

class _CodeCustomInputSheetState extends ConsumerState<CodeCustomInputSheet> {
  late final List<TextEditingController> _fields = [
    for (var i = 0; i < widget.signature.params.length; i++)
      TextEditingController(text: i < widget.initial.length ? widget.initial[i] : ''),
  ];
  List<String?> _errors = const [];

  @override
  void dispose() {
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  void _submit() {
    final t = ref.read(trProvider);
    final params = widget.signature.params;
    final args = <Object?>[];
    final errors = <String?>[];
    for (var i = 0; i < params.length; i++) {
      final parsed = parseCodeArg(params[i].type, _fields[i].text);
      errors.add(
        parsed == null
            ? t('code.run.inputError', {
                'type': t('code.type.${params[i].type}'),
                'example': codeTypeExample(params[i].type),
              })
            : null,
      );
      args.add(parsed?.value);
    }
    if (errors.any((e) => e != null)) {
      setState(() => _errors = errors);
      return;
    }
    final CustomInput result = (args: args, texts: [for (final f in _fields) f.text]);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(trProvider);
    final params = widget.signature.params;
    return ListView(
      key: const Key('code-custom-input-sheet'),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Semantics(
          header: true,
          child: Text(
            t('code.run.customTitle'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.forest),
          ),
        ),
        const SizedBox(height: 8),
        Text(t('code.run.customHint'), style: const TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 16),
        for (var i = 0; i < params.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              key: Key('code-custom-arg-$i'),
              controller: _fields[i],
              autocorrect: false,
              enableSuggestions: false,
              smartDashesType: SmartDashesType.disabled,
              smartQuotesType: SmartQuotesType.disabled,
              textInputAction: i == params.length - 1 ? TextInputAction.done : TextInputAction.next,
              onSubmitted: i == params.length - 1 ? (_) => _submit() : null,
              style: const TextStyle(fontFamily: 'RobotoMono', fontSize: 14),
              decoration: InputDecoration(
                labelText: '${params[i].name} · ${t('code.type.${params[i].type}')}',
                hintText: params[i].type == 'string' ? 'abc' : codeTypeExample(params[i].type),
                errorText: i < _errors.length ? _errors[i] : null,
                errorMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        const SizedBox(height: 4),
        MindyButton(
          key: const Key('code-custom-run'),
          label: t('code.run.customSubmit'),
          onPressed: _submit,
        ),
      ],
    );
  }
}
