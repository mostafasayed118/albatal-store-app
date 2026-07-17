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

String money(double n) => '${n.toStringAsFixed(0)} EGY';
