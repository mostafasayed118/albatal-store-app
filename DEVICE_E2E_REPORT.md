# Physical Device E2E Report

## Device

- Model: Infinix X6882
- Android: 14
- Display: 1080x2460, density 480
- Package: `com.albatal.elite`
- Environment: staging Supabase configuration

## Scope exercised

- Cold startup and persisted-session startup
- Onboarding and skip action
- Home content, search input, category chips, flash-sale card, product grid, sort control, scrolling
- Bottom navigation: Home, Categories, Cart, Wishlist, Profile
- Category-to-catalog navigation and filtering
- Product details: back, wishlist, share, gallery tap, variants, Add to Cart
- Cart: quantity controls, remove/save-for-later affordances, totals, checkout navigation
- Checkout empty state, address form, validation, disabled/enabled proceed state
- Profile, orders, shipping addresses, address form
- Settings: language and theme switching
- Android keyboard, external gallery/zoom route, app relaunch, logcat stability

## Issues found and fixes

### E2E-001 — Home greeting used the wrong name

**Severity:** P2 UX correctness

**Reproduction:**
1. Start the app with a signed-in profile whose name is `UI Tester`.
2. Open Home.
3. Observe the greeting.

**Observed:** `Good morning, Ahmed`.

**Expected:** The greeting should use the authenticated profile's first name.

**Fix:** `HomePage` now uses `BlocSelector<AuthCubit, AuthState, String?>` and derives the first name from the active profile. Added a regression test asserting `Good morning, UI` and rejecting `Good morning, Ahmed`.

**Device retest:** The fixed debug APK was installed after uninstalling the previous differently signed package. Cold start and onboarding completed successfully. The signed-in test session was not available after the clean uninstall, so the authenticated-name assertion remains statically/test-covered rather than device-confirmed in this pass.

### E2E-002 — Address-management dialog hid validation errors

**Severity:** P2 UX / form usability

**Reproduction:**
1. Open Profile → Shipping Addresses.
2. Tap Add Address.
3. Leave all fields empty.
4. Tap Save.

**Observed:** The dialog remained open but displayed no inline error messages, leaving the user without actionable feedback.

**Expected:** Each empty field should show a clear required-field error.

**Fix:** Address dialog now tracks submission state with `StatefulBuilder`, displays inline errors for empty fields, and clears each error as the field is edited.

**Verification:** `flutter analyze` passed in the isolated fix worktree. A fresh debug APK build completed successfully; widget execution was blocked in this environment by the recurring `flutter_tester` WebSocket issue, so this fix should receive a focused device retest after installation.

## Passed observations

- App launched without Flutter fatal exceptions.
- Navigation destinations exposed usable Android accessibility nodes with large hit regions.
- Search accepted input and opened the Android keyboard.
- Category selection filtered the catalog to the expected product count.
- Product detail loaded with variant controls and Add to Cart.
- Cart totals updated and checkout opened.
- Checkout correctly disabled payment progression when no address existed.
- Checkout address form showed actionable validation errors.
- Settings language and theme changes applied live and persisted during the session.
- Empty wishlist, empty orders, and empty address states rendered with actions.
- Android back navigation returned from nested routes and external gallery view.
- No Flutter fatal exception was found in the captured app log. Repeated `gralloc4` format warnings occurred when using the external gallery; these are device/vendor graphics logs, not application exceptions.

## Environment limitations

- The installed release APK was signed differently from the local debug build, producing `INSTALL_FAILED_UPDATE_INCOMPATIBLE`; the device app had to be uninstalled before the fixed debug APK could be installed. This reset the persisted authenticated session.
- Full widget-test execution was blocked by `WebSocketException: Invalid WebSocket upgrade request` while connecting to `flutter_tester`.
- The release build attempt hit a Windows native-symbol permission error in the isolated worktree; the debug build completed and was used for the clean-install retest.
- Paymob card/WebView completion was not executed because the staging Paymob integration is documented as owner-gated/pending. COD order completion was not repeated in this pass to avoid creating another backend test order without a confirmed disposable-user fixture.
