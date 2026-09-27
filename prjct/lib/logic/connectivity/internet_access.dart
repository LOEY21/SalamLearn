import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

/// A fresh reachability check for actions that must create a remote-backed
/// account or child profile. The function can be overridden in tests.
final internetAccessProvider = Provider<Future<bool> Function()>((ref) {
  return () => InternetConnection()
      .hasInternetAccess
      .timeout(const Duration(seconds: 5), onTimeout: () => false);
});

class AccountCreationOfflineException implements Exception {
  const AccountCreationOfflineException();

  @override
  String toString() =>
      'Connect to the internet before creating an account or child profile.';
}
