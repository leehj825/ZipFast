import 'dart:async';
import 'dart:isolate';

import 'models.dart';

/// A cancellable background job that reports progress.
///
/// The work runs in its own [Isolate] so the UI thread stays smooth even for
/// multi-gigabyte archives. Cancelling kills the isolate immediately.
class JobHandle<T> {
  JobHandle._();

  final Completer<T> _result = Completer<T>();
  final StreamController<JobProgress> _progress =
      StreamController<JobProgress>.broadcast();
  ReceivePort? _port;
  Isolate? _isolate;
  bool _finished = false;
  void Function()? _onCancel;

  /// Completes with the job result, or fails with the job's exception
  /// ([JobCancelledException] after [cancel]).
  Future<T> get result => _result.future;

  /// Progress updates; closed when the job ends.
  Stream<JobProgress> get progress => _progress.stream;

  /// Starts [task] in a new isolate. [task] and everything it captures must be
  /// sendable (plain data, no UI objects).
  static JobHandle<T> start<T>(
    Future<T> Function(void Function(JobProgress) report) task,
  ) {
    final handle = JobHandle<T>._();
    final port = handle._port = ReceivePort();
    port.listen(handle._onMessage);
    Isolate.spawn<_Start<T>>(
      _entry<T>,
      _Start<T>(port.sendPort, task),
    ).then((isolate) {
      if (handle._finished) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        handle._isolate = isolate;
      }
    }, onError: (Object e, StackTrace s) => handle._finish(error: e));
    return handle;
  }

  /// A handle driven by the caller, for work that does not run in a Dart
  /// isolate (native engines, chained jobs). Call [reportProgress], then
  /// [complete] or [fail]. [onCancel] is invoked once if the user cancels.
  static JobHandle<T> manual<T>({void Function()? onCancel}) {
    final handle = JobHandle<T>._();
    handle._onCancel = onCancel;
    return handle;
  }

  /// Publishes progress (for [manual] handles).
  void reportProgress(JobProgress progress) {
    if (!_finished && !_progress.isClosed) _progress.add(progress);
  }

  /// Finishes successfully (for [manual] handles).
  void complete(T value) => _finish(value: value, hasValue: true);

  /// Finishes with an error (for [manual] handles).
  void fail(Object error) => _finish(error: error);

  /// Whether the job has ended (successfully, with an error, or cancelled).
  bool get isFinished => _finished;

  /// Stops the job as soon as possible.
  void cancel() {
    if (_finished) return;
    final hook = _onCancel;
    _finish(error: const JobCancelledException());
    hook?.call();
  }

  void _onMessage(dynamic message) {
    if (message is JobProgress) {
      if (!_progress.isClosed) _progress.add(message);
    } else if (message is _Done) {
      _finish(value: message.value as T, hasValue: true);
    } else if (message is _Failed) {
      _finish(error: message.error);
    }
  }

  void _finish({T? value, bool hasValue = false, Object? error}) {
    if (_finished) return;
    _finished = true;
    _isolate?.kill(priority: Isolate.immediate);
    _port?.close();
    if (hasValue) {
      _result.complete(value as T);
    } else {
      _result.completeError(error!);
    }
    _progress.close();
  }
}

class _Start<T> {
  const _Start(this.sendPort, this.task);
  final SendPort sendPort;
  final Future<T> Function(void Function(JobProgress) report) task;
}

class _Done {
  const _Done(this.value);
  final Object? value;
}

class _Failed {
  const _Failed(this.error);
  final Object error;
}

Future<void> _entry<T>(_Start<T> start) async {
  try {
    final value = await start.task((p) => start.sendPort.send(p));
    start.sendPort.send(_Done(value));
  } on ZipFastException catch (e) {
    start.sendPort.send(_Failed(e));
  } catch (e) {
    start.sendPort.send(_Failed(CorruptArchiveException(e.toString())));
  }
}
