// Der Schirm `messungen` (#85) — was die Waage liefert (Gewicht,
// Körperfett, Muskel- beziehungsweise fettfreie Masse) plus Ruhepuls. Die
// Zahlen kommen aus `koerper_zustand.dart`, demselben Zustand wie
// `koerper`: zwei Anordnungen, eine Rechnung.
//
// API und Verhalten sind durch `app/test/shell/messungen_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/messungen.js`: „Aktuell und Trend" mit
// vier Verlaufskarten → Einordnungssatz zum Gewichtstrend → „Eiweiß pro
// Tag" → „Letzte Messungen" → Fußnote.
//
// **Der Trend ist hier wichtiger als der Wert:** Eine einzelne Wägung
// schwankt um ein Kilo, der Wochentrend nicht. Deshalb steht unter jedem
// Wert die Einordnung und nicht nur eine Zahl mit Pfeil.
//
// **Keine Zeitleiste auf diesem Schirm.** Sie sitzt auf dem Detailschirm —
// die eine begründete Abweichung von `MeasurementsView.swift:12–13`: Vier
// volle Diagramme untereinander wären vier Fußnoten und vier Achsen auf
// einem Schirm, durch den man scrollt (Spec, Teil D).
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/inset_card.dart';
import '../design/kacheln.dart' show Verlaufslinie;
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/section_header.dart';
import '../design/typografie.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import 'gewicht_eintragen.dart';
import 'mess_abschnitte.dart';
import 'koerper_zustand.dart';
import 'messung_detail_view.dart';
import 'router.dart';
import 'ziele.dart';

/// Öffnet Messungen auf dem Stapel des **aktuell gewählten** Tabs —
/// gerufen aus der Bereiche-Zeile „Messungen" auf `koerper`.
void oeffneMessungen(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => MessungenSeite(router: router)));

/// Der Rahmen: Gerüst und Navigationsleiste um [MessungenView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
class MessungenSeite extends StatelessWidget {
  const MessungenSeite({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(middle: Text('Messungen')),
      child: MessungenView(router: router),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
class MessungenView extends ConsumerWidget {
  const MessungenView({super.key, required this.router});

  final AppRouter router;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messwert = ref.watch(koerperWerteProvider);
    // Die Zeilen von „Letzte Messungen" kommen **nicht** aus den
    // Tageswerten, sondern aus den einzelnen Proben: Eine Statistik trägt
    // weder Uhrzeit noch Kennzeichen noch UUID, und alle drei braucht die
    // Liste (#270).
    final proben = ref.watch(gewichtsReiheProvider);
    final lage = messLageAus(messwert);
    final werte = messwert is Bekannt<KoerperWerte> ? messwert.wert : null;

    // Der Grund steht **einmal, oben** — nicht viermal in der Karte
    // (`messungen.js`, Variante „leer"). Während des Laufs steht er gar
    // nicht da (Fehler `01`), und nach einem Fehler auch nicht: Der sagt
    // nichts über die Datenlage.
    final ohneWaegung = werte == null || werte.gewicht.wert == null;
    final grundZeigen =
        ohneWaegung && (lage == MessLage.werte || lage == MessLage.leer);

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LageZeile(
            key: switch (lage) {
              MessLage.laedt => const Key('messungen-laden'),
              MessLage.fehler => const Key('messungen-fehler'),
              MessLage.werte || MessLage.leer => null,
            },
            lage: lage,
            stand: standAus(messwert),
            laeuft: messwert is Bekannt<KoerperWerte> && messwert.laeuft,
          ),
          if (grundZeigen)
            const Notizflaeche(
              key: Key('messungen-grund'),
              // Der Zusatz steht nur hier und nicht in `waagenGrund` selbst:
              // Die Konstante teilt sich mit `messung_detail_view`, und dort
              // gibt es keinen Weg zum Eintragen.
              text: '$waagenGrund Ein Gewicht von Hand einzutragen geht auch '
                  'ohne Waage.',
            ),
          const SectionHeader('Aktuell und Trend'),
          for (final art in MessArt.values)
            _Verlaufskarte(
              key: Key('messungen-karte-${art.name}'),
              art: art,
              lage: lage,
              werte: werte,
              onTap: () => oeffneMessungDetail(router, art),
            ),
          Notizflaeche(
            key: const Key('messungen-einordnung'),
            text: _einordnungssatz(lage, werte),
            // Feste Zeilenzahl: Derselbe Kasten trägt mal den Trendsatz und
            // mal „zu wenige Wägungen" — ohne Reservierung wüchse der
            // Schirm genau dann, wenn Werte fehlen (#24).
            zeilen: 3,
            ton: _einordnungsTon(werte?.trendEinordnung),
            oben: 16,
            // Beim Laden und nach einem gescheiterten Lauf gibt es keinen
            // Satz — dann stehen graue Balken da, nicht eine leere Karte
            // mit farbiger Kante.
            platzhalter:
                lage == MessLage.laedt || lage == MessLage.fehler,
          ),
          const SectionHeader('Eiweiß pro Tag'),
          MessKarte(
            key: const Key('messungen-eiweiss'),
            zeilen: [
              zeileMitLage(
                lage,
                schluessel: const Key('messungen-eiweiss-ziel'),
                name: 'Ziel aus dem Gewicht',
                // Ohne Wägung gibt es kein Ziel — und „0 g Eiweiß" wäre ein
                // Rat, den niemand gegeben hat.
                wert: werte?.eiweissZiel == null
                    ? ohneEinzelwert
                    : '${werte!.eiweissZiel!.$1}–${werte.eiweissZiel!.$2} g',
                beispiel: '000–000 g',
              ),
              // Die Rechnung hängt an keiner Messung und steht in jeder
              // Lage gleich da — in der Schreibweise des Entwurfs
              // (`messungen.js`).
              const MessZeileDaten(
                name: 'Rechnung',
                wert: '1,6–2,0 g pro kg',
              ),
            ],
          ),
          SectionHeader(
            'Letzte Messungen',
            zusatz: 'Eintragen',
            zusatzSchluessel: const Key('messungen-eintragen'),
            // **Hängt nicht an Daten.** „Eintragen" steht auch dann da,
            // wenn es keine Wägung gibt und während gelesen wird — gerade
            // dann will man eine eintragen.
            aufZusatz: () => zeigeGewichtEintragen(context),
          ),
          MessKarte(
            key: const Key('messungen-letzte'),
            zeilen: _letzteMessungen(context, proben, werte),
          ),
          const Hinweisfuss(
            'Werte kommen von der Waage über Apple Health, der Ruhepuls von '
            'der Uhr. Was du selbst einträgst, schreibt die App dorthin '
            'zurück und liest es von dort wieder. Ältere Werte holst du '
            'über Mehr › Daten übernehmen. Alles Schätzungen, keine '
            'medizinische Bewertung.',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Die vier Verlaufskarten
// ─────────────────────────────────────────────────────────────────────────

/// Name, Wert, Trendsatz, Kurve — `trendCard` aus
/// `docs/screens/components.js`.
///
/// **Die ganze Karte ist die Tür** (`messungen.js`, Nachtrag vom
/// 02.11.2026: „wenn ich auf einen der graphen drauf gehe kommt eine detail
/// ansicht"), und sie bleibt eine, auch wenn der Wert fehlt: Eine fehlende
/// Tür sieht aus wie eine Funktion, die es nicht gibt — und der
/// Detailschirm hat seine eigene Leeransicht.
///
/// **Die leere Karte hat dieselbe Höhe wie die gefüllte.** An der Stelle
/// der Kurve steht dann eine graue Fläche (`.sparkleer` im Entwurf), der
/// Trendsatz bekommt eine feste Zeile.
class _Verlaufskarte extends StatelessWidget {
  const _Verlaufskarte({
    super.key,
    required this.art,
    required this.lage,
    required this.werte,
    required this.onTap,
  });

  final MessArt art;
  final MessLage lage;
  final KoerperWerte? werte;
  final VoidCallback onTap;

  static const double _kurvenHoehe = 26;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final fill = ink.withValues(alpha: 0.06);
    final stand = werte?.stand(art);
    final wert = stand?.wert;
    final reihe = [
      for (final punkt in stand?.reihe ?? const <MeasurementPoint>[])
        punkt.value,
    ];
    final trendStil = TextStyle(fontSize: 12.5, color: muted);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        // Der Vorlesetext nennt den Zustand, nicht das Zeichen.
        label: wert == null
            ? '${messName(art)}, ${lage == MessLage.laedt ? 'wird geladen' : 'keine Werte'}'
            : '${messName(art)}, ${messWert(art, wert)}',
        button: true,
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: InsetCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          messName(art),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _Wert(art: art, lage: lage, wert: wert),
                      const SizedBox(width: 8),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 13,
                        color: muted.withValues(alpha: 0.7),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: FesteZeilen(
                      zeilen: 1,
                      stil: trendStil,
                      child: Text(
                        _trendsatz(art, lage, werte),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: trendStil,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: SizedBox(
                      height: _kurvenHoehe,
                      // Dieselbe Höhe mit und ohne Kurve: Fehlt sie, steht
                      // die graue Fläche an ihrer Stelle, statt dass die
                      // Karte zusammenfällt.
                      child: reihe.length < 2
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                color: fill,
                                borderRadius: BorderRadius.circular(6),
                              ),
                            )
                          : Verlaufslinie(
                              werte: reihe,
                              farbe: CupertinoDynamicColor.resolve(
                                _farbe(art),
                                context,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Die große Zahl mit ihrer Einheit — im Ladezustand die graue Fläche,
/// ohne Wert [ohneWert], **nie `0`**.
class _Wert extends StatelessWidget {
  const _Wert({required this.art, required this.lage, required this.wert});

  final MessArt art;
  final MessLage lage;
  final double? wert;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final stil = Typografie.tabularNumbers(
      Typografie.numeric(TypografieGroesse.title3).copyWith(color: ink),
    );
    final zahl = wert;

    if (zahl == null && lage == MessLage.laedt) {
      return Platzhalter(beispiel: messBeispiel(art), stil: stil);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(zahl == null ? ohneWert : messZahl(art, zahl), style: stil),
        const SizedBox(width: 3),
        Text(messEinheit(art), style: TextStyle(fontSize: 13, color: muted)),
      ],
    );
  }
}

/// Die Farbe der Kurve je Wert (`messungen.js`).
CupertinoDynamicColor _farbe(MessArt art) => switch (art) {
  MessArt.gewicht => Palette.ok,
  MessArt.koerperfett => Palette.river,
  MessArt.fettfreieMasse => Palette.iron,
  MessArt.ruhepuls => Palette.warn,
};

// ─────────────────────────────────────────────────────────────────────────
// Nutzertexte
// ─────────────────────────────────────────────────────────────────────────

/// Der Trendsatz unter dem Wert.
///
/// Beim Gewicht die **Steigung pro Woche** (so steht der Zielkorridor
/// daneben), bei den übrigen drei die Veränderung über sechs Wochen.
///
/// **Beim Ruhepuls zeigt der Entwurf stattdessen den 30-Tage-Median** — den
/// trägt `KoerperWerte` nicht; er steht auf dem Detailschirm. Bis das
/// entschieden ist, steht hier dieselbe Veränderung wie bei den anderen
/// beiden Waagenwerten (siehe Bericht zu #85).
String _trendsatz(MessArt art, MessLage lage, KoerperWerte? werte) {
  // Während des Laufs und nach einem Fehler steht hier nichts: Beides ist
  // keine Aussage über die Datenlage (Fehler `01`).
  if (lage == MessLage.laedt || lage == MessLage.fehler) return '';

  final stand = werte?.stand(art);
  if (stand?.wert == null) return 'Keine Werte';

  if (art == MessArt.gewicht) {
    final proWoche = werte!.gewichtsTrendProWoche;
    return proWoche == null
        ? 'Für einen Trend fehlen Messungen'
        : gewichtsTrendText(proWoche);
  }
  final veraenderung = stand!.veraenderung6Wochen;
  return veraenderung == null
      ? 'Für einen Trend fehlen Messungen'
      : veraenderungText(art, veraenderung);
}

/// Der Einordnungssatz zum Gewichtstrend — die vier Sätze aus
/// `MeasurementsView.swift:167–174`, nicht vier Wörter.
///
/// **Ohne Trend steht hier, dass noch zu wenige Wägungen vorliegen** — und
/// gerade nicht „0,00 kg pro Woche": Eine Gerade durch einen Punkt hat
/// keine Steigung, das wäre eine Zahl, die niemand gerechnet hat.
String _einordnungssatz(MessLage lage, KoerperWerte? werte) {
  if (lage == MessLage.laedt || lage == MessLage.fehler) return '';

  final proWoche = werte?.gewichtsTrendProWoche;
  final einordnung = werte?.trendEinordnung;
  if (proWoche == null || einordnung == null) {
    return 'Für einen Trend fehlen Messungen: Es braucht mindestens zwei an '
        'verschiedenen Tagen innerhalb der letzten 6 Wochen.';
  }

  final urteil = switch (einordnung) {
    TrendRating.losing => 'Das Gewicht sinkt — für Muskelaufbau zu wenig.',
    TrendRating.slow =>
      'Langsamer als der Zielbereich +0,10 bis +0,25 kg pro Woche.',
    TrendRating.good =>
      'Guter Bereich für Muskelaufbau (Ziel +0,10 bis +0,25 kg pro Woche).',
    TrendRating.fast => 'Schneller als nötig; der Überschuss wird eher Fett.',
  };
  return '${gewichtsTrendText(proWoche)}. $urteil Lineare Regression über '
      'die letzten 6 Wochen.';
}

/// Die Kante des Einordnungskastens — `noteBox('good')` im Entwurf, sonst
/// neutral. Eine Warnfarbe für „zu langsam" wäre eine Bewertung, die sich
/// der Schirm nicht anmaßt.
CupertinoDynamicColor _einordnungsTon(TrendRating? einordnung) =>
    einordnung == TrendRating.good ? Palette.ok : Palette.bib;

/// „Letzte Messungen": **je Wägung** eine Zeile mit Datum, Uhrzeit,
/// Gewicht und — wenn die Waage am selben Tag auch das Fett gemeldet hat —
/// dem Fettanteil.
///
/// **Je Probe, nicht je Tag** (Tim, 03.11.2026). Zwei Wägungen an einem Tag
/// sind zwei Zeilen: Für die Karten oben gewinnt die letzte des Tages, und
/// wenn die frühere gar nicht erst auftauchte, wäre weder zu sehen, warum
/// der Tag so aussieht, noch die falsche von beiden zu löschen.
///
/// Drei Zeilen, die jüngste zuerst. Ohne Wägung bleibt **eine** Zeile
/// stehen und sagt das; während des Laufs stehen drei graue Flächen da, wo
/// die Zeilen hinkommen (#24).
///
/// **Eine Tür hat nur, was `wasUserEntered` trägt** — und das Kennzeichen
/// kommt aus HealthKit, nicht aus einer Buchhaltung dieser App. Alles
/// andere gehört einer fremden App, und Apple gibt es weder zum Ändern noch
/// zum Löschen frei.
List<MessZeileDaten> _letzteMessungen(
  BuildContext context,
  Messwert<List<WeightSample>> proben,
  KoerperWerte? werte,
) => switch (proben) {
  // Der Platzhalter gehört **allein** in `NochNie` (`CLAUDE.md`). Liegt
  // schon eine Reihe vor, bleibt sie beim Nachlauf stehen — sonst blitzte
  // nach jedem Sichern und jedem Tageswechsel die graue Fläche auf.
  NochNie<List<WeightSample>>() => [
    for (var i = 0; i < _zeilen; i++)
      const MessZeileDaten(
        name: '',
        namePlatzhalter: '00.00.0000, 00:00',
        platzhalter: '00,0 kg · 00,0 %',
      ),
  ],
  // „Lauf gescheitert" ist nicht „nichts gefunden". Ein „Noch keine
  // Wägung" an dieser Stelle wäre Fehler `01`, und fehlende
  // HealthKit-Daten dürfen nie als „nichts getrackt" dastehen.
  Fehlgeschlagen<List<WeightSample>>() => const [
    MessZeileDaten(name: 'Wägungen nicht gelesen'),
  ],
  LeerNachLauf<List<WeightSample>>() => const [
    MessZeileDaten(name: 'Noch keine Wägung'),
  ],
  Bekannt<List<WeightSample>>(wert: final waegungen) => [
    // Die Reihe kommt aufsteigend; gezeigt wird die jüngste zuerst.
    for (final probe in waegungen.reversed.take(_zeilen))
      MessZeileDaten(
        schluessel: Key('messungen-waegung-${probe.id}'),
        name:
            '${Format.tag(kalendertag(probe.date))}, '
            '${Format.uhrzeit(probe.date)}',
        kennzeichen: probe.wasUserEntered ? 'manuell' : null,
        wert: switch (_fettAm(werte, probe.date)) {
          // Den Fettanteil zeigt nur die Zeile, die auch von der Waage
          // kommt: Eine Handeingabe trägt keinen, und ihn vom selben Tag zu
          // borgen behauptete eine Messung, die es nicht gab.
          final prozent? when !probe.wasUserEntered =>
            '${messWert(MessArt.gewicht, probe.kg)} · '
                '${messWert(MessArt.koerperfett, prozent)}',
          _ => messWert(MessArt.gewicht, probe.kg),
        },
        aufTippen: probe.wasUserEntered
            ? () => zeigeGewichtEintragen(context, probe: probe)
            : null,
      ),
  ],
};

/// Wie viele Zeilen „Letzte Messungen" trägt — in jedem Zustand dieselbe
/// Zahl, damit der Abschnitt beim Eintreffen der Werte nicht wächst.
///
/// **Vier und nicht drei** (`messungen.js`): Zwei Wägungen an einem Tag
/// sind zwei Zeilen, und bei dreien bliebe daneben nur noch eine einzige
/// von der Waage übrig.
const int _zeilen = 4;

/// Der Fettanteil des Tages, an dem [zeitpunkt] liegt — oder `null`.
double? _fettAm(KoerperWerte? werte, DateTime zeitpunkt) {
  final reihe = werte?.koerperfett.reihe;
  if (reihe == null) return null;
  final tag = BerlinCalendar.dayKey(zeitpunkt);
  for (final punkt in reihe) {
    if (BerlinCalendar.dayKey(punkt.date) == tag) return punkt.value;
  }
  return null;
}
