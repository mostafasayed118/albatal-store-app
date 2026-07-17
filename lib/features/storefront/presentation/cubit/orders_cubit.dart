import 'package:bloc/bloc.dart';

final class OrdersCubit extends Cubit<int> {
  OrdersCubit() : super(0);

  void tab(int index) => emit(index);
}
