import 'dart:convert';

import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/core/error/failure_codes.dart';
import 'package:al_batal_elite/core/error/result.dart';
import 'package:al_batal_elite/features/auth/data/supabase_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const String _columns =
    'id,full_name,phone,avatar_url,is_admin,membership_tier';

SupabaseClient _client(MockClient httpClient) {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-anon-key',
    httpClient: httpClient,
  );
  addTearDown(client.dispose);
  return client;
}

void main() {
  group('readProfile', () {
    test('returns null when the row is missing', () async {
      final client = _client(MockClient((request) async {
        return http.Response('[]', 200,
            headers: {'content-type': 'application/json'}, request: request);
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.readProfile('u1');

      final value =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(value, isNull);
    });

    test('maps a row with explicit columns for the requested user', () async {
      final requests = <http.Request>[];
      final client = _client(MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode([
            {
              'id': 'u1',
              'full_name': 'Ahmed',
              'phone': '+201000000000',
              'avatar_url': null,
              'is_admin': true,
              'membership_tier': 'premium',
            },
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.readProfile('u1');

      final profile =
          result.when(success: (v) => v, failure: (_) => fail('unexpected'));
      expect(profile?.id, 'u1');
      expect(profile?.fullName, 'Ahmed');
      expect(profile?.phone, '+201000000000');
      expect(profile?.isAdmin, isTrue);
      expect(profile?.tier, MembershipTier.premium);

      final url = requests.single.url;
      expect(url.path, '/rest/v1/profiles');
      expect(url.queryParameters['select'], _columns);
      expect(url.queryParameters['id'], 'eq.u1');
    });

    test('maps a Postgrest rejection into a load failure', () async {
      final client = _client(MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'permission denied', 'code': '42501'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.readProfile('u1');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureLoad);
      expect(error.message, 'Failed to load profile');
    });

    test('an identity-less row fails closed', () async {
      final client = _client(MockClient((request) async {
        return http.Response(
          jsonEncode([
            {'full_name': 'No id'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.readProfile('u1');

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureLoad);
    });
  });

  group('upsertProfile', () {
    test('writes only the self-service columns', () async {
      final requests = <http.Request>[];
      final client = _client(MockClient((request) async {
        requests.add(request);
        return http.Response('', 201, request: request);
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.upsertProfile(
        const Profile(
          id: 'u1',
          fullName: 'Ahmed',
          phone: '+201000000000',
          isAdmin: true,
          tier: MembershipTier.premium,
        ),
      );

      expect(result, isA<Success<void>>());
      final body = jsonDecode(requests.single.body) as Map<String, dynamic>;
      expect(body, {
        'id': 'u1',
        'full_name': 'Ahmed',
        'phone': '+201000000000',
        'avatar_url': null,
      });
      expect(body.containsKey('is_admin'), isFalse);
      expect(body.containsKey('membership_tier'), isFalse);
    });

    test('maps a Postgrest rejection into a save failure', () async {
      final client = _client(MockClient((request) async {
        return http.Response(
          jsonEncode({'message': 'row level security', 'code': '42501'}),
          403,
          headers: {'content-type': 'application/json'},
        );
      }));
      final repository = SupabaseProfileRepository(client: client);

      final result = await repository.upsertProfile(
        const Profile(id: 'u1', fullName: 'Ahmed'),
      );

      final error =
          result.when(success: (_) => fail('unexpected'), failure: (e) => e);
      expect(error.code, kFailureSave);
      expect(error.message, 'Failed to save profile');
    });
  });
}
