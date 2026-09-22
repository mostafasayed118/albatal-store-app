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

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete account?'**
  String get deleteAccountTitle;

  /// No description provided for @deleteAccountBody.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your profile, addresses, wishlist and cart. Past order records are kept for delivery and legal reasons.'**
  String get deleteAccountBody;

  /// No description provided for @deleteAccountConfirmHint.
  ///
  /// In en, this message translates to:
  /// **'Type your email to confirm'**
  String get deleteAccountConfirmHint;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete permanently'**
  String get deleteAccountConfirm;

  /// No description provided for @deleteAccountCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get deleteAccountCancel;

  /// No description provided for @deleteAccountSuccess.
  ///
  /// In en, this message translates to:
  /// **'Account deleted'**
  String get deleteAccountSuccess;

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

  /// No description provided for @failureLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load. Please try again.'**
  String get failureLoad;

  /// No description provided for @failureSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Please try again.'**
  String get failureSave;

  /// No description provided for @failureNetwork.
  ///
  /// In en, this message translates to:
  /// **'Connection problem. Please try again.'**
  String get failureNetwork;

  /// No description provided for @failureNotAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get failureNotAuthenticated;

  /// No description provided for @failureSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session expired. Please sign in again.'**
  String get failureSessionExpired;

  /// No description provided for @failureSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed. Please try again.'**
  String get failureSignInFailed;

  /// No description provided for @failureSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'Sign-up failed. Please try again.'**
  String get failureSignUpFailed;

  /// No description provided for @failureNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get failureNotFound;

  /// No description provided for @failureUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get failureUnexpected;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authInvalidCredentials;

  /// No description provided for @authEmailUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Please verify your email address first'**
  String get authEmailUnconfirmed;

  /// No description provided for @authEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists'**
  String get authEmailInUse;

  /// No description provided for @authWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authWeakPassword;

  /// No description provided for @deleteEmailMismatch.
  ///
  /// In en, this message translates to:
  /// **'The email does not match this account'**
  String get deleteEmailMismatch;

  /// No description provided for @deleteAdminBlocked.
  ///
  /// In en, this message translates to:
  /// **'Admin accounts cannot be deleted in the app'**
  String get deleteAdminBlocked;

  /// No description provided for @deleteNotOwner.
  ///
  /// In en, this message translates to:
  /// **'You can only delete your own account'**
  String get deleteNotOwner;

  /// No description provided for @deleteFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Account deletion failed. Please try again.'**
  String get deleteFailedRetry;

  /// No description provided for @errorBody.
  ///
  /// In en, this message translates to:
  /// **'Please check your connection and try again.'**
  String get errorBody;

  /// No description provided for @offlineBannerMessage.
  ///
  /// In en, this message translates to:
  /// **'No internet connection'**
  String get offlineBannerMessage;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open that. Please try again.'**
  String get couldNotOpenLink;

  /// No description provided for @imageRemoved.
  ///
  /// In en, this message translates to:
  /// **'Image removed'**
  String get imageRemoved;

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

  /// No description provided for @payment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get payment;

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

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start shopping'**
  String get startShopping;

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

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @orderTimelineTitle.
  ///
  /// In en, this message translates to:
  /// **'Order tracking'**
  String get orderTimelineTitle;

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

  /// No description provided for @wishlistEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Your wishlist is empty'**
  String get wishlistEmptyTitle;

  /// No description provided for @wishlistEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart on any product to save it here.'**
  String get wishlistEmptyBody;

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

  /// No description provided for @premiumMember.
  ///
  /// In en, this message translates to:
  /// **'Premium Member'**
  String get premiumMember;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @membershipTier.
  ///
  /// In en, this message translates to:
  /// **'Membership tier'**
  String get membershipTier;

  /// No description provided for @standardMember.
  ///
  /// In en, this message translates to:
  /// **'Standard Member'**
  String get standardMember;

  /// No description provided for @changeMembershipTier.
  ///
  /// In en, this message translates to:
  /// **'Change membership tier'**
  String get changeMembershipTier;

  /// No description provided for @membershipTierUpdated.
  ///
  /// In en, this message translates to:
  /// **'Membership tier updated'**
  String get membershipTierUpdated;

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

  /// No description provided for @signedOut.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get signedOut;

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

  /// No description provided for @addToCartTotal.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart - {total}'**
  String addToCartTotal(String total);

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

  /// No description provided for @sortNameAZ.
  ///
  /// In en, this message translates to:
  /// **'Name: A to Z'**
  String get sortNameAZ;

  /// No description provided for @sortNewest.
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get sortNewest;

  /// Number of fabrics found
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No fabrics found} =1{1 fabric found} other{{count} fabrics found}}'**
  String fabricsFound(int count);

  /// No description provided for @newArrival.
  ///
  /// In en, this message translates to:
  /// **'New Arrival'**
  String get newArrival;

  /// No description provided for @newSilkCollection.
  ///
  /// In en, this message translates to:
  /// **'New Silk Collection'**
  String get newSilkCollection;

  /// No description provided for @percentOff.
  ///
  /// In en, this message translates to:
  /// **'20% Off'**
  String get percentOff;

  /// No description provided for @shopNow.
  ///
  /// In en, this message translates to:
  /// **'Shop Now'**
  String get shopNow;

  /// Screen-reader label for the flash-sale countdown
  ///
  /// In en, this message translates to:
  /// **'Flash sale ends in {time}'**
  String flashSaleTimeRemaining(String time);

  /// Screen-reader label for a hero carousel page dot
  ///
  /// In en, this message translates to:
  /// **'Go to slide {number}'**
  String goToSlide(int number);

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

  /// No description provided for @removeFromWishlistAction.
  ///
  /// In en, this message translates to:
  /// **'Remove from wishlist'**
  String get removeFromWishlistAction;

  /// No description provided for @fabricCategories.
  ///
  /// In en, this message translates to:
  /// **'Fabric Categories'**
  String get fabricCategories;

  /// Number of curated fabrics in a category
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No curated fabrics} =1{1 curated fabric} other{{count} curated fabrics}}'**
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

  /// No description provided for @whatsappShareProduct.
  ///
  /// In en, this message translates to:
  /// **'Share on WhatsApp'**
  String get whatsappShareProduct;

  /// WhatsApp prefill: product name, price and deep link
  ///
  /// In en, this message translates to:
  /// **'{name} — {price}\n{url}'**
  String whatsappShareProductMessage(Object name, Object price, Object url);

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @recentSearches.
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// No description provided for @recentlyViewed.
  ///
  /// In en, this message translates to:
  /// **'Recently viewed'**
  String get recentlyViewed;

  /// No description provided for @searchSuggestions.
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get searchSuggestions;

  /// No description provided for @clearRecent.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearRecent;

  /// No description provided for @couponFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'Coupon code'**
  String get couponFieldLabel;

  /// No description provided for @couponApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get couponApply;

  /// No description provided for @couponApplied.
  ///
  /// In en, this message translates to:
  /// **'Coupon applied — the discount is confirmed by the server when you place the order.'**
  String get couponApplied;

  /// No description provided for @couponInvalid.
  ///
  /// In en, this message translates to:
  /// **'This coupon code is not valid.'**
  String get couponInvalid;

  /// No description provided for @couponUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Coupons are unavailable right now.'**
  String get couponUnavailable;

  /// No description provided for @couponRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove coupon'**
  String get couponRemove;

  /// No description provided for @adminCoupons.
  ///
  /// In en, this message translates to:
  /// **'Coupons'**
  String get adminCoupons;

  /// No description provided for @manageCoupons.
  ///
  /// In en, this message translates to:
  /// **'Create and manage discount codes'**
  String get manageCoupons;

  /// No description provided for @couponCode.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get couponCode;

  /// No description provided for @couponDiscountEgp.
  ///
  /// In en, this message translates to:
  /// **'Discount (EGP)'**
  String get couponDiscountEgp;

  /// No description provided for @couponActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get couponActive;

  /// No description provided for @adminAddCoupon.
  ///
  /// In en, this message translates to:
  /// **'Add coupon'**
  String get adminAddCoupon;

  /// No description provided for @customerReviews.
  ///
  /// In en, this message translates to:
  /// **'Customer reviews'**
  String get customerReviews;

  /// Inline review list: opens the sheet holding every review, showing how many are not listed inline. The count is dropped when exactly one review is hidden, where it would be redundant
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Show all} other{Show all ({count})}}'**
  String showAllReviews(int count);

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review'**
  String get writeReview;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet — be the first.'**
  String get noReviewsYet;

  /// No description provided for @reviewPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'How is the fabric?'**
  String get reviewPlaceholder;

  /// No description provided for @reviewAddPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get reviewAddPhoto;

  /// No description provided for @reviewPhotoAdded.
  ///
  /// In en, this message translates to:
  /// **'Photo attached'**
  String get reviewPhotoAdded;

  /// No description provided for @reviewSubmit.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get reviewSubmit;

  /// No description provided for @reviewBuyRequired.
  ///
  /// In en, this message translates to:
  /// **'Reviews are open to customers who received this item.'**
  String get reviewBuyRequired;

  /// No description provided for @reviewUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Reviews are unavailable right now.'**
  String get reviewUnavailable;

  /// No description provided for @reviewModeration.
  ///
  /// In en, this message translates to:
  /// **'Review moderation'**
  String get reviewModeration;

  /// No description provided for @reviewApprove.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get reviewApprove;

  /// No description provided for @reviewReject.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get reviewReject;

  /// No description provided for @widthLabel.
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get widthLabel;

  /// No description provided for @metersValue.
  ///
  /// In en, this message translates to:
  /// **'{value} m'**
  String metersValue(num value);

  /// No description provided for @gsmLabel.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get gsmLabel;

  /// No description provided for @gsmValue.
  ///
  /// In en, this message translates to:
  /// **'{value} GSM'**
  String gsmValue(int value);

  /// No description provided for @cutLength.
  ///
  /// In en, this message translates to:
  /// **'Cut length'**
  String get cutLength;

  /// No description provided for @sellByLengthNote.
  ///
  /// In en, this message translates to:
  /// **'Sold by the meter — minimum cut applies.'**
  String get sellByLengthNote;

  /// Running line price under the cut-length selector
  ///
  /// In en, this message translates to:
  /// **'Estimated total: {total}'**
  String cutLengthEstimatedTotal(String total);

  /// No description provided for @pricingTiersTitle.
  ///
  /// In en, this message translates to:
  /// **'Wholesale pricing'**
  String get pricingTiersTitle;

  /// One wholesale tier row: minimum meters and discount
  ///
  /// In en, this message translates to:
  /// **'{meters}+ m — {percent}% off'**
  String pricingTierRow(String meters, int percent);

  /// No description provided for @orderSample.
  ///
  /// In en, this message translates to:
  /// **'Order fabric sample'**
  String get orderSample;

  /// No description provided for @sampleAdded.
  ///
  /// In en, this message translates to:
  /// **'Sample added to your cart'**
  String get sampleAdded;

  /// No description provided for @sampleLineItem.
  ///
  /// In en, this message translates to:
  /// **'Sample'**
  String get sampleLineItem;

  /// No description provided for @maintenanceTitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ll be right back'**
  String get maintenanceTitle;

  /// No description provided for @maintenanceBody.
  ///
  /// In en, this message translates to:
  /// **'Al Batal Elite is under maintenance. Please check back soon.'**
  String get maintenanceBody;

  /// No description provided for @updateRequiredTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateRequiredTitle;

  /// No description provided for @updateRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'This version is no longer supported. Please update the app to continue shopping.'**
  String get updateRequiredBody;

  /// No description provided for @adminCustomers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get adminCustomers;

  /// No description provided for @adminSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get adminSearch;

  /// No description provided for @adminSearchCustomersHint.
  ///
  /// In en, this message translates to:
  /// **'Search name or phone'**
  String get adminSearchCustomersHint;

  /// Directory count line. {total} is how many rows match the ACTIVE SEARCH (the whole table when no search is active), not just the loaded page.
  ///
  /// In en, this message translates to:
  /// **'Showing {shown} of {total}'**
  String customersShownOf(int shown, int total);

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @invoiceSave.
  ///
  /// In en, this message translates to:
  /// **'Save invoice'**
  String get invoiceSave;

  /// No description provided for @signInWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Google'**
  String get signInWithGoogle;

  /// No description provided for @signInWithApple.
  ///
  /// In en, this message translates to:
  /// **'Apple'**
  String get signInWithApple;

  /// No description provided for @oauthUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Sign-in with this provider is unavailable.'**
  String get oauthUnavailable;

  /// No description provided for @oauthCancelled.
  ///
  /// In en, this message translates to:
  /// **'Sign-in was cancelled.'**
  String get oauthCancelled;

  /// No description provided for @reorderAdded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing was added to your cart} =1{Added 1 item to your cart} other{Added {count} items to your cart}}'**
  String reorderAdded(int count);

  /// No description provided for @reorderUnavailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item is unavailable and was skipped} other{{count} items are unavailable and were skipped}}'**
  String reorderUnavailable(int count);

  /// No description provided for @shareProductMessage.
  ///
  /// In en, this message translates to:
  /// **'{name} — Al Batal Elite\n{url}'**
  String shareProductMessage(Object name, Object url);

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
  /// **'Good morning, {name}'**
  String goodMorning(Object name);

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
  /// **'{count, plural, =0{0 items} =1{1 item} other{{count} items}}'**
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

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit address'**
  String get editAddress;

  /// No description provided for @recipientName.
  ///
  /// In en, this message translates to:
  /// **'Recipient'**
  String get recipientName;

  /// No description provided for @streetAddress.
  ///
  /// In en, this message translates to:
  /// **'Street address'**
  String get streetAddress;

  /// No description provided for @city.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// No description provided for @country.
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// No description provided for @streetAddressRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid street address'**
  String get streetAddressRequired;

  /// No description provided for @cityRequired.
  ///
  /// In en, this message translates to:
  /// **'City is required'**
  String get cityRequired;

  /// No description provided for @countryRequired.
  ///
  /// In en, this message translates to:
  /// **'Country is required'**
  String get countryRequired;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

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

  /// No description provided for @freeShipping.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeShipping;

  /// No description provided for @premiumFreeShipping.
  ///
  /// In en, this message translates to:
  /// **'Free shipping on every order'**
  String get premiumFreeShipping;

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
  /// **'Password must be at least 8 characters'**
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

  /// No description provided for @instapay.
  ///
  /// In en, this message translates to:
  /// **'InstaPay'**
  String get instapay;

  /// No description provided for @instapayDescription.
  ///
  /// In en, this message translates to:
  /// **'Transfer via InstaPay, then submit the proof for review'**
  String get instapayDescription;

  /// No description provided for @instapayInstructionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Complete your InstaPay transfer'**
  String get instapayInstructionsTitle;

  /// No description provided for @instapayTransferTo.
  ///
  /// In en, this message translates to:
  /// **'Transfer the exact amount to'**
  String get instapayTransferTo;

  /// No description provided for @instapayAddressLabel.
  ///
  /// In en, this message translates to:
  /// **'InstaPay address'**
  String get instapayAddressLabel;

  /// No description provided for @instapayCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get instapayCopy;

  /// No description provided for @instapayCopied.
  ///
  /// In en, this message translates to:
  /// **'InstaPay address copied'**
  String get instapayCopied;

  /// No description provided for @instapayAmountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get instapayAmountLabel;

  /// No description provided for @instapayReferenceLabel.
  ///
  /// In en, this message translates to:
  /// **'Transfer reference (optional)'**
  String get instapayReferenceLabel;

  /// No description provided for @instapayReferenceHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. operation number or last 4 digits'**
  String get instapayReferenceHint;

  /// No description provided for @instapayAttachScreenshot.
  ///
  /// In en, this message translates to:
  /// **'Attach transfer screenshot'**
  String get instapayAttachScreenshot;

  /// No description provided for @instapayScreenshotAttached.
  ///
  /// In en, this message translates to:
  /// **'Screenshot attached'**
  String get instapayScreenshotAttached;

  /// No description provided for @instapaySubmitProof.
  ///
  /// In en, this message translates to:
  /// **'Submit proof for review'**
  String get instapaySubmitProof;

  /// No description provided for @instapayProofSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Proof submitted — we will review it shortly'**
  String get instapayProofSubmitted;

  /// No description provided for @instapayProofPendingNote.
  ///
  /// In en, this message translates to:
  /// **'Your payment stays pending until we review the proof. You can safely leave this page — the status appears in your orders.'**
  String get instapayProofPendingNote;

  /// No description provided for @instapayPickScreenshotError.
  ///
  /// In en, this message translates to:
  /// **'Could not pick the screenshot. Please try again.'**
  String get instapayPickScreenshotError;

  /// No description provided for @instapayFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The screenshot is too large. Please attach a smaller image.'**
  String get instapayFileTooLarge;

  /// No description provided for @instapayFileTypeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'That file type is not supported. Please attach a PNG, JPG, or WebP image.'**
  String get instapayFileTypeNotAllowed;

  /// No description provided for @instapayReferenceTooLong.
  ///
  /// In en, this message translates to:
  /// **'The reference is too long. Please keep it under 64 characters.'**
  String get instapayReferenceTooLong;

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

  /// No description provided for @noOrdersFoundBody.
  ///
  /// In en, this message translates to:
  /// **'New orders will appear here as customers check out.'**
  String get noOrdersFoundBody;

  /// Tooltip on the admin order queue's CSV export action, which shares the visible rows as a file (feature-batch §14).
  ///
  /// In en, this message translates to:
  /// **'Export orders as CSV'**
  String get exportOrdersCsv;

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

  /// No description provided for @stockUpdated.
  ///
  /// In en, this message translates to:
  /// **'Stock updated'**
  String get stockUpdated;

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
  /// **'al3tar66@gmail.com'**
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

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @updateStock.
  ///
  /// In en, this message translates to:
  /// **'Update Stock'**
  String get updateStock;

  /// No description provided for @newStockLevel.
  ///
  /// In en, this message translates to:
  /// **'New stock level'**
  String get newStockLevel;

  /// No description provided for @courierName.
  ///
  /// In en, this message translates to:
  /// **'Courier Name'**
  String get courierName;

  /// No description provided for @trackingNumber.
  ///
  /// In en, this message translates to:
  /// **'Tracking Number'**
  String get trackingNumber;

  /// No description provided for @addTrackingDetails.
  ///
  /// In en, this message translates to:
  /// **'Add Tracking Details'**
  String get addTrackingDetails;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @enterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid number'**
  String get enterValidNumber;

  /// No description provided for @stockCannotBeNegative.
  ///
  /// In en, this message translates to:
  /// **'Stock cannot be negative'**
  String get stockCannotBeNegative;

  /// No description provided for @orderStatusUpdatedTo.
  ///
  /// In en, this message translates to:
  /// **'Order status updated to {statusName}'**
  String orderStatusUpdatedTo(String statusName);

  /// No description provided for @orderMarkedAsShipped.
  ///
  /// In en, this message translates to:
  /// **'Order marked as shipped'**
  String get orderMarkedAsShipped;

  /// No description provided for @returnToPayment.
  ///
  /// In en, this message translates to:
  /// **'Return to payment'**
  String get returnToPayment;

  /// No description provided for @invalidCheckoutLink.
  ///
  /// In en, this message translates to:
  /// **'The payment checkout link is invalid. Please return and retry.'**
  String get invalidCheckoutLink;

  /// No description provided for @onboardingExquisiteTitle.
  ///
  /// In en, this message translates to:
  /// **'Exquisite Fabrics'**
  String get onboardingExquisiteTitle;

  /// No description provided for @onboardingExquisiteBody.
  ///
  /// In en, this message translates to:
  /// **'Discover a curated collection of the world\'s finest silks, linens, and velvets.'**
  String get onboardingExquisiteBody;

  /// No description provided for @onboardingCraftsmanshipTitle.
  ///
  /// In en, this message translates to:
  /// **'Artisanal Craftsmanship'**
  String get onboardingCraftsmanshipTitle;

  /// No description provided for @onboardingCraftsmanshipBody.
  ///
  /// In en, this message translates to:
  /// **'Every thread is woven with precision and heritage to ensure unparalleled quality.'**
  String get onboardingCraftsmanshipBody;

  /// No description provided for @onboardingExcellenceTitle.
  ///
  /// In en, this message translates to:
  /// **'Tailored for Excellence'**
  String get onboardingExcellenceTitle;

  /// No description provided for @onboardingExcellenceBody.
  ///
  /// In en, this message translates to:
  /// **'Experience the luxury of fabrics designed for those who settle for nothing less than elite.'**
  String get onboardingExcellenceBody;

  /// No description provided for @onboardingNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get onboardingNext;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paid;

  /// No description provided for @goodMorningGuest.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorningGuest;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon, {name}'**
  String goodAfternoon(Object name);

  /// No description provided for @goodAfternoonGuest.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoonGuest;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good evening, {name}'**
  String goodEvening(Object name);

  /// No description provided for @goodEveningGuest.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEveningGuest;

  /// No description provided for @estimatedTotalsNote.
  ///
  /// In en, this message translates to:
  /// **'Estimated totals — the final amount is confirmed at payment.'**
  String get estimatedTotalsNote;

  /// No description provided for @serverConfirmedTotals.
  ///
  /// In en, this message translates to:
  /// **'Server-confirmed totals'**
  String get serverConfirmedTotals;

  /// No description provided for @orderReferenceMissing.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue: the order reference is missing.'**
  String get orderReferenceMissing;

  /// No description provided for @customerEmailMissing.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue: the customer email is missing. Please sign in again.'**
  String get customerEmailMissing;

  /// No description provided for @paymentLinkInvalid.
  ///
  /// In en, this message translates to:
  /// **'The payment checkout link is invalid. Please retry.'**
  String get paymentLinkInvalid;

  /// No description provided for @paymentSucceededNoReference.
  ///
  /// In en, this message translates to:
  /// **'Payment succeeded but the order reference is missing.'**
  String get paymentSucceededNoReference;

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

  /// No description provided for @paymentTimedOutRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment verification timed out. Please check your orders before retrying.'**
  String get paymentTimedOutRetry;

  /// No description provided for @paymentFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. You can retry.'**
  String get paymentFailedRetry;

  /// No description provided for @paymentGenericFailure.
  ///
  /// In en, this message translates to:
  /// **'Payment failed. Please try again.'**
  String get paymentGenericFailure;

  /// No description provided for @paymentNotPending.
  ///
  /// In en, this message translates to:
  /// **'This payment is no longer pending.'**
  String get paymentNotPending;

  /// No description provided for @paymentVerifyFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment verification failed. Please try again.'**
  String get paymentVerifyFailed;

  /// No description provided for @paymentTimeout.
  ///
  /// In en, this message translates to:
  /// **'Payment timed out. Please check your orders before retrying.'**
  String get paymentTimeout;

  /// No description provided for @orderRefRequired.
  ///
  /// In en, this message translates to:
  /// **'Unable to continue: the order reference is missing.'**
  String get orderRefRequired;

  /// No description provided for @checkoutFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Checkout failed. Please try again.'**
  String get checkoutFailedRetry;

  /// No description provided for @checkoutCartEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your cart is empty. Add something exquisite first.'**
  String get checkoutCartEmpty;

  /// No description provided for @paymentMethodUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get paymentMethodUnknown;

  /// No description provided for @adminAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Admin access required'**
  String get adminAccessRequired;

  /// No description provided for @orderNotifications.
  ///
  /// In en, this message translates to:
  /// **'Order notifications'**
  String get orderNotifications;

  /// No description provided for @orderNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Confirmations and status updates'**
  String get orderNotificationsSubtitle;

  /// No description provided for @instapaySessionMissing.
  ///
  /// In en, this message translates to:
  /// **'Payment session not found'**
  String get instapaySessionMissing;

  /// No description provided for @galleryViewerLabel.
  ///
  /// In en, this message translates to:
  /// **'Product image viewer'**
  String get galleryViewerLabel;

  /// No description provided for @galleryClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get galleryClose;

  /// No description provided for @galleryZoomHint.
  ///
  /// In en, this message translates to:
  /// **'Pinch to zoom'**
  String get galleryZoomHint;

  /// No description provided for @gallerySwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe to browse photos'**
  String get gallerySwipeHint;

  /// No description provided for @notifyWhenBackInStock.
  ///
  /// In en, this message translates to:
  /// **'Notify me when back in stock'**
  String get notifyWhenBackInStock;

  /// No description provided for @backInStockAlertOn.
  ///
  /// In en, this message translates to:
  /// **'We\'ll notify you when {product} is back in stock'**
  String backInStockAlertOn(String product);

  /// No description provided for @backInStockAlertOff.
  ///
  /// In en, this message translates to:
  /// **'Back-in-stock alert removed'**
  String get backInStockAlertOff;

  /// No description provided for @backInStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Back in stock'**
  String get backInStockTitle;

  /// No description provided for @backInStockBody.
  ///
  /// In en, this message translates to:
  /// **'{product} is back in stock'**
  String backInStockBody(String product);

  /// Title shown on the biometric app-lock screen (feature-batch §15).
  ///
  /// In en, this message translates to:
  /// **'App locked'**
  String get appLocked;

  /// Body copy on the biometric app-lock screen.
  ///
  /// In en, this message translates to:
  /// **'Unlock with your device biometrics to continue.'**
  String get appLockMessage;

  /// Button label that re-triggers the biometric prompt.
  ///
  /// In en, this message translates to:
  /// **'Unlock'**
  String get appLockUnlock;

  /// Shown when the biometric prompt did not succeed; the app stays locked.
  ///
  /// In en, this message translates to:
  /// **'Authentication failed. Try again to unlock the app.'**
  String get appLockFailed;

  /// Escape hatch on the app-lock screen: signs the user out, then unlocks.
  ///
  /// In en, this message translates to:
  /// **'Sign out instead'**
  String get appLockSignOut;

  /// Settings toggle title that turns the biometric app lock on or off.
  ///
  /// In en, this message translates to:
  /// **'App lock'**
  String get appLockToggle;

  /// Settings toggle subtitle describing what the app lock does.
  ///
  /// In en, this message translates to:
  /// **'Require biometrics or the device passcode to open the app'**
  String get appLockToggleSubtitle;

  /// Shown when the device cannot authenticate (no biometrics and no passcode).
  ///
  /// In en, this message translates to:
  /// **'App lock isn\'t available on this device'**
  String get appLockUnavailable;

  /// No description provided for @salesDashboard.
  ///
  /// In en, this message translates to:
  /// **'Sales Dashboard'**
  String get salesDashboard;

  /// No description provided for @salesDashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Revenue, best sellers, low stock'**
  String get salesDashboardSubtitle;

  /// No description provided for @adminAccessCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify admin access. Please try again.'**
  String get adminAccessCheckFailed;

  /// No description provided for @adminNoCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories yet'**
  String get adminNoCategories;

  /// No description provided for @adminNoCategoriesBody.
  ///
  /// In en, this message translates to:
  /// **'Categories are created in the database; the storefront needs at least one.'**
  String get adminNoCategoriesBody;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @adminImagesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Images updated'**
  String get adminImagesUpdated;

  /// No description provided for @adminImageFileEmpty.
  ///
  /// In en, this message translates to:
  /// **'Selected file is empty.'**
  String get adminImageFileEmpty;

  /// No description provided for @adminImageUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported format. Use JPG, PNG, or WebP.'**
  String get adminImageUnsupportedFormat;

  /// No description provided for @adminImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large after compression.'**
  String get adminImageTooLarge;

  /// No description provided for @adminImageUploaded.
  ///
  /// In en, this message translates to:
  /// **'Image uploaded'**
  String get adminImageUploaded;

  /// No description provided for @adminImageUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed. Please try again.'**
  String get adminImageUploadFailed;

  /// No description provided for @adminDeleteImageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete image?'**
  String get adminDeleteImageTitle;

  /// No description provided for @adminDeleteImageBody.
  ///
  /// In en, this message translates to:
  /// **'This removes the image from the product gallery on the store.'**
  String get adminDeleteImageBody;

  /// No description provided for @adminImagesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load images'**
  String get adminImagesLoadFailed;

  /// No description provided for @adminUploadImage.
  ///
  /// In en, this message translates to:
  /// **'Upload Image'**
  String get adminUploadImage;

  /// No description provided for @adminNoImages.
  ///
  /// In en, this message translates to:
  /// **'No images yet'**
  String get adminNoImages;

  /// No description provided for @adminNoImagesBody.
  ///
  /// In en, this message translates to:
  /// **'Upload the first image so the product has a gallery on the store.'**
  String get adminNoImagesBody;

  /// No description provided for @adminProductNotFound.
  ///
  /// In en, this message translates to:
  /// **'Product not found'**
  String get adminProductNotFound;

  /// No description provided for @adminSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get adminSelectCategory;

  /// No description provided for @adminInvalidPrice.
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get adminInvalidPrice;

  /// No description provided for @adminPriceNegative.
  ///
  /// In en, this message translates to:
  /// **'Price cannot be negative'**
  String get adminPriceNegative;

  /// No description provided for @adminProductCreated.
  ///
  /// In en, this message translates to:
  /// **'Product created'**
  String get adminProductCreated;

  /// No description provided for @adminProductUpdated.
  ///
  /// In en, this message translates to:
  /// **'Product updated'**
  String get adminProductUpdated;

  /// No description provided for @adminNewProduct.
  ///
  /// In en, this message translates to:
  /// **'New Product'**
  String get adminNewProduct;

  /// No description provided for @adminEditProduct.
  ///
  /// In en, this message translates to:
  /// **'Edit Product'**
  String get adminEditProduct;

  /// No description provided for @adminNameField.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get adminNameField;

  /// No description provided for @adminSlugField.
  ///
  /// In en, this message translates to:
  /// **'Slug'**
  String get adminSlugField;

  /// No description provided for @adminRequiredField.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get adminRequiredField;

  /// No description provided for @adminBasePrice.
  ///
  /// In en, this message translates to:
  /// **'Base Price (EGP)'**
  String get adminBasePrice;

  /// No description provided for @adminInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get adminInvalidNumber;

  /// No description provided for @adminWidthCm.
  ///
  /// In en, this message translates to:
  /// **'Width (cm)'**
  String get adminWidthCm;

  /// No description provided for @adminWeightGsm.
  ///
  /// In en, this message translates to:
  /// **'Weight (GSM)'**
  String get adminWeightGsm;

  /// No description provided for @adminSellByLength.
  ///
  /// In en, this message translates to:
  /// **'Sell by length (per meter)'**
  String get adminSellByLength;

  /// No description provided for @adminSellByLengthHint.
  ///
  /// In en, this message translates to:
  /// **'Shoppers pick a custom cut length in 0.5 m steps'**
  String get adminSellByLengthHint;

  /// No description provided for @adminMinCutMeters.
  ///
  /// In en, this message translates to:
  /// **'Minimum cut (meters)'**
  String get adminMinCutMeters;

  /// No description provided for @adminCreateProduct.
  ///
  /// In en, this message translates to:
  /// **'Create Product'**
  String get adminCreateProduct;

  /// No description provided for @adminUpdateProduct.
  ///
  /// In en, this message translates to:
  /// **'Update Product'**
  String get adminUpdateProduct;

  /// No description provided for @adminNoProducts.
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get adminNoProducts;

  /// No description provided for @adminNoProductsBody.
  ///
  /// In en, this message translates to:
  /// **'Create the first product so the storefront has something to sell.'**
  String get adminNoProductsBody;

  /// No description provided for @adminImagesTooltip.
  ///
  /// In en, this message translates to:
  /// **'Images'**
  String get adminImagesTooltip;

  /// No description provided for @adminReload.
  ///
  /// In en, this message translates to:
  /// **'Reload'**
  String get adminReload;

  /// No description provided for @adminSalesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load sales'**
  String get adminSalesLoadFailed;

  /// No description provided for @adminSalesLoadFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Failed to load sales data.'**
  String get adminSalesLoadFailedBody;

  /// No description provided for @adminNoSalesData.
  ///
  /// In en, this message translates to:
  /// **'No sales data available.'**
  String get adminNoSalesData;

  /// No description provided for @adminAddVariant.
  ///
  /// In en, this message translates to:
  /// **'Add Variant'**
  String get adminAddVariant;

  /// No description provided for @adminEditVariant.
  ///
  /// In en, this message translates to:
  /// **'Edit Variant'**
  String get adminEditVariant;

  /// No description provided for @adminSizeField.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get adminSizeField;

  /// No description provided for @adminStockField.
  ///
  /// In en, this message translates to:
  /// **'Stock'**
  String get adminStockField;

  /// No description provided for @adminPriceOverrideOptional.
  ///
  /// In en, this message translates to:
  /// **'Price Override (optional)'**
  String get adminPriceOverrideOptional;

  /// No description provided for @adminSizeColorRequired.
  ///
  /// In en, this message translates to:
  /// **'Size and color are required'**
  String get adminSizeColorRequired;

  /// No description provided for @adminInvalidStock.
  ///
  /// In en, this message translates to:
  /// **'Invalid stock'**
  String get adminInvalidStock;

  /// No description provided for @adminInvalidPriceOverride.
  ///
  /// In en, this message translates to:
  /// **'Invalid price override'**
  String get adminInvalidPriceOverride;

  /// No description provided for @adminPriceOverrideNegative.
  ///
  /// In en, this message translates to:
  /// **'Price override cannot be negative'**
  String get adminPriceOverrideNegative;

  /// No description provided for @adminVariantSaved.
  ///
  /// In en, this message translates to:
  /// **'Variant saved'**
  String get adminVariantSaved;

  /// No description provided for @adminNoVariants.
  ///
  /// In en, this message translates to:
  /// **'No variants yet'**
  String get adminNoVariants;

  /// No description provided for @adminVariantStock.
  ///
  /// In en, this message translates to:
  /// **'Stock: {count}'**
  String adminVariantStock(int count);

  /// No description provided for @adminVariantOverride.
  ///
  /// In en, this message translates to:
  /// **'Override: {price}'**
  String adminVariantOverride(String price);

  /// No description provided for @adminLowStockTitle.
  ///
  /// In en, this message translates to:
  /// **'Low stock (≤ {threshold})'**
  String adminLowStockTitle(int threshold);

  /// No description provided for @adminLowStockEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing below the threshold'**
  String get adminLowStockEmpty;

  /// No description provided for @adminStockLeft.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 left} other{{count} left}}'**
  String adminStockLeft(int count);

  /// No description provided for @adminRevenueLastDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{Revenue — last day} other{Revenue — last {days} days}}'**
  String adminRevenueLastDays(int days);

  /// No description provided for @adminNoRevenueData.
  ///
  /// In en, this message translates to:
  /// **'No revenue data'**
  String get adminNoRevenueData;

  /// No description provided for @adminOrdersByStatus.
  ///
  /// In en, this message translates to:
  /// **'Orders by status'**
  String get adminOrdersByStatus;

  /// No description provided for @adminNoOrdersInWindow.
  ///
  /// In en, this message translates to:
  /// **'No orders in this window'**
  String get adminNoOrdersInWindow;

  /// No description provided for @adminBestSellers.
  ///
  /// In en, this message translates to:
  /// **'Best sellers — units sold'**
  String get adminBestSellers;

  /// No description provided for @adminNoSalesInWindow.
  ///
  /// In en, this message translates to:
  /// **'No sales in this window'**
  String get adminNoSalesInWindow;

  /// No description provided for @adminUnitsShort.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 u} other{{count} u}}'**
  String adminUnitsShort(int count);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @refunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get refunded;

  /// No description provided for @adminFailureAccessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access denied: admin only'**
  String get adminFailureAccessDenied;

  /// No description provided for @adminFailureOrdersLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load orders. Please try again.'**
  String get adminFailureOrdersLoad;

  /// No description provided for @adminFailureOrderLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this order. Please try again.'**
  String get adminFailureOrderLoad;

  /// No description provided for @adminFailureOrderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get adminFailureOrderNotFound;

  /// No description provided for @adminFailureStatusInvalid.
  ///
  /// In en, this message translates to:
  /// **'That order status isn\'t recognized.'**
  String get adminFailureStatusInvalid;

  /// No description provided for @adminFailureStatusUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the order status. Please try again.'**
  String get adminFailureStatusUpdate;

  /// No description provided for @adminFailureLowStockLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load low-stock products. Please try again.'**
  String get adminFailureLowStockLoad;

  /// No description provided for @adminFailureSalesLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load sales data. Please try again.'**
  String get adminFailureSalesLoad;

  /// No description provided for @adminFailureStockUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the stock. Please try again.'**
  String get adminFailureStockUpdate;

  /// No description provided for @adminFailureProductsLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load products. Please try again.'**
  String get adminFailureProductsLoad;

  /// No description provided for @adminFailureProductLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this product. Please try again.'**
  String get adminFailureProductLoad;

  /// No description provided for @adminFailureCategoriesLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load categories. Please try again.'**
  String get adminFailureCategoriesLoad;

  /// No description provided for @adminFailureProductSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the product. Please try again.'**
  String get adminFailureProductSave;

  /// No description provided for @adminFailureVariantSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the variant. Please try again.'**
  String get adminFailureVariantSave;

  /// No description provided for @adminFailureImagesSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the images. Please try again.'**
  String get adminFailureImagesSave;

  /// No description provided for @adminFailureVariantsLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load variants. Please try again.'**
  String get adminFailureVariantsLoad;

  /// No description provided for @adminFailureImagesLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load images. Please try again.'**
  String get adminFailureImagesLoad;

  /// No description provided for @adminFailureMembershipUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the membership tier. Please try again.'**
  String get adminFailureMembershipUpdate;

  /// No description provided for @adminFailureCouponsLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load coupons. Please try again.'**
  String get adminFailureCouponsLoad;

  /// No description provided for @adminFailureCouponCreate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create the coupon. Please try again.'**
  String get adminFailureCouponCreate;

  /// No description provided for @adminFailureCouponUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the coupon. Please try again.'**
  String get adminFailureCouponUpdate;

  /// No description provided for @adminFailureCustomersLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load customers. Please try again.'**
  String get adminFailureCustomersLoad;

  /// No description provided for @adminFailureReviewsLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the review queue. Please try again.'**
  String get adminFailureReviewsLoad;

  /// No description provided for @adminFailureReviewUpdate.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the review. Please try again.'**
  String get adminFailureReviewUpdate;
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
