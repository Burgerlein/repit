// Der Schirm „Aufteilung" (#433 unter #374): wie sich das feste Tagesziel
// auf Frühstück, Mittag, Abend und Snack verteilt.
//
// Zustände und Übergänge sind durch `app/test/ernaehrung/aufteilung_view_test
// .dart` vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`). Gebaut nach `docs/screens/screens/aufteilung.js`
// (Zustände `startwert`, `geaendert`, `ohne-ziel`) und der Spec
// `docs/superpowers/specs/2026-11-10-mahlzeiten-aufteilung-design.md`,
// Abschnitt „Der Schirm „Aufteilung"", V13.
//
// **Eine Einstellung, keine Empfehlung** (`CLAUDE.md`, „Keine Diagnosen").
// Der Startwert 25 · 35 · 30 · 10 steht nur im Formular. Er gilt erst, wenn
// Tim sichert (Entscheidung 1); bis dahin hat keine Mahlzeit ein Ziel. Wer
// ihn ab Werk gelten lässt, bricht den Hinweis oben auf dem Schirm.
//
// **Zweite Tabellengruppe: `Messwert<T>` gilt hier nicht.** Die Aufteilung
// ist Tims eigene Einstellung, leer heißt leer.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/mahlzeit_aufteilungen.dart';
import '../design/glas_abstand.dart';
import '../design/grosse_ueberschrift.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/zahlen.dart';
import '../health/health_provider.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'ernaehrung_abschnitte.dart' show mahlzeitName, mahlzeitSymbol;
import 'ernaehrung_provider.dart';

/// Öffnet `aufteilung` auf dem Stapel des **aktuell gewählten** Tabs —
/// `AppTarget.aktuell`, nie ein Tabwechsel (`CLAUDE.md`).
void oeffneAufteilung(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const AufteilungSeite()));

/// Der Rahmen: Gerüst und Navigationsleiste um [AufteilungView]. **Kein
/// eigener `Navigator`** — den stellt `RootView`.
class AufteilungSeite extends StatelessWidget {
  const AufteilungSeite({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Aufteilung')),
      child: const AufteilungView(),
    );
  }
}

/// Die Reihenfolge auf dem Schirm (V8): Snack zuletzt, als Rest.
const _reihenfolge = [
  Mahlzeit.fruehstueck,
  Mahlzeit.mittag,
  Mahlzeit.abend,
  Mahlzeit.snack,
];

/// Der Schirm selbst. **Er besorgt seine Daten selbst**:
/// [mahlzeitAufteilungenProvider] für die Historie und
/// [ernaehrungsTagProvider] von heute für das Tagesziel (V5).
class AufteilungView extends ConsumerStatefulWidget {
  const AufteilungView({super.key});

  @override
  ConsumerState<AufteilungView> createState() => _AufteilungZustand();
}

class _AufteilungZustand extends ConsumerState<AufteilungView> {
  /// Was im Formular steht. `null`, solange die Historie nicht gelesen ist —
  /// dann steht dort eine graue Form, **nicht** der Startwert, der sähe aus
  /// wie eine gesicherte Aufteilung.
  MahlzeitAufteilung? _formular;

  bool _laeuft = false;

  @override
  Widget build(BuildContext context) {
    final heute = BerlinCalendar.dayKey(ref.watch(clockProvider)());
    final historie = ref.watch(mahlzeitAufteilungenProvider);
    final tag = ref.watch(ernaehrungsTagProvider(heute));

    // Die heute geltende, nicht „die letzte" (Entscheidung 5, V13).
    final geltend = historie.hasValue
        ? geltendeAufteilung(historie.value!, heute)
        : null;
    // Die Vorbelegung kommt **genau einmal**. Danach gehört das Formular
    // Tim: Ein späteres Lesen der Historie überschriebe sonst seine Eingabe.
    if (_formular == null && historie.hasValue) {
      _formular = geltend ?? MahlzeitAufteilung.startwert;
    }
    final formular = _formular;

    final tagesziel = tag.zielLaedt ? null : tag.zielKcal;
    final sichernAktiv =
        formular != null &&
        !_laeuft &&
        (geltend == null || geltend != formular);

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GrosseUeberschrift(
            'Aufteilung',
            einordnung: 'Kalorienziel je Mahlzeit',
          ),
          const _Hinweis(),
          SectionHeader(
            tag.zielLaedt
                ? 'Anteil am Tagesziel'
                : 'Anteil am Tagesziel · '
                      '${tagesziel == null ? ohneWert : formatNumber(tagesziel)}'
                      ' kcal',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: InsetCard(
              child: Column(
                children: [
                  for (final m in _reihenfolge) ...[
                    if (m != _reihenfolge.first) const _Trennlinie(),
                    _AnteilZeile(
                      mahlzeit: m,
                      formular: formular,
                      tagesziel: tagesziel,
                      zielLaedt: tag.zielLaedt,
                      beiMinus: () =>
                          setState(() => _formular = formular!.minus(m)),
                      beiPlus: () =>
                          setState(() => _formular = formular!.plus(m)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
            child: CupertinoButton.filled(
              key: const Key('aufteilung-sichern'),
              onPressed: sichernAktiv ? () => _sichere(formular) : null,
              child: const Text('Sichern'),
            ),
          ),
          // Erscheint, sobald das Formular vom Startwert abweicht, und
          // ändert nur das Formular (V13) — gesichert wird erst mit
          // „Sichern".
          if (formular != null && formular != MahlzeitAufteilung.startwert)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: CupertinoButton.tinted(
                key: const Key('aufteilung-zuruecksetzen'),
                onPressed: () =>
                    setState(() => _formular = MahlzeitAufteilung.startwert),
                child: const Text('Auf 25 · 35 · 30 · 10 zurücksetzen'),
              ),
            ),
          const Hinweisfuss(
            'Das Ziel je Mahlzeit ist dein Kalorienziel, aufgeteilt nach '
            'diesen Anteilen. Es ändert nichts am Tagesziel und ist keine '
            'Ernährungsberatung. Eine neue Aufteilung gilt ab heute; frühere '
            'Tage behalten ihre.',
          ),
        ],
      ),
    );
  }

  /// Sichert ab heute (V2). Der Schirm bleibt danach stehen, wie
  /// „Vorläufige Werte" (V13).
  Future<void> _sichere(MahlzeitAufteilung a) async {
    setState(() => _laeuft = true);
    // Vor dem ersten `await` gelesen — danach kann der Schirm schon weg sein.
    final notifier = ref.read(mahlzeitAufteilungenProvider.notifier);
    try {
      await notifier.setzeAbHeute(a);
    } finally {
      if (mounted) setState(() => _laeuft = false);
    }
  }
}

/// Eine Zeile der Karte — `anteilZeile` aus `docs/screens/components.js`:
/// Symbol, Name über kcal, rechts − Prozent +. Die Snackzeile trägt „Rest"
/// statt der Knöpfe (Entscheidung 2).
class _AnteilZeile extends StatelessWidget {
  const _AnteilZeile({
    required this.mahlzeit,
    required this.formular,
    required this.tagesziel,
    required this.zielLaedt,
    required this.beiMinus,
    required this.beiPlus,
  });

  final Mahlzeit mahlzeit;
  final MahlzeitAufteilung? formular;
  final double? tagesziel;
  final bool zielLaedt;
  final VoidCallback beiMinus;
  final VoidCallback beiPlus;

  bool get _istRest => mahlzeit == Mahlzeit.snack;

  /// Die kcal dieser Mahlzeit bei [tagesziel]. Eine Mahlzeit mit 0 % hat
  /// kein Ziel (V4) — hier steht trotzdem „0 kcal", denn das Formular
  /// zeigt, was der Anteil vom Tagesziel **ist**, und das ist bei 0 % eine
  /// gelesene Null, kein fehlender Wert (so zeichnet es `aufteilung.js`).
  double? get _kcal {
    final f = formular;
    final ziel = tagesziel;
    if (f == null || ziel == null || ziel <= 0) return null;
    return mahlzeitZielKcal(
          tageszielKcal: ziel,
          aufteilung: f,
          mahlzeit: mahlzeit,
        ) ??
        0;
  }

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final f = formular;
    final name = mahlzeitName(mahlzeit);
    final kcal = _kcal;
    final prozent = f?.prozent(mahlzeit);

    const kcalStil = TextStyle(fontSize: 13);
    final prozentStil = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      color: _istRest ? muted : ink,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final kcalAnzeige = KeyedSubtree(
      key: Key('aufteilung-kcal-${mahlzeit.name}'),
      child: zielLaedt || (f == null && tagesziel != null)
          ? Platzhalter(beispiel: '630 kcal', stil: kcalStil)
          : Text(
              kcal == null ? '$ohneWert kcal' : '${formatNumber(kcal)} kcal',
              style: kcalStil.copyWith(color: muted),
            ),
    );

    final prozentAnzeige = SizedBox(
      width: 52,
      child: Center(
        child: KeyedSubtree(
          key: Key('aufteilung-prozent-${mahlzeit.name}'),
          child: prozent == null
              ? Platzhalter(beispiel: '35 %', stil: prozentStil)
              : Text('$prozent %', style: prozentStil),
        ),
      ),
    );

    // Der Vorlesetext nennt den Zustand, nicht das Zeichen (`CLAUDE.md`).
    final vorlesen = [
      name,
      if (_istRest) 'Rest',
      prozent == null ? 'wird geladen' : '$prozent Prozent',
      if (!zielLaedt && prozent != null)
        kcal == null ? 'keine Werte' : '${formatNumber(kcal)} Kilokalorien',
    ].join(', ');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              label: vorlesen,
              excludeSemantics: true,
              child: Row(
                children: [
                  SizedBox(
                    width: 28,
                    child: Text(
                      mahlzeitSymbol(mahlzeit),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 21),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        kcalAnzeige,
                      ],
                    ),
                  ),
                  if (_istRest) ...[
                    _RestMarke(farbe: muted),
                    const SizedBox(width: 10),
                    ExcludeSemantics(child: prozentAnzeige),
                    // Die Breite des „+", damit die Prozentzahl des Rests
                    // unter denen der anderen Zeilen steht.
                    const SizedBox(width: 44),
                  ],
                ],
              ),
            ),
          ),
          if (!_istRest) ...[
            _Knopf(
              schluessel: Key('aufteilung-minus-${mahlzeit.name}'),
              zeichen: '−',
              vorlesen: '$name, weniger',
              beiTipp: f != null && f.kannMinus(mahlzeit) ? beiMinus : null,
            ),
            ExcludeSemantics(child: prozentAnzeige),
            _Knopf(
              schluessel: Key('aufteilung-plus-${mahlzeit.name}'),
              zeichen: '+',
              vorlesen: '$name, mehr',
              beiTipp: f != null && f.kannPlus(mahlzeit) ? beiPlus : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Ein runder Knopf, 30 pt, wie `.anteil .k` im Entwurf. Gesperrt ist er
/// blass und als gesperrt angesagt (`onPressed == null`).
class _Knopf extends StatelessWidget {
  const _Knopf({
    required this.schluessel,
    required this.zeichen,
    required this.vorlesen,
    required this.beiTipp,
  });

  final Key schluessel;
  final String zeichen;
  final String vorlesen;
  final VoidCallback? beiTipp;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final aus = beiTipp == null;

    return Semantics(
      label: vorlesen,
      child: CupertinoButton(
        key: schluessel,
        padding: EdgeInsets.zero,
        // 44 pt Trefferfläche um den 30-pt-Kreis.
        minimumSize: const Size(44, 44),
        onPressed: beiTipp,
        child: Opacity(
          opacity: aus ? 0.45 : 1,
          child: Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: ink.withValues(alpha: 0.06),
              shape: BoxShape.circle,
            ),
            child: ExcludeSemantics(
              child: Text(
                zeichen,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: aus ? muted : river,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// „Rest" als kleine Pille — `.anteil .r` im Entwurf.
class _RestMarke extends StatelessWidget {
  const _RestMarke({required this.farbe});

  final Color farbe;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Text('Rest', style: TextStyle(fontSize: 12, color: farbe)),
      ),
    );
  }
}

class _Trennlinie extends StatelessWidget {
  const _Trennlinie();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Container(
      height: 0.5,
      color: CupertinoDynamicColor.resolve(Palette.line, context),
    ),
  );
}

/// „Eine Einstellung, keine Empfehlung …" — `noteBox('neutral', …)` aus
/// dem Entwurf. **Steht immer**, auch nach dem Sichern: Er gilt für jede
/// Zahl auf dem Schirm.
class _Hinweis extends StatelessWidget {
  const _Hinweis();

  @override
  Widget build(BuildContext context) {
    final ton = CupertinoDynamicColor.resolve(Palette.bib, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ton.withValues(alpha: 0.10),
            border: Border(left: BorderSide(color: ton, width: 3)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
            child: Text(
              'Eine Einstellung, keine Empfehlung: Wie du dein Tagesziel auf '
              'die Mahlzeiten verteilst, entscheidest du. 25 · 35 · 30 · 10 '
              'ist nur ein Startwert zum Anpassen.',
              style: TextStyle(fontSize: 13, height: 1.35, color: ink),
            ),
          ),
        ),
      ),
    );
  }
}
