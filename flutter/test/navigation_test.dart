// Regression tests for the v1.10.2 "black screen after deleting a contact"
// bug: a screen that closes itself must never close Home as well.
import 'dart:async';

import 'package:celebria/widgets/nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late BuildContext homeCtx, detailCtx, editCtx;
  late GlobalKey<NavigatorState> navKey;

  Future<void> pumpStack(WidgetTester tester, {bool withEdit = true}) async {
    navKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
      navigatorKey: navKey,
      home: Builder(builder: (c) {
        homeCtx = c;
        return const Text('HOME');
      }),
    ));
    navKey.currentState!.push(MaterialPageRoute(builder: (c) {
      detailCtx = c;
      return const Text('DETAIL');
    }));
    await tester.pumpAndSettle();
    if (withEdit) {
      navKey.currentState!.push(MaterialPageRoute(builder: (c) {
        editCtx = c;
        return const Text('EDIT');
      }));
      await tester.pumpAndSettle();
    }
  }

  testWidgets('delete flow: edit closes, detail closes (called twice) — Home stays',
      (tester) async {
    await pumpStack(tester);
    // Delete → the edit screen closes itself...
    closeOwnRoute(editCtx);
    // ...and the detail screen, now without its contact, rebuilds twice
    // before its frame callback runs (what produced the black screen).
    closeOwnRoute(detailCtx);
    closeOwnRoute(detailCtx);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(find.text('DETAIL'), findsNothing);
    expect(navKey.currentState!.canPop(), isFalse, reason: 'only Home is left');
    expect(homeCtx.mounted, isTrue);
  });

  testWidgets('closing a route that is not on top removes only that route', (tester) async {
    await pumpStack(tester);
    closeOwnRoute(detailCtx); // Detail is under Edit
    await tester.pumpAndSettle();
    expect(find.text('EDIT'), findsOneWidget);
    closeOwnRoute(editCtx);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    expect(navKey.currentState!.canPop(), isFalse);
  });

  testWidgets('double tap on a "close" button never pops Home', (tester) async {
    await pumpStack(tester, withEdit: false);
    closeOwnRoute(detailCtx);
    closeOwnRoute(detailCtx); // second tap during the exit animation
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
    closeOwnRoute(homeCtx); // even asked directly, Home is the root: no black screen
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });

  test('OnceGuard ignores a second run while the first is in progress', () async {
    final guard = OnceGuard();
    var runs = 0;
    final gate = Completer<void>();
    final first = guard.run(() async {
      runs++;
      await gate.future;
    });
    await guard.run(() async => runs++); // double tap
    expect(runs, 1);
    gate.complete();
    await first;
    await guard.run(() async => runs++); // a later, separate tap works
    expect(runs, 2);
  });
}
