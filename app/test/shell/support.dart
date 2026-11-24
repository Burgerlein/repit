import 'package:flutter/cupertino.dart';

/// Testhuelle für das Tab-Gerüst (Task 10).
///
/// Anders als `test/design/support.dart` wickelt diese Huelle **keinen**
/// zusätzlichen `CupertinoPageScaffold` um `child`: `RootView` baut selbst
/// einen `CupertinoTabScaffold` mit je einem `CupertinoPageScaffold` pro Tab
/// (flutter#166487, siehe Task-Brief Schritt 3). Eine zweite Scaffold-Schicht
/// darüber wäre nicht falsch, aber unnötig und würde die Baumsuche in den
/// Tests verfälschen (`find.byType(CupertinoPageScaffold)` fände dann immer
/// mindestens zwei, auch wenn nur eine pro Tab gemeint ist).
Widget huelle(Widget child) {
  return CupertinoApp(home: child);
}
