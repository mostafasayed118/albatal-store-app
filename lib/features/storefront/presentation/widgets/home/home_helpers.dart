import '../../../../../generated/l10n/app_localizations.dart';
import '../../cubit/catalog_cubit.dart';

/// Whether [HomePage]'s outer catalog [BlocBuilder] should rebuild for the
/// transition [previous] → [current] (audit Task 11).
///
/// Compares only the fields the home page actually renders: [CatalogStatus],
/// the product list (drives [CatalogState.visible] and
/// [CatalogState.featuredProducts]), categories, [CatalogFilters], recent
/// queries, and [CatalogState.flashSales] (banner presence plus
/// [CatalogState.discountLabel]).
///
/// The flash countdown needs no exclusion clause (audit P3): ticks flow
/// on the cubit's [CatalogCubit.flashCountdown] stream and never produce
/// a state emission at all. [CatalogState.carouselIndex] is excluded —
/// StitchHeroCarousel owns its page position internally.
///
/// List fields are compared by identity: the cubit assigns fresh list
/// instances only when the underlying data changes (copyWith passes the
/// same instance through on data-preserving emits), which keeps the
/// predicate O(1) instead of deep-scanning the catalog on every emit.
///
/// Extracted from `home_page.dart` verbatim (import the page for the
/// widget; import this file for the pure helpers).
bool homeBuildWhen(CatalogState previous, CatalogState current) {
  if (previous.status != current.status) return true;
  if (previous.isOffline != current.isOffline) return true;
  if (!identical(previous.allProducts, current.allProducts)) return true;
  if (previous.categories != current.categories) return true;
  if (previous.filters != current.filters) return true;
  if (previous.recentQueries != current.recentQueries) return true;
  if (previous.flashSales != current.flashSales) return true;
  return false;
}

/// Time-of-day greeting copy (UX-044).
///
/// Buckets: 05:00–11:59 morning, 12:00–16:59 afternoon, otherwise evening
/// (17:00–04:59). [firstName] selects the personalized form; `null` picks
/// the guest form.
String homeGreeting(AppLocalizations l10n, String? firstName, DateTime now) {
  final hour = now.hour;
  if (hour >= 5 && hour < 12) {
    return firstName == null
        ? l10n.goodMorningGuest
        : l10n.goodMorning(firstName);
  }
  if (hour >= 12 && hour < 17) {
    return firstName == null
        ? l10n.goodAfternoonGuest
        : l10n.goodAfternoon(firstName);
  }
  return firstName == null
      ? l10n.goodEveningGuest
      : l10n.goodEvening(firstName);
}
