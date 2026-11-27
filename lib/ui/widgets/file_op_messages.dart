import 'package:material_ui/material_ui.dart';

import '../../l10n/gen/app_localizations.dart';
import '../../state/file_ops.dart';

/// Shows a snackbar describing why a file operation failed.
void showOpError(BuildContext context, FileOpException e) {
  final l10n = AppLocalizations.of(context);
  final text = switch (e.reason) {
    FileOpFailure.invalidName => l10n.opNameInvalid,
    FileOpFailure.nameTaken => l10n.opNameTaken,
    FileOpFailure.intoItself => l10n.opIntoItself,
    FileOpFailure.outsideRoot || FileOpFailure.missing => l10n.opFailed,
  };
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}

/// Asks for a line of text. Returns `null` if cancelled.
Future<String?> askForText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _TextPromptDialog(title: title, label: label, initial: initial),
  );
}

/// Owns its controller, so it is disposed only after the dialog is fully gone.
class _TextPromptDialog extends StatefulWidget {
  const _TextPromptDialog({required this.title, required this.label, required this.initial});

  final String title;
  final String label;
  final String initial;

  @override
  State<_TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<_TextPromptDialog> {
  late final TextEditingController _controller = TextEditingController(text: widget.initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: widget.initial.length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.cancel)),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: Text(l10n.ok)),
      ],
    );
  }
}
