import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/ki/ki_schluessel.dart';

/// Tests für die **Dart-Seite des Keychain-Kanals** — Task 6 des Plans
/// `docs/superpowers/plans/2026-11-04-ki-zugang.md` (Karte #337), Spec
/// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitt
/// „Der Schlüssel".
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf ausgeführt, aber nicht verändert werden. Geschrieben
/// ohne den Code von `lib/ki/ki_schluessel.dart` gesehen zu haben — es gab
/// ihn beim Schreiben noch nicht.
///
/// ## Was diese Datei verbindlich vorgibt
///
/// In `lib/ki/ki_schluessel.dart` (Namen aus dem Plan):
///
/// ```dart
/// abstract interface class KiSchluesselSpeicher {
///   Future<String?> lies();
///   Future<void> schreibe(String wert);
///   Future<void> loesche();
/// }
/// class KanalSchluesselSpeicher implements KiSchluesselSpeicher { … }
/// class AttrappenSchluesselSpeicher implements KiSchluesselSpeicher { … }
/// final kiSchluesselProvider = Provider<KiSchluesselSpeicher>(…);
/// String endung(String schluessel);
/// ```
///
/// Die Gegenseite ist `app/ios/Runner/KeychainChannel.swift` (in main):
/// Kanal `de.rosenbach.repit/keychain`, Methoden `lies`,
/// `schreibe`, `loesche`, Argumente als Map `{konto, wert}`. Das Konto ist
/// `gemini` (Spec). Geprüft wird hier die Dart-Hälfte gegen dieselben
/// Zeichenketten — dasselbe Verfahren wie in `hrv_kanal_test.dart`.
///
/// ## Eigene Festlegungen dieser Datei — nicht von Tim freigegeben
///
/// Plan und Spec lassen offen, was hier festgelegt wird. Es sind
/// Entscheidungen des Test-Agenten, keine abgestimmten:
///
/// - **Beide Speicher haben einen Konstruktor ohne Argumente.**
///   `KanalSchluesselSpeicher()` spricht den Kanal oben an,
///   `AttrappenSchluesselSpeicher()` beginnt leer.
/// - **Ein Kanalfehler beim Lesen wird geworfen, nicht zu `null`.** `null`
///   heißt „kein Schlüssel hinterlegt"; ein verschluckter Keychain-Fehler
///   ließe den Schirm „ohne Schlüssel" zeigen, obwohl einer da ist — `01`
///   eine Ebene tiefer.
/// - **Auch ein geworfener Fehler enthält den Wert nicht.** Die Swift-Seite
///   sichert das für ihre Meldungen zu; die Dart-Seite darf ihn beim
///   Weiterreichen nicht hineinschreiben.
/// - **Der Provider liefert ohne Überschreibung den Kanal-Speicher.** Die
///   Attrappe ist für Tests, nicht für den Simulator; ob es dort eine
///   andere Vorgabe braucht, ist nicht Teil dieser Karte.
///
/// ## Alle Schlüssel hier sind erfunden
///
/// Kein echter Schlüssel, in keinem Test (`CLAUDE.md`, „Niemals tun"). Die
/// Zeichenfolgen tragen **nicht** das Präfix `AIza` echter Google-Schlüssel
/// und sagen schon im Text, dass sie erfunden sind.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const kanalName = 'de.rosenbach.repit/keychain';
  const kanal = MethodChannel(kanalName);

  /// Erfunden, ohne `AIza`. Lang genug, dass ein Zufallstreffer in einem
  /// `toString` ausgeschlossen ist.
  const erfunden = 'erfunden-kein-echter-schluessel-Q7x9';

  group('endung — der Zustand kennt nur die letzten vier Zeichen', () {
    test("endung('abcdefgh1234') ist '1234'", () {
      expect(endung('abcdefgh1234'), '1234');
    });

    test(
      'endung des erfundenen Schlüssels sind seine letzten vier Zeichen',
      () {
        expect(endung(erfunden), 'Q7x9');
        expect(
          endung(erfunden).length,
          4,
          reason:
              'mehr als vier Zeichen verrieten mehr vom Schlüssel, als der '
              'Schirm braucht (Spec, „Der Schlüssel")',
        );
      },
    );
  });

  group('KanalSchluesselSpeicher spricht den Keychain-Kanal an', () {
    late List<MethodCall> aufrufe;
    late Future<Object?> Function(MethodCall) antwort;

    setUp(() {
      aufrufe = [];
      antwort = (_) async => null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, (aufruf) {
            aufrufe.add(aufruf);
            return antwort(aufruf);
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kanal, null);
    });

    Map<Object?, Object?> argumenteVon(String methode) {
      final passende = aufrufe.where((a) => a.method == methode).toList();
      expect(
        passende,
        hasLength(1),
        reason:
            'genau ein Aufruf von „$methode" erwartet, '
            'gesehen: ${aufrufe.map((a) => a.method).toList()}',
      );
      return passende.single.arguments as Map<Object?, Object?>;
    }

    test(
      'lies ruft „lies" mit Konto gemini und gibt den Wert zurück',
      () async {
        antwort = (_) async => erfunden;

        final gelesen = await KanalSchluesselSpeicher().lies();

        expect(gelesen, erfunden);
        expect(argumenteVon('lies'), {'konto': 'gemini'});
      },
    );

    test('lies gibt null zurück, wenn die Keychain nichts hat', () async {
      antwort = (_) async => null;

      expect(await KanalSchluesselSpeicher().lies(), isNull);
      expect(argumenteVon('lies'), {'konto': 'gemini'});
    });

    test('schreibe ruft „schreibe" mit Konto gemini und dem Wert', () async {
      await KanalSchluesselSpeicher().schreibe(erfunden);

      expect(argumenteVon('schreibe'), {'konto': 'gemini', 'wert': erfunden});
    });

    test('loesche ruft „loesche" mit Konto gemini', () async {
      await KanalSchluesselSpeicher().loesche();

      expect(argumenteVon('loesche'), {'konto': 'gemini'});
    });

    test(
      'jeder Aufruf geht an das Konto gemini, keiner an ein anderes',
      () async {
        antwort = (_) async => null;
        final speicher = KanalSchluesselSpeicher();

        await speicher.schreibe(erfunden);
        await speicher.lies();
        await speicher.loesche();

        expect(aufrufe, isNotEmpty);
        for (final aufruf in aufrufe) {
          final argumente = aufruf.arguments as Map<Object?, Object?>;
          expect(argumente['konto'], 'gemini', reason: aufruf.method);
        }
      },
    );

    test('toString des Speichers enthält den Wert nicht — weder nach '
        'schreibe noch nach lies', () async {
      antwort = (aufruf) async => aufruf.method == 'lies' ? erfunden : null;
      final speicher = KanalSchluesselSpeicher();

      await speicher.schreibe(erfunden);
      expect(speicher.toString(), isNot(contains(erfunden)));
      expect(speicher.toString(), isNot(contains(endung(erfunden))));

      await speicher.lies();
      expect(speicher.toString(), isNot(contains(erfunden)));
      expect(speicher.toString(), isNot(contains(endung(erfunden))));
    });

    test(
      'ein Keychain-Fehler beim Lesen wird geworfen, nicht zu null',
      () async {
        antwort = (_) async =>
            throw PlatformException(code: 'keychain', message: '-25308');

        await expectLater(
          KanalSchluesselSpeicher().lies(),
          throwsA(anything),
          reason:
              'null hieße „kein Schlüssel hinterlegt" — ein verschluckter '
              'Fehler behauptete einen Leerstand, den es nicht gibt',
        );
      },
    );

    test('ein Keychain-Fehler beim Schreiben wird geworfen und enthält den '
        'Wert nicht', () async {
      antwort = (_) async =>
          throw PlatformException(code: 'keychain', message: '-25299');

      Object? gefangen;
      try {
        await KanalSchluesselSpeicher().schreibe(erfunden);
      } catch (fehler) {
        gefangen = fehler;
      }

      expect(
        gefangen,
        isNotNull,
        reason: 'ein gescheitertes Sichern darf nicht still gelingen',
      );
      expect(gefangen.toString(), isNot(contains(erfunden)));
    });
  });

  group('AttrappenSchluesselSpeicher — im Speicher, für Tests', () {
    test('ist ein KiSchluesselSpeicher', () {
      expect(AttrappenSchluesselSpeicher(), isA<KiSchluesselSpeicher>());
    });

    test('beginnt leer', () async {
      expect(await AttrappenSchluesselSpeicher().lies(), isNull);
    });

    test('schreibe, lies, überschreibe, loesche', () async {
      final speicher = AttrappenSchluesselSpeicher();

      await speicher.schreibe(erfunden);
      expect(await speicher.lies(), erfunden);

      const zweiter = 'erfunden-zweiter-platzhalter-K2m4';
      await speicher.schreibe(zweiter);
      expect(await speicher.lies(), zweiter);

      await speicher.loesche();
      expect(await speicher.lies(), isNull);
    });

    test('loesche auf leerem Speicher ist kein Fehler', () async {
      final speicher = AttrappenSchluesselSpeicher();
      await speicher.loesche();
      expect(await speicher.lies(), isNull);
    });

    test('toString enthält den Wert nicht', () async {
      final speicher = AttrappenSchluesselSpeicher();
      await speicher.schreibe(erfunden);

      expect(speicher.toString(), isNot(contains(erfunden)));
      expect(speicher.toString(), isNot(contains(endung(erfunden))));
    });
  });

  group('kiSchluesselProvider', () {
    test('liefert ohne Überschreibung den Kanal-Speicher', () {
      final container = ProviderContainer(retry: (_, _) => null);
      addTearDown(container.dispose);

      expect(
        container.read(kiSchluesselProvider),
        isA<KanalSchluesselSpeicher>(),
      );
    });

    test('lässt sich in Tests durch die Attrappe ersetzen', () async {
      final attrappe = AttrappenSchluesselSpeicher();
      final container = ProviderContainer(
        retry: (_, _) => null,
        overrides: [kiSchluesselProvider.overrideWithValue(attrappe)],
      );
      addTearDown(container.dispose);

      final speicher = container.read(kiSchluesselProvider);
      await speicher.schreibe(erfunden);

      expect(identical(speicher, attrappe), isTrue);
      expect(await attrappe.lies(), erfunden);
    });
  });
}
