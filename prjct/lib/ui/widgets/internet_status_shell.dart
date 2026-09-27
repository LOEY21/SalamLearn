import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Briefly announces connection changes above every route.
class InternetStatusShell extends StatefulWidget {
  const InternetStatusShell({
    super.key,
    required this.child,
    required this.checkInternet,
    required this.connectivityChanges,
  });

  final Widget child;
  final Future<bool> Function() checkInternet;
  final Stream<List<ConnectivityResult>> connectivityChanges;

  @override
  State<InternetStatusShell> createState() => _InternetStatusShellState();
}

class _InternetStatusShellState extends State<InternetStatusShell>
    with WidgetsBindingObserver {
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _timer;
  Timer? _hideTimer;
  bool? _isOnline;
  bool _visible = false;
  int _checkVersion = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscription = widget.connectivityChanges.listen((results) {
      if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        _setOffline();
      } else {
        _refresh();
      }
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    _refresh();
  }

  void _setOffline() {
    _checkVersion++;
    if (mounted && _isOnline != false) _showStatus(false);
  }

  void _showStatus(bool online) {
    _hideTimer?.cancel();
    setState(() {
      _isOnline = online;
      _visible = online;
    });
    if (online) {
      _hideTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(() => _visible = false);
      });
    }
  }

  Future<void> _refresh() async {
    final version = ++_checkVersion;
    bool online;
    try {
      online = await widget.checkInternet();
    } catch (_) {
      online = false;
    }
    if (!mounted || version != _checkVersion || _isOnline == online) return;
    _showStatus(online);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _checkVersion++;
    _timer?.cancel();
    _hideTimer?.cancel();
    _subscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_isOnline == false)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Semantics(
                liveRegion: true,
                child: const IgnorePointer(
                  child: ColoredBox(
                    color: AppColors.danger,
                    child: SizedBox(
                      key: Key('offline-internet-line'),
                      height: 24,
                      child: Center(
                        child: Text(
                          'No internet connection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_visible && _isOnline == true)
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Align(
                alignment: Alignment.topCenter,
                child: Semantics(
                  liveRegion: true,
                  child: Material(
                    color: AppColors.mint,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.wifi_rounded,
                            size: 18,
                            color: AppColors.tealDark,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected to the internet',
                            style: const TextStyle(
                              color: AppColors.tealDark,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
