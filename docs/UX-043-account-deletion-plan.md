# UX-043 — Account Deletion: Implementation Plan (for human approval)

**Status:** PLAN — no `supabase/` or code changes made. Backend parts are
human-gated (migrations + edge functions require review before landing).

---

## 1. Why

Google Play requires apps with account creation to offer in-app account
deletion. `Al Batal Elite` has none today (audit UX-043, HIGH for release).
This plan covers schema changes, a deletion edge function, and the settings
UI + l10n, with the product decisions that must be made first.

## 2. Current-state facts (verified on master `2c443c4`)

Foreign-key graph around `profiles` (migrations 001/006/010):

| Table | Link to `profiles` | Effect on hard delete |
|---|---|---|
| `addresses`, `wishlists`, `cart_items` | `ON DELETE CASCADE` | deleted automatically |
| `payments` (006) | `ON DELETE CASCADE` | deleted automatically |
| `notifications` / analytics (010) | `ON DELETE SET NULL` | safe |
| `orders` (001) | `ON DELETE RESTRICT`, `user_id NOT NULL` | **blocks deletion** while any order exists |

- `profiles.id` → `auth.users(id) ON DELETE CASCADE` (001): deleting the auth
  user wipes the profile.
- `orders` rows are self-contained for fulfillment: they carry
  `address_snapshot JSONB` + `order_items` (product name/image/size/color
  snapshots, unit_price, quantity) that survive independently of the user row.

## 3. Product decisions required (blocks backend work)

- **A. Admin accounts:** recommend refusing in-app deletion for
  `profiles.is_admin = true` (store operators must not self-delete → lockout).
  Fallback: owner-only deletion via DB.
- **B. Transaction retention:** deleting the auth user cascades `payments`
  and drops the `orders.user_id` link. Recommend **retaining** `orders` +
  `order_items` + `payments` rows for COD fulfillment / financial records,
  while unlinking the person:
  - `orders.user_id` becomes nullable `ON DELETE SET NULL` (migration).
  - `payments` currently `CASCADE` — if financial records must be kept, this
    also needs `SET NULL` on `user_id` (add to the migration). Deleting them
    is acceptable only if the store keeps zero financial history by design.
  - Address snapshots inside `orders` are retention data; disclose this in
    the confirmation copy ("order records for past purchases are kept for
    delivery and legal reasons").
- **C. Re-authentication:** Play recommends re-auth before deletion. Cheapest
  compliant flow: user types their email + taps a destructive confirm; a
  recent-sign-in requirement can be layered on later via
  `auth.users.last_sign_in_at`.

## 4. Backend design (human-gated)

### 4a. Migration (new `supabase/migrations/04X_account_deletion.sql`)

Idempotent, forward-only:

1. `orders`: drop `user_id NOT NULL` + swap FK `RESTRICT` → `ON DELETE SET
   NULL` (drop constraint, re-add with new action — SQL guarded by existence
   checks).
2. If decision B = retain payments: same swap for `payments.user_id`
   (`NOT NULL` kept unless payments may be anonymous → drop NOT NULL too).
3. Grant/revoke: deletion is driven by the edge function's service role, not
   by client SQL, so no new RLS policy is needed on `profiles`.

### 4b. Edge function `delete-account` (mirrors repo's existing edge-function
conventions, e.g. `paymob-initiate`)

Contract:

- `POST` with the user's JWT. `{ "userId": "..." }`.
- Verify `auth.uid()` (from the verified JWT) equals `userId`, else 403.
- Service-role query `profiles.is_admin` for the id → refuse (403 "admin")
  per decision A.
- Delete the auth user: `supabase.auth.admin.deleteUser(userId)` → cascades
  to profile → addresses/wishlists/cart_items (and payments if B = delete).
- Delete the user's avatar from storage (bucket from migration 005) if set.
- Return `200 { deleted: true }`. Errors mapped to `AppError`-style messages
  by the client repository.
- Note: the profile row dies with the auth user; `orders.user_id` nulls via
  the relaxed FK (their snapshot data remains).

## 5. Client work (implementable after approval)

### Data layer
- `AuthRepository` gains `Future<Result<void>> deleteAccount()`.
- `SupabaseAuthRepository` implements it via
  `supabase.functions.invoke('delete-account')`.
- All test doubles implementing `AuthRepository` gain the override
  (`test/helpers/stub_auth_repositories.dart` + any fakes).

### AuthCubit
- `deleteAccount()` → call repo; on success `signOut()` and **clear local
  persistence** (cart/wishlist `MemoryStorefrontPersistence` + any local
  caches) before emitting `unauthenticated`.

### Settings UI (`settings_page.dart`)
- New destructive `ListTile` below Support — `Icons.delete_outline`, error
  color — visible only when authenticated.
- Tap → confirmation dialog: explain scope (order retention per decision B),
  a text field asking the user to type their email, destructive confirm +
  cancel. Errors surface as snackbar with `AppError.message`.

### l10n keys (draft; AR to be native-checked)
| Key | EN | AR (draft) |
|---|---|---|
| `deleteAccount` | Delete account | حذف الحساب |
| `deleteAccountTitle` | Delete account | حذف الحساب |
| `deleteAccountBody` | Deletes your profile, addresses, wishlist, cart and saved data. Past order records are kept for delivery and legal reasons. | سيتم حذف ملفك الشخصي وعناوينك وقائمتك المفضلة وسلة مشترياتك. تبقى سجلات الطلبات السابقة لأغراض التوصيل والقانون. |
| `deleteAccountConfirmHint` | Type your email to confirm | اكتب بريدك الإلكتروني للتأكيد |
| `deleteAccountConfirm` | Delete permanently | حذف نهائي |
| `deleteAccountCancel` | Cancel | إلغاء |
| `deleteAccountEmailMismatch` | Email does not match this account | البريد الإلكتروني غير مطابق لهذا الحساب |
| `deleteAccountSuccess` | Account deleted | تم حذف الحساب |
| `deleteAccountAdminBlocked` | Admin accounts can’t be deleted in the app | لا يمكن حذف حسابات المسؤولين من التطبيق |
| `accountDeletion` note about Play disclosure | — | — |

### Tests
- Cubit: success → `unauthenticated` + persistence cleared; failure →
  error surfaced; admin-blocked error mapped.
- Widget: settings row only for authenticated users; dialog validation
  (mismatched email blocks confirm).
- l10n: EN + AR keys regenerated and rendered (same pattern as
  `test/microcopy_plural_test.dart`).

## 6. Rollout

1. Human reviews this plan + decisions A/B/C → approve.
2. Migration 04X written + `supabase db push` to staging (human), RLS
   adversarial checks re-run.
3. Edge function `delete-account` deployed (human).
4. Client branch (worktree) implemented + full suite + CI; PR → master.
5. Manual E2E on staging: delete → session ends, local data cleared, orders
   retained + unlinked, sign-in with deleted email blocked.

## 7. Open decisions to confirm

- [ ] A: block admin in-app deletion? (recommended yes)
- [ ] B: retain `orders` (+`payments`) with user unlinked vs. full erase?
      (recommended retain)
- [ ] C: require re-authentication now or later?
