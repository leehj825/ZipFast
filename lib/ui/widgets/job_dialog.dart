import 'package:material_ui/material_ui.dart';

import '../../engine/job_runner.dart';
import '../../engine/models.dart';
import '../../l10n/gen/app_localizations.dart';
import '../actions.dart';

/// Shows a modal progress dialog for [handle] with a cancel button.
///
/// When the job succeeds, [doneBuilder] renders the result inside the same
/// dialog. Returns the result, or `null` if the job failed or was cancelled.
Future<T?> showJobDialog<T>(
  BuildContext context,
  JobHandle<T> handle, {
  required String title,
  required String doneTitle,
  required Widget Function(BuildContext context, T result) doneBuilder,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _JobDialog<T>(
      handle: handle,
      title: title,
      doneTitle: doneTitle,
      doneBuilder: doneBuilder,
    ),
  );
}

class _JobDialog<T> extends StatefulWidget {
  const _JobDialog({
    required this.handle,
    required this.title,
    required this.doneTitle,
    required this.doneBuilder,
  });

  final JobHandle<T> handle;
  final String title;
  final String doneTitle;
  final Widget Function(BuildContext, T) doneBuilder;

  @override
  State<_JobDialog<T>> createState() => _JobDialogState<T>();
}

class _JobDialogState<T> extends State<_JobDialog<T>> {
  T? _result;
  bool _done = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    widget.handle.result.then((value) {
      if (!mounted) return;
      setState(() {
        _result = value;
        _done = true;
      });
    }, onError: (Object e) {
      if (!mounted) return;
      if (e is JobCancelledException) {
        Navigator.pop(context);
      } else {
        setState(() => _error = e);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_error != null) {
      return AlertDialog(
        title: Text(l10n.corruptTitle),
        content: Text(describeError(l10n, _error!)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.close))],
      );
    }
    if (_done) {
      return AlertDialog(
        title: Text(widget.doneTitle),
        content: widget.doneBuilder(context, _result as T),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, _result),
            child: Text(l10n.done),
          ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      content: StreamBuilder<JobProgress>(
        stream: widget.handle.progress,
        builder: (context, snap) {
          final progress = snap.data;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LinearProgressIndicator(value: progress?.fraction),
              const SizedBox(height: 12),
              Text(
                progress == null || progress.total == 0
                    ? ' '
                    : '${progress.done} / ${progress.total}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              if (progress?.current != null)
                Text(progress!.current!, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          );
        },
      ),
      actions: [
        TextButton(onPressed: widget.handle.cancel, child: Text(l10n.cancel)),
      ],
    );
  }
}
