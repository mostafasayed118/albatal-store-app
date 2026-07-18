// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Al Batal Elite';

  @override
  String get home => 'Home';

  @override
  String get categories => 'Categories';

  @override
  String get wishlist => 'Wishlist';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get settingsSubtitle => 'Appearance and language';

  @override
  String get welcomeTitle => 'Crafted for distinction';

  @override
  String get welcomeBody =>
      'A premium commerce foundation with considered defaults for every direction and display.';

  @override
  String get foundationReady => 'Foundation ready';

  @override
  String get foundationBody =>
      'Theme, language, routing, and feedback states are in place. Storefront features come next.';

  @override
  String get appearance => 'Appearance';

  @override
  String get language => 'Language';

  @override
  String get themeSystem => 'Use device setting';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get english => 'English';

  @override
  String get arabic => 'Arabic';

  @override
  String get continueLabel => 'Continue';

  @override
  String get returnHome => 'Return to home';

  @override
  String get notAvailableTitle => 'Coming in the next slice';

  @override
  String get notAvailableBody =>
      'This area is intentionally a foundation placeholder while the reusable system is established.';

  @override
  String get retry => 'Retry';

  @override
  String get emptyTitle => 'Nothing here yet';

  @override
  String get emptyBody => 'When content is available, it will appear here.';

  @override
  String get errorTitle => 'Something went wrong';

  @override
  String get loading => 'Loading';

  @override
  String get cart => 'Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get shippingAddress => 'Shipping Address';

  @override
  String get paymentMethod => 'Payment Method';

  @override
  String get addNewAddress => 'Add New Address';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get total => 'Total';

  @override
  String get trackMyOrder => 'Track My Order';

  @override
  String get continueShopping => 'Continue Shopping';

  @override
  String get active => 'Active';

  @override
  String get completed => 'Completed';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get placed => 'Placed';

  @override
  String get shipped => 'Shipped';

  @override
  String get delivered => 'Delivered';

  @override
  String get noItemsFound => 'No items found';

  @override
  String get exploreCategories => 'Explore Categories';

  @override
  String get length => 'Length';

  @override
  String get color => 'Color';

  @override
  String get quantity => 'Quantity';

  @override
  String get brandName => 'AL BATAL ELITE';

  @override
  String goodMorning(String name) {
    return 'Good morning, $name';
  }

  @override
  String get searchFabrics => 'Search exquisite fabrics';

  @override
  String get clearSearch => 'Clear search';

  @override
  String get voiceSearch => 'Voice search';

  @override
  String get openSettings => 'Open settings';

  @override
  String get sortProducts => 'Sort products';

  @override
  String get newSilkCollection => 'NEW SILK COLLECTION';

  @override
  String get wovenForDistinction => 'Woven for distinction';

  @override
  String get exploreCollection => 'Explore collection';

  @override
  String get flashSale => 'Flash Sale';

  @override
  String get popularProducts => 'Popular products';

  @override
  String fabricsFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fabrics found',
      one: '$count fabric found',
    );
    return '$_temp0';
  }

  @override
  String curatedFabrics(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count curated fabrics',
      one: '$count curated fabric',
    );
    return '$_temp0';
  }

  @override
  String get noFabricsFound => 'No fabrics found';

  @override
  String get tryAnotherSearch => 'Try another search or clear your filters.';

  @override
  String get viewAllFabrics => 'View all fabrics';

  @override
  String get myCart => 'My Cart';

  @override
  String get cartEmptyTitle => 'Your cart is waiting for something exquisite.';

  @override
  String get remove => 'Remove';

  @override
  String get proceedToCheckout => 'Proceed to Checkout';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get shipping => 'Shipping';

  @override
  String get expressDelivery => 'Express Delivery';

  @override
  String get expressDeliveryBody => 'Delivered within 24–48 hours';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get shareLinkCopied => 'Share link copied';

  @override
  String get addedToCart => 'Added to your cart';

  @override
  String discountPercent(int percent) {
    return '-$percent%';
  }

  @override
  String get shareProduct => 'Share product';

  @override
  String get addToWishlist => 'Add to wishlist';

  @override
  String get removeFromWishlist => 'Remove from wishlist';

  @override
  String get decreaseQuantity => 'Decrease quantity';

  @override
  String get increaseQuantity => 'Increase quantity';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get fabricCategories => 'Fabric Categories';

  @override
  String get confirmStep => 'Confirm';

  @override
  String get mockCustomerName => 'Ahmed Mansour';

  @override
  String get mockAddress => '12 El Tahrir Street, Cairo, Egypt';

  @override
  String get mockAddressDialogBody =>
      'Address entry is simulated in this local mock.';

  @override
  String get myProfile => 'My Profile';

  @override
  String get premiumMember => 'Premium Member';

  @override
  String get myOrders => 'My Orders';

  @override
  String get shippingAddresses => 'Shipping Addresses';

  @override
  String get paymentMethods => 'Payment Methods';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get logOut => 'Log out';

  @override
  String get noCancelledOrders => 'No cancelled orders';

  @override
  String get orderItemsSummary => 'Royal Emerald Silk · 2 items';

  @override
  String get deliveredOnDate => 'Delivered · 12 July 2026';

  @override
  String get successTitle => 'Success!';

  @override
  String get orderPlacedBody =>
      'Your order has been placed. We will keep you updated.';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get noActiveOrders => 'No active orders';

  @override
  String get noCompletedOrders => 'No completed orders';

  @override
  String get advanceOrder => 'Advance order status';

  @override
  String get moveToCart => 'Move to Cart';

  @override
  String get saveForLater => 'Save for Later';

  @override
  String get movedToCart => 'Moved to cart';

  @override
  String get undo => 'Undo';

  @override
  String get description => 'Description';

  @override
  String get details => 'Details';

  @override
  String get care => 'Care';

  @override
  String get composition => 'Composition';

  @override
  String get origin => 'Origin';
}
