/// Holds form fields and in-flight inputs during user registration and onboarding.
class AuthRegistrationFormState {
  String? userType;
  String? email;
  String? verificationCode;
  String? password;
  String? name;
  String? phone;
  String position = 'GK';
  String governorate = 'Cairo';

  /// Clears form fields back to default initial state.
  void reset() {
    userType = null;
    email = null;
    password = null;
    name = null;
    phone = null;
    position = 'GK';
  }
}
