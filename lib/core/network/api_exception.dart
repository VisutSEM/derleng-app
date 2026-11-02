/// A user-facing API failure.
class ApiException implements Exception {
  const ApiException(
    this.message, {
    this.statusCode,
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;
  final bool isNetwork;

  factory ApiException.network() => const ApiException(
        'Cannot reach the Derleng API. Check your connection or switch to demo data.',
        isNetwork: true,
      );

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}
