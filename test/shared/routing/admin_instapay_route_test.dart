import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/admin/domain/entities/instapay_proof.dart';
import 'package:al_batal_elite/features/admin/domain/repositories/admin_instapay_port.dart';
import 'package:al_batal_elite/features/admin/presentation/pages/admin_instapay_reviews_page.dart';
import 'package:al_batal_elite/shared/routing/app_routes.dart';
import 'package:al_batal_elite/shared/routing/route_pages.dart';
import 'package:al_batal_elite/shared/services/service_locator.dart';
import 'package:flutter_test/flutter_test.dart';

final class _StubInstapayPort implements AdminInstapayPort {
  @override
  Future<Result<List<InstapayProof>>> listPendingProofs() async =>
      const Success([]);

  @override
  Future<Result<void>> reviewProof(
    String proofId, {
    required bool approve,
    String? note,
  }) async =>
      const Success(null);

  @override
  Future<Result<String>> signedProofUrl(String storagePath) async =>
      const Success('https://signed.example/proof');
}

void main() {
  test('the InstaPay review path is the declared admin route', () {
    expect(Routes.adminInstapay, '/admin/instapay');
    expect(Routes.adminInstapay.startsWith(Routes.admin), isTrue);
  });

  test('RoutePages.adminInstapay resolves the page and its port', () {
    if (getIt.isRegistered<AdminInstapayPort>()) {
      getIt.unregister<AdminInstapayPort>();
    }
    final port = _StubInstapayPort();
    getIt.registerSingleton<AdminInstapayPort>(port);
    addTearDown(() {
      if (getIt.isRegistered<AdminInstapayPort>()) {
        getIt.unregister<AdminInstapayPort>();
      }
    });

    final page = RoutePages.adminInstapay();

    expect(page, isA<AdminInstapayReviewsPage>());
    expect((page as AdminInstapayReviewsPage).repository, same(port),
        reason: 'the composition root owns the port; the view never '
            'service-locates');
  });
}
