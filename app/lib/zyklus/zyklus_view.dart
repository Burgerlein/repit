// Der Schirm „Zyklus" — der Kalender (#571 unter #539).
//
// API und Verhalten sind durch `app/test/zyklus/zyklus_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/zyklus.js`: Monat, Legende, Lage, Tür.
// Spec: `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte 3, 5.1
// und 7.
//
// **Der Schirm rechnet nichts.** Jede Zelle kommt fertig aus
// `zyklusMonatProvider` (Hausregel 2); hier liegt nur, was der Nutzerin
// gerade gehört: welcher Monat aufgeschlagen ist.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hilfe.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../health/health_provider.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'zyklus_einrichten_view.dart';
import 'zyklus_raster.dart';
import 'zyklus_tag_view.dart';
import 'zyklus_texte.dart';
import 'zyklus_zustand.dart';

/// Öffnet den Kalender auf dem Stapel des **aktuell gewählten** Tabs — die
/// eine Stelle, die das weiß. Von hier ruft später `MehrView` (#573), und
/// nur, wenn der Kalender eingeschaltet ist ([zyklusAnProvider]).
void oeffneZyklus(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => ZyklusSeite(router: router)));

/// **Kein eigener `Navigator`:** Dieser Schirm wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
class ZyklusSeite extends ConsumerStatefulWidget {
  const ZyklusSeite({super.key, required this.router});

  /// Derselbe Router, über den der Schirm geöffnet wurde — jeder Tag ist
  /// eine Tür, und die Türen laufen über `AppRouter`, nicht über
  /// `Navigator` im Schirm (`CLAUDE.md`).
  final AppRouter router;

  @override
  ConsumerState<ZyklusSeite> createState() => _ZyklusSeitenZustand();
}

class _ZyklusSeitenZustand extends ConsumerState<ZyklusSeite> {
  /// Der aufgeschlagene Monat als `JJJJ-MM`. **Aus der Uhr der App**, nie
  /// `DateTime.now()` — sonst wäre der Schirm nicht prüfbar.
  late String _monat = BerlinCalendar.dayKey(ref.read(heutigerTagProvider))
      .substring(0, 7);

  @override
  Widget build(BuildContext context) {
    final heute = BerlinCalendar.dayKey(ref.watch(heutigerTagProvider));
    final stand = ref.watch(zyklusMonatProvider(_monat));
    final lage = ref.watch(zyklusLageProvider);

    return CupertinoPageScaffold(
      key: const Key('zyklus'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(zyklusTitel),
        // Das Zahnrad steht im Entwurf in **jeder** Variante des
        // Kalenders (`zyklus.js`, `chrome.trailing`); es fehlte hier
        // nur, solange es den Schirm dahinter nicht gab (#573).
        trailing: CupertinoButton(
          key: const Key('zyklus-zahnrad'),
          padding: EdgeInsets.zero,
          minimumSize: const Size.square(44),
          onPressed: () => oeffneZyklusEinrichten(widget.router),
          child: Semantics(
            button: true,
            label: zyklusEinrichtenZeile,
            child: const Icon(CupertinoIcons.gear, size: 22),
          ),
        ),
      ),
      // **`Builder`, damit der Abstand unter der Leiste stimmt:**
      // `CupertinoPageScaffold` schreibt die Höhe seiner durchscheinenden
      // Navigationsleiste in die `MediaQuery` seines **Kindes**. Wer
      // `GlasAbstand.of` mit dem Kontext des Schirms selbst fragt, bekommt
      // den Stand von darüber — und dann liegt die erste Zeile unter der
      // Leiste, samt Blätterpfeilen, die sich nicht antippen lassen.
      child: Builder(
        builder: (context) => SingleChildScrollView(
          padding: GlasAbstand.of(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ZyklusMonat(
                monat: stand.titel,
                vorlauf: stand.vorlauf,
                tage: stand.tage,
                blaesse: stand.blaesse,
                aufTipp: _oeffneTag,
                // **Beide Pfeile sind immer an** (#601). Der
                // Vorwärtspfeil hing bis zum 24.11.2026 an der
                // Vorhersage und war ohne sie aus — wer
                // zurückblätterte, kam nicht mehr in den aktuellen
                // Monat. Blättern hängt an der Stelle im Kalender,
                // nicht daran, ob im Zielmonat etwas zu sehen ist: Ein
                // leerer Monat ist kein Grund, den Weg zu versperren,
                // die Zellen stehen da und lassen sich füllen.
                aufFrueher: () => _blaettere(-1),
                aufSpaeter: () => _blaettere(1),
              ),
              const ZyklusLegende(key: Key('zyklus-legende')),
              // **Unter der Legende, nicht über dem Raster** (Tim,
              // 23.11.2026): Oben drängte sich die Zeile vor das Bild, um
              // das es geht, und schob das Raster nach unten.
              if (lage != null) _lagezeile(lage),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: InsetCard(child: _tuer(heute)),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  /// Die Zeile am Fuß — was man täglich tut, steht unten und ist mit dem
  /// Daumen erreichbar (Tim, 23.11.2026).
  ///
  /// Sie heißt **immer** „Heute eintragen" und öffnet immer heute. Bis
  /// zum 24.11.2026 nannte sie den zuletzt angetippten Tag; dafür musste
  /// der Schirm sich einen merken, und der trug im Raster einen Ring, den
  /// nichts wieder aufhob (#603). Gebraucht wurde beides nie: Ein Tipp
  /// auf einen Tag öffnet dessen Eintragen unmittelbar, also kommt
  /// niemand in die Lage, hier den falschen Tag zu erwischen.
  Widget _tuer(String heute) => IconRow(
    key: const Key('zyklus-eintragen'),
    symbol: 'plus.circle',
    accent: CupertinoDynamicColor.resolve(Palette.blut, context),
    title: zyklusEintragenTitel,
    subtitle: zyklusEintragenUnterzeile,
    onTap: () => oeffneZyklusTag(widget.router, tag: heute),
  );

  Widget _lagezeile(ZyklusLage lage) => switch (lage) {
    ZyklusLageKeineVorhersage() => const LageZeile(
      key: Key('zyklus-lage'),
      unten: true,
      leitwort: zyklusKeineVorhersage,
      text: zyklusKeineVorhersageGrund,
    ),
    ZyklusLagePausiert(:final seit) => LageZeile(
      key: const Key('zyklus-lage'),
      unten: true,
      leitwort: zyklusPausiertLeitwort,
      text: zyklusPausiertText(
        Format.tagMonatAusgeschrieben(datumZumAnzeigen(seit)),
      ),
    ),
  };

  /// **Jeder** Tag ist eine Tür, nicht nur heute — so trägt man nach, was
  /// man gestern vergessen hat (Tim, 23.11.2026).
  ///
  /// Der Tipp öffnet nur; er **wählt nichts aus**. Die Methode hieß bis
  /// zum 24.11.2026 `_waehle` und setzte zusätzlich einen Ring, den
  /// nichts wieder aufhob (#603) — ein Zustand ohne Ausweg.
  void _oeffneTag(String tag) => oeffneZyklusTag(widget.router, tag: tag);

  /// Ein Monat, geblättert — nicht ein endloser Streifen (Entwurf): Die
  /// Vorhersage reicht ohnehin nur einen Zyklus weit.
  void _blaettere(int schritte) {
    final jahr = int.parse(_monat.substring(0, 4));
    final nummer = int.parse(_monat.substring(5, 7));
    final neu = DateTime.utc(jahr, nummer + schritte);
    setState(
      () => _monat =
          '${neu.year.toString().padLeft(4, '0')}-'
          '${neu.month.toString().padLeft(2, '0')}',
    );
  }
}
