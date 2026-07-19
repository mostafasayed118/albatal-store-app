/// Outcome of an authentication operation that may produce a session.
///
/// Returned by [AuthRepository] methods wrapped in [Result]. The two
/// variants distinguish "session established" from "account created but
/// email confirmation required" — a distinction the previous code
/// encoded as a null response.user with no session.
sealed class AuthOutcome {
  const AuthOutcome();
}

/// A session was established; the user is signed in.
final class Authenticated extends AuthOutcome {
  const Authenticated(this.userId);
  final String userId;
}

/// Account was created but email confirmation is pending; no session yet.
final class ConfirmationRequired extends AuthOutcome {
  const ConfirmationRequired();
}
