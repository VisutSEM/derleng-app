final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String value) => _emailPattern.hasMatch(value.trim());

String? validateEmail(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Email is required';
  if (!isValidEmail(text)) return 'Enter a valid email address';
  return null;
}

String? validatePassword(String? value) {
  final text = value ?? '';
  if (text.isEmpty) return 'Password is required';
  if (text.length < 6) return 'Use at least 6 characters';
  return null;
}

String? validateName(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return 'Name is required';
  if (text.length < 2) return 'Enter your full name';
  return null;
}
