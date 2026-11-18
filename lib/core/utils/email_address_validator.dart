/// A shared syntax guard for login, signup and password recovery.
///
/// It validates input shape only. Supabase remains authoritative for account
/// ownership and delivery; public recovery must not reveal account existence.
abstract final class EmailAddressValidator {
  static final RegExp _syntax =
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static bool isValid(String rawEmail) {
    final email = rawEmail.trim();
    return email.isNotEmpty && email.length <= 254 && _syntax.hasMatch(email);
  }
}
