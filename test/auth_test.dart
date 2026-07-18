import 'package:al_batal_elite/core/entities/profile.dart';
import 'package:al_batal_elite/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthState', () {
    test('isAuthenticated when status is authenticated', () {
      const state = AuthState(status: AuthStatus.authenticated);
      expect(state.isAuthenticated, isTrue);
      expect(state.isGuest, isFalse);
    });

    test('isGuest when status is unauthenticated', () {
      const state = AuthState(status: AuthStatus.unauthenticated);
      expect(state.isGuest, isTrue);
      expect(state.isAuthenticated, isFalse);
    });

    test('isLoading for initial, checkingSession, authenticating', () {
      expect(
          const AuthState(status: AuthStatus.initial).isLoading, isTrue);
      expect(const AuthState(status: AuthStatus.checkingSession).isLoading,
          isTrue);
      expect(
          const AuthState(status: AuthStatus.authenticating).isLoading, isTrue);
      expect(
          const AuthState(status: AuthStatus.authenticated).isLoading, isFalse);
    });

    test('copyWith clearProfile sets profile to null', () {
      const state = AuthState(
        status: AuthStatus.authenticated,
        profile: Profile(id: 'u1', fullName: 'Test'),
      );
      final cleared = state.copyWith(clearProfile: true);
      expect(cleared.profile, isNull);
    });

    test('copyWith preserves profile when clearProfile is false', () {
      const profile = Profile(id: 'u1', fullName: 'Test');
      const state = AuthState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
      final updated = state.copyWith(profile: Profile(id: 'u1', fullName: 'Updated'));
      expect(updated.profile!.fullName, 'Updated');
    });
  });

  group('Profile', () {
    test('copyWith preserves all fields', () {
      const profile = Profile(
        id: 'u1',
        fullName: 'Ahmed',
        phone: '+20123456789',
        isAdmin: false,
      );
      final updated = profile.copyWith(fullName: 'Sara', phone: '+20987654321');
      expect(updated.id, 'u1');
      expect(updated.fullName, 'Sara');
      expect(updated.phone, '+20987654321');
      expect(updated.isAdmin, isFalse);
    });

    test('props includes all fields', () {
      const profile = Profile(id: 'u1', fullName: 'Test');
      expect(profile.props, ['u1', 'Test', null, null, false]);
    });
  });
}
