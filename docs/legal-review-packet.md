# Legal review packet — customer policies (DRAFT)

Status: **draft for owner/counsel review.** The in-app copy is live in the ARB
files but is not legal advice and has not been reviewed by a lawyer.

Review target (EN + AR):

- `l10n/app_en.arb` / `l10n/app_ar.arb`
  - `privacyPolicyContent`
  - `termsOfServiceContent`
  - `shippingPolicyContent`
  - `returnsPolicyContent`
  - `legalLastUpdated`
- Rendered by:
  - `lib/features/support/presentation/pages/privacy_policy_page.dart`
  - `lib/features/support/presentation/pages/terms_of_service_page.dart`
  - `lib/features/support/presentation/pages/shipping_policy_page.dart`
  - `lib/features/support/presentation/pages/returns_policy_page.dart`

The policies intentionally do **not** invent a company address, phone number,
registration number, or tax ID. Contact is routed through the in-app Support
page. Counsel must supply the legal entity details and the official contact
address before release.

## Data map (what the app actually does)

| Data | Where it lives | Purpose | Retention / deletion |
|---|---|---|---|
| Name, phone, email, avatar URL | Supabase `profiles` | Account, delivery contact | Deleted with the account; past order rows are retained without the profile |
| Address book | On-device storage (local repository) | Delivery | Wiped on sign-out / account deletion |
| Cart, wishlist, recently viewed, recent searches | On-device storage (+ wishlist sync when signed in) | Convenience | Wiped on sign-out / account deletion |
| Orders + line items | Supabase `orders`, `order_items` | Fulfilment, accounting | Retained after account deletion for delivery/accounting/legal reasons (the delete-account copy says this) |
| Payment records | Supabase `payments` | Payment status, reconciliation | Retained after account deletion with the user link cleared; **no card numbers are stored** |
| Card payments | Paymob hosted checkout | Payment processing | Paymob is the processor; the app receives a payment id/status only |
| InstaPay transfer proofs | Private Supabase Storage bucket `instapay-proofs` + `instapay_proofs` metadata | Manual payment verification | Reviewed/retained for reconciliation; not public |
| Push identity | OneSignal external user id (the Supabase user id) | Order-status push | Unlinked on sign-out; provider retention governed by OneSignal |
| Transactional email | Resend | Order notifications (when configured) | Provider retention governed by Resend |
| First-party analytics events | Supabase `analytics_events` | Product/usage analytics | 90-day purge job (migration 031) |
| Crash diagnostics | Sentry | Stability | Provider retention governed by Sentry |
| App settings / app lock | On-device storage | Preferences, biometric lock | Wiped on app data clear |

Hosting/region: Supabase project is in **eu-west-1** (staging and production).
Payment processing is Egypt-focused (Paymob / InstaPay). OneSignal, Resend and
Sentry are third-party processors outside Egypt/EU depending on contract —
counsel should confirm the transfer mechanism and the current DPA list.

## Questions for counsel

1. **Legal entity + contact**: registered name, address, commercial register,
   tax ID, privacy contact email, and the governing-law clause.
2. **Consumer withdrawal/returns**: confirm the 14-day unused/uncut rule and the
   exclusions for cut-to-length and custom fabric under Egyptian consumer law.
3. **Refund timing/method**: confirm the wording "refunded to the original
   payment method" and the maximum statutory period.
4. **Shipping liability**: who bears risk in transit, and what the failed-delivery
   rule should say.
5. **Privacy**: controller identity, lawful basis, data-subject request channel,
   cross-border transfer wording, and whether the 90-day analytics retention and
   account-deletion exceptions are sufficient.
6. **Payment records**: confirm the retention period for order/payment records
   after account deletion (tax/accounting).
7. **Minors**: confirm the minimum age / guardian consent wording if required.
8. **Arabic/English**: confirm the Arabic version is the authoritative one for
   Egyptian customers, or state which prevails.

## Release checklist after counsel review

- [ ] Entity name/address/contact added to Privacy + Terms.
- [ ] Return window and exclusions confirmed.
- [ ] Refund method/period confirmed.
- [ ] Governing law and jurisdiction confirmed.
- [ ] Cross-border processor list confirmed.
- [ ] Both ARB locales updated and `flutter test test/l10n` green.
- [ ] `legalLastUpdated` bumped on the next change.
