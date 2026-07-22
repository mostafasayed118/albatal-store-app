import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Al Batal Elite'**
  String get appTitle;

  /// No description provided for @brandName.
  ///
  /// In en, this message translates to:
  /// **'Al Batal Elite'**
  String get brandName;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @wishlist.
  ///
  /// In en, this message translates to:
  /// **'Wishlist'**
  String get wishlist;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Appearance and language'**
  String get settingsSubtitle;

  /// No description provided for @welcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Crafted for distinction'**
  String get welcomeTitle;

  /// No description provided for @welcomeBody.
  ///
  /// In en, this message translates to:
  /// **'A premium commerce foundation with considered defaults for every direction and display.'**
  String get welcomeBody;

  /// No description provided for @foundationReady.
  ///
  /// In en, this message translates to:
  /// **'Foundation ready'**
  String get foundationReady;

  /// No description provided for @foundationBody.
  ///
  /// In en, this message translates to:
  /// **'Theme, language, routing, and feedback states are in place. Storefront features come next.'**
  String get foundationBody;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Use device setting'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @continueLabel.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueLabel;

  /// No description provided for @returnHome.
  ///
  /// In en, this message translates to:
  /// **'Return to home'**
  String get returnHome;

  /// No description provided for @notAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Coming in the next slice'**
  String get notAvailableTitle;

  /// No description provided for @notAvailableBody.
  ///
  /// In en, this message translates to:
  /// **'This area is intentionally a foundation placeholder while the reusable system is established.'**
  String get notAvailableBody;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @emptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get emptyTitle;

  /// No description provided for @emptyBody.
  ///
  /// In en, this message translates to:
  /// **'When content is available, it will appear here.'**
  String get emptyBody;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorTitle;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get loading;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @myCart.
  ///
  /// In en, this message translates to:
  /// **'My Cart'**
  String get myCart;

  /// No description provided for @cartEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your cart is waiting for something exquisite.'**
  String get cartEmptyTitle;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @shippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Shipping Address'**
  String get shippingAddress;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @proceedToCheckout.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Checkout'**
  String get proceedToCheckout;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @shipping.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shipping;

  /// No description provided for @trackMyOrder.
  ///
  /// In en, this message translates to:
  /// **'Track My Order'**
  String get trackMyOrder;

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @placed.
  ///
  /// In en, this message translates to:
  /// **'Placed'**
  String get placed;

  /// No description provided for @shipped.
  ///
  /// In en, this message translates to:
  /// **'Shipped'**
  String get shipped;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @noItemsFound.
  ///
  /// In en, this message translates to:
  /// **'No items found'**
  String get noItemsFound;

  /// No description provided for @exploreCategories.
  ///
  /// In en, this message translates to:
  /// **'Explore Categories'**
  String get exploreCategories;

  /// No description provided for @length.
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @creditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get creditCard;

  /// No description provided for @digitalWallet.
  ///
  /// In en, this message translates to:
  /// **'Digital Wallet'**
  String get digitalWallet;

  /// No description provided for @cashOnDelivery.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery'**
  String get cashOnDelivery;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @myProfile.
  ///
  /// In en, this message translates to:
  /// **'My Profile'**
  String get myProfile;

  /// No description provided for @mockCustomerName.
  ///
  /// In en, this message translates to:
  /// **'Ahmed Mansour'**
  String get mockCustomerName;

  /// No description provided for @premiumMember.
  ///
  /// In en, this message translates to:
  /// **'Premium Member'**
  String get premiumMember;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @shippingAddresses.
  ///
  /// In en, this message translates to:
  /// **'Shipping Addresses'**
  String get shippingAddresses;

  /// No description provided for @paymentMethods.
  ///
  /// In en, this message translates to:
  /// **'Payment Methods'**
  String get paymentMethods;

  /// No description provided for @accountSettings.
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// No description provided for @logOut.
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logOut;

  /// No description provided for @noActiveOrders.
  ///
  /// In en, this message translates to:
  /// **'No active orders'**
  String get noActiveOrders;

  /// No description provided for @noCompletedOrders.
  ///
  /// In en, this message translates to:
  /// **'No completed orders'**
  String get noCompletedOrders;

  /// No description provided for @noCancelledOrders.
  ///
  /// In en, this message translates to:
  /// **'No cancelled orders'**
  String get noCancelledOrders;

  /// No description provided for @advanceOrder.
  ///
  /// In en, this message translates to:
  /// **'Advance Order'**
  String get advanceOrder;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @addedToCart.
  ///
  /// In en, this message translates to:
  /// **'Added to your cart'**
  String get addedToCart;

  /// No description provided for @movedToCart.
  ///
  /// In en, this message translates to:
  /// **'Moved to cart'**
  String get movedToCart;

  /// No description provided for @moveToCart.
  ///
  /// In en, this message translates to:
  /// **'Move to Cart'**
  String get moveToCart;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @undo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get undo;

  /// No description provided for @saveForLater.
  ///
  /// In en, this message translates to:
  /// **'Save for Later'**
  String get saveForLater;

  /// No description provided for @noFabricsFound.
  ///
  /// In en, this message translates to:
  /// **'No fabrics found'**
  String get noFabricsFound;

  /// No description provided for @tryAnotherSearch.
  ///
  /// In en, this message translates to:
  /// **'Try another search'**
  String get tryAnotherSearch;

  /// No description provided for @viewAllFabrics.
  ///
  /// In en, this message translates to:
  /// **'View all fabrics'**
  String get viewAllFabrics;

  /// No description provided for @flashSale.
  ///
  /// In en, this message translates to:
  /// **'Flash Sale'**
  String get flashSale;

  /// No description provided for @searchFabrics.
  ///
  /// In en, this message translates to:
  /// **'Search fabrics'**
  String get searchFabrics;

  /// No description provided for @voiceSearch.
  ///
  /// In en, this message translates to:
  /// **'Voice search'**
  String get voiceSearch;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearch;

  /// No description provided for @popularProducts.
  ///
  /// In en, this message translates to:
  /// **'Popular products'**
  String get popularProducts;

  /// No description provided for @sortProducts.
  ///
  /// In en, this message translates to:
  /// **'Sort products'**
  String get sortProducts;

  /// No description provided for @sortFeatured.
  ///
  /// In en, this message translates to:
  /// **'Featured'**
  String get sortFeatured;

  /// No description provided for @sortPriceLowToHigh.
  ///
  /// In en, this message translates to:
  /// **'Price: low to high'**
  String get sortPriceLowToHigh;

  /// No description provided for @sortPriceHighToLow.
  ///
  /// In en, this message translates to:
  /// **'Price: high to low'**
  String get sortPriceHighToLow;

  /// No description provided for @sortNameAToZ.
  ///
  /// In en, this message translates to:
  /// **'Name: A to Z'**
  String get sortNameAToZ;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// Number of fabrics found
  ///
  /// In en, this message translates to:
  /// **'{count} fabrics found'**
  String fabricsFound(int count);

  /// No description provided for @newSilkCollection.
  ///
  /// In en, this message translates to:
  /// **'NEW SILK COLLECTION'**
  String get newSilkCollection;

  /// No description provided for @wovenForDistinction.
  ///
  /// In en, this message translates to:
  /// **'Woven for distinction'**
  String get wovenForDistinction;

  /// No description provided for @exploreCollection.
  ///
  /// In en, this message translates to:
  /// **'Explore collection'**
  String get exploreCollection;

  /// No description provided for @decreaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Decrease quantity'**
  String get decreaseQuantity;

  /// No description provided for @increaseQuantity.
  ///
  /// In en, this message translates to:
  /// **'Increase quantity'**
  String get increaseQuantity;

  /// No description provided for @removeFromWishlist.
  ///
  /// In en, this message translates to:
  /// **'Removed from wishlist'**
  String get removeFromWishlist;

  /// No description provided for @addToWishlist.
  ///
  /// In en, this message translates to:
  /// **'Add to wishlist'**
  String get addToWishlist;

  /// No description provided for @fabricCategories.
  ///
  /// In en, this message translates to:
  /// **'Fabric Categories'**
  String get fabricCategories;

  /// Number of curated fabrics in a category
  ///
  /// In en, this message translates to:
  /// **'{count} curated fabrics'**
  String curatedFabrics(int count);

  /// No description provided for @confirmStep.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirmStep;

  /// No description provided for @shareProduct.
  ///
  /// In en, this message translates to:
  /// **'Share product'**
  String get shareProduct;

  /// No description provided for @shareLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Share link copied'**
  String get shareLinkCopied;

  /// Discount percentage label
  ///
  /// In en, this message translates to:
  /// **'{percent}% OFF'**
  String discountPercent(int percent);

  /// No description provided for @expressDelivery.
  ///
  /// In en, this message translates to:
  /// **'Express Delivery'**
  String get expressDelivery;

  /// No description provided for @expressDeliveryBody.
  ///
  /// In en, this message translates to:
  /// **'Delivered within 24–48 hours'**
  String get expressDeliveryBody;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @composition.
  ///
  /// In en, this message translates to:
  /// **'Composition'**
  String get composition;

  /// No description provided for @origin.
  ///
  /// In en, this message translates to:
  /// **'Origin'**
  String get origin;

  /// No description provided for @care.
  ///
  /// In en, this message translates to:
  /// **'Care'**
  String get care;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good morning, Ahmed'**
  String get goodMorning;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSettings;

  /// No description provided for @successTitle.
  ///
  /// In en, this message translates to:
  /// **'Success!'**
  String get successTitle;

  /// No description provided for @orderPlacedBody.
  ///
  /// In en, this message translates to:
  /// **'Your order has been placed. We will keep you updated.'**
  String get orderPlacedBody;

  /// Number of items in an order
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String itemsCount(int count);

  /// No description provided for @reviewOrder.
  ///
  /// In en, this message translates to:
  /// **'Review Order'**
  String get reviewOrder;

  /// No description provided for @shippingTo.
  ///
  /// In en, this message translates to:
  /// **'Shipping to'**
  String get shippingTo;

  /// No description provided for @paymentSummary.
  ///
  /// In en, this message translates to:
  /// **'Payment Summary'**
  String get paymentSummary;

  /// No description provided for @selectAddress.
  ///
  /// In en, this message translates to:
  /// **'Select Address'**
  String get selectAddress;

  /// No description provided for @noAddressesSaved.
  ///
  /// In en, this message translates to:
  /// **'No addresses saved yet'**
  String get noAddressesSaved;

  /// No description provided for @addAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Address'**
  String get addAddress;

  /// No description provided for @useThisAddress.
  ///
  /// In en, this message translates to:
  /// **'Use this address'**
  String get useThisAddress;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// Number of items in the cart for checkout review
  ///
  /// In en, this message translates to:
  /// **'{count} items in cart'**
  String itemsInCart(int count);

  /// No description provided for @confirmAndPay.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Pay'**
  String get confirmAndPay;

  /// No description provided for @changingAddress.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get changingAddress;

  /// No description provided for @validationSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select a shipping address'**
  String get validationSelectAddress;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetFilters;

  /// No description provided for @clearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearAll;

  /// No description provided for @priceRange.
  ///
  /// In en, this message translates to:
  /// **'Price Range'**
  String get priceRange;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResultsFound;

  /// No description provided for @tryAdjustingFilters.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search or filters'**
  String get tryAdjustingFilters;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @sizeGuide.
  ///
  /// In en, this message translates to:
  /// **'Size Guide'**
  String get sizeGuide;

  /// No description provided for @relatedProducts.
  ///
  /// In en, this message translates to:
  /// **'Related Products'**
  String get relatedProducts;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// Low stock warning
  ///
  /// In en, this message translates to:
  /// **'Only {count} left'**
  String onlyLeft(int count);

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @returnsBody.
  ///
  /// In en, this message translates to:
  /// **'Free returns within 30 days of purchase'**
  String get returnsBody;

  /// No description provided for @width.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// No description provided for @bestFor.
  ///
  /// In en, this message translates to:
  /// **'Best For'**
  String get bestFor;

  /// No description provided for @sizeGuide1m.
  ///
  /// In en, this message translates to:
  /// **'Small projects, swatches'**
  String get sizeGuide1m;

  /// No description provided for @sizeGuide2m.
  ///
  /// In en, this message translates to:
  /// **'Garments, dresses'**
  String get sizeGuide2m;

  /// No description provided for @sizeGuide5m.
  ///
  /// In en, this message translates to:
  /// **'Full suits, upholstery'**
  String get sizeGuide5m;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access your account'**
  String get signInSubtitle;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get createAccount;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordBody;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Link'**
  String get sendResetLink;

  /// No description provided for @resetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Check your email for the reset link'**
  String get resetEmailSent;

  /// No description provided for @resetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @updatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update Password'**
  String get updatePassword;

  /// No description provided for @passwordUpdated.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully'**
  String get passwordUpdated;

  /// No description provided for @checkEmailToVerify.
  ///
  /// In en, this message translates to:
  /// **'Check your email to verify your account'**
  String get checkEmailToVerify;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get invalidEmail;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @continueAsGuest.
  ///
  /// In en, this message translates to:
  /// **'Continue as Guest'**
  String get continueAsGuest;

  /// No description provided for @signInToViewProfile.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view your profile and orders'**
  String get signInToViewProfile;

  /// No description provided for @unknownUser.
  ///
  /// In en, this message translates to:
  /// **'Guest User'**
  String get unknownUser;

  /// No description provided for @authError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error'**
  String get authError;

  /// No description provided for @selectPaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Select Payment Method'**
  String get selectPaymentMethod;

  /// No description provided for @payWithCard.
  ///
  /// In en, this message translates to:
  /// **'Pay with Card'**
  String get payWithCard;

  /// No description provided for @payWithCardDescription.
  ///
  /// In en, this message translates to:
  /// **'Credit or Debit Card via Paymob'**
  String get payWithCardDescription;

  /// No description provided for @cashOnDeliveryDescription.
  ///
  /// In en, this message translates to:
  /// **'Pay when your order arrives'**
  String get cashOnDeliveryDescription;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @completePayment.
  ///
  /// In en, this message translates to:
  /// **'Complete Payment'**
  String get completePayment;

  /// No description provided for @paymentSuccess.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccess;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentCancelled.
  ///
  /// In en, this message translates to:
  /// **'Payment Cancelled'**
  String get paymentCancelled;

  /// No description provided for @paymentProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get paymentProcessing;

  /// No description provided for @proceedToPayment.
  ///
  /// In en, this message translates to:
  /// **'Proceed to Payment'**
  String get proceedToPayment;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @totalOrders.
  ///
  /// In en, this message translates to:
  /// **'Total Orders'**
  String get totalOrders;

  /// No description provided for @pendingOrders.
  ///
  /// In en, this message translates to:
  /// **'Pending Orders'**
  String get pendingOrders;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @orderQueue.
  ///
  /// In en, this message translates to:
  /// **'Order Queue'**
  String get orderQueue;

  /// No description provided for @viewAllOrders.
  ///
  /// In en, this message translates to:
  /// **'View All Orders'**
  String get viewAllOrders;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @manageStock.
  ///
  /// In en, this message translates to:
  /// **'Manage Stock'**
  String get manageStock;

  /// No description provided for @catalog.
  ///
  /// In en, this message translates to:
  /// **'Catalog'**
  String get catalog;

  /// No description provided for @manageProducts.
  ///
  /// In en, this message translates to:
  /// **'Manage Products'**
  String get manageProducts;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @orderDetails.
  ///
  /// In en, this message translates to:
  /// **'Order Details'**
  String get orderDetails;

  /// No description provided for @placedAt.
  ///
  /// In en, this message translates to:
  /// **'Placed At'**
  String get placedAt;

  /// No description provided for @fulfillmentActions.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment Actions'**
  String get fulfillmentActions;

  /// No description provided for @confirmOrder.
  ///
  /// In en, this message translates to:
  /// **'Confirm Order'**
  String get confirmOrder;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @markAsShipped.
  ///
  /// In en, this message translates to:
  /// **'Mark as Shipped'**
  String get markAsShipped;

  /// No description provided for @markAsDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as Delivered'**
  String get markAsDelivered;

  /// No description provided for @noActionsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No actions available for this status'**
  String get noActionsAvailable;

  /// No description provided for @allOrders.
  ///
  /// In en, this message translates to:
  /// **'All Orders'**
  String get allOrders;

  /// No description provided for @noOrdersFound.
  ///
  /// In en, this message translates to:
  /// **'No orders found'**
  String get noOrdersFound;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @allStockLevelsHealthy.
  ///
  /// In en, this message translates to:
  /// **'All stock levels are healthy'**
  String get allStockLevelsHealthy;

  /// No description provided for @catalogManagement.
  ///
  /// In en, this message translates to:
  /// **'Catalog Management'**
  String get catalogManagement;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @productImages.
  ///
  /// In en, this message translates to:
  /// **'Product Images'**
  String get productImages;

  /// No description provided for @manageProductImages.
  ///
  /// In en, this message translates to:
  /// **'Manage Product Images'**
  String get manageProductImages;

  /// No description provided for @variants.
  ///
  /// In en, this message translates to:
  /// **'Variants'**
  String get variants;

  /// No description provided for @manageVariantsAndStock.
  ///
  /// In en, this message translates to:
  /// **'Manage Variants & Stock'**
  String get manageVariantsAndStock;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyContent.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy content will be added here.'**
  String get privacyPolicyContent;

  /// No description provided for @termsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get termsOfService;

  /// No description provided for @termsOfServiceContent.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service content will be added here.'**
  String get termsOfServiceContent;

  /// No description provided for @shippingPolicy.
  ///
  /// In en, this message translates to:
  /// **'Shipping Policy'**
  String get shippingPolicy;

  /// No description provided for @shippingPolicyContent.
  ///
  /// In en, this message translates to:
  /// **'Shipping Policy content will be added here.'**
  String get shippingPolicyContent;

  /// No description provided for @returnsPolicy.
  ///
  /// In en, this message translates to:
  /// **'Returns & Exchange Policy'**
  String get returnsPolicy;

  /// No description provided for @returnsPolicyContent.
  ///
  /// In en, this message translates to:
  /// **'Returns & Exchange Policy content will be added here.'**
  String get returnsPolicyContent;

  /// No description provided for @customerSupport.
  ///
  /// In en, this message translates to:
  /// **'Customer Support'**
  String get customerSupport;

  /// No description provided for @whatsappSupport.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Support'**
  String get whatsappSupport;

  /// No description provided for @whatsappSupportDescription.
  ///
  /// In en, this message translates to:
  /// **'Chat with us on WhatsApp'**
  String get whatsappSupportDescription;

  /// No description provided for @emailSupport.
  ///
  /// In en, this message translates to:
  /// **'Email Support'**
  String get emailSupport;

  /// No description provided for @emailSupportAddress.
  ///
  /// In en, this message translates to:
  /// **'support@albatal.com'**
  String get emailSupportAddress;

  /// No description provided for @faq.
  ///
  /// In en, this message translates to:
  /// **'Frequently Asked Questions'**
  String get faq;

  /// No description provided for @faqDescription.
  ///
  /// In en, this message translates to:
  /// **'Find answers to common questions'**
  String get faqDescription;

  /// SnackBar confirmation shown after copying a support contact value to the clipboard
  ///
  /// In en, this message translates to:
  /// **'{label} copied to clipboard'**
  String copiedToClipboard(String label);

  /// No description provided for @faqShippingQuestion.
  ///
  /// In en, this message translates to:
  /// **'How long does shipping take?'**
  String get faqShippingQuestion;

  /// No description provided for @faqShippingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Orders are processed within 1–2 business days and typically delivered within 3–7 business days depending on your location.'**
  String get faqShippingAnswer;

  /// No description provided for @faqReturnsQuestion.
  ///
  /// In en, this message translates to:
  /// **'What is your return policy?'**
  String get faqReturnsQuestion;

  /// No description provided for @faqReturnsAnswer.
  ///
  /// In en, this message translates to:
  /// **'Unworn items in their original condition can be returned within 14 days of delivery. See our Returns & Exchange Policy for full details.'**
  String get faqReturnsAnswer;

  /// No description provided for @faqPaymentQuestion.
  ///
  /// In en, this message translates to:
  /// **'Which payment methods do you accept?'**
  String get faqPaymentQuestion;

  /// No description provided for @faqPaymentAnswer.
  ///
  /// In en, this message translates to:
  /// **'We accept major cards and mobile wallets through our secure Paymob checkout, as well as cash on delivery where available.'**
  String get faqPaymentAnswer;

  /// No description provided for @faqOrderTrackingQuestion.
  ///
  /// In en, this message translates to:
  /// **'How do I track my order?'**
  String get faqOrderTrackingQuestion;

  /// No description provided for @faqOrderTrackingAnswer.
  ///
  /// In en, this message translates to:
  /// **'Once your order ships you will receive tracking details, and you can view live status any time under Orders in your profile.'**
  String get faqOrderTrackingAnswer;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'items'**
  String get items;

  /// No description provided for @noAddressProvided.
  ///
  /// In en, this message translates to:
  /// **'No address provided'**
  String get noAddressProvided;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default'**
  String get setAsDefault;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @addAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Add address'**
  String get addAddressTitle;

  /// No description provided for @editAddressTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddressTitle;

  /// No description provided for @recipientLabel.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipientLabel;

  /// No description provided for @streetAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddressLabel;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @countryLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryLabel;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @invalidCheckoutLink.
  ///
  /// In en, this message translates to:
  /// **'The payment checkout link is invalid. Please retry.'**
  String get invalidCheckoutLink;

  /// No description provided for @paymentSuccessOrderMissing.
  ///
  /// In en, this message translates to:
  /// **'Payment succeeded but the order reference is missing.'**
  String get paymentSuccessOrderMissing;

  /// No description provided for @paymentCancelledRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment cancelled. You can retry.'**
  String get paymentCancelledRetry;

  /// No description provided for @paymentExpiredRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment expired. You can retry.'**
  String get paymentExpiredRetry;

  /// No description provided for @paymentTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Payment verification timed out. Please check your orders before retrying.'**
  String get paymentTimedOut;

  /// No description provided for @paymentFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. You can retry.'**
  String get paymentFailedRetry;

  /// No description provided for @unableToContinueOrderMissing.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue: the order reference is missing.'**
  String get unableToContinueOrderMissing;

  /// No description provided for @invalidCheckoutLinkFull.
  ///
  /// In en, this message translates to:
  /// **'The payment checkout link is invalid. Please return and retry.'**
  String get invalidCheckoutLinkFull;

  /// No description provided for @returnToPayment.
  ///
  /// In en, this message translates to:
  /// **'Return to payment'**
  String get returnToPayment;

  /// SnackBar after admin updates order status
  ///
  /// In en, this message translates to:
  /// **'Order status updated to {status}'**
  String orderStatusUpdatedTo(String status);

  /// No description provided for @addTrackingDetails.
  ///
  /// In en, this message translates to:
  /// **'Add Tracking Details'**
  String get addTrackingDetails;

  /// No description provided for @courierNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Courier Name'**
  String get courierNameLabel;

  /// No description provided for @trackingNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Tracking Number'**
  String get trackingNumberLabel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @orderMarkedAsShipped.
  ///
  /// In en, this message translates to:
  /// **'Order marked as shipped'**
  String get orderMarkedAsShipped;

  /// No description provided for @failedToUpdateStatus.
  ///
  /// In en, this message translates to:
  /// **'Failed to update status. Please try again.'**
  String get failedToUpdateStatus;

  /// No description provided for @trackingNumberRequired.
  ///
  /// In en, this message translates to:
  /// **'Tracking number is required'**
  String get trackingNumberRequired;

  /// No description provided for @updateStock.
  ///
  /// In en, this message translates to:
  /// **'Update Stock'**
  String get updateStock;

  /// No description provided for @newStockLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'New stock level'**
  String get newStockLevelLabel;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @serverConfirmedTotals.
  ///
  /// In en, this message translates to:
  /// **'Server-confirmed totals'**
  String get serverConfirmedTotals;

  /// No description provided for @subtotalLabel.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotalLabel;

  /// No description provided for @shippingLabel.
  ///
  /// In en, this message translates to:
  /// **'Shipping'**
  String get shippingLabel;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get totalLabel;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullNameLabel;

  /// No description provided for @streetAddressFormLabel.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddressFormLabel;

  /// No description provided for @cityFormLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityFormLabel;

  /// No description provided for @countryFormLabel.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get countryFormLabel;

  /// No description provided for @nameRequiredValidation.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequiredValidation;

  /// No description provided for @validStreetAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid street address'**
  String get validStreetAddressRequired;

  /// No description provided for @cityRequiredValidation.
  ///
  /// In en, this message translates to:
  /// **'City is required'**
  String get cityRequiredValidation;

  /// No description provided for @countryRequiredValidation.
  ///
  /// In en, this message translates to:
  /// **'Country is required'**
  String get countryRequiredValidation;

  /// No description provided for @orderReferenceMissing.
  ///
  /// In en, this message translates to:
  /// **'Order reference is missing. Please check your order history.'**
  String get orderReferenceMissing;

  /// No description provided for @unknownLabel.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknownLabel;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// Order number title with truncated or full id
  ///
  /// In en, this message translates to:
  /// **'Order #{id}'**
  String orderNumber(String id);

  /// No description provided for @currencyCode.
  ///
  /// In en, this message translates to:
  /// **'EGP'**
  String get currencyCode;

  /// No description provided for @categoryAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get categoryAll;

  /// No description provided for @categorySilk.
  ///
  /// In en, this message translates to:
  /// **'Silk'**
  String get categorySilk;

  /// No description provided for @categoryCotton.
  ///
  /// In en, this message translates to:
  /// **'Cotton'**
  String get categoryCotton;

  /// No description provided for @categoryVelvet.
  ///
  /// In en, this message translates to:
  /// **'Velvet'**
  String get categoryVelvet;

  /// No description provided for @categoryLinen.
  ///
  /// In en, this message translates to:
  /// **'Linen'**
  String get categoryLinen;

  /// No description provided for @categoryWool.
  ///
  /// In en, this message translates to:
  /// **'Wool'**
  String get categoryWool;

  /// Flash sale discount badge and price
  ///
  /// In en, this message translates to:
  /// **'{discount} · {price}'**
  String flashSalePriceLine(String discount, String price);

  /// No description provided for @compositionMulberrySilk.
  ///
  /// In en, this message translates to:
  /// **'100% Mulberry Silk'**
  String get compositionMulberrySilk;

  /// No description provided for @compositionEgyptianGizaCotton.
  ///
  /// In en, this message translates to:
  /// **'100% Egyptian Giza Cotton'**
  String get compositionEgyptianGizaCotton;

  /// No description provided for @compositionCottonSilkBlend.
  ///
  /// In en, this message translates to:
  /// **'85% Cotton, 15% Silk'**
  String get compositionCottonSilkBlend;

  /// No description provided for @compositionEuropeanFlaxLinen.
  ///
  /// In en, this message translates to:
  /// **'100% European Flax Linen'**
  String get compositionEuropeanFlaxLinen;

  /// No description provided for @compositionMerinoWool.
  ///
  /// In en, this message translates to:
  /// **'100% Merino Wool'**
  String get compositionMerinoWool;

  /// No description provided for @compositionMulberrySilkCharmeuse.
  ///
  /// In en, this message translates to:
  /// **'100% Mulberry Silk Charmeuse'**
  String get compositionMulberrySilkCharmeuse;

  /// No description provided for @compositionCombedCotton.
  ///
  /// In en, this message translates to:
  /// **'100% Combed Cotton'**
  String get compositionCombedCotton;

  /// No description provided for @compositionSilkViscoseBlend.
  ///
  /// In en, this message translates to:
  /// **'70% Silk, 30% Viscose'**
  String get compositionSilkViscoseBlend;

  /// No description provided for @compositionIrishLinen.
  ///
  /// In en, this message translates to:
  /// **'100% Irish Linen'**
  String get compositionIrishLinen;

  /// No description provided for @careDryCleanSilk.
  ///
  /// In en, this message translates to:
  /// **'Dry clean only. Cool iron on reverse. Store folded in breathable cotton.'**
  String get careDryCleanSilk;

  /// No description provided for @careMachineWashCotton.
  ///
  /// In en, this message translates to:
  /// **'Machine wash cold, gentle cycle. Tumble dry low. Iron while slightly damp.'**
  String get careMachineWashCotton;

  /// No description provided for @careDryCleanVelvet.
  ///
  /// In en, this message translates to:
  /// **'Dry clean only. Steam to remove creases. Brush nap gently in one direction.'**
  String get careDryCleanVelvet;

  /// No description provided for @careMachineWashLinen.
  ///
  /// In en, this message translates to:
  /// **'Machine wash cold. Hang dry. Embrace natural wrinkles or iron on high while damp.'**
  String get careMachineWashLinen;

  /// No description provided for @careDryCleanWool.
  ///
  /// In en, this message translates to:
  /// **'Dry clean preferred. Spot clean with cold water. Store with cedar to deter moths.'**
  String get careDryCleanWool;

  /// No description provided for @careDryCleanSilkCharmeuse.
  ///
  /// In en, this message translates to:
  /// **'Dry clean only. Cool iron on reverse. Hang on padded hanger to prevent creasing.'**
  String get careDryCleanSilkCharmeuse;

  /// No description provided for @careMachineWashCombedCotton.
  ///
  /// In en, this message translates to:
  /// **'Machine wash warm. Tumble dry low. Iron on medium heat.'**
  String get careMachineWashCombedCotton;

  /// No description provided for @careDryCleanCrushedVelvet.
  ///
  /// In en, this message translates to:
  /// **'Dry clean only. Steam from a distance. Never press directly.'**
  String get careDryCleanCrushedVelvet;

  /// No description provided for @careMachineWashIrishLinen.
  ///
  /// In en, this message translates to:
  /// **'Machine wash cold. Line dry for best results. Iron while damp for crisp finish.'**
  String get careMachineWashIrishLinen;

  /// No description provided for @originVaranasiIndia.
  ///
  /// In en, this message translates to:
  /// **'Varanasi, India'**
  String get originVaranasiIndia;

  /// No description provided for @originNileDeltaEgypt.
  ///
  /// In en, this message translates to:
  /// **'Nile Delta, Egypt'**
  String get originNileDeltaEgypt;

  /// No description provided for @originComoItaly.
  ///
  /// In en, this message translates to:
  /// **'Como, Italy'**
  String get originComoItaly;

  /// No description provided for @originBelgium.
  ///
  /// In en, this message translates to:
  /// **'Belgium'**
  String get originBelgium;

  /// No description provided for @originYorkshireEngland.
  ///
  /// In en, this message translates to:
  /// **'Yorkshire, England'**
  String get originYorkshireEngland;

  /// No description provided for @originSuzhouChina.
  ///
  /// In en, this message translates to:
  /// **'Suzhou, China'**
  String get originSuzhouChina;

  /// No description provided for @originIzmirTurkey.
  ///
  /// In en, this message translates to:
  /// **'Izmir, Turkey'**
  String get originIzmirTurkey;

  /// No description provided for @originBursaTurkey.
  ///
  /// In en, this message translates to:
  /// **'Bursa, Turkey'**
  String get originBursaTurkey;

  /// No description provided for @originBelfastNorthernIreland.
  ///
  /// In en, this message translates to:
  /// **'Belfast, Northern Ireland'**
  String get originBelfastNorthernIreland;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
