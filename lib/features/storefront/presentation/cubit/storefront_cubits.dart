import 'dart:async';

import 'package:al_batal_elite/features/storefront/data/storefront_persistence.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/entities/product.dart';

const products = <Product>[
  Product(
      id: 'silk-01',
      name: 'Royal Emerald Silk',
      category: 'Silk',
      price: 1290,
      oldPrice: 1520,
      imageColor: 0xFF176B57),
  Product(
      id: 'cotton-01',
      name: 'Egyptian Cotton',
      category: 'Cotton',
      price: 690,
      imageColor: 0xFFC99A64),
  Product(
      id: 'velvet-01',
      name: 'Midnight Velvet',
      category: 'Velvet',
      price: 980,
      oldPrice: 1150,
      imageColor: 0xFF302244),
  Product(
      id: 'linen-01',
      name: 'Natural Linen',
      category: 'Linen',
      price: 540,
      imageColor: 0xFFD9C6A1),
  Product(
      id: 'wool-01',
      name: 'Heritage Wool',
      category: 'Wool',
      price: 820,
      imageColor: 0xFF88715F),
];
const categories = ['All', 'Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];

final class CatalogState extends Equatable {
  const CatalogState(
      {this.category = 'All',
      this.carouselIndex = 0,
      this.saleSeconds = 14362});
  final String category;
  final int carouselIndex, saleSeconds;
  List<Product> get visible => category == 'All'
      ? products
      : products.where((p) => p.category == category).toList();
  @override
  List<Object?> get props => [category, carouselIndex, saleSeconds];
}

final class CatalogCubit extends Cubit<CatalogState> {
  CatalogCubit() : super(const CatalogState()) {
    _timer = Timer.periodic(
        const Duration(seconds: 1),
        (_) => emit(CatalogState(
            category: state.category,
            carouselIndex: state.carouselIndex,
            saleSeconds: (state.saleSeconds - 1).clamp(0, 999999))));
  }
  late final Timer _timer;
  void select(String c) => emit(CatalogState(
      category: c,
      carouselIndex: state.carouselIndex,
      saleSeconds: state.saleSeconds));
  void carousel(int i) => emit(CatalogState(
      category: state.category,
      carouselIndex: i,
      saleSeconds: state.saleSeconds));
  @override
  Future<void> close() {
    _timer.cancel();
    return super.close();
  }
}

final class WishlistCubit extends Cubit<Set<String>> {
  WishlistCubit() : super(<String>{});
  void toggle(String id) => emit({...state}..toggle(id));
}

extension on Set<String> {
  void toggle(String value) {
    contains(value) ? remove(value) : add(value);
  }
}

final class CartState extends Equatable {
  const CartState(this.items);
  final List<CartItem> items;
  double get subtotal =>
      items.fold(0, (v, i) => v + i.product.price * i.quantity);
  double get shipping => items.isEmpty ? 0 : 75;
  double get total => subtotal + shipping;
  int get count => items.fold(0, (v, i) => v + i.quantity);
  @override
  List<Object?> get props => [items];
}

final class CartCubit extends Cubit<CartState> {
  CartCubit(MemoryStorefrontPersistence memoryStorefrontPersistence)
      : super(const CartState([]));
  void add(Product p,
      {String color = 'Emerald', String length = '2m', int quantity = 1}) {
    final item =
        CartItem(product: p, color: color, length: length, quantity: quantity);
    final old = state.items.where((x) => x.key == item.key).firstOrNull;
    if (old == null)
      emit(CartState([...state.items, item]));
    else
      update(item.key, old.quantity + quantity);
  }

  void update(String key, int quantity) => emit(CartState(state.items
      .map(
          (i) => i.key == key ? i.copyWith(quantity: quantity.clamp(1, 99)) : i)
      .toList()));
  void remove(String key) =>
      emit(CartState(state.items.where((i) => i.key != key).toList()));
  void clear() => emit(const CartState([]));
}

extension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}

final class DetailsState extends Equatable {
  const DetailsState(
      {this.color = 'Emerald', this.length = '2m', this.quantity = 1});
  final String color, length;
  final int quantity;
  DetailsState copyWith({String? color, String? length, int? quantity}) =>
      DetailsState(
          color: color ?? this.color,
          length: length ?? this.length,
          quantity: quantity ?? this.quantity);
  @override
  List<Object?> get props => [color, length, quantity];
}

final class ProductDetailsCubit extends Cubit<DetailsState> {
  ProductDetailsCubit() : super(const DetailsState());
  void color(String v) => emit(state.copyWith(color: v));
  void length(String v) => emit(state.copyWith(length: v));
  void quantity(int v) => emit(state.copyWith(quantity: v.clamp(1, 99)));
}

final class CheckoutState extends Equatable {
  const CheckoutState(
      {this.step = 0, this.payment = 'Credit Card', this.placing = false});
  final int step;
  final String payment;
  final bool placing;
  CheckoutState copyWith({int? step, String? payment, bool? placing}) =>
      CheckoutState(
          step: step ?? this.step,
          payment: payment ?? this.payment,
          placing: placing ?? this.placing);
  @override
  List<Object?> get props => [step, payment, placing];
}

final class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit() : super(const CheckoutState());
  void payment(String v) => emit(state.copyWith(payment: v));
  Future<void> place() async {
    emit(state.copyWith(placing: true));
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    emit(state.copyWith(placing: false, step: 2));
  }
}

final class OrdersCubit extends Cubit<int> {
  OrdersCubit() : super(0);
  void tab(int i) => emit(i);
}
