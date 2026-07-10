import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Result of the silent launch checks (FR-1.1, FR-1.2).
class LaunchCheckResult {
  const LaunchCheckResult({
    required this.assetsIntact,
    required this.storageOk,
  });

  final bool assetsIntact;
  final bool storageOk;

  bool get allPassed => assetsIntact && storageOk;
}

/// Mocked launch checks for the offline demo phase.
///
/// Real implementation later: hash-verify cached .mp3/.png/.json bundles
/// (FR-1.1) and query free disk space against the 500MB floor (FR-1.2).
final launchChecksProvider = FutureProvider<LaunchCheckResult>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 1400));
  return const LaunchCheckResult(assetsIntact: true, storageOk: true);
});
