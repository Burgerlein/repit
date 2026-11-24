// Die Abschnitte des Verlaufsschirms je Maß (#479 unter #88) —
// Diagrammkarte samt Legende, Kennzahlen und „Alle Messungen". Der Schirm
// selbst steht daneben in `umfang_detail_view.dart` und bleibt klein
// (`CLAUDE.md`, „Views bleiben klein"), so wie `koerper_abschnitte.dart`
// neben `koerper_view.dart`.
//
// API und Verhalten sind durch `app/test/shell/umfang_detail_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/umfang-detail.js`, Varianten `verlauf`,
// `ohne-partner`, `erste`, `nie`, `laedt` und `unlesbar`.
//
// **Die Diagrammfläche bleibt in jeder Lage stehen** — in Grau, mit `–/–`
// im Kopf, nicht weggelassen. Sonst wüchse der Schirm in dem Moment, in dem
// die zweite Messung eintrifft, und alles darunter rutschte (`CLAUDE.md`,
// „Eine Anzeige, die es gibt, hat genau eine Form"). Die Swift-Vorlage
// macht es anders und ersetzt das Diagramm unter zwei Punkten durch eine
// Notiz; Plan und Hausregel sind jünger und ausdrücklicher.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/diagramm_auswahl.dart' show DiagrammKopf;
import '../design/formatierung.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/zeitdiagramm.dart';
import '../design/zeitdiagramm_geruest.dart';
import '../shell/diagramm_zeitraum.dart';
import '../shell/mess_abschnitte.dart'
    show MessKarte, MessZeileDaten, datumZumAnzeigen;
import 'umfaenge_notiz.dart';
import 'umfaenge_trend.dart';
import 'umfang_detail_provider.dart';
import 'umfang_loeschen.dart';

// ─────────────────────────────────────────────────────────────────────────
// Schlüssel und Texte
// ─────────────────────────────────────────────────────────────────────────

const kUmfangDetailDiagramm = Key('umfang-detail-diagramm');
const kUmfangDetailPartner = Key('umfang-detail-partner');
const kUmfangDetailTrend = Key('umfang-detail-trend');
const kUmfangDetailSeite = Key('umfang-detail-seite');
const kUmfangDetailWerte = Key('umfang-detail-werte');

/// **Fünf Stufen gibt es in der App** — T · W · M · 6M · J. **Dieser Schirm
/// bietet drei davon an**, und `M` ist damit nach der Hausregel zugleich die
/// Startstufe (#7, die kleinste angebotene).
///
/// Am Maßband misst man alle zwei bis vier Wochen; `T` und `W` zeigten leere
/// Fenster. Eine sechste Stufe „Alles" gibt es nicht — sie ginge quer durch
/// alle neun Diagramme, und am 26.10.2026 hat Tim entschieden, dass es bei
/// den fünfen bleibt.
const List<DiagrammStufe> umfangDetailStufen = [
  DiagrammStufe.monat,
  DiagrammStufe.halbjahr,
  DiagrammStufe.jahr,
];

/// **Keine Diagnose** (`CLAUDE.md`): Ein halber Zentimeter ist kein Befund.
const String umfangMassbandHinweis =
    'Umfänge misst du selbst. Ein halber Zentimeter Unterschied kann auch '
    'an der Stelle oder der Spannung des Maßbands liegen — erst der Verlauf '
    'über mehrere Messungen sagt etwas.';

/// Die Fußzeile unter der Kurve. Ab `6M` trägt ein Punkt einen ganzen Monat
/// — das muss dastehen, sonst liest man einen Monatsschnitt als
/// Einzelmessung.
String umfangDetailFuss(DiagrammStufe stufe) => stufe == DiagrammStufe.monat
    ? 'Je Punkt eine Messung. Zwischen zwei Messungen wird nicht '
          'interpoliert — die Linie verbindet, sie behauptet nichts '
          'dazwischen.'
    : 'Je Punkt ein Monat, gezeigt wird der Monatsdurchschnitt.';

// ─────────────────────────────────────────────────────────────────────────
// Die Diagrammkarte
// ─────────────────────────────────────────────────────────────────────────

/// Die Karte mit der Kurve — oder **dieselbe Karte ungefüllt**.
///
/// Ab zwei Punkten steht ein [Zeitdiagramm] da, darunter das
/// [ZeitdiagrammGeruest] ohne Linie: dieselbe Leiste, dieselbe Kopfzeile,
/// dieselbe Graphhöhe, dieselbe Fußzeile. Beide bauen dieselbe Stelle, also
/// haben sie dieselbe Geometrie — und das bleibt beim nächsten Umbau wahr.
class UmfangDetailDiagramm extends StatelessWidget {
  const UmfangDetailDiagramm({
    super.key,
    required this.mass,
    required this.lage,
    required this.gelesen,
  });

  final Umfang mass;
  final VerlaufLage lage;
  final VerlaufGelesen? gelesen;

  /// Ab wie vielen Punkten eine Linie steht: zwei. Ein Punkt ist noch kein
  /// Verlauf.
  static const int mindestPunkte = 2;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stand = gelesen;
    final hatKurve = stand != null && stand.reihe.length >= mindestPunkte;
    // **Die Legende steht nur, wenn die Gegenseite Werte hat.** Eine leere
    // zweite Linie wäre eine Legende ohne Inhalt (Swift-Vorlage,
    // `partnerSeries`).
    final gegenseite = (stand != null && stand.gegenreihe.isNotEmpty)
        ? mass.partner
        : null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hatKurve)
            KeyedSubtree(
              key: kUmfangDetailDiagramm,
              child: Zeitdiagramm(
                // Je Maß ein eigener Zustand: Stufe und Blätterstand des
                // einen gelten nicht für das andere.
                key: ValueKey('umfang-detail-kurve-${mass.schluessel}'),
                reihe: stand.reihe,
                // **Die Gegenseite als zweite Reihe, nicht in der eigenen.**
                // Acht Punkte in einer Linie wären eine Kurve, die es nie
                // gab — links und rechts abwechselnd.
                zweiteReihe: stand.gegenreihe,
                zweiteFarbe: Palette.river2,
                stufen: umfangDetailStufen,
                alsBalken: false,
                einheit: 'cm',
                kopfzahl: umfangsZahl,
                fussnote: umfangDetailFuss,
              ),
            )
          else
            _UngefuellteKarte(mass: mass, lage: lage, gelesen: stand),
          if (gegenseite != null)
            Padding(
              key: kUmfangDetailPartner,
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                children: [
                  _Strich(
                    farbe: CupertinoDynamicColor.resolve(
                      Palette.river2,
                      context,
                    ),
                  ),
                  const SizedBox(width: 6),
                  // `Flexible`, damit der Name bei großer Schrift kürzt
                  // statt über den Rand zu laufen.
                  Flexible(
                    child: Text(
                      'Blass gestrichelt: ${gegenseite.deutsch}.',
                      style: TextStyle(fontSize: 12, height: 1.4, color: muted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Die Karte **ohne Linie**: dasselbe Gerüst, die Leiste auf `M` und
/// gesperrt — es gibt nichts zu wählen.
class _UngefuellteKarte extends StatelessWidget {
  const _UngefuellteKarte({
    required this.mass,
    required this.lage,
    required this.gelesen,
  });

  final Umfang mass;
  final VerlaufLage lage;
  final VerlaufGelesen? gelesen;

  @override
  Widget build(BuildContext context) {
    final spur = CupertinoDynamicColor.resolve(Palette.line, context);
    final stand = gelesen;
    // Bei genau einem Punkt steht die eine Zahl im Kopf — sie ist bekannt,
    // nur der zweite Punkt fehlt.
    final einzel = (stand != null && stand.reihe.length == 1)
        ? stand.reihe.single.wert
        : null;

    return ZeitdiagrammGeruest(
      leiste: IgnorePointer(
        child: Zeitraumleiste(
          stufen: umfangDetailStufen,
          gewaehlt: DiagrammStufe.monat,
          onWaehle: (_) {},
        ),
      ),
      kopf: DiagrammKopf(
        ueberschrift: 'Aktuell',
        // Eine geschützte Leerstelle, solange nichts gelesen ist: `–/–`
        // hieße „gelesen, kein Wert", und die Leerstelle hält die
        // Zeilenhöhe der Zahl.
        wert: switch (lage) {
          VerlaufLage.laedt => ' ',
          VerlaufLage.unlesbar => ohneWert,
          VerlaufLage.gelesen =>
            einzel == null ? ohneWert : umfangsZahl(einzel),
        },
        // Wo keine Zahl steht, steht auch keine Einheit.
        einheit: einzel == null ? '' : 'cm',
        unterzeile: _unterzeile(stand),
        abgelesen: false,
      ),
      fussnote: _fussnote(stand),
      graph: Semantics(
        key: kUmfangDetailDiagramm,
        // **Der Vorlesetext nennt den Zustand, nicht das Zeichen**
        // (`CLAUDE.md`): „–/–" ergäbe vorgelesen „Strich Schrägstrich
        // Strich". Und während gelesen wird, steht hier keine Aussage über
        // Tims Daten (`01`).
        label: switch (lage) {
          VerlaufLage.laedt => '${mass.deutsch}, wird gelesen',
          VerlaufLage.unlesbar => '${mass.deutsch}, nicht lesbar',
          VerlaufLage.gelesen =>
            einzel == null
                ? '${mass.deutsch}, keine Werte'
                : '${mass.deutsch}, eine Messung, noch keine Kurve',
        },
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 20),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: spur.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
        ),
      ),
    );
  }

  String _unterzeile(VerlaufGelesen? stand) => switch (lage) {
    // Nichts behaupten, solange nichts gelesen ist.
    VerlaufLage.laedt => '',
    VerlaufLage.unlesbar => 'nicht lesbar',
    VerlaufLage.gelesen => switch (stand!.reihe.length) {
      0 => 'kein Zeitraum',
      _ =>
        'eine Messung am '
            '${Format.tag(datumZumAnzeigen(stand.messungen.first.tag))}',
    },
  };

  String _fussnote(VerlaufGelesen? stand) => switch (lage) {
    // Die Fußzeile beschreibt das Diagramm, nicht die Datenlage — sie darf
    // auch dastehen, solange niemand weiß, was gemessen ist.
    VerlaufLage.laedt => umfangDetailFuss(DiagrammStufe.monat),
    VerlaufLage.unlesbar =>
      'Sobald die Messungen wieder lesbar sind, steht hier die Kurve.',
    VerlaufLage.gelesen =>
      stand!.istLeer
          ? 'Sobald du dieses Maß einträgst, steht hier die Kurve.'
          : 'Ab der zweiten Messung steht hier die Kurve.',
  };
}

/// Das Linienstück vor dem Legendeneintrag — gestrichelt, wie die zweite
/// Linie im Diagramm.
class _Strich extends StatelessWidget {
  const _Strich({required this.farbe});

  final Color farbe;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 2,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < 3; i++)
            Container(width: 4, height: 2, color: farbe),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Die Kennzahlen
// ─────────────────────────────────────────────────────────────────────────

/// „Veränderung" — die fünf Rechnungen des Kerns und die Zahl der
/// Messungen.
///
/// **Die Namen folgen `UmfangsFortschritt`**: `veraenderung`, `seitStart`,
/// `proMonat`, `spanne`, `seitendifferenz`. Gerechnet wird dort, hier wird
/// geschrieben.
///
/// **Die Seitendifferenz-Zeile gibt es nur bei Maßen mit Gegenseite**
/// ([Umfang.partner], #493). Bei Brust, Schultern, Taille, Hals und Hüfte
/// stellt sich die Frage nicht — das ist keine fehlende Datenlage, sondern
/// ein Maß ohne Gegenseite, und eine Zeile, die sich nie füllen kann, wäre
/// eine Funktion, die es nicht gibt. Ob die Zeile existiert, hängt am Maß
/// und nicht an den Daten; deshalb steht sie auch da, solange gelesen wird.
class UmfangDetailKennzahlen extends StatelessWidget {
  const UmfangDetailKennzahlen({
    super.key,
    required this.mass,
    required this.lage,
    required this.gelesen,
  });

  final Umfang mass;
  final VerlaufLage lage;
  final VerlaufGelesen? gelesen;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stand = gelesen;

    return MessKarte(
      zeilen: [
        MessZeileDaten(
          name: 'Seit der letzten Messung',
          wertSchluessel: kUmfangDetailTrend,
          wertFarbe: umfangsTrendFarbe(context, stand?.veraenderung, muted),
          wert: _wert(
            stand == null
                ? null
                : stand.veraenderung == null
                ? null
                : umfangsVeraenderungText(stand.veraenderung!),
          ),
          platzhalter: _platzhalter('+0,0 cm'),
          kennzeichen: _kennzeichen(
            stand == null
                ? null
                : stand.vorigerTag == null
                ? (stand.istLeer ? null : 'erste Messung')
                : 'seit ${Format.tagMonat(datumZumAnzeigen(stand.vorigerTag!))}',
          ),
        ),
        MessZeileDaten(
          name: 'Seit der ersten Messung',
          wert: _wert(
            stand?.seitStart == null
                ? null
                : '${stand!.seitStart! > 0 ? '+' : '−'}'
                      '${umfangsWert(stand.seitStart!.abs())}',
          ),
          platzhalter: _platzhalter('+0,0 cm'),
          kennzeichen: _kennzeichen(
            stand == null || stand.ersterTag == null || stand.istErsteMessung
                ? (stand != null && stand.istErsteMessung
                      ? 'erste Messung'
                      : null)
                : 'seit ${Format.tagMonat(datumZumAnzeigen(stand.ersterTag!))}',
          ),
        ),
        MessZeileDaten(
          name: 'Pro Monat',
          // **Pro Monat, nicht pro Woche** — in einer Woche bewegt sich am
          // Maßband nichts Messbares (Spec, Detailschirm Punkt 3).
          wert: _wert(
            stand?.proMonat == null
                ? null
                : '${stand!.proMonat! > 0 ? '+' : '−'}'
                      '${umfangsWert(stand.proMonat!.abs())}',
          ),
          platzhalter: _platzhalter('+0,0 cm'),
          kennzeichen: _kennzeichen(
            stand == null
                ? null
                : stand.reihe.length < 2
                ? 'braucht zwei Messungen'
                : 'über ${stand.reihe.length} Messungen',
          ),
        ),
        MessZeileDaten(
          name: 'Kleinster und größter Wert',
          wert: _wert(
            stand?.spanne == null
                ? null
                : '${umfangsZahl(stand!.spanne!.$1)} – '
                      '${umfangsWert(stand.spanne!.$2)}',
          ),
          platzhalter: _platzhalter('00,0 – 00,0 cm'),
        ),
        if (mass.partner != null)
          MessZeileDaten(
            schluessel: kUmfangDetailSeite,
            name: 'Seitendifferenz',
            // Den Betrag bildet die Ansicht; das Vorzeichen trägt die
            // Richtung daneben — „dieses Maß minus Partner" sagt der Kern.
            //
            // **In der Totzone steht kein gerundeter Betrag.** 0,19 cm
            // rundeten auf „0,2 cm" — dieselbe Zahl wie eine echte
            // Differenz von 0,2 cm, die eine Richtung bekommt (der
            // Kern-Test warnt genau davor). „unter 0,2 cm" behauptet
            // nichts, was die Messgenauigkeit nicht trägt; die Grenze
            // kommt aus dem Kern, nicht als zweites Literal.
            wert: _wert(switch (stand?.seitendifferenz) {
              null => null,
              final differenz when
                      differenz.vergleich == SeitenVergleich.gleich =>
                'unter ${umfangsWert(UmfangsFortschritt.totzone)}',
              final differenz => umfangsWert(differenz.delta.abs()),
            }),
            platzhalter: _platzhalter('0,0 cm'),
            kennzeichen: _kennzeichen(
              stand == null
                  ? null
                  : switch (stand.seitendifferenz?.vergleich) {
                      // Eine Seite hat keinen Wert — das sagt die Zeile
                      // anders als „gleich" und anders als gar nichts.
                      null => 'es fehlt eine Seite',
                      SeitenVergleich.gleich => 'beide Seiten gleich',
                      SeitenVergleich.diesesGroesser =>
                        'dieses Maß ist größer',
                      SeitenVergleich.partnerGroesser =>
                        'die Gegenseite ist größer',
                    },
            ),
          ),
        MessZeileDaten(
          name: 'Messungen',
          wert: _wert(stand == null ? null : '${stand.reihe.length}'),
          platzhalter: _platzhalter('00'),
          kennzeichen: _kennzeichen(null),
        ),
      ],
    );
  }

  /// `null` heißt „graue Form" und steht allein im Ladezustand; sonst der
  /// Text oder `–/–`.
  String? _wert(String? text) =>
      lage == VerlaufLage.laedt ? null : (text ?? ohneWert);

  String? _platzhalter(String beispiel) =>
      lage == VerlaufLage.laedt ? beispiel : null;

  /// Das Kennzeichen sagt, worauf sich die Zahl bezieht. **Im Ladezustand
  /// keines** — es wäre eine Auskunft über Daten, die niemand kennt; nach
  /// einem gescheiterten Lauf benennt es den Fehler.
  String? _kennzeichen(String? text) => switch (lage) {
    VerlaufLage.laedt => null,
    VerlaufLage.unlesbar => 'nicht lesbar',
    VerlaufLage.gelesen => text,
  };
}

// ─────────────────────────────────────────────────────────────────────────
// Alle Messungen
// ─────────────────────────────────────────────────────────────────────────

/// „Alle Werte dieses Maßes als Liste, neueste zuerst" (Spec).
///
/// **Die Liste gehört diesem Maß.** Der Wert der Gegenseite steht im
/// Diagramm, nicht zwischen den eigenen Messungen.
///
/// **Nach links wischen löscht einen Messpunkt**, mit Rückfrage (#486) —
/// hier und nicht auf der Übersicht, denn im Diagramm darüber sieht man den
/// Ausreißer, den man loswird. Die übrigen Maße desselben Tages bleiben
/// stehen; den ganzen Messtag löscht die Übersicht.
class UmfangDetailMessungen extends StatefulWidget {
  const UmfangDetailMessungen({
    super.key,
    required this.mass,
    required this.lage,
    required this.gelesen,
    required this.aufLoeschen,
  });

  final Umfang mass;
  final VerlaufLage lage;
  final VerlaufGelesen? gelesen;

  /// Löscht den Messpunkt dieses Maßes in der Ablage und stößt das
  /// Neu-Lesen an. Läuft erst nach bestätigter Rückfrage.
  final Future<void> Function(String tag) aufLoeschen;

  @override
  State<UmfangDetailMessungen> createState() => _UmfangDetailMessungenState();
}

class _UmfangDetailMessungenState extends State<UmfangDetailMessungen> {
  /// Was weggewischt ist, verschwindet sofort aus der Liste — der Provider
  /// liefert bis zum Ende des Neu-Lesens noch den alten Stand, und ein
  /// weggewischtes `Dismissible`, das weiter im Baum steht, ist ein Fehler
  /// (dieselbe Form wie in `umfaenge_view.dart` und `wasser_blatt.dart`).
  final Set<String> _weggewischt = {};

  /// Das Löschen ist gescheitert; die Zeile steht wieder da und der
  /// Hinweis sagt es. Eine Zeile, die verschwindet, während der Wert noch
  /// in der Ablage liegt, wäre eine falsche Auskunft — dasselbe Argument
  /// wie bei `_panne` in `gewicht_eintragen.dart`.
  bool _panne = false;

  VerlaufLage get lage => widget.lage;

  @override
  Widget build(BuildContext context) {
    final zeilen = widget.gelesen?.messungen ?? const <Verlaufszeile>[];

    // Steht ein Tag nicht mehr im gelesenen Stand, ist das Löschen
    // angekommen — der Merker hat ausgedient.
    _weggewischt.removeWhere(
      (tag) => !zeilen.any((zeile) => zeile.tag == tag),
    );
    final sichtbar = [
      for (final zeile in zeilen)
        if (!_weggewischt.contains(zeile.tag)) zeile,
    ];

    return Column(
      key: kUmfangDetailWerte,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Alle Messungen'),
        if (_panne)
          const UmfangsNotiz(
            key: Key('umfang-detail-loeschen-panne'),
            ton: UmfangsNotizTon.warnung,
            text:
                'Das Maß ließ sich nicht löschen — es steht unverändert in '
                'der Liste. Versuch es gleich noch einmal.',
          ),
        if (sichtbar.isEmpty)
          _Satz(text: _satz())
        else
          // **Dieselbe Karte wie überall** ([MessKarte]), nur die Zeilen
          // stecken in der Wischhülle — keine dritte Kopie der
          // Kartengeometrie.
          MessKarte(
            zeilen: [
              for (final zeile in sichtbar)
                MessZeileDaten(
                  name: Format.tag(datumZumAnzeigen(zeile.tag)),
                  wert: umfangsWert(zeile.wert),
                ),
            ],
            huelle: (i, kind) => _wischbareZeile(sichtbar[i], kind),
          ),
      ],
    );
  }

  Widget _wischbareZeile(Verlaufszeile zeile, Widget kind) {
    final datum = Format.tag(datumZumAnzeigen(zeile.tag));
    final mass = widget.mass;
    return WischLoeschen(
      key: Key('umfang-detail-messung-${zeile.tag}'),
      aktion: '${mass.deutsch} vom $datum löschen',
      frage: (context) => umfangLoeschenFrage(
        context,
        titel: '${mass.deutsch} vom $datum löschen?',
        text:
            'Nur dieses eine Maß. Die übrigen Maße des '
            '${Format.tagMonat(datumZumAnzeigen(zeile.tag))} bleiben '
            'stehen. Das lässt sich nicht rückgängig machen.',
      ),
      aufBestaetigt: () => _loesche(zeile.tag),
      child: kind,
    );
  }

  /// Zeile sofort weg, dann die Ablage. **Scheitert die, kommt die Zeile
  /// zurück** — samt Hinweis: Ohne Satz tippt man wieder und wieder auf
  /// eine Geste, die nichts tut.
  Future<void> _loesche(String tag) async {
    setState(() {
      _weggewischt.add(tag);
      _panne = false;
    });
    try {
      await widget.aufLoeschen(tag);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _weggewischt.remove(tag);
        _panne = true;
      });
    }
  }

  /// Drei Lagen, drei Auskünfte. **„Noch nichts gemessen" erst nach dem
  /// Lauf:** Während gelesen wird, weiß niemand, ob etwas erfasst ist, und
  /// ein gescheitertes Lesen ist etwas anderes als eine leere Tabelle.
  String _satz() => switch (lage) {
    VerlaufLage.laedt => '',
    VerlaufLage.unlesbar => 'Die Liste ließ sich nicht lesen.',
    VerlaufLage.gelesen =>
      'Noch nichts gemessen. Sobald du dieses Maß einträgst, steht die '
          'Messung hier.',
  };
}

/// Ein Satz in der Karte, wo keine Zeilen stehen — und im Ladezustand eine
/// graue Form statt eines Satzes, den noch niemand sagen kann.
class _Satz extends StatelessWidget {
  const _Satz({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = TextStyle(fontSize: 13, height: 1.35, color: muted);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: text.isEmpty
              ? Platzhalter(beispiel: '00.00.0000', stil: stil)
              : Text(text, style: stil),
        ),
      ),
    );
  }
}
