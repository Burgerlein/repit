// Die Blätter des Schirms „KI-Zugang" (#339): Schlüssel eintragen und
// Schlüssel entfernen, gezeichnet in `docs/screens/screens/ki-zugang.js`.
// „Modell für Fotos" steht in `ki_zugang_modellblatt.dart`, Monatslimit und
// Preis in `ki_zugang_zahlenblatt.dart`.
//
// API und Verhalten sind durch `app/test/ki/ki_zugang_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`).
//
// **Kein Blatt hält den Schlüssel länger als nötig.** Das Eintragfeld hat
// seinen Controller, solange das Blatt offen ist; gesichert wird über
// `KiZugangNotifier.sichere`, und danach ist das Blatt zu. Ein gesicherter
// Schlüssel wird nie zurück ins Feld gelesen.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/palette.dart';
import 'ki_zugang_bausteine.dart';
import 'ki_zugang_provider.dart';

export 'ki_zugang_modellblatt.dart' show zeigeModellWahl;
export 'ki_zugang_zahlenblatt.dart' show zeigeLimit, zeigePreis;

// ---------------------------------------------------------------------------
// Schlüssel eintragen

/// Öffnet „Gemini-Schlüssel" — eintragen oder ersetzen.
Future<void> zeigeSchluesselEintragen(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _EintragenBlatt(key: Key('ki-schluessel-blatt')),
    );

class _EintragenBlatt extends ConsumerStatefulWidget {
  const _EintragenBlatt({super.key});

  @override
  ConsumerState<_EintragenBlatt> createState() => _EintragenZustand();
}

class _EintragenZustand extends ConsumerState<_EintragenBlatt> {
  final _feld = TextEditingController();

  bool _prueft = false;

  /// Wie der letzte Versuch ausging; `null` heißt „noch keiner" oder
  /// „seitdem geändert".
  KiSichern? _ergebnis;

  @override
  void initState() {
    super.initState();
    _feld.addListener(_geaendert);
  }

  void _geaendert() {
    if (!mounted) return;
    // Ein Grund, der zum alten Text gehörte, gilt für den neuen nicht.
    setState(() => _ergebnis = null);
  }

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  Future<void> _sichere() async {
    setState(() {
      _prueft = true;
      _ergebnis = null;
    });
    final ergebnis = await ref
        .read(kiZugangProvider.notifier)
        .sichere(_feld.text);
    if (!mounted) return;
    if (ergebnis == KiSichern.gesichert) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _prueft = false;
      _ergebnis = ergebnis;
    });
  }

  @override
  Widget build(BuildContext context) {
    final leer = _feld.text.trim().isEmpty;
    return KiBlatt(
      titel: 'Gemini-Schlüssel',
      abbrechen: KiLeistenKnopf(
        key: const Key('ki-schluessel-abbrechen'),
        titel: 'Abbrechen',
        onPressed: () => Navigator.of(context).pop(),
      ),
      rechts: KiLeistenKnopf(
        key: const Key('ki-schluessel-sichern'),
        titel: _prueft ? 'Prüft …' : 'Sichern',
        // Aus, solange geprüft wird: Ein zweiter Tipp startete einen
        // zweiten Abruf.
        onPressed: _prueft || leer ? null : _sichere,
      ),
      inhalt: [
        const SizedBox(height: 14),
        KiFormKarte(
          zeilen: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
              child: Row(
                children: [
                  const Text('API-Schlüssel'),
                  const SizedBox(width: 10),
                  Expanded(
                    child: CupertinoTextField.borderless(
                      key: const Key('ki-schluessel-feld'),
                      controller: _feld,
                      placeholder: 'einfügen',
                      textAlign: TextAlign.end,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      enableIMEPersonalizedLearning: false,
                      smartDashesType: SmartDashesType.disabled,
                      smartQuotesType: SmartQuotesType.disabled,
                      keyboardType: TextInputType.visiblePassword,
                      enabled: !_prueft,
                      style: TextStyle(
                        color: CupertinoDynamicColor.resolve(
                          Palette.river,
                          context,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const KiFormFuss(
          'Einen Schlüssel legst du in Google AI Studio unter '
          '„API-Schlüssel" an. Er wird verdeckt eingegeben und nur gesichert, '
          'wenn Google ihn annimmt.',
        ),
        // Die Fläche für das Ergebnis ist immer da und gleich hoch —
        // sonst spränge der Fuß beim Prüfen.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 104),
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _ergebnisFlaeche(),
          ),
        ),
        const KiFormFuss(
          'Geprüft wird, indem die App die Modellliste abruft. Das kostet '
          'nichts und zählt nicht in den Verbrauch.',
        ),
      ],
    );
  }

  Widget _ergebnisFlaeche() {
    if (_prueft) {
      return const KiNotiz(
        key: Key('ki-schluessel-prueft'),
        ton: KiTon.neutral,
        text: 'Wird bei Google geprüft …',
      );
    }
    return switch (_ergebnis) {
      null || KiSichern.gesichert => const SizedBox.shrink(),
      KiSichern.abgelehnt => const KiNotiz(
        key: Key('ki-schluessel-abgelehnt'),
        ton: KiTon.warnung,
        text:
            'Google nimmt diesen Schlüssel nicht an — vertippt, gelöscht '
            'oder für die Gemini-API nicht freigegeben. Gesichert wurde '
            'nichts.',
      ),
      KiSichern.keinNetz => const KiNotiz(
        key: Key('ki-schluessel-kein-netz'),
        ton: KiTon.neutral,
        text:
            'Kein Netz — Google ist nicht erreichbar. Geprüft und gesichert '
            'wird, sobald du wieder online bist und nochmal „Sichern" '
            'tippst.',
      ),
      KiSichern.gestoert => const KiNotiz(
        key: Key('ki-schluessel-gestoert'),
        ton: KiTon.neutral,
        text:
            'Google antwortet gerade nicht wie erwartet. Gesichert wurde '
            'nichts — nochmal „Sichern" versucht es erneut.',
      ),
    };
  }
}

// ---------------------------------------------------------------------------
// Schlüssel entfernen

/// Öffnet die Bestätigung „Schlüssel entfernen?".
Future<void> zeigeSchluesselEntfernen(BuildContext context) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) => const _EntfernenBlatt(key: Key('ki-entfernen-blatt')),
    );

class _EntfernenBlatt extends ConsumerStatefulWidget {
  const _EntfernenBlatt({super.key});

  @override
  ConsumerState<_EntfernenBlatt> createState() => _EntfernenZustand();
}

class _EntfernenZustand extends ConsumerState<_EntfernenBlatt> {
  bool _laeuft = false;

  Future<void> _entferne() async {
    setState(() => _laeuft = true);
    await ref.read(kiZugangProvider.notifier).entferne();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => KiBlatt(
    titel: 'Schlüssel entfernen?',
    abbrechen: KiLeistenKnopf(
      key: const Key('ki-entfernen-abbrechen'),
      titel: 'Abbrechen',
      onPressed: _laeuft ? null : () => Navigator.of(context).pop(),
    ),
    inhalt: [
      const KiNotiz(
        ton: KiTon.warnung,
        text:
            'Der Schlüssel wird aus der Keychain dieses iPhones gelöscht. Die '
            'Foto-Schätzung steht danach ohne Zugang da. Bei Google bleibt '
            'er gültig — widerrufen kannst du ihn nur in AI Studio.',
        rand: EdgeInsets.fromLTRB(16, 10, 16, 0),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: KiKnopf(
          key: const Key('ki-entfernen-bestaetigen'),
          titel: 'Entfernen',
          farbe: Palette.warn,
          voll: true,
          onPressed: _laeuft ? null : _entferne,
        ),
      ),
      const KiFormFuss(
        'Der gezählte Verbrauch dieses Monats bleibt stehen. Ein neuer '
        'Schlüssel zahlt aus demselben Topf.',
      ),
    ],
  );
}
