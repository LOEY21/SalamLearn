import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:salamlearn/ui/widgets/internet_status_shell.dart';

void main() {
  testWidgets('shows the current internet status and updates when it changes',
      (tester) async {
    final changes = StreamController<List<ConnectivityResult>>.broadcast();
    addTearDown(changes.close);
    var online = true;

    await tester.pumpWidget(MaterialApp(
      home: InternetStatusShell(
        checkInternet: () async => online,
        connectivityChanges: changes.stream,
        child: const Scaffold(body: Center(child: Text('Page content'))),
      ),
    ));
    await tester.pump();
    expect(find.text('Connected to the internet'), findsOneWidget);
    expect(find.text('Page content'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Connected to the internet'), findsNothing);
    expect(find.text('Page content'), findsOneWidget);

    online = false;
    // Wi-Fi can still be connected while internet access is unavailable.
    changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('offline-internet-line'))).height,
        24);
    expect(find.text('No internet connection'), findsOneWidget);
    expect(find.text('Connected to the internet'), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);

    online = true;
    changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();
    expect(find.text('Connected to the internet'), findsOneWidget);
    expect(find.byKey(const Key('offline-internet-line')), findsNothing);

    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Connected to the internet'), findsNothing);

    changes.add([ConnectivityResult.none]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);

    changes.add([ConnectivityResult.wifi]);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('offline-internet-line')), findsNothing);
    expect(find.text('Connected to the internet'), findsOneWidget);
  });

  testWidgets('treats a failed reachability check as offline', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: InternetStatusShell(
        checkInternet: () async => throw StateError('No route'),
        connectivityChanges: const Stream.empty(),
        child: const Scaffold(body: Text('Page content')),
      ),
    ));
    await tester.pump();
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);
    expect(find.text('No internet connection'), findsOneWidget);
  });

  testWidgets('rechecks while the app stays open on the same network',
      (tester) async {
    var online = true;
    await tester.pumpWidget(MaterialApp(
      home: InternetStatusShell(
        checkInternet: () async => online,
        connectivityChanges: const Stream.empty(),
        child: const Scaffold(body: Text('Page content')),
      ),
    ));
    await tester.pump();
    expect(find.text('Connected to the internet'), findsOneWidget);

    online = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump();
    expect(find.byKey(const Key('offline-internet-line')), findsOneWidget);
  });
}
