// Das Formular „von Hand eintragen" (#131) — eine Nacht oder ein
// Nickerchen, als Blatt über dem Schirm, aus dem es aufgerufen wird.
//
// API und Verhalten sind durch `app/test/shell/schlaf_eintragen_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/schlaf.js` (`FORM`, Zustände
// `form-zeiten` und `form-dauer`) und `tagschlaf.js`.
//
// **Die Art wird hier gewählt, nicht auf dem Schirm** (#502). Beide Türen
// auf den Tagschlaf-Schirm hingen an bereits vorhandenen Nickerchen — ohne
// eines kam man nicht hin, und ohne hinzukommen trug man keines ein. Der
// Ausweg ist ein zweiter Segment-Schalter im Formular statt einer neuen
// Zeile auf dem Schirm: Ohne Nickerchen steht weiterhin keine
// Nickerchen-Zeile da, die eine Messung von null behaupten würde (#209).
// Anzeigen und Eintragen sind entkoppelt.
//
// **Ein Blatt, kein Schirm.** Der Entwurf zeigt es als `sheet` über dem
// Schlaf-Schirm; es landet deshalb nicht im Navigationsstapel eines Tabs,
// und `AppRouter` ist hier nicht beteiligt.
//
// **Pickerräder statt Tastatur, wo es geht.** Uhrzeit und Dauer kommen aus
// `CupertinoDatePicker`/`CupertinoTimerPicker` — nicht, um die Tastatur zu
// vermeiden, sondern weil eine Uhrzeit ein Rad ist und keine Zeichenkette.
// Die Notiz braucht die Tastatur; darunter zeichnet das Blatt deshalb
// durch, statt abzuschneiden (siehe [_Blatt.build], flutter#179482).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/schlaf_eintrag.dart';
import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';

/// Was eingetragen wird.
enum SchlafEintragenArt { nacht, tagschlaf }

/// Die beiden Fassungen des Formulars.
///
/// Der Entwurf führt sie als Segment-Auswahl unter dem Datum: „Zeiten" oder
/// „Nur Dauer". Mehr gibt es nicht — eine halbe Zeitangabe nimmt schon die
/// Ablage nicht an.
enum SchlafEintragenModus { zeiten, dauer }

/// Öffnet das Formular als Blatt über dem aktuellen Schirm.
///
/// [art] ist die **Vorbelegung** des Umschalters, nicht die Festlegung
/// (#502): Der Nutzer stellt im Formular um, wenn er sich vergriffen hat.
/// Was der Aufrufer mitgibt, ist trotzdem wichtig — vom (+) des
/// Tagschlaf-Schirms aus muss „Tagschlaf" vorne stehen, sonst trägt man
/// dort aus Versehen eine Nacht ein.
///
/// [tag] ist der vorbelegte Tag: bei der Nacht der **Aufwachtag**, beim
/// Nickerchen der Tag, an dem es stattfand. Er kommt vom aufrufenden
/// Schirm (die gerade gezeigte Nacht), nicht aus einer Uhr im Formular —
/// zwei Stellen, die den Tag unabhängig bestimmen, waren schon einmal ein
/// Befund.
Future<void> zeigeSchlafEintragen(
  BuildContext context, {
  required SchlafEintragenArt art,
  required DateTime tag,
}) {
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) =>
        _Blatt(key: const Key('schlaf-eintragen-blatt'), art: art, tag: tag),
  );
}

class _Blatt extends ConsumerStatefulWidget {
  const _Blatt({super.key, required this.art, required this.tag});

  final SchlafEintragenArt art;
  final DateTime tag;

  @override
  ConsumerState<_Blatt> createState() => _BlattZustand();
}

class _BlattZustand extends ConsumerState<_Blatt> {
  /// Was eingetragen wird. [_Blatt.art] ist die **Vorbelegung**, nicht die
  /// Festlegung: Wer vom Schlaf-Schirm kommt, findet „Nacht" vor, wer das
  /// (+) des Tagschlaf-Schirms drückt, „Tagschlaf" — umstellen kann er es
  /// hier (#502).
  late SchlafEintragenArt _art = widget.art;

  /// Zeiten sind die Vorgabe — sie ordnen die Phase in den Tag ein, und bei
  /// der Nacht tragen sie die Zubettgehzeit.
  SchlafEintragenModus _modus = SchlafEintragenModus.zeiten;

  /// Die beiden Uhrzeiten, **sobald sie von Hand gesetzt wurden**. Solange
  /// `null`, gilt die Vorgabe der gerade gewählten Art — und nur deshalb
  /// wechselt sie beim Umschalten mit. Dieselbe Form wie bei
  /// [_dauerMinuten], und aus demselben Grund: Eine Eingabe darf nicht
  /// unter der Hand zurückspringen, eine Vorgabe soll mitgehen. Jedes der
  /// beiden Räder zählt dabei für sich — wer nur die Einschlafzeit gesetzt
  /// hat, hat über die Aufwachzeit nichts gesagt.
  int? _beginnMinuten;
  int? _endeMinuten;

  /// Die Dauer, sobald sie von Hand überschrieben wurde. Solange `null`,
  /// rechnet sie sich aus den Zeiten — der Entwurf: „Die Dauer rechnet sich
  /// aus den Zeiten und lässt sich überschreiben, falls du wach dazwischen
  /// lagst."
  int? _dauerMinuten;

  final _notiz = TextEditingController();
  bool _laeuft = false;

  /// Vorgaben, die **keine Ereignisse** sind, sondern übliche Uhrzeiten:
  /// 23:00 bis 06:30 für eine Nacht, 13:30 bis 14:00 für ein Nickerchen.
  /// Sie belegen die Räder vor, damit niemand bei 00:00 anfangen muss.
  static const _vorgabeNachtBeginn = 23 * 60;
  static const _vorgabeNachtEnde = 6 * 60 + 30;
  static const _vorgabeNapBeginn = 13 * 60 + 30;
  static const _vorgabeNapEnde = 14 * 60;

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  bool get _istNacht => _art == SchlafEintragenArt.nacht;

  int get _beginn =>
      _beginnMinuten ?? (_istNacht ? _vorgabeNachtBeginn : _vorgabeNapBeginn);
  int get _ende =>
      _endeMinuten ?? (_istNacht ? _vorgabeNachtEnde : _vorgabeNapEnde);

  /// Die Dauer, die gesichert wird: die überschriebene, sonst die aus den
  /// Zeiten gerechnete. Über Mitternacht hinweg wird weitergezählt.
  int get _dauer {
    final ueberschrieben = _dauerMinuten;
    if (ueberschrieben != null) return ueberschrieben;
    if (_modus == SchlafEintragenModus.dauer) return _vorgabeDauer;
    final roh = _ende - _beginn;
    return roh > 0 ? roh : roh + Duration.minutesPerDay;
  }

  int get _vorgabeDauer => _istNacht ? 7 * 60 : 30;

  @override
  Widget build(BuildContext context) {
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    // **Unten durchzeichnen statt abschneiden** (`CLAUDE.md`,
    // flutter#179482): Die halbtransparente Tastatur schiebt sich über das
    // Blatt, und wo Flutter nicht zeichnet, steht Schwarz. Das Blatt ist
    // deshalb bis zum Rand gefärbt, und der Inhalt bekommt die Höhe der
    // Tastatur als zusätzliche Polsterung — er rutscht hoch, die Fläche
    // bleibt.
    final tastatur = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      height: MediaQuery.of(context).size.height * 0.88,
      child: DefaultTextStyle(
        style: TextStyle(color: ink, fontSize: 15),
        child: Column(
          children: [
            _Kopf(
              titel: _istNacht ? 'Nacht eintragen' : 'Tagschlaf eintragen',
              aufAbbrechen: _laeuft ? null : () => Navigator.of(context).pop(),
              aufSichern: _laeuft ? null : _sichere,
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + tastatur),
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

    return [
      // **Oben, vor dem Tag.** Die Art entscheidet, was der Tag darunter
      // bedeutet: bei der Nacht der Aufwachtag, beim Nickerchen der Tag,
      // an dem es stattfand (#209). Der Tag selbst wechselt dabei nicht —
      // er kommt vom aufrufenden Schirm, und ein Umschalten, das ihn
      // stillschweigend verschöbe, trüge den Eintrag am falschen Tag ein.
      _Kapitel('Was'),
      CupertinoSlidingSegmentedControl<SchlafEintragenArt>(
        key: const Key('schlaf-eintragen-art'),
        groupValue: _art,
        onValueChanged: (art) {
          if (art == null) return;
          setState(() => _art = art);
        },
        children: {
          SchlafEintragenArt.nacht: const Padding(
            key: Key('schlaf-eintragen-art-nacht'),
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nacht'),
          ),
          SchlafEintragenArt.tagschlaf: const Padding(
            key: Key('schlaf-eintragen-art-tagschlaf'),
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Tagschlaf'),
          ),
        },
      ),

      _Kapitel(_istNacht ? 'Nacht auf' : 'Wann'),
      InsetCard(
        child: _Zeile(
          titel: _istNacht ? 'Datum' : 'Tag',
          wert: Format.wochentagUndDatum(widget.tag),
        ),
      ),
      const SizedBox(height: 10),
      CupertinoSlidingSegmentedControl<SchlafEintragenModus>(
        key: const Key('schlaf-eintragen-modus'),
        groupValue: _modus,
        onValueChanged: (modus) {
          if (modus == null) return;
          setState(() => _modus = modus);
        },
        children: {
          SchlafEintragenModus.zeiten: const Padding(
            key: Key('schlaf-eintragen-modus-zeiten'),
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Zeiten'),
          ),
          SchlafEintragenModus.dauer: const Padding(
            key: Key('schlaf-eintragen-modus-dauer'),
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Text('Nur Dauer'),
          ),
        },
      ),
      const SizedBox(height: 14),

      if (_modus == SchlafEintragenModus.zeiten) ...[
        _Kapitel('Zeiten'),
        _UhrzeitRad(
          titel: _istNacht ? 'Zu Bett' : 'Eingeschlafen',
          minuten: _beginn,
          // **Derselbe Schlüsselgriff wie beim Dauer-Rad** (#210): Auch
          // `CupertinoDatePicker.initialDateTime` ist initial, also geht
          // das Rad einer Änderung von außen nur über einen
          // Schlüsselwechsel nach. Von außen ändert sich die Uhrzeit
          // genau dann, wenn die Art wechselt — und nur die Art steht
          // deshalb im Schlüssel. Stünde die Uhrzeit selbst darin, baute
          // sich der Picker mitten in der Geste neu auf.
          radSchluessel: '$_art',
          // Die überschriebene Dauer fällt weg, sobald die Zeiten sich
          // ändern: Sonst stünde eine Zahl da, die zu den Uhrzeiten
          // darüber nicht mehr passt.
          aufWahl: (wert) => setState(() {
            _beginnMinuten = wert;
            _dauerMinuten = null;
          }),
        ),
        _UhrzeitRad(
          titel: _istNacht ? 'Aufgestanden' : 'Aufgewacht',
          minuten: _ende,
          radSchluessel: '$_art',
          aufWahl: (wert) => setState(() {
            _endeMinuten = wert;
            _dauerMinuten = null;
          }),
        ),
      ],

      _Kapitel('Dauer'),
      _DauerRad(
        titel: 'Geschlafen',
        minuten: _dauer,
        // **Woraus sich die Dauer rechnet, nicht was sie gerade ist**
        // (#210). Am Schlüssel hängt, wann das Rad neu aufgebaut wird:
        // Ändern sich Art, Fassung oder Uhrzeiten, ist die gezeigte Dauer
        // überholt und das Rad muss mitgehen; dreht der Nutzer am Rad,
        // ändert sich keiner dieser vier Werte und es bleibt stehen, wo
        // er es hinlegt. Ein Schlüssel an der Dauer selbst täte genau
        // das nicht — er wechselte bei der ersten Raste und baute den
        // Picker mitten in der Geste neu auf.
        //
        // **Die Art muss darin stehen** (#502): In der Fassung „nur
        // Dauer" rechnet [_dauer] allein aus der Vorgabe der Art (7 h
        // gegen 30 min). Sind die Uhrzeiten darunter von Hand gesetzt,
        // ändern sie sich beim Umschalten nicht — ohne die Art bliebe
        // der Schlüssel gleich und das Rad stünde auf der alten Zahl,
        // während die Zeile darüber schon die neue zeigt.
        radSchluessel: '$_art-$_modus-$_beginn-$_ende',
        aufWahl: (wert) => setState(() => _dauerMinuten = wert),
      ),

      // **Was die zweite Fassung kostet, steht vor dem Sichern da** — nicht
      // hinterher am halben Score. Beim Tagschlaf kostet sie nichts: Er hat
      // keinen Score, also auch keine Zubettgehzeit, die verloren ginge.
      if (_istNacht && _modus == SchlafEintragenModus.dauer)
        Padding(
          key: const Key('schlaf-eintragen-kosten'),
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
          child: Text(
            'Ohne Einschlafzeit entfällt auch die Zubettgehzeit — '
            'erreichbar sind dann 50 von 100 Punkten. Wenn du die Zeiten '
            'ungefähr weißt, nimm lieber „Zeiten".',
            style: TextStyle(fontSize: 12, height: 1.35, color: muted),
          ),
        ),

      _Kapitel('Notiz'),
      InsetCard(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: CupertinoTextField.borderless(
            key: const Key('schlaf-eintragen-notiz'),
            controller: _notiz,
            placeholder: 'optional',
            maxLength: 140,
          ),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
        child: Text(
          _istNacht
              ? 'Unterbrechungen lassen sich nicht nachtragen — es gibt '
                    'nichts zu zählen. Die 20 Punkte dafür entfallen, statt '
                    'geschätzt zu werden. Der Eintrag liegt in dieser App, '
                    'nicht in Apple Health.'
              : 'Der Eintrag liegt in dieser App, nicht in Apple Health. '
                    'Er zählt — wie der gemessene — nicht in Dauer, '
                    'Bewertung oder Wachzeit der Nacht.',
          style: TextStyle(fontSize: 12, height: 1.35, color: muted),
        ),
      ),
    ];
  }

  Future<void> _sichere() async {
    setState(() => _laeuft = true);
    final notifier = ref.read(schlafEintraegeProvider.notifier);
    final mitZeiten = _modus == SchlafEintragenModus.zeiten;
    final tag = BerlinCalendar.dayKey(widget.tag);
    final notiz = _notiz.text;

    try {
      if (_istNacht) {
        await notifier.setzeNacht(
          tag: tag,
          schlafMinuten: _dauer,
          beginnMinuten: mitZeiten ? _beginn : null,
          endeMinuten: mitZeiten ? _ende : null,
          notiz: notiz,
        );
      } else {
        await notifier.fuegeTagschlafHinzu(
          tag: tag,
          schlafMinuten: _dauer,
          beginnMinuten: mitZeiten ? _beginn : null,
          endeMinuten: mitZeiten ? _ende : null,
          notiz: notiz,
        );
      }
    } catch (_) {
      // Ein abgewiesener Wert schließt das Blatt nicht — sonst wäre der
      // Eintrag weg und niemand wüsste, warum nichts dasteht.
      if (mounted) setState(() => _laeuft = false);
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }
}

/// Kopfzeile des Blatts: Abbrechen · Titel · Sichern.
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
            key: const Key('schlaf-eintragen-abbrechen'),
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
            key: const Key('schlaf-eintragen-sichern'),
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
      padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
      child: Text(
        titel.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: muted,
        ),
      ),
    );
  }
}

class _Zeile extends StatelessWidget {
  const _Zeile({required this.titel, required this.wert});

  final String titel;
  final String wert;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(child: Text(titel)),
          Text(wert, style: TextStyle(color: muted)),
        ],
      ),
    );
  }
}

/// Eine Uhrzeit als Rad — Minuten nach Mitternacht hinein, Minuten nach
/// Mitternacht heraus.
///
/// Der `CupertinoDatePicker` braucht einen `DateTime` als Träger; der
/// Kalendertag darin ist beliebig und wird nie gelesen. Ein echter
/// Zeitpunkt wäre hier falsch: Der Eintrag trägt eine Uhrzeit, keinen
/// Moment.
class _UhrzeitRad extends StatelessWidget {
  const _UhrzeitRad({
    required this.titel,
    required this.minuten,
    required this.radSchluessel,
    required this.aufWahl,
  });

  final String titel;
  final int minuten;

  /// Wechselt genau dann, wenn [minuten] **von außen** neu bestimmt wird
  /// — siehe die Stelle, die ihn setzt.
  final String radSchluessel;

  final ValueChanged<int> aufWahl;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InsetCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Zeile(titel: titel, wert: _text(minuten)),
            SizedBox(
              height: 110,
              child: CupertinoDatePicker(
                // `initialDateTime` ist **initial** — wie
                // `initialTimerDuration` beim Dauer-Rad (#210). Nur ein
                // Schlüsselwechsel setzt die Radstellung neu.
                key: ValueKey(radSchluessel),
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                minuteInterval: 5,
                initialDateTime: DateTime.utc(
                  2000,
                  1,
                  1,
                  minuten ~/ Duration.minutesPerHour,
                  (minuten % Duration.minutesPerHour) ~/ 5 * 5,
                ),
                onDateTimeChanged: (wert) =>
                    aufWahl(wert.hour * Duration.minutesPerHour + wert.minute),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _text(int minuten) => Format.uhrzeit(
    DateTime.utc(
      2000,
      1,
      1,
      minuten ~/ Duration.minutesPerHour,
      minuten % Duration.minutesPerHour,
    ),
  );
}

/// Die Dauer als Rad, in Stunden und Minuten.
class _DauerRad extends StatelessWidget {
  const _DauerRad({
    required this.titel,
    required this.minuten,
    required this.radSchluessel,
    required this.aufWahl,
  });

  final String titel;
  final int minuten;

  /// Wechselt genau dann, wenn [minuten] **von außen** neu bestimmt wird
  /// — siehe die Stelle, die ihn setzt.
  final String radSchluessel;

  final ValueChanged<int> aufWahl;

  @override
  Widget build(BuildContext context) {
    return InsetCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Zeile(
            titel: titel,
            wert:
                '${minuten ~/ Duration.minutesPerHour}:'
                '${(minuten % Duration.minutesPerHour).toString().padLeft(2, '0')} h',
          ),
          SizedBox(
            key: const Key('schlaf-eintragen-dauer'),
            height: 110,
            child: CupertinoTimerPicker(
              // `initialTimerDuration` ist **initial**: Der Picker hält
              // seine Radstellung in seinem eigenen `State`. Nur ein
              // Schlüsselwechsel setzt sie neu — der äußere Schlüssel
              // bezeichnet weiter dieselbe Stelle im Blatt, der innere
              // trägt den Wechsel (#210).
              key: ValueKey(radSchluessel),
              mode: CupertinoTimerPickerMode.hm,
              minuteInterval: 5,
              // Auf das Raster des Rades gerundet: Ein Wert dazwischen
              // löst in `CupertinoTimerPicker` eine Zusicherung aus.
              initialTimerDuration: Duration(minutes: minuten ~/ 5 * 5),
              onTimerDurationChanged: (wert) => aufWahl(wert.inMinutes),
            ),
          ),
        ],
      ),
    );
  }
}
