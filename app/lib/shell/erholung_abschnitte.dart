// Die Abschnitte des Erholung-Schirms (#115) als eigene, kleine Bausteine —
// `erholung_view.dart` setzt sie zusammen. Getrennt, weil ein Schirm mit
// acht Abschnitten in einer Datei über ein paar hundert Zeilen wächst und
// dann zu viel macht (`CLAUDE.md`, „Views bleiben klein").
//
// **Alle Nutzertexte dieses Schirms stehen hier oder in
// `erholung_zustand.dart`, nie in `trainings_core`** — wörtlich aus
// `docs/superpowers/plans/2026-10-27-erholung-schirm-texte.md`, das sie aus
// der Swift-Vorlage gezogen hat.
import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/inset_card.dart';
import '../design/klapp_abschnitt.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../design/vital_ton.dart';
import 'erholung_zustand.dart';
import 'verlauf_zustand.dart';

/// Was bei fehlenden Health-Daten dasteht. Apple verrät den Lesestatus
/// nicht, also werden **beide** Möglichkeiten benannt — nie „nichts
/// getrackt" (`CLAUDE.md`).
const beideMoeglichkeiten = 'nicht aufgezeichnet oder nicht freigegeben';

/// Ein fehlender Einzelwert. Nie „0": Eine gemessene Null ist eine Aussage,
/// eine Lücke nicht.
const keinWert = '—';

// ─────────────────────────────────────────────────────────────────────────
// Abschnitt 3 + 3b — Hinweiskasten und Health-Knopf
// ─────────────────────────────────────────────────────────────────────────

/// Der Rat zum Verdikt. Fällt bei `calm` weg — dann baut der Schirm ihn gar
/// nicht erst.
///
/// **Erst die farbige Kante, dann der Schnitt auf der ganzen Karte**
/// (`CLAUDE.md`): [InsetCard] legt außen ein `ClipRRect`, der 4 Punkt breite
/// Balken läuft deshalb nicht über die runde Ecke hinaus.
class ErholungHinweiskasten extends StatelessWidget {
  const ErholungHinweiskasten({
    super.key,
    required this.hinweis,
    required this.onHealthEinstellungen,
    required this.onSchlafNachtragen,
  });

  final ErholungHinweis hinweis;
  final VoidCallback onHealthEinstellungen;

  /// Der zweite Weg aus derselben Lücke — „Schlaf manuell hinzufügen".
  /// Hängt am **selben** Fall wie [onHealthEinstellungen]
  /// (`hinweis.zeigtHealthEinstellungen`), es gibt kein zweites Flag: Der
  /// Satz darüber sagt „Beides sieht von hier gleich aus", und genau
  /// deshalb stehen beide Wege zusammen oder gar nicht.
  final VoidCallback onSchlafNachtragen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kante = CupertinoDynamicColor.resolve(hinweis.kante, context);
    final signale = hinweis.signale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: InsetCard(
        // Die Kante als linker Rand, nicht als eigenes Kind in einer
        // gestreckten `Row`: Die bekäme im scrollenden Schirm unbegrenzte
        // Höhe. `InsetCard` schneidet außen, der Balken läuft also nicht
        // über die Ecke hinaus.
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: kante, width: 4)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(13, 13, 13, 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (signale.isNotEmpty) ...[
                  Text(
                    _ueberschrift(signale.length),
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  for (final signal in signale)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        '· $signal',
                        style: TextStyle(fontSize: 13, color: ink),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
                for (final absatz in hinweis.absaetze)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      absatz,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: muted,
                      ),
                    ),
                  ),
                if (hinweis.zeigtHealthEinstellungen)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    // Die beiden Wege stehen **nebeneinander**, je halbe
                    // Breite (Entwurf: `btnrow`). Nebeneinander zu stehen
                    // ist die Aussage; untereinander läse sich der zweite
                    // wie der Nachsatz zum ersten.
                    //
                    // `IntrinsicHeight`, weil `btnrow` die Knöpfe auf
                    // gleiche Höhe zieht (`align-items: stretch`): Bricht
                    // eine Beschriftung um, wächst der andere Knopf mit,
                    // statt daneben halbhoch zu hängen. Zwei Knöpfe sind
                    // dafür billig genug.
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _HinweisKnopf(
                              key: const Key('erholung-health-einstellungen'),
                              titel: 'Health-Einstellungen öffnen',
                              onPressed: onHealthEinstellungen,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _HinweisKnopf(
                              key: const Key('erholung-schlaf-nachtragen'),
                              titel: 'Schlaf manuell hinzufügen',
                              onPressed: onSchlafNachtragen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _ueberschrift(int anzahl) {
    const zahlwort = ['Kein', 'Ein', 'Zwei', 'Drei', 'Vier'];
    final wort = anzahl < zahlwort.length ? zahlwort[anzahl] : '$anzahl';
    return anzahl == 1 ? '$wort Warnsignal:' : '$wort Warnsignale:';
  }
}

/// Einer der beiden gleichrangigen Knöpfe unter dem Hinweiskasten.
///
/// **Ohne `color`** — ein gesetztes `color` ist `CupertinoButton.filled`
/// und damit der hervorgehobene Knopf. Einen der beiden hervorzuheben
/// hieße zu vermuten, welcher der beiden Fälle vorliegt (nichts
/// aufgezeichnet oder nicht freigegeben), und genau das weiß die App
/// nicht.
///
/// Die Beschriftung **bricht um**, statt abgeschnitten zu werden: Zwei
/// Knöpfe nebeneinander haben je die halbe Breite, und ein zerhackter
/// Knopftext sagt weniger als ein zweizeiliger.
class _HinweisKnopf extends StatelessWidget {
  const _HinweisKnopf({
    super.key,
    required this.titel,
    required this.onPressed,
  });

  final String titel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => CupertinoButton(
    padding: const EdgeInsets.symmetric(vertical: 6),
    onPressed: onPressed,
    child: Text(
      titel,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 14, height: 1.2),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────
// Abschnitt 6 — Verläufe
// ─────────────────────────────────────────────────────────────────────────

/// Eine Verlaufszeile — Dart-Entsprechung von `trendRow` in
/// `docs/screens/components.js` (`.trendrow`).
///
/// **Kein [IconRow]:** Der Entwurf zeigt in den Verläufen keine Symbole,
/// und `IconRow` ohne `symbol`/`accent` gibt es nicht. Links Titel und
/// Detailzeile, rechts der Wert — nach der Ampel eingefärbt —, dahinter der
/// Winkel, wenn die Zeile weiterführt.
///
/// **Der Wert ist der heutige Messwert, der Vergleichswert steht in
/// [detail].** Gebaut war es umgekehrt (der Durchschnitt als Wert, kein
/// Vergleichswert); ohne diesen Tausch hinge die Farbe in der Luft, denn
/// sie vergleicht beide, und beide müssen in derselben Zeile stehen.
class ErholungVerlaufsZeile extends StatelessWidget {
  const ErholungVerlaufsZeile({
    super.key,
    required this.titel,
    required this.detail,
    this.wert,
    this.ton = VitalTon.unbeurteilt,
    this.onTap,
  });

  final String titel;

  /// Fenster und Vergleichswert: „9 Tage · Median 60 ms".
  final String detail;

  /// Der Wert des gezeigten Tages. Eine Lücke steht als „—" da, nicht als
  /// Leere: Eine Anzeige, die es gibt, hat genau eine Form.
  ///
  /// `null` heißt „die Zeile trägt gar keinen Wert". Seit #268 nutzt das
  /// keine der fünf Zeilen mehr — die Alkohol-Zeile war die letzte.
  final String? wert;

  /// [VitalTon.unbeurteilt] heißt „keine Farbe": weder gut noch schlecht.
  /// Der Vorgabewert ist der ehrliche — wer nichts übergibt, hat nicht
  /// bewertet (#308).
  final VitalTon ton;

  /// Winkel **und** Tür gehören zusammen. Ein Winkel ohne Ziel wäre genau
  /// die Zeile, die `docs/screens/pruefen.mjs` am Board verhindert; eine
  /// Tür ohne Winkel findet niemand.
  final VoidCallback? onTap;

  /// Der Winkelplatz ist immer reserviert, auch ohne Tür — sonst springt
  /// die Wertspalte, sobald eine Zeile nicht weiterführt. `tabular-nums`
  /// allein genügt dafür nicht: Das richtet die Ziffern innerhalb einer
  /// Zahl aus, nicht die Zahlen zueinander.
  static const double _winkelBreite = 13;

  /// Feste Breite der Wertspalte, damit alle Zahlen auf einer Kante
  /// stehen.
  static const double _wertBreite = 64;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ton = this.ton;
    final wert = this.wert;
    final onTap = this.onTap;

    final zeile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      child: Row(
        // Der Wert sitzt auf der **Mitte der Zeile**, nicht auf der
        // Grundlinie des Titels — sonst stünde er sichtbar zu hoch,
        // während der Winkel daneben schon mittig säße.
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titel, style: TextStyle(fontSize: 15, color: ink)),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    detail,
                    style: TextStyle(fontSize: 12, color: muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (wert != null)
            SizedBox(
              width: _wertBreite,
              child: Text(
                wert,
                textAlign: TextAlign.right,
                style: Typografie.tabularNumbers(
                  Typografie.numeric(TypografieGroesse.callout).copyWith(
                    // Aufgelöst, nicht als `CupertinoDynamicColor`
                    // weitergereicht — die bliebe im Dunkelmodus auf ihrer
                    // hellen Variante stehen. Aufgelöst wird in
                    // `vitalTonFarbe`, derselben Stelle wie auf Heute
                    // (#308).
                    //
                    // **`muted` als Grundfarbe, nicht `ink`:** Der Entwurf
                    // führt den Wert einer Zeile ohne Ampel gedämpft
                    // (`trendRow` in `docs/screens/components.js`).
                    color: vitalTonFarbe(ton, context, muted),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: _wertBreite),
          const SizedBox(width: 8),
          SizedBox(
            width: _winkelBreite,
            child: onTap == null
                ? null
                : Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: muted.withValues(alpha: 0.7),
                  ),
          ),
        ],
      ),
    );

    if (onTap == null) return zeile;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: zeile,
    );
  }
}

/// Die fünf Verlaufszeilen.
///
/// **Die vier Messwert-Zeilen führen weiter, die Alkohol-Zeile nicht.**
/// Tims Befund vom 27.10.2026 war „Bei der Atemfrequenz fehlt der Pfeil";
/// gelöst wird er mit Pfeil **und** Tür. Die Alkohol-Zeile trägt seit #125
/// eine gelesene Zahl und seit #268 eine Auskunft über den Vortag, bleibt
/// aber eine Nicht-Tür: Ein Verlaufs-Schirm zeigt den Verlauf eines
/// Messwerts, und weder eine Zahl von Tagen im Fenster noch eine
/// Ja/Nein-Auskunft ist einer.
///
/// **Welche Zeile eine Tür ist, entscheidet [verlaufArtZu]** — nicht der
/// Titel der Zeile und kein Sonderfall hier: `null` heißt „keine Tür".
/// Kommt eine sechste Verlaufszeile dazu, steht die Entscheidung weiter an
/// einer Stelle statt an zweien.
class ErholungVerlaeufe extends StatelessWidget {
  const ErholungVerlaeufe({
    super.key,
    required this.trends,
    required this.messwerte,
    required this.baseline,
    required this.onVerlauf,
    this.alkoholVortag = AlcoholEve.unknown,
    this.bewertung,
  });

  /// Das Urteil der Ampel zu demselben Tag — es entscheidet, **ob**
  /// überhaupt gefärbt wird (#308). Nach der OP ruht die Ampel, `rated`
  /// ist dann leer, und keine der vier Zeilen trägt eine Farbe; bis dahin
  /// färbten sie weiter und widersprachen damit dem Kasten darüber.
  ///
  /// Der Vorgabewert ist der ehrliche: Wer nichts übergibt, hat nicht
  /// bewertet.
  final RecoveryEvaluation? bewertung;

  /// Ob am **Vortag** des gezeigten Tages Alkohol erfasst ist (#268).
  /// Kommt aus `RecoverySnapshot.alcoholEve`.
  ///
  /// Der Vorgabewert ist der ehrliche: Wer nichts übergibt, weiß nichts.
  final AlcoholEve alkoholVortag;

  final List<RecoveryTrend> trends;

  /// Die heutigen Messwerte — der Wert rechts in jeder Zeile.
  final RecoveryReading messwerte;

  /// Die Mediane — der Vergleichswert in der Detailzeile und die Grundlage
  /// der Ampel.
  final RecoveryBaseline baseline;

  /// Trägt die Art der angetippten Zeile — **nicht** `VerlaufArt?`: Eine
  /// Zeile ohne Art ruft gar nicht erst. Damit ist „eine Zeile, die
  /// drückbar aussieht und nirgendwohin führt", im Vertrag unausdrückbar
  /// statt nur unterlassen (`docs/todo/06`).
  final void Function(VerlaufArt art) onVerlauf;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final zeilen = [for (final trend in trends) _zeile(trend)];

    return Column(
      key: const Key('erholung-verlaeufe'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Verläufe'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: InsetCard(
            child: Column(
              children: [
                for (var i = 0; i < zeilen.length; i++) ...[
                  zeilen[i],
                  if (i < zeilen.length - 1) Container(height: 1, color: line),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  ErholungVerlaufsZeile _zeile(RecoveryTrend trend) {
    final ton = verlaufsTon(
      art: trend.kind,
      messwerte: messwerte,
      baseline: baseline,
      bewertung: bewertung,
    );

    // Die eine Stelle, an der „führt weiter / führt nicht weiter" steht.
    final art = verlaufArtZu(trend.kind);
    final tuer = art == null ? null : () => onVerlauf(art);

    /// „9 Tage · Median 60 ms" — ohne Vergleichswert bleibt das Fenster
    /// allein stehen, statt eine Zahl zu erfinden.
    String detail(String einheit, String? vergleich) {
      final fenster = trend.count == 0
          ? 'keine Werte'
          : '${trend.count} $einheit';
      return vergleich == null ? fenster : '$fenster · $vergleich';
    }

    return switch (trend.kind) {
      RecoveryTrendKind.sleep => ErholungVerlaufsZeile(
        titel: 'Schlafdauer',
        detail: detail(
          'Nächte',
          baseline.sleepHours == null
              ? null
              : 'Ø ${stundenText(baseline.sleepHours!)}',
        ),
        wert: messwerte.sleepHours == null
            ? keinWert
            : stundenText(messwerte.sleepHours!),
        ton: ton,
        onTap: tuer,
      ),
      RecoveryTrendKind.hrv => ErholungVerlaufsZeile(
        titel: 'HRV',
        detail: detail(
          'Tage',
          baseline.hrv == null ? null : 'Median ${baseline.hrv!.round()} ms',
        ),
        wert: messwerte.hrv == null ? keinWert : '${messwerte.hrv!.round()} ms',
        ton: ton,
        onTap: tuer,
      ),
      RecoveryTrendKind.restingHeartRate => ErholungVerlaufsZeile(
        titel: 'Ruhepuls',
        detail: detail(
          'Tage',
          baseline.restingHeartRate == null
              ? null
              : 'Median ${baseline.restingHeartRate!.round()}',
        ),
        wert: messwerte.restingHeartRate == null
            ? keinWert
            : '${messwerte.restingHeartRate!.round()}',
        ton: ton,
        onTap: tuer,
      ),
      RecoveryTrendKind.respiratoryRate => ErholungVerlaufsZeile(
        titel: 'Atemfrequenz',
        detail: detail(
          'Tage',
          baseline.respiratoryRate == null
              ? null
              : 'Normal ${kommazahl(baseline.respiratoryRate!)}',
        ),
        wert: messwerte.respiratoryRate == null
            ? keinWert
            : kommazahl(messwerte.respiratoryRate!),
        ton: ton,
        onTap: tuer,
      ),
      // **Der Vortag, nicht „zuletzt"** (#268). Tim am 03.11.2026: „wenn
      // ich den Schirm heute angucke, steht da, ob ich gestern getrunken
      // habe." Alkohol drückt die Erholung der folgenden Nacht; „zuletzt
      // am 2. November" sagte über die Nacht auf den 28. Oktober nichts —
      // und wanderte beim Blättern nicht mit.
      //
      // **Drei Zustände, nicht zwei.** „Nein" steht nur bei einer
      // gemessenen Null; sonst steht dort die Lücke, nicht ein erfundenes
      // Nein. Ein „nein", das in Wahrheit „keine Daten" heißt, wäre
      // Fehler `01` in klein.
      //
      // **Die Zahl im Zeitraum bleibt**, aber getrennt: Sie beantwortet
      // eine andere Frage — wie oft —, und sie steht deshalb in der
      // Detailzeile, dort, wo bei allen anderen Zeilen auch das Fenster
      // steht.
      //
      // Keine Farbe (siehe `verlaufsTon`) und keine Tür: Die Zeile stellt
      // einen Zusammenhang her, sie bewertet nicht. `onTap: tuer` steht
      // trotzdem hier und nicht als weggelassener Sonderfall — was eine
      // Tür ist, sagt [verlaufArtZu] für alle fünf Zeilen gleich.
      RecoveryTrendKind.alcoholDays => ErholungVerlaufsZeile(
        titel: 'Alkohol am Vortag',
        detail: switch (trend.count) {
          0 => _ohneAlkoholTag,
          1 => '1 Alkohol-Tag im Zeitraum',
          final anzahl => '$anzahl Alkohol-Tage im Zeitraum',
        },
        wert: switch (alkoholVortag) {
          AlcoholEve.drinks => 'Ja',
          AlcoholEve.noDrinks => 'Nein',
          AlcoholEve.unknown => keinWert,
        },
        onTap: tuer,
      ),
    };
  }
}

/// **„freigegeben", nicht „freigeben":** Beide Möglichkeiten stehen als
/// Zustand da, nicht als Aufforderung — dieselbe Regel wie im
/// Hinweiskasten. Und kein Wort darüber, ob getrunken wurde oder nicht:
/// Niemand weiß es. Steht hier „0 Alkohol-Tage", wäre das eine Behauptung
/// über das Verhalten des Nutzers, und sie kann allein an der fehlenden
/// Freigabe liegen.
const _ohneAlkoholTag = 'keine Daten oder nicht freigegeben';

// ─────────────────────────────────────────────────────────────────────────
// Abschnitt 7 — „Was die Werte besser macht"
// ─────────────────────────────────────────────────────────────────────────

/// Vier Tipps, **eingeklappt**. Allgemeine Empfehlungen, keine Diagnose —
/// der letzte nennt die OP ausdrücklich als Normalfall, nicht als Warnung.
///
/// Entwurf: `sectionCard({ title: 'Tipps', hint: '4 Punkte', open: false })`.
/// Tim am 27.10.2026: „unten die Tipps sollten default eingeklappt sein."
/// Die vier Punkte ändern sich von Tag zu Tag nicht — wer sie kennt,
/// scrollt sonst jedes Mal an ihnen vorbei, und darunter steht noch die
/// Fußnote.
///
/// **Die Klapp-Mechanik liegt seit #253 in [KlappAbschnitt]** und nicht
/// mehr hier: Sie wird inzwischen fünfmal gebraucht — einmal hier, viermal
/// am Fuß des Schlaf-Schirms —, und fünfmal von Hand wäre fünfmal die
/// Gelegenheit, sie unterschiedlich falsch zu machen. Die Regel
/// „aufgeklappt bleibt aufgeklappt" steht dort, wo sie jetzt durchgesetzt
/// wird.
///
/// **Der Rand bleibt bei 20**, nicht beim vorbelegten 16 des Bauteils: Die
/// Karte sitzt hier unter einer [SectionHeader], und die rückt ebenfalls
/// 20 ein. Ein Wechsel auf 16 wäre eine Entwurfsänderung, die niemand
/// beschlossen hat.
class ErholungTipps extends StatelessWidget {
  const ErholungTipps({super.key});

  static const _tipps = [
    'Regelmäßige Schlafenszeit, auch am Wochenende. Schwankungen über eine '
        'Stunde merkt man oft an der HRV.',
    'Kein spätes, schweres Essen und kein Alkohol am Abend vor harten '
        'Einheiten.',
    'Lockere Läufe wirklich in Zone 2. Zu harte „lockere" Läufe drücken die '
        'Erholung.',
    'Nach der OP sind niedrige HRV und höherer Ruhepuls normal. Der Körper '
        'heilt, dann zählt nur Ruhe.',
  ];

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader('Was die Werte besser macht'),
        KlappAbschnitt(
          titel: 'Tipps',
          hinweis: '${_tipps.length} Punkte',
          kopfSchluessel: const Key('erholung-tipps-kopf'),
          inhaltSchluessel: const Key('erholung-tipps-inhalt'),
          randAbstand: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          inhalt: () => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final tipp in _tipps)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '· $tipp',
                    style: TextStyle(fontSize: 13, height: 1.35, color: ink),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Zahlen zu Text
// ─────────────────────────────────────────────────────────────────────────

/// „7 Std." bzw. „5 Std. 28 Min." — reine Mechanik, kein Fachbegriff.
String dauerText(double minuten) {
  final ganz = minuten.round();
  final stunden = ganz ~/ Duration.minutesPerHour;
  final rest = ganz % Duration.minutesPerHour;
  if (rest == 0) return '$stunden Std.';
  return '$stunden Std. $rest Min.';
}

/// „14,0" — eine Nachkommastelle mit Komma statt Punkt. Reine Mechanik.
String kommazahl(double wert) => wert.toStringAsFixed(1).replaceAll('.', ',');

/// „6:48 h" aus einem Stundenwert.
String stundenText(double stunden) {
  var ganz = stunden.floor();
  var minuten = ((stunden - ganz) * Duration.minutesPerHour).round();
  if (minuten == Duration.minutesPerHour) {
    ganz += 1;
    minuten = 0;
  }
  return '$ganz:${minuten.toString().padLeft(2, '0')} h';
}
