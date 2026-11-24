// Das Blatt „Gewicht eintragen" (#270) — der erste Ort, an dem die App
// nach Apple Health **schreibt**.
//
// API und Verhalten sind durch `app/test/shell/gewicht_eintragen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/gewicht-eintragen.js`, Zustände `neu`,
// `bearbeiten` und `keine-freigabe`. Begründungen stehen in
// `docs/superpowers/specs/2026-11-03-gewicht-eintragen-design.md`.
//
// **Ein Blatt, kein Schirm** (`showCupertinoModalPopup`, wie
// `schlaf_eintragen.dart`): Es landet nicht im Navigationsstapel eines
// Tabs, und `AppRouter` ist hier nicht beteiligt.
//
// **Nur Gewicht, kein Körperfett und keine Muskelmasse** (Tim, 03.11.2026).
// Beide schätzt eine Waage über Bioimpedanz, und zwei Geräte kommen auf
// verschieden große Zahlen; ein fremder Punkt verbiegt diese Reihen mehr,
// als eine Lücke ihnen schadet.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/zahlen.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../health/health_provider.dart';
import '../core/messwert.dart';
import '../health/health_types.dart';

/// Öffnet das Blatt über dem aktuellen Schirm.
///
/// [probe] gesetzt heißt „ändern": Der alte Wert steht **im** Feld, und es
/// gibt „Eintrag löschen". [probe] `null` heißt „neu": Das Feld ist leer,
/// der letzte bekannte Wert steht als Platzhalter dahinter.
Future<void> zeigeGewichtEintragen(
  BuildContext context, {
  WeightSample? probe,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) => _Blatt(key: const Key('gewicht-blatt'), probe: probe),
  );
}

class _Blatt extends ConsumerStatefulWidget {
  const _Blatt({super.key, required this.probe});

  final WeightSample? probe;

  @override
  ConsumerState<_Blatt> createState() => _BlattZustand();
}

class _BlattZustand extends ConsumerState<_Blatt> {
  late final TextEditingController _feld = TextEditingController(
    // Beim Ändern steht der alte Wert **im** Feld: Er ist bereits
    // eingetragen, hier wird er korrigiert. Beim Neueintrag bleibt das Feld
    // leer, siehe `_platzhalter`.
    text: widget.probe == null ? '' : formatNumber(widget.probe!.kg, nachkommastellen: 1),
  );

  /// Der gewählte Zeitpunkt. Vorbelegt ist „jetzt" aus der Uhr der App —
  /// nie `DateTime.now()`, sonst wäre das Blatt nicht deterministisch
  /// prüfbar (Spec 5.3b).
  late DateTime _zeitpunkt =
      widget.probe?.date ?? ref.read(clockProvider)();

  /// Läuft gerade ein Schreib- oder Löschzugriff.
  bool _laeuft = false;

  /// Woran es zuletzt gescheitert ist, oder `null`. Gesetzt wird das
  /// **erst beim Sichern** — der Systemdialog gehört an den Knopf, nicht
  /// ans Öffnen des Blattes.
  _Panne? _panne;

  /// Der neue Wert steht schon in Health; nur der alte ließ sich nicht
  /// entfernen. Ab hier darf **nicht** noch einmal geschrieben werden —
  /// ein zweiter Tipp auf „Sichern" machte daraus eine dritte Probe.
  bool get _bereitsGeschrieben => _panne == _Panne.altNichtGeloescht;

  bool get _istAenderung => widget.probe != null;

  @override
  void initState() {
    super.initState();
    // Der Knopf hängt am Inhalt des Feldes, nicht an einem Abschicken.
    _feld.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  /// Das geprüfte Gewicht, oder `null`, wenn der Text keines ergibt.
  ///
  /// Die Rechnung steht im Kern (`WeightInput.parse`), der Satz dazu hier:
  /// Nutzertexte gehören nicht in den Kern.
  double? get _gewicht => switch (WeightInput.parse(_feld.text)) {
    WeightOk(:final kg) => kg,
    WeightRejected() => null,
  };

  /// Der Hinweis unter dem Feld. `null` heißt „nichts zu sagen" — und das
  /// gilt auch für das leere Feld: Der Anfangszustand ist kein Fehler.
  String? get _hinweis => switch (WeightInput.parse(_feld.text)) {
    WeightOk() => null,
    WeightRejected(reason: WeightInputError.empty) => null,
    WeightRejected(reason: WeightInputError.tooManyDecimals) =>
      'Höchstens eine Stelle hinter dem Komma.',
    WeightRejected(reason: WeightInputError.outOfRange) =>
      'Zwischen ${formatNumber(WeightInput.minKg, nachkommastellen: 0)} und '
          '${formatNumber(WeightInput.maxKg, nachkommastellen: 0)} kg.',
    WeightRejected(reason: WeightInputError.notANumber) =>
      'Nur Ziffern, mit Komma oder Punkt.',
  };

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    // Unten durchzeichnen statt abschneiden (`CLAUDE.md`, flutter#179482):
    // Die halbtransparente Tastatur schiebt sich über das Blatt, und wo
    // Flutter nicht zeichnet, steht Schwarz.
    final tastatur = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      height: MediaQuery.of(context).size.height * 0.62,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          children: [
            _Kopf(
              titel: _istAenderung ? 'Eintrag ändern' : 'Gewicht eintragen',
              aufAbbrechen: _laeuft ? null : () => Navigator.of(context).pop(),
              // Grau, solange das Feld keinen tragfähigen Wert hat. Der
              // Platzhalter zählt dabei nicht als Eingabe: Wer nur
              // „Sichern" tippt, trüge den letzten Wert als heutigen ein
              // und behauptete einen Trend, den es nicht gibt.
              aufSichern: _laeuft || _gewicht == null || _bereitsGeschrieben
                  ? null
                  : _sichere,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(20, 4, 20, 24 + tastatur),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _inhalt(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _inhalt(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return [
      // Ein Kasten, ein Platz. Die drei Gründe erscheinen nie zugleich,
      // und der Unterschied steckt im Satz — nicht in der Anwesenheit
      // eines zweiten Widgets an derselben Stelle.
      if (_panne == _Panne.freigabeFehlt)
        _Notiz(
          key: const Key('gewicht-blatt-freigabe'),
          ton: warn,
          text:
              'Die App darf dein Gewicht gerade nicht nach Apple Health '
              'schreiben. In der Health-App unter Datenzugriff und Geräte '
              'lässt sich das erlauben. Bis dahin wird nichts gesichert — '
              'auch nicht in der App.',
        ),
      if (_panne == _Panne.schreibenGescheitert ||
          _panne == _Panne.altNichtGeloescht ||
          _panne == _Panne.loeschenGescheitert)
        _Notiz(
          key: const Key('gewicht-blatt-fehler'),
          ton: warn,
          text: switch (_panne!) {
            _Panne.schreibenGescheitert =>
              'Der Wert ließ sich nicht nach Apple Health schreiben. Es '
                  'wurde nichts gesichert — auch nicht in der App. Noch '
                  'einmal „Sichern" tippen versucht es erneut.',
            _Panne.altNichtGeloescht =>
              'Der neue Wert steht in Apple Health. Der alte ließ sich '
                  'nicht entfernen — er steht noch in „Letzte Messungen" '
                  'und lässt sich dort löschen.',
            _Panne.loeschenGescheitert =>
              'Der Eintrag ließ sich nicht aus Apple Health entfernen. '
                  'Vielleicht ist er dort schon weg — dann hilft ein Blick '
                  'in die Health-App.',
            _Panne.freigabeFehlt => '',
          },
        ),
      _Kapitel('Gewicht'),
      InsetCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 0),
              Expanded(
                child: CupertinoTextField(
                  key: const Key('gewicht-blatt-feld'),
                  controller: _feld,
                  placeholder: _platzhalter,
                  decoration: null,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: const TextStyle(fontSize: 22),
                  autofocus: true,
                ),
              ),
              Text('kg', style: TextStyle(fontSize: 15, color: muted)),
            ],
          ),
        ),
      ),
      _Fuss(
        _hinweis ??
            (_istAenderung
                ? 'Ändern heißt in Apple Health: alten Wert löschen, neuen '
                      'schreiben. Das macht die App.'
                : 'Platzhalter ist der letzte bekannte Wert. '
                      '${formatNumber(WeightInput.minKg, nachkommastellen: 0)} bis '
                      '${formatNumber(WeightInput.maxKg, nachkommastellen: 0)} kg, mit '
                      'Komma oder Punkt.'),
        ton: _hinweis == null ? muted : warn,
      ),
      _Kapitel('Gemessen am'),
      InsetCard(
        child: SizedBox(
          height: 160,
          child: CupertinoDatePicker(
            key: const Key('gewicht-blatt-datum'),
            mode: CupertinoDatePickerMode.dateAndTime,
            initialDateTime: _zeitpunkt,
            // Nicht in die Zukunft, und nicht weiter zurück, als die Quelle
            // überhaupt hergibt — beides eine Eigenschaft des Rades, nicht
            // eine Prüfung beim Sichern.
            minimumDate: ref.read(healthProvider).earliestPermittedDate,
            maximumDate: ref.read(clockProvider)(),
            use24hFormat: true,
            onDateTimeChanged: (wert) => _zeitpunkt = wert,
          ),
        ),
      ),
      _Fuss(
        'Vorbelegt ist jetzt. Zurückdatieren geht, in die Zukunft nicht.',
        ton: muted,
      ),
      if (_istAenderung) ...[
        const SizedBox(height: 18),
        InsetCard(
          child: CupertinoButton(
            key: const Key('gewicht-blatt-loeschen'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            onPressed: _laeuft ? null : _loesche,
            child: Text(
              'Eintrag löschen',
              style: TextStyle(fontSize: 15, color: warn),
            ),
          ),
        ),
        _Fuss(
          'Löscht die Wägung auch aus Apple Health. Werte deiner Waage kann '
          'die App nicht löschen — die gehören ihrer App.',
          ton: muted,
        ),
      ] else
        _Fuss(
          'Wird nach Apple Health geschrieben und von dort wieder gelesen. '
          'Körperfett und Muskelmasse trägst du hier nicht ein: Jede Waage '
          'schätzt die anders.',
          ton: muted,
        ),
    ];
  }

  /// Der letzte bekannte Wert als Platzhalter — er zeigt die
  /// Größenordnung, und ein vertipptes 584 fällt damit sofort auf.
  String? get _platzhalter {
    // `last`, nicht `reduce`: Beide Quellen liefern aufsteigend sortiert,
    // und diese Zeile läuft bei **jedem Tastendruck** — ein Durchlauf über
    // ein Jahr Wägungen je Zeichen wäre genau Hausregel 2.
    final reihe = ref.read(gewichtsReiheProvider);
    if (reihe is! Bekannt<List<WeightSample>> || reihe.wert.isEmpty) {
      return null;
    }
    return formatNumber(reihe.wert.last.kg, nachkommastellen: 1);
  }

  Future<void> _sichere() async {
    final kg = _gewicht;
    if (kg == null || _bereitsGeschrieben) return;

    final quelle = ref.read(healthProvider);
    final probenNotifier = ref.read(gewichtsProbenProvider.notifier);
    setState(() {
      _laeuft = true;
      _panne = null;
    });

    try {
      // Schritt 1: Freigabe. Nur `granted` darf schreiben — ein
      // weggewischter Dialog (`notDetermined`) zählt wie eine Verweigerung.
      final freigabe = await quelle.requestWeightWriteAuthorization();
      if (freigabe != WriteAuthorization.granted) {
        if (mounted) setState(() => _panne = _Panne.freigabeFehlt);
        return;
      }

      // Schritt 2: erst schreiben, dann löschen. Scheitert das Schreiben,
      // steht der alte Wert noch — ein Löschen davor hätte ihn weggeworfen,
      // ohne dass etwas an seine Stelle tritt.
      try {
        await quelle.writeWeight(kg: kg, at: _zeitpunkt);
      } catch (_) {
        // Nichts ist in Health gelandet. „Sichern" bleibt aktiv: Ein
        // zweiter Versuch ist hier genau das Richtige und gefahrlos.
        if (mounted) setState(() => _panne = _Panne.schreibenGescheitert);
        return;
      }

      final alte = widget.probe;
      if (alte != null) {
        try {
          await quelle.deleteWeight(alte.id);
        } catch (_) {
          // Der gefährliche Fall: Der neue Wert **ist** in Health, der
          // alte auch. Die Liste wird trotzdem neu gelesen — sonst sähe
          // es aus, als wäre gar nichts passiert — und „Sichern" wird
          // grau, damit ein zweiter Tipp keine dritte Probe schreibt.
          probenNotifier.neuLaden();
          if (mounted) setState(() => _panne = _Panne.altNichtGeloescht);
          return;
        }
      }

      // **Vor dem Schließen gelesen**, und über den vorher geholten
      // Notifier: Wird das Blatt während des Sicherns weggewischt, wäre
      // ein `ref.read` hier nach dispose — der Wert stünde in Health und
      // nicht in der Liste.
      probenNotifier.neuLaden();
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }

  Future<void> _loesche() async {
    final alte = widget.probe;
    if (alte == null) return;

    final quelle = ref.read(healthProvider);
    final probenNotifier = ref.read(gewichtsProbenProvider.notifier);
    setState(() {
      _laeuft = true;
      _panne = null;
    });

    try {
      await quelle.deleteWeight(alte.id);
      probenNotifier.neuLaden();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      // Bleibt offen und sagt, was los ist: Ein geschlossenes Blatt
      // behauptete, die Probe sei weg. Ohne Satz tippt man wieder und
      // wieder auf einen Knopf, der nichts tut.
      if (mounted) setState(() => _panne = _Panne.loeschenGescheitert);
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }
}

/// Woran das Sichern oder Löschen gescheitert ist.
///
/// Ein Grund, nicht ein Bündel von Flags: Die vier erscheinen nie zugleich,
/// und ein `switch` darüber ist vollständig prüfbar — dasselbe Argument wie
/// bei `Messwert<T>`.
enum _Panne {
  /// Apple hat die Schreibfreigabe nicht erteilt.
  freigabeFehlt,

  /// Nichts ist in Health gelandet. Ein zweiter Versuch ist gefahrlos.
  schreibenGescheitert,

  /// Der neue Wert **ist** in Health, nur der alte blieb stehen. Ab hier
  /// darf nicht noch einmal geschrieben werden.
  altNichtGeloescht,

  /// Das Löschen über „Eintrag löschen" ging schief.
  loeschenGescheitert,
}

// ─────────────────────────────────────────────────────────────────────────
// Bausteine des Blattes
// ─────────────────────────────────────────────────────────────────────────

/// Abbrechen · Titel · Sichern — dieselbe Form wie in
/// `schlaf_eintragen.dart`. „Inaktiv" heißt `onPressed == null`.
class _Kopf extends StatelessWidget {
  const _Kopf({
    required this.titel,
    required this.aufAbbrechen,
    required this.aufSichern,
  });

  final String titel;
  final VoidCallback? aufAbbrechen;
  final VoidCallback? aufSichern;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: [
          CupertinoButton(
            key: const Key('gewicht-blatt-abbrechen'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
            onPressed: aufAbbrechen,
            child: const Text('Abbrechen'),
          ),
          Expanded(
            child: Text(
              titel,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
          CupertinoButton(
            key: const Key('gewicht-blatt-sichern'),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(44, 36),
            onPressed: aufSichern,
            child: const Text('Sichern'),
          ),
        ],
      ),
    );
  }
}

class _Kapitel extends StatelessWidget {
  const _Kapitel(this.titel);

  final String titel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

/// Der erklärende Satz unter einer Karte.
///
/// **Feste Zeilenzahl**, weil derselbe Fuß mal den Hinweis und mal den
/// Erklärsatz trägt: Ohne Reservierung spränge das Blatt beim Tippen
/// (`CLAUDE.md`, „Mehrzeilige Erläuterungen bekommen eine feste
/// Zeilenzahl").
class _Fuss extends StatelessWidget {
  const _Fuss(this.text, {required this.ton});

  final String text;
  final Color ton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 7, 4, 0),
      child: SizedBox(
        height: 48,
        child: Text(
          text,
          maxLines: 3,
          style: TextStyle(
            fontSize: 12,
            height: 1.33,
            color: ton,
          ),
        ),
      ),
    );
  }
}

/// Der Kasten mit farbiger Kante — `noteBox` im Entwurf.
class _Notiz extends StatelessWidget {
  const _Notiz({super.key, required this.ton, required this.text});

  final Color ton;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: ton.withValues(alpha: 0.12),
        border: Border(left: BorderSide(color: ton, width: 3)),
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 13, height: 1.35)),
    );
  }
}
