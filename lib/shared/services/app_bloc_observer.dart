import 'package:bloc/bloc.dart';

import 'logger.dart';

/// Observer that logs all Cubit/Bloc state changes.
class AppBlocObserver extends BlocObserver {
  @override
  void onTransition(
      Bloc<dynamic, dynamic> bloc, Transition<dynamic, dynamic> transition) {
    Log.cubit(
      bloc.runtimeType.toString(),
      '${transition.currentState.runtimeType} → ${transition.nextState.runtimeType}',
    );
    super.onTransition(bloc, transition);
  }

  @override
  void onError(BlocBase<dynamic> bloc, Object error, StackTrace stackTrace) {
    Log.e(
      '${bloc.runtimeType} error',
      category: LogCategory.cubit,
      error: error,
      stackTrace: stackTrace,
    );
    super.onError(bloc, error, stackTrace);
  }

  @override
  void onEvent(Bloc<dynamic, dynamic> bloc, Object? event) {
    Log.cubit(
      bloc.runtimeType.toString(),
      'Event: ${event.runtimeType}',
    );
    super.onEvent(bloc, event);
  }

  @override
  void onCreate(BlocBase<dynamic> bloc) {
    Log.cubit(bloc.runtimeType.toString(), 'Created');
    super.onCreate(bloc);
  }

  @override
  void onClose(BlocBase<dynamic> bloc) {
    Log.cubit(bloc.runtimeType.toString(), 'Closed');
    super.onClose(bloc);
  }
}
