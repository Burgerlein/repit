import 'package:flutter/cupertino.dart';

import 'kachel_karte.dart';
import 'palette.dart';
import 'platzhalter.dart';
import 'typografie.dart';
import 'vital_ton.dart';

/// [VitalTon] gehört zur Karte, liegt aber seit #308 daneben: Der
/// Erholungs-Schirm färbt seine Verlaufszeilen mit demselben
/// Aufzählungstyp, und eine Karte als Heimat dafür wäre ein Schirm, der an
/// einem Bauteil hängt, das er nicht benutzt. Wer `VitalWert` baut,
/// braucht den Typ — deshalb kommt er hier weiter mit heraus.
export 'vital_ton.dart' show VitalTon;

/// Ein Vitalwert der Erholungskarte: Name, Wert, Einordnung —
/// Dart-Entsprechung eines Eintrags aus `vitals` in `recoveryCard`
/// (`docs/screens/components.js`, `.vitals`). Keine Swift-Entsprechung
/// vorhanden (zu unterscheiden von `VitalRow` auf dem separaten
/// Erholung-Screen).
///
/// `wert` ist `String?`, nicht `0` oder ein leerer String als Sentinel:
/// Fehlt ein Wert (z. B. `restingHR` an einer Lücke im Demo-Datensatz),
/// übergibt der Aufrufer `null` und bekommt dafür keinen erfundenen Wert
/// gezeigt (CLAUDE.md, Abschnitt HealthKit).
class VitalWert {
  const VitalWert({
    required this.name,
    this.wert,
    this.hinweis,
    this.platzhalter,
    this.ton = VitalTon.unbeurteilt,
  });

  final String name;
  final String? wert;

  /// Die Einordnung unter dem Wert („Median 58", „Ø 66") — ein Mittelwert
  /// über Wochen, der nicht am heutigen Messwert hängt und deshalb auch
  /// ohne ihn stehen bleibt.
  ///
  /// **Kein Ort für den Grund, warum ein Wert fehlt.** Der stand früher
  /// hier, lief in der schmalen Spalte über mehrere Zeilen und machte die
  /// Karte genau dann höher, wenn Werte fehlten. Er gehört einmal in
  /// [ErholungsKarte.satz], nicht viermal in die Spalten (Spec
  /// `2026-10-28-leerzustaende-design.md`).
  final String? hinweis;

  /// Beispieltext für die graue Fläche, solange noch nichts gelesen wurde
  /// (#24). Nur wirksam, wenn [wert] fehlt.
  final String? platzhalter;

  /// Was die Ampel über diesen Wert gesagt hat (#254).
  ///
  /// **Vorgabe ist [VitalTon.unbeurteilt]**, nicht `normal`: Wer den
  /// Zustand nicht mitgibt, hat nicht bewertet — und ein Vorgabewert, der
  /// „im Normalbereich" behauptet, wäre eine Aussage, die niemand gemacht
  /// hat.
  final VitalTon ton;
}

/// Die Erholungskarte — Dart-Entsprechung von `recoveryCard` in
/// `docs/screens/components.js` (`.rec-top`, `.rec-sub`, `.vitals`). Keine
/// Swift-Entsprechung vorhanden.
///
/// `vitalwerte` ist eine Liste beliebiger Länge, wie `vitals` im Entwurf —
/// nichts erzwingt genau vier Einträge (Schlaf/HRV/Ruhepuls/Atmung), auch
/// wenn der Entwurf genau die zeigt.
class ErholungsKarte extends StatelessWidget {
  const ErholungsKarte({
    super.key,
    required this.ueberschrift,
    required this.satz,
    required this.akzent,
    required this.vitalwerte,
  });

  final String ueberschrift;
  final String satz;
  final Color akzent;
  final List<VitalWert> vitalwerte;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);

    // **Dieselbe Fläche wie die Kacheln darüber** (#299, Tim am 03.11.2026).
    // Auf Home steht diese Karte unmittelbar unter Schritte und Gewicht;
    // mit dem damaligen `InsetCard` trug sie als Einzige einen Rahmen und
    // einen kleineren Radius und fiel damit aus der Reihe.
    //
    // Seit #376 gab sie die Form für ganz Home vor, seit #384 für die ganze
    // App (Tim, 05.11.2026). Getragen über `KachelKarte`; die Form selbst
    // steht in `kartenFlaeche`.
    return KachelKarte(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: akzent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                // `Expanded`, nicht nackt: „Keine Werte von der Uhr" ist
                // länger als „Erholung" und lief auf Gerätebreite über den
                // Rand hinaus (gelb-schwarzer Balken auf dem Gerät, auf
                // Flutters 800-Punkt-Testfläche nie sichtbar).
                Expanded(
                  child: Text(
                    ueberschrift,
                    // Eine Zeile, fest: Die Überschrift wechselt mit der
                    // Datenlage („Erholung" ↔ „Keine Werte"), und eine
                    // umbrechende machte die Karte genau dann höher, wenn
                    // Werte fehlen.
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              // Zwei Zeilen fest reserviert (#24): Der Satz ist im
              // Leerfall ein anderer als im Normalfall, und ohne feste
              // Zeilenzahl wüchse die Karte beim Umschalten.
              child: FesteZeilen(
                zeilen: 2,
                stil: _satzStil(muted),
                child: Text(
                  satz,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _satzStil(muted),
                ),
              ),
            ),
            if (vitalwerte.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final vital in vitalwerte)
                      Expanded(child: _VitalSpalte(vital: vital)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VitalSpalte extends StatelessWidget {
  const _VitalSpalte({required this.vital});

  final VitalWert vital;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final hinweis = vital.hinweis;

    // **Mittig, nicht linksbündig** (Tims Befund vom 27.10.2026). Die vier
    // Spalten füllen die Karte schon ganz aus; gemeint war die Ausrichtung
    // **in** der Spalte: Name, Wert und Unterschrift standen an der linken
    // Spaltenkante und damit je nach Länge des Werts unterschiedlich weit
    // von der Spaltenmitte entfernt.
    //
    // `maxLines: 1` mit `ellipsis` hält die Unterschrift einzeilig — ein
    // langer Hinweis macht die Spalte sonst höher als ihre Nachbarn.
    return Semantics(
      // Siehe `_vorlesetext` in `kacheln.dart`: derselbe Grund, dieselbe
      // Formulierung — „HRV, keine Werte" statt „HRV Strich Schrägstrich
      // Strich".
      label: _vorlesetext(vital),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            vital.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            // Aus dem Urteil der Ampel wird eine Farbe — in
            // `vitalTonFarbe`, für jeden Schirm dieselbe (#254, seit #308
            // im Design-System statt hier). **`ink` und nicht `muted`:**
            // Grau heißt auf dem Erholungs-Schirm „kein Wert", und ein
            // gemessener, nur unverglichener Wert darf nicht wie ein
            // fehlender aussehen. Ein fehlender Wert ist ohnehin nie
            // beurteilt — er steht als Strich da, und den färbt niemand
            // ein.
            child: _Zahl(
              vital: vital,
              ink: vitalTonFarbe(vital.ton, context, ink),
            ),
          ),
          if (hinweis != null)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Text(
                hinweis,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10, color: muted),
              ),
            ),
        ],
      ),
    );
  }
}

TextStyle _satzStil(Color muted) => TextStyle(fontSize: 12, color: muted);

/// Was VoiceOver zu einer Spalte sagt — der Zustand in Worten, nie das
/// Zeichen.
String _vorlesetext(VitalWert vital) {
  final hinweis = vital.hinweis == null ? '' : '. ${vital.hinweis}';
  final zahl = vital.wert;
  if (zahl == null) {
    if (vital.platzhalter != null) return '${vital.name}, wird geladen';
    return '${vital.name}, keine Werte$hinweis';
  }
  return '${vital.name}, $zahl$hinweis';
}

/// Der Messwert einer Spalte: die Zahl, bei fehlendem Wert das Zeichen
/// [ohneWert] — nie eine stillschweigende „0" —, und solange noch gar
/// nichts gelesen wurde eine graue Fläche.
class _Zahl extends StatelessWidget {
  const _Zahl({required this.vital, required this.ink});

  final VitalWert vital;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title3)
          .copyWith(color: ink, fontWeight: FontWeight.w500),
    );
    final zahl = vital.wert;
    final beispiel = vital.platzhalter;
    if (zahl == null && beispiel != null) {
      // `Align` füllt die Spaltenbreite, der Platzhalter muss seine
      // Ausrichtung also selbst mitbringen — und zwar dieselbe wie die
      // Zahl, die ihn ablöst. Stand hier `centerLeft` (so kam #137 aus
      // `main`, als die Spalte noch linksbündig war), spränge die graue
      // Fläche beim Eintreffen des Werts in die Mitte. Genau den Sprung
      // soll der Platzhalter verhindern.
      return Align(
        alignment: Alignment.center,
        child: Platzhalter(beispiel: beispiel, stil: stil),
      );
    }
    // **Eine Zeile, fest** (#501). Seit die Werte ihre Einheit tragen
    // („11,8/min" statt „11,8"), ist die Spalte das knappste Maß der
    // Karte. Bräche der Wert um, wäre die Karte genau bei dem Wert
    // höher, der am längsten ist — und beim Umschalten auf `–/–`
    // wieder niedriger. Gekürzt wird lieber als gesprungen; dass die
    // Einheit auf Gerätebreite hineinpasst, steht in der Prüfanleitung
    // (die Testschrift von `flutter test` misst hier nicht das Gerät).
    return Text(
      zahl ?? ohneWert,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: stil,
    );
  }
}
