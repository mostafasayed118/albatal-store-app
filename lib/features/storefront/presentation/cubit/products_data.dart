import '../../../../core/entities/product.dart';

const products = <Product>[
  Product(
      id: 'silk-01',
      name: 'Royal Emerald Silk',
      category: 'Silk',
      price: 1290,
      oldPrice: 1520,
      imageColor: 0xFF176B57,
      imageAsset: 'assets/images/1.png'),
  Product(
      id: 'cotton-01',
      name: 'Egyptian Cotton',
      category: 'Cotton',
      price: 690,
      imageColor: 0xFFC99A64,
      imageAsset: 'assets/images/2.png'),
  Product(
      id: 'velvet-01',
      name: 'Midnight Velvet',
      category: 'Velvet',
      price: 980,
      oldPrice: 1150,
      imageColor: 0xFF302244,
      imageAsset: 'assets/images/3.png'),
  Product(
      id: 'linen-01',
      name: 'Natural Linen',
      category: 'Linen',
      price: 540,
      imageColor: 0xFFD9C6A1,
      imageAsset: 'assets/images/4.png'),
  Product(
      id: 'wool-01',
      name: 'Heritage Wool',
      category: 'Wool',
      price: 820,
      imageColor: 0xFF88715F,
      imageAsset: 'assets/images/5.png'),
  Product(
      id: 'silk-02',
      name: 'Desert Gold Silk',
      category: 'Silk',
      price: 1340,
      imageColor: 0xFFB57A2A,
      imageAsset: 'assets/images/6.png'),
  Product(
      id: 'cotton-02',
      name: 'Nile Mist Cotton',
      category: 'Cotton',
      price: 720,
      imageColor: 0xFF6FA39A,
      imageAsset: 'assets/images/7.png'),
  Product(
      id: 'velvet-02',
      name: 'Crimson Throne Velvet',
      category: 'Velvet',
      price: 1050,
      oldPrice: 1240,
      imageColor: 0xFF6B1F2E,
      imageAsset: 'assets/images/8.png'),
  Product(
      id: 'linen-02',
      name: 'Oasis Sand Linen',
      category: 'Linen',
      price: 580,
      imageColor: 0xFFE0CDA0,
      imageAsset: 'assets/images/9.png'),
];

const categories = ['All', 'Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];

String money(double n) => '${n.toStringAsFixed(0)} EGY';
