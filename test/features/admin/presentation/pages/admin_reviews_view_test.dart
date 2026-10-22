import 'package:al_batal_elite/core/error/app_error.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_reviews_port.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_reviews_page.dart';
import 'package:al_batal_elite/generated/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _PendingRow = ({String id, String product, String text, int rating});

class _FakeReviewsPort implements AdminReviewsPort {
  Result<List<_PendingRow>> result = const Success(<_PendingRow>[]);
  int fetchCalls = 0;
  final List<(String, String)> statusWrites = [];

  @override
  Future<Result<List<_PendingRow>>> fetchPendingReviews() async {
    fetchCalls++;
    return result;
  }

  @override
  Future<Result<void>> setReviewStatus(String id, String status) async {
    statusWrites.add((id, status));
    return const Success(null);
  }
}

void main() {
  late _FakeReviewsPort port;

  setUp(() {
    port = _FakeReviewsPort();
  });

  Widget harness() => MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AdminReviewsPage(repository: port),
      );

  testWidgets('renders the pending queue, then moderates rows out of it',
      (tester) async {
    port.result = const Success(<_PendingRow>[
      (id: 'r-1', product: 'Royal Silk', text: 'Beautiful fabric', rating: 4),
      (id: 'r-2', product: 'Linen', text: 'Fast delivery', rating: 5),
    ]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Review moderation'), findsOneWidget);
    expect(find.text('Beautiful fabric'), findsOneWidget);
    expect(find.text('Royal Silk · ★★★★'), findsOneWidget);
    expect(find.text('Linen · ★★★★★'), findsOneWidget);

    await tester.tap(find.byTooltip('Approve').first);
    await tester.pumpAndSettle();

    expect(port.statusWrites, [('r-1', 'approved')]);
    expect(find.text('Beautiful fabric'), findsNothing);
    expect(find.text('Fast delivery'), findsOneWidget);

    await tester.tap(find.byTooltip('Reject'));
    await tester.pumpAndSettle();

    expect(port.statusWrites, [
      ('r-1', 'approved'),
      ('r-2', 'rejected'),
    ]);
    expect(find.text('No reviews yet — be the first.'), findsOneWidget);
    expect(port.fetchCalls, 1);
  });

  testWidgets('pull-to-refresh reloads the queue', (tester) async {
    port.result = const Success(<_PendingRow>[
      (id: 'r-1', product: 'Silk', text: 'Nice', rating: 3),
    ]);

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final indicator =
        tester.widget<RefreshIndicator>(find.byType(RefreshIndicator));
    await indicator.onRefresh();
    await tester.pumpAndSettle();

    expect(port.fetchCalls, 2);
    expect(find.text('Nice'), findsOneWidget);
  });

  testWidgets('failed load renders the error and a retry that recovers',
      (tester) async {
    port.result = const Failure(AppError('offline'));

    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    port.result = const Success(<_PendingRow>[
      (id: 'r-1', product: 'Silk', text: 'Recovered', rating: 5),
    ]);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(port.fetchCalls, 2);
    expect(find.text('offline'), findsNothing);
    expect(find.text('Recovered'), findsOneWidget);
  });

  testWidgets('an empty queue renders the empty state', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('No reviews yet — be the first.'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
}
