import '../../../../core/entities/product.dart';

export '../../../../core/utils/currency.dart';

const products = <Product>[
  Product(
      id: 'silk-01',
      name: 'Royal Emerald Silk',
      category: 'Silk',
      price: 1290,
      oldPrice: 1520,
      imageColor: 0xFF176B57,
      imageAsset: 'assets/images/1.png',
      description:
          'Hand-loomed mulberry silk with a rich emerald sheen. The tight weave gives it a fluid drape ideal for evening wear, formal suiting, and statement linings.',
      composition: '100% Mulberry Silk',
      care: 'Dry clean only. Cool iron on reverse. Store folded in breathable cotton.',
      origin: 'Varanasi, India'),
  Product(
      id: 'cotton-01',
      name: 'Egyptian Cotton',
      category: 'Cotton',
      price: 690,
      imageColor: 0xFFC99A64,
      imageAsset: 'assets/images/2.png',
      description:
          'Long-staple Giza cotton with a warm golden undertone. Exceptionally soft hand feel with natural breathability — perfect for shirting, dresses, and light trousers.',
      composition: '100% Egyptian Giza Cotton',
      care: 'Machine wash cold, gentle cycle. Tumble dry low. Iron while slightly damp.',
      origin: 'Nile Delta, Egypt'),
  Product(
      id: 'velvet-01',
      name: 'Midnight Velvet',
      category: 'Velvet',
      price: 980,
      oldPrice: 1150,
      imageColor: 0xFF302244,
      imageAsset: 'assets/images/3.png',
      description:
          'Dense cotton velvet with a deep midnight-purple pile. The short nap catches light beautifully, making it a first choice for evening gowns, blazers, and upholstery.',
      composition: '85% Cotton, 15% Silk',
      care: 'Dry clean only. Steam to remove creases. Brush nap gently in one direction.',
      origin: 'Como, Italy'),
  Product(
      id: 'linen-01',
      name: 'Natural Linen',
      category: 'Linen',
      price: 540,
      imageColor: 0xFFD9C6A1,
      imageAsset: 'assets/images/4.png',
      description:
          'Stonewashed European flax linen with a relaxed, lived-in texture. Naturally temperature-regulating — cool in summer, warm in winter.',
      composition: '100% European Flax Linen',
      care: 'Machine wash cold. Hang dry. Embrace natural wrinkles or iron on high while damp.',
      origin: 'Belgium'),
  Product(
      id: 'wool-01',
      name: 'Heritage Wool',
      category: 'Wool',
      price: 820,
      imageColor: 0xFF88715F,
      imageAsset: 'assets/images/5.png',
      description:
          'Medium-weight merino wool with a natural crimp that gives excellent body. Tailored for structured garments — coats, trousers, and tailored suits.',
      composition: '100% Merino Wool',
      care: 'Dry clean preferred. Spot clean with cold water. Store with cedar to deter moths.',
      origin: 'Yorkshire, England'),
  Product(
      id: 'silk-02',
      name: 'Desert Gold Silk',
      category: 'Silk',
      price: 1340,
      imageColor: 0xFFB57A2A,
      imageAsset: 'assets/images/6.png',
      description:
          'Heavy charmeuse silk in a warm desert-gold tone. The lustrous face and matte reverse make it versatile for bias-cut dresses and luxury linings.',
      composition: '100% Mulberry Silk Charmeuse',
      care: 'Dry clean only. Cool iron on reverse. Hang on padded hanger to prevent creasing.',
      origin: 'Suzhou, China'),
  Product(
      id: 'cotton-02',
      name: 'Nile Mist Cotton',
      category: 'Cotton',
      price: 720,
      imageColor: 0xFF6FA39A,
      imageAsset: 'assets/images/7.png',
      description:
          'Brushed cotton lawn with a soft mist-green hue. Lightweight yet opaque — ideal for spring blouses, children\'s wear, and structured shirts.',
      composition: '100% Combed Cotton',
      care: 'Machine wash warm. Tumble dry low. Iron on medium heat.',
      origin: 'Izmir, Turkey'),
  Product(
      id: 'velvet-02',
      name: 'Crimson Throne Velvet',
      category: 'Velvet',
      price: 1050,
      oldPrice: 1240,
      imageColor: 0xFF6B1F2E,
      imageAsset: 'assets/images/8.png',
      description:
          'Silk-blend crushed velvet in a commanding crimson. The irregular pile creates a dynamic play of light — reserved for pieces that demand attention.',
      composition: '70% Silk, 30% Viscose',
      care: 'Dry clean only. Steam from a distance. Never press directly.',
      origin: 'Bursa, Turkey'),
  Product(
      id: 'linen-02',
      name: 'Oasis Sand Linen',
      category: 'Linen',
      price: 580,
      imageColor: 0xFFE0CDA0,
      imageAsset: 'assets/images/9.png',
      description:
          'Fine-weave Irish linen in a pale sand tone. The smooth hand and subtle luster elevate casual tailoring, table linens, and summer suiting.',
      composition: '100% Irish Linen',
      care: 'Machine wash cold. Line dry for best results. Iron while damp for crisp finish.',
      origin: 'Belfast, Northern Ireland'),
];

const categories = ['All', 'Silk', 'Cotton', 'Velvet', 'Linen', 'Wool'];

String money(double n) => '${n.toStringAsFixed(0)} EGY';
