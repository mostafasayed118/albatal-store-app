// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'البطل إيليت';

  @override
  String get home => 'الرئيسية';

  @override
  String get categories => 'الفئات';

  @override
  String get wishlist => 'المفضلة';

  @override
  String get profile => 'الحساب';

  @override
  String get settings => 'الإعدادات';

  @override
  String get settingsSubtitle => 'المظهر واللغة';

  @override
  String get welcomeTitle => 'مصنوع للتميّز';

  @override
  String get welcomeBody =>
      'أساس لتجارة إلكترونية راقية بخيارات مدروعة لكل اتجاه ووضع عرض.';

  @override
  String get foundationReady => 'الأساس جاهز';

  @override
  String get foundationBody =>
      'الوضع والمظهر واللغة والتنقل وحالات الواجهة جاهزة. ميزات المتجر تأتي لاحقاً.';

  @override
  String get appearance => 'المظهر';

  @override
  String get language => 'اللغة';

  @override
  String get themeSystem => 'استخدام إعداد الجهاز';

  @override
  String get themeLight => 'فاتح';

  @override
  String get themeDark => 'داكن';

  @override
  String get english => 'الإنجليزية';

  @override
  String get arabic => 'العربية';

  @override
  String get continueLabel => 'متابعة';

  @override
  String get returnHome => 'العودة للرئيسية';

  @override
  String get notAvailableTitle => 'قادم في المرحلة التالية';

  @override
  String get notAvailableBody =>
      'هذه المساحة عنصر مؤقت مقصود بينما نؤسس النظام القابل لإعادة الاستخدام.';

  @override
  String get retry => 'إعادة المحاولة';

  @override
  String get emptyTitle => 'لا يوجد شيء هنا بعد';

  @override
  String get emptyBody => 'سيظهر المحتوى هنا عندما يصبح متاحاً.';

  @override
  String get errorTitle => 'حدث خطأ ما';

  @override
  String get loading => 'جارٍ التحميل';

  @override
  String get cart => 'السلة';

  @override
  String get checkout => 'الدفع';

  @override
  String get shippingAddress => 'عنوان الشحن';

  @override
  String get paymentMethod => 'طريقة الدفع';

  @override
  String get addNewAddress => 'إضافة عنوان جديد';

  @override
  String get placeOrder => 'تأكيد الطلب';

  @override
  String get total => 'الإجمالي';

  @override
  String get trackMyOrder => 'تتبّع طلبي';

  @override
  String get continueShopping => 'متابعة التسوّق';

  @override
  String get active => 'نشطة';

  @override
  String get completed => 'مكتملة';

  @override
  String get cancelled => 'ملغاة';

  @override
  String get placed => 'تم الطلب';

  @override
  String get shipped => 'تم الشحن';

  @override
  String get delivered => 'تم التوصيل';

  @override
  String get noItemsFound => 'لا توجد عناصر';

  @override
  String get exploreCategories => 'استكشف الفئات';

  @override
  String get length => 'الطول';

  @override
  String get color => 'اللون';

  @override
  String get quantity => 'الكمية';

  @override
  String get brandName => 'البطل إيليت';

  @override
  String goodMorning(String name) {
    return 'صباح الخير، $name';
  }

  @override
  String get searchFabrics => 'ابحث عن أقمشة فاخرة';

  @override
  String get clearSearch => 'مسح البحث';

  @override
  String get voiceSearch => 'البحث الصوتي';

  @override
  String get openSettings => 'فتح الإعدادات';

  @override
  String get sortProducts => 'ترتيب المنتجات';

  @override
  String get newSilkCollection => 'مجموعة الحرير الجديدة';

  @override
  String get wovenForDistinction => 'منسوجة للتميّز';

  @override
  String get exploreCollection => 'استكشف المجموعة';

  @override
  String get flashSale => 'تخفيضات سريعة';

  @override
  String get popularProducts => 'منتجات رائجة';

  @override
  String fabricsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم العثور على $count قماش',
      one: 'تم العثور على قماش واحد',
    );
    return '$_temp0';
  }

  @override
  String curatedFabrics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count أقمشة منتقاة',
      one: 'قماش واحد منتقى',
    );
    return '$_temp0';
  }

  @override
  String get noFabricsFound => 'لم يتم العثور على أقمشة';

  @override
  String get tryAnotherSearch => 'جرّب بحثاً آخر أو امسح عوامل التصفية.';

  @override
  String get viewAllFabrics => 'عرض كل الأقمشة';

  @override
  String get myCart => 'سلتي';

  @override
  String get cartEmptyTitle => 'سلتك تنتظر شيئاً مميزاً.';

  @override
  String get remove => 'إزالة';

  @override
  String get proceedToCheckout => 'المتابعة إلى الدفع';

  @override
  String get subtotal => 'المجموع الفرعي';

  @override
  String get shipping => 'الشحن';

  @override
  String get expressDelivery => 'توصيل سريع';

  @override
  String get expressDeliveryBody => 'يُسلّم خلال ٢٤–٤٨ ساعة';

  @override
  String get addToCart => 'أضف إلى السلة';

  @override
  String get shareLinkCopied => 'تم نسخ رابط المشاركة';

  @override
  String get addedToCart => 'أُضيف إلى سلتك';

  @override
  String discountPercent(int percent) {
    return '-$percent٪';
  }

  @override
  String get shareProduct => 'مشاركة المنتج';

  @override
  String get addToWishlist => 'إضافة إلى المفضلة';

  @override
  String get removeFromWishlist => 'إزالة من المفضلة';

  @override
  String get decreaseQuantity => 'تقليل الكمية';

  @override
  String get increaseQuantity => 'زيادة الكمية';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get fabricCategories => 'فئات الأقمشة';

  @override
  String get confirmStep => 'تأكيد';

  @override
  String get mockCustomerName => 'أحمد منصور';

  @override
  String get mockAddress => '١٢ شارع التحرير، القاهرة، مصر';

  @override
  String get mockAddressDialogBody =>
      'إدخال العنوان محاكاة في هذا النموذج المحلي.';

  @override
  String get myProfile => 'ملفّي الشخصي';

  @override
  String get premiumMember => 'عضو مميّز';

  @override
  String get myOrders => 'طلباتي';

  @override
  String get shippingAddresses => 'عناوين الشحن';

  @override
  String get paymentMethods => 'طرق الدفع';

  @override
  String get accountSettings => 'إعدادات الحساب';

  @override
  String get logOut => 'تسجيل الخروج';

  @override
  String get noCancelledOrders => 'لا توجد طلبات ملغاة';

  @override
  String get orderItemsSummary => 'حرير الزمردي الملكي · قطعتان';

  @override
  String get deliveredOnDate => 'تم التوصيل · ١٢ يوليو ٢٠٢٦';

  @override
  String get successTitle => 'تم بنجاح!';

  @override
  String get orderPlacedBody => 'تم تسجيل طلبك. سنبقيك على اطّلاع.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count قطعة',
      one: 'قطعة واحدة',
    );
    return '$_temp0';
  }

  @override
  String get noActiveOrders => 'لا توجد طلبات نشطة';

  @override
  String get noCompletedOrders => 'لا توجد طلبات مكتملة';

  @override
  String get advanceOrder => 'تقديم حالة الطلب';

  @override
  String get moveToCart => 'نقل إلى السلة';

  @override
  String get saveForLater => 'حفظ لوقت لاحق';

  @override
  String get movedToCart => 'تم النقل إلى السلة';
}
