import 'package:flutter/cupertino.dart';

import 'inset_card.dart';
import 'palette.dart';
import 'segment_ring.dart';

/// Eine der drei Spalten der Ringkarte: die Segmente ihres Rings und die
/// drei Texte darum herum. Die **Beschriftung** („SCHLAF") steht
/// absichtlich nicht hier — die setzt [RingKarte], damit Groß- und
/// Kleinschreibung an einer Stelle entschieden wird.
class RingSpalte {
  const RingSpalte({
    required this.abschnitte,
    required this.mitte,
    required this.caption,
    required this.detail,
  });

  final List<RingAbschnitt> abschnitte;

  /// Die große Zahl im Ring — „76", „2", „187" oder „—".
  final String mitte;

  /// Unter der Zahl — „Score", „von 70", „Signale", „min".
  final String caption;

  /// Unter der Beschriftung — „5:35 h", „Schlaf, HRV", „Woche · Ziel 210".
  final String detail;
}

/// Die drei Spalten der Ringkarte in einem Wertobjekt.
class RingKartenDaten {
  const RingKartenDaten({
    required this.schlaf,
    required this.erholung,
    required this.belastung,
  });

  final RingSpalte schlaf;
  final RingSpalte erholung;
  final RingSpalte belastung;
}

/// Die vier Werte der Erholungs-Ampel in der **Vertragsreihenfolge**
/// (Spec `2026-10-26-erholung-flutter-design.md`, Abschnitt 6). Die
/// Reihenfolge der Fälle ist die Reihenfolge der Viertel im Ring und der
/// Namen im Detail — nicht die Reihenfolge, in der ein Aufrufer seine
/// Signale übergibt.
enum ErholungWert { schlaf, ruhepuls, hrv, atemfrequenz }

extension ErholungWertName on ErholungWert {
  String get name => switch (this) {
    ErholungWert.schlaf => 'Schlaf',
    ErholungWert.ruhepuls => 'Ruhepuls',
    ErholungWert.hrv => 'HRV',
    ErholungWert.atemfrequenz => 'Atemfrequenz',
  };
}

/// Die Zahlen der drei Ringe, einmal an einer Stelle — Dart-Entsprechung
/// von `enum RecoveryRings` in
/// `Sources/Features/Recovery/RecoveryRings.swift`.
///
/// **Primitive Parameter statt der Typen aus `trainings_core`:** Die
/// Rechenschicht (#109 Ampel, #110 Schlaf-Score) entsteht getrennt davon.
/// Die Oberfläche legt deren Signaturen nicht fest; sie bekommt Zahlen und
/// macht daraus Segmente und Texte.
abstract final class ErholungRinge {
  /// Drei Segmente, Anteile 50/30/20, jedes nach seiner eigenen Teilnote
  /// gefüllt.
  ///
  /// Ohne Zubettgehzeit **bleibt das 30-%-Segment stehen** und wird
  /// gestrichelt; der Ring normiert **nicht** auf 70 um. Die Aussage trägt
  /// allein die Caption „von 70" — rechnete der Ring um, sähe eine Nacht
  /// ohne Einschlafzeit besser aus, als sie ist.
  static RingSpalte schlaf({
    required int gesamt,
    required int punkteDauer,
    required int? punkteZubettgehzeit,
    required int punkteUnterbrechungen,
    required String dauer,
  }) {
    final zubett = punkteZubettgehzeit;
    return RingSpalte(
      abschnitte: [
        RingAbschnitt(
          anteil: 0.5,
          fuellung: punkteDauer / 50,
          farbe: Palette.river,
        ),
        RingAbschnitt(
          anteil: 0.3,
          fuellung: zubett == null ? 0 : zubett / 30,
          farbe: Palette.ok,
          hatGrundlage: zubett != null,
        ),
        RingAbschnitt(
          anteil: 0.2,
          fuellung: punkteUnterbrechungen / 20,
          farbe: Palette.wach,
        ),
      ],
      mitte: '$gesamt',
      caption: zubett == null ? 'von 70' : 'Score',
      detail: dauer,
    );
  }

  /// Ohne Nacht **ein** graues Segment über den ganzen Kreis — nicht drei
  /// leere. Drei Segmente ohne Daten sähen aus wie eine Nacht mit null
  /// Punkten in jedem Teil.
  static RingSpalte schlafOhneNacht() {
    return const RingSpalte(
      abschnitte: [
        RingAbschnitt(
          anteil: 1,
          fuellung: 0,
          farbe: Palette.rest,
          hatGrundlage: false,
        ),
      ],
      mitte: '—',
      caption: 'kein Wert',
      detail: 'keine Nacht',
    );
  }

  /// Vier Viertel, eins je Wert: `bib` heißt Warnsignal, `ok` heißt im
  /// eigenen Normalbereich. **Keine Prozentzahl** — vier Messwerte ergeben
  /// keine Note auf den Körper, die Mitte zählt Signale.
  static RingSpalte erholung({required List<ErholungWert> signale}) {
    // In Vertragsreihenfolge, unabhängig von der Reihenfolge des
    // Aufrufers: sonst stünde dasselbe Ergebnis je nach Aufrufweg anders da.
    final auffaellig = ErholungWert.values
        .where(signale.contains)
        .toList(growable: false);
    return RingSpalte(
      abschnitte: [
        for (final wert in ErholungWert.values)
          RingAbschnitt(
            anteil: 0.25,
            fuellung: 1,
            farbe: auffaellig.contains(wert) ? Palette.bib : Palette.ok,
          ),
      ],
      mitte: '${auffaellig.length}',
      caption: 'Signale',
      detail: auffaellig.isEmpty
          ? 'alles im Normalbereich'
          : auffaellig.map((wert) => wert.name).join(', '),
    );
  }

  /// Keine Werte von der Uhr: alle Viertel grau und ohne Grundlage.
  static RingSpalte erholungOhneWerte() {
    return RingSpalte(
      abschnitte: _vierteOhneGrundlage(),
      mitte: '—',
      caption: 'keine Werte',
      detail: 'Uhr prüfen',
    );
  }

  /// Nach der OP ruht die Ampel. „Schlecht erholt" wäre nach einer
  /// Operation keine Warnung, sondern der Normalfall — und eine Zahl, die
  /// zum Trainieren verleitet.
  static RingSpalte erholungNachOp() {
    return RingSpalte(
      abschnitte: _vierteOhneGrundlage(),
      mitte: '—',
      caption: 'pausiert',
      detail: 'nach der OP',
    );
  }

  static List<RingAbschnitt> _vierteOhneGrundlage() {
    return [
      for (var i = 0; i < ErholungWert.values.length; i++)
        const RingAbschnitt(
          anteil: 0.25,
          fuellung: 0,
          farbe: Palette.rest,
          hatGrundlage: false,
        ),
    ];
  }

  /// Ein Segment über den ganzen Kreis, gefüllt nach Wochenminuten durch
  /// Wochenziel.
  ///
  /// Ohne aufgezeichnete Minuten steht „—", nie „0 min": Eine gemessene
  /// Null ist die Aussage „diese Woche nichts trainiert", ohne
  /// Aufzeichnung gibt es diese Aussage nicht. Ein Wochenziel von 0 füllt
  /// nichts, statt durch null zu teilen.
  static RingSpalte belastung({
    required double? wochenminuten,
    required double wochenziel,
  }) {
    final minuten = wochenminuten;
    return RingSpalte(
      abschnitte: [
        RingAbschnitt(
          anteil: 1,
          fuellung: minuten == null || wochenziel <= 0
              ? 0
              : minuten / wochenziel,
          farbe: Palette.iron,
          hatGrundlage: minuten != null,
        ),
      ],
      mitte: minuten == null ? '—' : '${minuten.round()}',
      caption: 'min',
      detail: minuten == null
          ? 'nichts aufgezeichnet'
          : 'Woche · Ziel ${wochenziel.round()}',
    );
  }
}

/// Die drei Ringe über dem Erholung-Schirm — Dart-Entsprechung von
/// `RecoveryRingCard` in `RecoveryRings.swift`. Jede Spalte ist eine Tür.
///
/// **Die Karte bekommt fertige Daten und drei Rückrufe.** Sie kennt weder
/// Router noch Provider: Jeder Tab führt seinen eigenen Navigationsstapel,
/// und auf welchen geschoben wird, entscheidet der Schirm — nicht die
/// Karte (`CLAUDE.md`). Darum auch kein eigener `Navigator` und kein
/// eigenes Gerüst hier.
class RingKarte extends StatelessWidget {
  const RingKarte({
    super.key,
    required this.daten,
    required this.onSchlaf,
    required this.onErholung,
    required this.onBelastung,
    required this.onHilfe,
  });

  final RingKartenDaten daten;
  final VoidCallback onSchlaf;
  final VoidCallback onErholung;
  final VoidCallback onBelastung;

  /// Öffnet das Hilfe-Blatt, keine Tür.
  final VoidCallback onHilfe;

  @override
  Widget build(BuildContext context) {
    // `InsetCard` schneidet außen mit einem `ClipRRect` — erst die Fläche,
    // dann der Schnitt auf der ganzen Karte, damit eine farbige Kante nicht
    // über die Ecke hinausläuft (`CLAUDE.md`).
    return InsetCard(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Kopfzeile(onHilfe: onHilfe),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Spalte(
                    spalte: daten.schlaf,
                    beschriftung: 'Schlaf',
                    onTap: onSchlaf,
                  ),
                ),
                Expanded(
                  child: _Spalte(
                    spalte: daten.erholung,
                    beschriftung: 'Erholung',
                    onTap: onErholung,
                  ),
                ),
                Expanded(
                  child: _Spalte(
                    spalte: daten.belastung,
                    beschriftung: 'Belastung',
                    onTap: onBelastung,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Kopfzeile extends StatelessWidget {
  const _Kopfzeile({required this.onHilfe});

  final VoidCallback onHilfe;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Row(
      children: [
        Text(
          'HEUTE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: muted,
          ),
        ),
        const Spacer(),
        // Ein „?" allein wird von VoiceOver wie ein Satzzeichen vorgelesen;
        // die Beschriftung ersetzt es.
        Semantics(
          label: 'Was die Ringe bedeuten',
          button: true,
          excludeSemantics: true,
          child: GestureDetector(
            onTap: onHilfe,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ink.withValues(alpha: 0.06),
                shape: BoxShape.circle,
              ),
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: river,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Spalte extends StatelessWidget {
  const _Spalte({
    required this.spalte,
    required this.beschriftung,
    required this.onTap,
  });

  final RingSpalte spalte;

  /// In gemischter Schreibung übergeben; die Großschreibung macht die
  /// Karte, damit sie nicht in jedem Aufrufer steht.
  final String beschriftung;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SegmentRing(
            abschnitte: spalte.abschnitte,
            mitte: spalte.mitte,
            caption: spalte.caption,
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                beschriftung.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: muted,
                ),
              ),
              const SizedBox(width: 2),
              Icon(CupertinoIcons.chevron_right, size: 9, color: muted),
            ],
          ),
          Text(
            spalte.detail,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: ink),
          ),
        ],
      ),
    );
  }
}
