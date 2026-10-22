import 'package:al_batal_elite/shared/services/analytics_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/supabase_admin_fakes.dart';

class _RecordingSink implements AnalyticsSink {
  final List<({String name, Map<String, dynamic> props})> sent = [];
  final List<List<({String name, Map<String, dynamic> props})>> batches = [];
  bool failNextBatch = false;

  @override
  Future<void> send(String name, Map<String, dynamic> props) async {
    sent.add((name: name, props: props));
  }

  @override
  Future<void> sendBatch(
    List<({String name, Map<String, dynamic> props})> events,
  ) async {
    if (failNextBatch) {
      failNextBatch = false;
      throw Exception('offline');
    }
    batches.add(List.of(events));
  }
}

void main() {
  setUpAll(() {
    registerFallbackValue(Object());
  });

  group('AnalyticsService buffering', () {
    test('disabled service buffers and sends nothing', () async {
      final sink = _RecordingSink();
      final service = AnalyticsService(sink: sink, enabled: false);

      service.log(AnalyticsService.productView, {'id': 'p1'});
      await service.flush();

      expect(sink.batches, isEmpty);
      service.dispose();
    });

    test('flush sends the buffered batch once', () async {
      final sink = _RecordingSink();
      final service = AnalyticsService(sink: sink);

      service.log(AnalyticsService.productView, {'id': 'p1'});
      service.log(AnalyticsService.addToCart, {'id': 'p1', 'qty': 2});
      await service.flush();

      expect(sink.batches.single, hasLength(2));
      expect(sink.batches.single.first.name, AnalyticsService.productView);
      expect(sink.batches.single.last.props['qty'], 2);
      service.dispose();
    });

    test('flush is a no-op when the buffer is empty', () async {
      final sink = _RecordingSink();
      final service = AnalyticsService(sink: sink);

      await service.flush();

      expect(sink.batches, isEmpty);
      service.dispose();
    });

    test('reaching the batch size flushes without waiting for the timer',
        () async {
      final sink = _RecordingSink();
      final service = AnalyticsService(sink: sink);

      for (var i = 0; i < AnalyticsService.batchSize; i++) {
        service.log(AnalyticsService.productView, {'id': '$i'});
      }
      await Future<void>.delayed(Duration.zero);

      expect(sink.batches.single, hasLength(AnalyticsService.batchSize));
      service.dispose();
    });

    test('a failed flush re-queues the events for the next attempt', () async {
      final sink = _RecordingSink()..failNextBatch = true;
      final service = AnalyticsService(sink: sink);

      service.log(AnalyticsService.purchase, {'id': 'order-1'});
      await service.flush();
      expect(sink.batches, isEmpty);

      await service.flush();
      expect(sink.batches.single.single.name, AnalyticsService.purchase);
      service.dispose();
    });

    test('dispose cancels the pending timer', () async {
      final sink = _RecordingSink();
      final service = AnalyticsService(sink: sink);

      service.log(AnalyticsService.checkoutStart);
      service.dispose();

      expect(sink.batches, isEmpty);
    });
  });

  group('SupabaseAnalyticsSink', () {
    late MockSupabaseClient client;
    late MockSupabaseQueryBuilder builder;

    setUp(() {
      client = MockSupabaseClient();
      builder = MockSupabaseQueryBuilder();
      when(() => client.from('analytics_events')).thenAnswer((_) => builder);
      when(() => builder.insert(any()))
          .thenAnswer((_) => FakeFilterBuilder<dynamic>(const <dynamic>[]));
    });

    test('single send inserts one row', () async {
      final sink = SupabaseAnalyticsSink(client: client);

      await sink.send('product_view', {'id': 'p1'});

      final rows = verify(() => builder.insert(captureAny())).captured.single;
      expect(rows, [
        {
          'event': 'product_view',
          'properties': {'id': 'p1'},
        }
      ]);
    });

    test('batch send inserts one row per event and ignores empty batches',
        () async {
      final sink = SupabaseAnalyticsSink(client: client);

      await sink.sendBatch([
        (name: 'product_view', props: {'id': 'p1'}),
        (name: 'add_to_cart', props: {'id': 'p1'}),
      ]);
      await sink.sendBatch(const []);

      final rows = verify(() => builder.insert(captureAny())).captured.single;
      expect(rows, [
        {
          'event': 'product_view',
          'properties': {'id': 'p1'},
        },
        {
          'event': 'add_to_cart',
          'properties': {'id': 'p1'},
        },
      ]);
    });
  });
}
