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
  final ReceivePort _port = ReceivePort();
  Isolate? _isolate;
  bool _finished = false;

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
    handle._port.listen(handle._onMessage);
    Isolate.spawn<_Start<T>>(
      _entry<T>,
      _Start<T>(handle._port.sendPort, task),
    ).then((isolate) {
      if (handle._finished) {
        isolate.kill(priority: Isolate.immediate);
      } else {
        handle._isolate = isolate;
      }
    }, onError: (Object e, StackTrace s) => handle._finish(error: e));
    return handle;
  }

  /// Stops the job as soon as possible.
  void cancel() {
    if (_finished) return;
    _finish(error: const JobCancelledException());
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
    _port.close();
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
