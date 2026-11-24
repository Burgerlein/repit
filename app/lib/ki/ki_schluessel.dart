import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Die Dart-Hälfte des Keychain-Kanals (#337). Gegenseite:
// `app/ios/Runner/KeychainChannel.swift` (#336). Spec
// „KI-Zugang und Foto-Schätzung" (`docs/superpowers/specs/`), „Der Schlüssel".
//
// **Der Schlüssel steht nirgends außer in der Keychain.** Diese Datei reicht
// ihn durch, hält ihn aber nicht: Kein Speicher merkt sich einen gelesenen
// Wert, kein `toString` und keine Fehlermeldung enthält ihn.

/// Wo der Gemini-Schlüssel liegt. Views und Provider sprechen nur diese
/// Schnittstelle an, nie den Kanal direkt — sonst wäre die Attrappe wertlos.
abstract interface class KiSchluesselSpeicher {
  /// Der hinterlegte Schlüssel, `null` heißt „keiner hinterlegt".
  ///
  /// Ein Fehler der Keychain wird **geworfen**, nicht zu `null`: Ein
  /// verschluckter Fehler ließe den Schirm „ohne Schlüssel" zeigen, obwohl
  /// einer da ist.
  Future<String?> lies();

  /// Legt [wert] ab und ersetzt einen vorhandenen.
  Future<void> schreibe(String wert);

  /// Entfernt den Schlüssel. Ist keiner da, ist das kein Fehler.
  Future<void> loesche();
}

/// Die letzten vier Zeichen von [schluessel] — mehr kennt der Zustand des
/// Schirms nicht. Ist [schluessel] kürzer, kommt er ganz zurück; ein echter
/// Gemini-Schlüssel ist weit länger.
String endung(String schluessel) => schluessel.length <= 4
    ? schluessel
    : schluessel.substring(schluessel.length - 4);

/// Ein Fehler der Keychain, ohne den Wert.
///
/// Trägt nur den Fehlercode des Kanals und den `OSStatus`, den die
/// Swift-Seite meldet. Die Swift-Seite sichert zu, dass ihre Meldungen den
/// Wert nicht enthalten; diese Klasse sichert es für die Dart-Seite noch
/// einmal ab (siehe [KanalSchluesselSpeicher.schreibe]).
class KiSchluesselFehler implements Exception {
  const KiSchluesselFehler({required this.code, this.status});

  /// Der Fehlercode des Kanals, etwa `keychain` oder `argumente`.
  final String code;

  /// Der `OSStatus` als Text, falls gemeldet.
  final String? status;

  @override
  String toString() => status == null
      ? 'KiSchluesselFehler($code)'
      : 'KiSchluesselFehler($code, $status)';
}

/// Der echte Speicher: der Kanal `de.rosenbach.repit/keychain`,
/// Konto `gemini`.
class KanalSchluesselSpeicher implements KiSchluesselSpeicher {
  KanalSchluesselSpeicher();

  static const _kanal = MethodChannel('de.rosenbach.repit/keychain');
  static const _konto = 'gemini';

  @override
  Future<String?> lies() =>
      _rufe(() => _kanal.invokeMethod<String>('lies', {'konto': _konto}));

  @override
  Future<void> schreibe(String wert) => _rufe(
    () =>
        _kanal.invokeMethod<void>('schreibe', {'konto': _konto, 'wert': wert}),
    verbergen: wert,
  );

  @override
  Future<void> loesche() =>
      _rufe(() => _kanal.invokeMethod<void>('loesche', {'konto': _konto}));

  /// Übersetzt eine `PlatformException` in [KiSchluesselFehler].
  ///
  /// Enthielte die Meldung je den Wert [verbergen] — etwa nach einer
  /// Änderung auf der Swift-Seite —, fällt sie weg, statt ihn
  /// weiterzureichen.
  static Future<T> _rufe<T>(
    Future<T> Function() aufruf, {
    String? verbergen,
  }) async {
    try {
      return await aufruf();
    } on PlatformException catch (fehler) {
      final status = fehler.message;
      final sicher =
          verbergen != null &&
              verbergen.isNotEmpty &&
              status != null &&
              status.contains(verbergen)
          ? null
          : status;
      throw KiSchluesselFehler(code: fehler.code, status: sicher);
    }
  }

  @override
  String toString() => 'KanalSchluesselSpeicher(konto: $_konto)';
}

/// Ein Speicher im Arbeitsspeicher, **für Tests** — nicht für den
/// Simulator. Beginnt leer.
class AttrappenSchluesselSpeicher implements KiSchluesselSpeicher {
  AttrappenSchluesselSpeicher();

  String? _wert;

  @override
  Future<String?> lies() async => _wert;

  @override
  Future<void> schreibe(String wert) async => _wert = wert;

  @override
  Future<void> loesche() async => _wert = null;

  @override
  String toString() => 'AttrappenSchluesselSpeicher(belegt: ${_wert != null})';
}

/// Der Speicher des Schlüssels. Ohne Überschreibung der Keychain-Kanal;
/// Tests ersetzen ihn durch [AttrappenSchluesselSpeicher].
///
/// Liefert den **Speicher**, nicht den Schlüssel: Kein Provider hält den
/// Wert im Zustand (Spec, „Der Schlüssel").
final kiSchluesselProvider = Provider<KiSchluesselSpeicher>(
  (ref) => KanalSchluesselSpeicher(),
);
