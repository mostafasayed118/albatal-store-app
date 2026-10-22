import 'package:al_batal_elite/shared/services/app_bloc_observer.dart';
import 'package:bloc/bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBloc extends Mock implements Bloc<dynamic, dynamic> {}

void main() {
  late AppBlocObserver observer;
  late _MockBloc bloc;

  setUp(() {
    observer = AppBlocObserver();
    bloc = _MockBloc();
  });

  test('onCreate logs the bloc creation', () {
    expect(() => observer.onCreate(bloc), returnsNormally);
  });

  test('onClose logs the bloc close', () {
    expect(() => observer.onClose(bloc), returnsNormally);
  });

  test('onEvent logs the event type', () {
    expect(() => observer.onEvent(bloc, 'an-event'), returnsNormally);
  });

  test('onTransition logs the state transition', () {
    expect(
      () => observer.onTransition(
        bloc,
        const Transition<dynamic, dynamic>(
          currentState: 1,
          nextState: 2,
          event: null,
        ),
      ),
      returnsNormally,
    );
  });

  test('onError logs the error and its stack trace', () {
    expect(
      () => observer.onError(bloc, StateError('boom'), StackTrace.current),
      returnsNormally,
    );
  });
}
