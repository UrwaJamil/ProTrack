import 'dart:async';

/// Change notification shared by the preview's in-memory repositories:
/// [watch] emits the current value on listen and again after every
/// [notify], like a Firestore snapshot stream.
class LiveStore {
  final _changes = StreamController<void>.broadcast();

  void notify() => _changes.add(null);

  Stream<T> watch<T>(T Function() read) {
    StreamSubscription<void>? changes;
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () {
        changes = _changes.stream.listen((_) => controller.add(read()));
        controller.add(read());
      },
      onCancel: () => changes?.cancel(),
    );
    return controller.stream;
  }
}
