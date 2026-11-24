// Das Blatt über einer Übung — in **zwei Zuständen** (#534, #561;
// Nachtrag 29 der Spec `2026-11-19-eigene-trainings-design.md`; Entwurf
// `docs/screens/screens/gym-training-editor.js`, Varianten
// `uebung-einstellen` und `uebung-vorschau`):
//
// - **Zeilen-Weg** ([GymEditorEinstellBlatt]): Die Übung ist schon im
//   Training. Sätze, Wiederholungsbereich, Position, unten das
//   Bewegungsbild und **ganz am Ende** „Aus dem Training entfernen"
//   (Nachtrag 29 Nr. 3). „Fertig" und „Zurück" behalten die Übung.
// - **Vorschau** ([GymEditorVorschauBlatt]): Aus der Auswahl heraus, die
//   Übung ist **noch nicht** im Training. Dieselben Stellschrauben, dazu
//   das Bild — aber **keine Position und kein Entfernen**: Beides
//   behauptete, sie sei schon drin. Oben rechts „Speichern"; erst das
//   fügt sie mit den eingestellten Werten hinzu, „Zurück" verwirft.
//
// Die Erklärtexte stehen seit Nachtrag 29 Nr. 2 **nicht mehr** als Füße im
// Blatt, sondern hinter dem „?" in der Kopfzeile „Umfang" — auf beiden
// Wegen derselbe Text, gebaut mit [HilfeKopfzeile] aus der
// Entwurfsschicht, damit der nächste Schirm ihn übernehmen kann.
//
// Herausgelöst aus `gym_editor_blaetter.dart` (#559): Die Datei trug drei
// Blätter und ihre Bauteile und war über 900 Zeilen lang.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/hilfe_fragezeichen.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/typografie.dart';
import 'gym_bewegungsbild.dart';
import 'gym_editor_blatt_bausteine.dart';
import 'gym_editor_provider.dart';
import 'gym_editor_texte.dart';
import 'gym_training_editor_schluessel.dart';
import 'uebungsbilder_provider.dart';

/// Der Umfang einer Übung: Sätze und Wiederholungs- bzw. Sekundenbereich.
///
/// Ein Werttyp, kein Zustand: Die Vorschau hält ihn, solange die Übung noch
/// nicht im Training ist; der Zeilen-Weg liest ihn aus dem Editor-Stand.
/// So steht die Umfang-Karte **einmal** im Code und sieht auf beiden Wegen
/// gleich aus (`CLAUDE.md`, „Eine Anzeige hat genau eine Form").
@immutable
class GymEditorUmfang {
  const GymEditorUmfang({
    required this.saetze,
    required this.wdhVon,
    required this.wdhBis,
  });

  /// Die Vorbelegung aus der Bibliothek.
  GymEditorUmfang.ausKatalog(Exercise katalog)
    : saetze = katalog.sets,
      wdhVon = katalog.repLow,
      wdhBis = katalog.repHigh;

  final int saetze;
  final int wdhVon;
  final int wdhBis;

  /// Der Bereich bleibt geordnet: Wer die Untergrenze über die Obergrenze
  /// schiebt, schiebt die Obergrenze mit (und umgekehrt) — dieselbe Regel
  /// wie im Notifier.
  GymEditorUmfang mit({int? saetze, int? wdhVon, int? wdhBis}) {
    final von = wdhVon ?? this.wdhVon;
    final bis = wdhBis ?? this.wdhBis;
    return GymEditorUmfang(
      saetze: saetze ?? this.saetze,
      wdhVon: wdhVon != null && von > bis ? von : (von > bis ? bis : von),
      wdhBis: wdhBis != null && bis < von ? bis : (bis < von ? von : bis),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GymEditorUmfang &&
      other.saetze == saetze &&
      other.wdhVon == wdhVon &&
      other.wdhBis == wdhBis;

  @override
  int get hashCode => Object.hash(saetze, wdhVon, wdhBis);
}

/// Die Karte „Umfang" samt Kopfzeile mit „?" — auf beiden Wegen dieselbe.
class _UmfangAbschnitt extends StatelessWidget {
  const _UmfangAbschnitt({
    required this.katalog,
    required this.umfang,
    required this.onUmfang,
  });

  final Exercise katalog;
  final GymEditorUmfang umfang;
  final ValueChanged<GymEditorUmfang> onUmfang;

  @override
  Widget build(BuildContext context) {
    final zeit = katalog.isTimed;
    final grenze = zeit ? WorkoutRules.maxSeconds : WorkoutRules.maxReps;
    final schritt = zeit ? 5 : 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HilfeKopfzeile(
          titel: gymEditorBlattUmfang,
          modalTitel: gymEditorBlattHilfeTitel,
          absaetze: gymEditorBlattHilfeAbsaetze(katalog),
          vorlesetext: gymEditorBlattHilfeVorlesen,
          schliessen: gymEditorBlattHilfeSchliessen,
          hilfeSchluessel: kGymEditorBlattHilfe,
          modalSchluessel: kGymEditorBlattHilfeModal,
          schliessenSchluessel: kGymEditorBlattHilfeSchliessen,
        ),
        InsetCard(
          child: Column(
            children: [
              GymEditorStepperZeile(
                schluessel: kGymEditorBlattSaetze,
                label: gymEditorBlattSaetze,
                wert: umfang.saetze,
                min: 1,
                max: WorkoutRules.maxSets,
                onChanged: (v) => onUmfang(umfang.mit(saetze: v)),
              ),
              const GymEditorBlattTrenner(),
              GymEditorStepperZeile(
                schluessel: kGymEditorBlattWdhVon,
                label:
                    '${zeit ? gymEditorBlattSekunden : gymEditorBlattWiederholungen} $gymEditorBlattVon',
                wert: umfang.wdhVon,
                min: 1,
                max: grenze,
                schritt: schritt,
                onChanged: (v) => onUmfang(umfang.mit(wdhVon: v)),
              ),
              const GymEditorBlattTrenner(),
              GymEditorStepperZeile(
                schluessel: kGymEditorBlattWdhBis,
                label: gymEditorBlattBis,
                wert: umfang.wdhBis,
                min: 1,
                max: grenze,
                schritt: schritt,
                onChanged: (v) => onUmfang(umfang.mit(wdhBis: v)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Das Bewegungsbild unten im Blatt — **nur wenn es eines gibt**, sonst
/// nichts und kein Platzhalter (Spec 28 Nr. 2).
class _BildAbschnitt extends ConsumerWidget {
  const _BildAbschnitt(this.katalog);

  final Exercise katalog;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hatBild = ref.watch(uebungsbilderProvider).fuer(katalog.id) != null;
    if (!hatBild) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: GymBewegungsbild(uebung: katalog),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Vorschau (aus der Auswahl)
// ─────────────────────────────────────────────────────────────────────────

/// Die **Vorschau** einer Übung, die noch nicht im Training ist
/// (Nachtrag 29 Nr. 1, Tim: „Wenn ich sie andrücke, ist sie schon drin,
/// obwohl ich sie mir erst mal anschauen wollte").
///
/// Der eingestellte Umfang lebt **hier**, nicht im Editor-Stand: Vor dem
/// „Speichern" hat die Übung im Training nichts verloren. „Zurück" oder
/// Zuziehen verwirft ihn mitsamt der Übung.
class GymEditorVorschauBlatt extends ConsumerStatefulWidget {
  const GymEditorVorschauBlatt({
    super.key,
    required this.quelle,
    required this.uebungId,
  });

  final GymEditorQuelle quelle;
  final String uebungId;

  @override
  ConsumerState<GymEditorVorschauBlatt> createState() => _VorschauZustand();
}

class _VorschauZustand extends ConsumerState<GymEditorVorschauBlatt> {
  late final Exercise? _katalog = ExerciseLibrary.byId(widget.uebungId);
  late GymEditorUmfang _umfang = _katalog == null
      ? const GymEditorUmfang(saetze: 1, wdhVon: 1, wdhBis: 1)
      : GymEditorUmfang.ausKatalog(_katalog);

  void _speichere() {
    final notifier = ref.read(gymEditorProvider(widget.quelle).notifier);
    // Erst hinzufügen (vorbelegt aus der Bibliothek), dann die eingestellten
    // Werte setzen: Der Notifier ist die eine Stelle, die den Stand ändert.
    notifier
      ..fuegeUebungHinzu(widget.uebungId)
      ..setzeUmfang(
        widget.uebungId,
        saetze: _umfang.saetze,
        wdhVon: _umfang.wdhVon,
        wdhBis: _umfang.wdhBis,
      );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final katalog = _katalog;
    if (katalog == null) {
      // Eine Übung, die die Bibliothek nicht kennt, lässt sich nicht
      // ansehen — das Blatt steht leer da und schließt über „Zurück".
      return GymEditorBlattRahmen(
        key: kGymEditorBlatt,
        titel: '',
        lead: gymEditorBlattZurueck,
        leadSchluessel: kGymEditorBlattZurueck,
        trail: null,
        child: const SizedBox.shrink(),
      );
    }

    return GymEditorBlattRahmen(
      key: kGymEditorBlatt,
      titel: katalog.name,
      lead: gymEditorBlattZurueck,
      leadSchluessel: kGymEditorBlattZurueck,
      trail: gymEditorBlattSpeichern,
      trailSchluessel: kGymEditorBlattSpeichern,
      trailAktion: _speichere,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UmfangAbschnitt(
              katalog: katalog,
              umfang: _umfang,
              onUmfang: (u) => setState(() => _umfang = u),
            ),
            _BildAbschnitt(katalog),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Einstellblatt (über die Übungszeile)
// ─────────────────────────────────────────────────────────────────────────

/// Das Blatt hinter einer Übungszeile: Sätze, Wiederholungsbereich,
/// Position, unten das Bewegungsbild und **ganz am Ende** „Aus dem Training
/// entfernen" (Nachtrag 29 Nr. 3).
///
/// „Zurück" und „Fertig" behalten die Übung (Spec 28, Folgerung);
/// zurückgenommen wird nur über „Entfernen". Wer aus der **Auswahl** kommt,
/// bekommt stattdessen [GymEditorVorschauBlatt].
class GymEditorEinstellBlatt extends ConsumerWidget {
  const GymEditorEinstellBlatt({
    super.key,
    required this.quelle,
    required this.uebungId,
  });

  final GymEditorQuelle quelle;
  final String uebungId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uebungen = ref.watch(
      gymEditorProvider(quelle).select((s) => s.uebungen),
    );
    final notifier = ref.read(gymEditorProvider(quelle).notifier);
    final index = uebungen.indexWhere((e) => e.exerciseId == uebungId);
    final katalog = ExerciseLibrary.byId(uebungId);
    if (index < 0 || katalog == null) {
      // Die Übung ist (gerade) herausgenommen: Das Blatt schließt.
      return GymEditorBlattRahmen(
        key: kGymEditorBlatt,
        titel: katalog?.name ?? '',
        lead: gymEditorBlattZurueck,
        leadSchluessel: kGymEditorBlattZurueck,
        trail: gymEditorBlattFertig,
        trailSchluessel: kGymEditorBlattFertig,
        child: const SizedBox.shrink(),
      );
    }
    final e = uebungen[index];
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);

    return GymEditorBlattRahmen(
      key: kGymEditorBlatt,
      titel: katalog.name,
      lead: gymEditorBlattZurueck,
      leadSchluessel: kGymEditorBlattZurueck,
      trail: gymEditorBlattFertig,
      trailSchluessel: kGymEditorBlattFertig,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UmfangAbschnitt(
              katalog: katalog,
              umfang: GymEditorUmfang(
                saetze: e.sets,
                wdhVon: e.repLow,
                wdhBis: e.repHigh,
              ),
              onUmfang: (u) => notifier.setzeUmfang(
                uebungId,
                saetze: u.saetze,
                wdhVon: u.wdhVon,
                wdhBis: u.wdhBis,
              ),
            ),
            const GymEditorBlattKapitel(gymEditorBlattPosition),
            InsetCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 4,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          gymEditorBlattImTraining,
                          style: TextStyle(fontSize: 15, color: ink),
                        ),
                      ),
                      CupertinoButton(
                        key: kGymEditorBlattHoch,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: index > 0
                            ? () => notifier.verschiebeUebung(index, index - 1)
                            : null,
                        child: Semantics(
                          label: gymEditorNachOben,
                          child: const Text(
                            '↑',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                      Semantics(
                        label: 'Übung ${index + 1} von ${uebungen.length}',
                        excludeSemantics: true,
                        child: Text(
                          gymEditorBlattPositionText(
                            index + 1,
                            uebungen.length,
                          ),
                          key: kGymEditorBlattPosition,
                          style: Typografie.tabularNumbers(
                            TextStyle(fontSize: 15, color: ink),
                          ),
                        ),
                      ),
                      CupertinoButton(
                        key: kGymEditorBlattRunter,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(44, 44),
                        onPressed: index < uebungen.length - 1
                            ? () => notifier.verschiebeUebung(index, index + 1)
                            : null,
                        child: Semantics(
                          label: gymEditorNachUnten,
                          child: const Text(
                            '↓',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _BildAbschnitt(katalog),
            // „Aus dem Training entfernen" steht **ganz unten, unter dem
            // Bild** (Nachtrag 29 Nr. 3, Tim am 23.11.2026) — vorher stand
            // das Bild darunter. Der erklärende Fuß ist ins Hilfe-Modal
            // gezogen (Nr. 2).
            const SizedBox(height: 18),
            InsetCard(
              child: CupertinoButton(
                key: kGymEditorBlattEntfernen,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: () {
                  notifier.entferneUebung(uebungId);
                  Navigator.of(context).pop();
                },
                child: Text(
                  gymEditorBlattEntfernen,
                  style: TextStyle(fontSize: 15, color: warn),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
