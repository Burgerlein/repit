// Der Schirm „Zyklus einrichten" (#573 unter #539) — was der Kalender über
// die Nutzerin wissen muss, und der einzige Ort, an dem er sich abschalten
// lässt.
//
// API und Verhalten sind durch
// `app/test/zyklus/zyklus_einrichten_view_test.dart` verbindlich
// vorgegeben (siehe dessen Dateikopf) — diese Datei darf die Tests
// ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung"). Die Tests sind vor dieser Datei
// entstanden und committet; ab da bewacht sie der Pre-Commit-Haken.
//
// Aufbau nach `docs/screens/screens/zyklus-einrichten.js`, Varianten
// `aus`, `hilfe`, `einschalten`, `eingerichtet`, `mit-verhuetung` und
// `ohne-health`. Spec:
// `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte 3.7, 4.3
// und 7.
//
// **Wo der Schirm hängt — eine benannte Abweichung vom Entwurfsboard.**
// Dort liegt er unter *Mehr › Einstellungen* (`parent: 'einstellungen'`);
// den Einstellungs-Schirm gibt es im Flutter-Neubau noch nicht. Bis dahin
// hängt er unmittelbar unter *Mehr*, genau wie „Vorläufige Werte" (#307),
// „KI-Zugang" (#339) und „Daten übernehmen" (#59) — dieselbe Abweichung,
// kein neuer Platz. Der zweite Weg hierher ist das Zahnrad in der Leiste
// des Kalenders, und das steht im Entwurf.
//
// **Zwei Zeilen des Entwurfs stehen abgeblendet da**: die Tür zu den
// Erinnerungen (#589) und „Alle Zyklusdaten löschen". Beides sind eigene
// Karten, und beides wegzulassen hieße, eine Funktion unsichtbar zu
// machen, die es geben wird — „wo es keine Anzeige gibt, steht ein Satz,
// bis das Feature dran ist" (`CLAUDE.md`). Dasselbe Muster wie im
// Mehr-Menü.
//
// **Nichts wird hier gerechnet** (Hausregel 2): Was dasteht, kommt aus
// `zyklusEinstellungenProvider` und `zyklusImportStandProvider`; eigen ist
// nur, ob das Datumsrad gerade aufgeklappt ist.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/zyklus_repository.dart';
import '../design/formatierung.dart';
import '../design/formular.dart';
import '../design/glas_abstand.dart';
import '../design/hilfe.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../health/health_provider.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'zyklus_texte.dart';
import 'zyklus_zustand.dart';

/// Öffnet „Zyklus einrichten" auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß.
///
/// Zwei Aufrufer: die Zeile unter *Mehr* und das Zahnrad in der Leiste des
/// Kalenders. Beide liegen in ihrem eigenen Tab-Stapel, und genau deshalb
/// `AppTarget.aktuell` — sonst führte „zurück" in ein Menü, das die
/// Nutzerin nie geöffnet hat (`CLAUDE.md`).
void oeffneZyklusEinrichten(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const ZyklusEinrichtenSeite()));

/// **Kein eigener `Navigator`:** Dieser Schirm wird geschoben.
class ZyklusEinrichtenSeite extends ConsumerStatefulWidget {
  const ZyklusEinrichtenSeite({super.key});

  @override
  ConsumerState<ZyklusEinrichtenSeite> createState() =>
      _ZyklusEinrichtenZustand();
}

class _ZyklusEinrichtenZustand extends ConsumerState<ZyklusEinrichtenSeite> {
  /// Ob das Datumsrad unter „Seit" aufgeklappt ist. Das einzige, was
  /// diesem Schirm selbst gehört.
  bool _seitOffen = false;

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(zyklusEinstellungenProvider);

    return CupertinoPageScaffold(
      key: const Key('zyklus-einrichten'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: const CupertinoNavigationBar(
        middle: Text(zyklusEinrichtenTitel),
      ),
      // **`Builder`, damit der Abstand unter der Leiste stimmt:**
      // `CupertinoPageScaffold` schreibt die Höhe seiner durchscheinenden
      // Navigationsleiste in die `MediaQuery` seines **Kindes**. Mit dem
      // Kontext des Schirms selbst läge der erste Kopf unter der Leiste.
      child: Builder(
        builder: (context) => SingleChildScrollView(
          padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _abschnitte(context, stand),
          ),
        ),
      ),
    );
  }

  List<Widget> _abschnitte(BuildContext context, ZyklusEinstellungen stand) => [
    _schalterAbschnitt(context, stand),
    // **Was aus ist, verschwindet** (Entwurf): Unter dem Schalter steht
    // dann nur noch, was das Ausschalten bedeutet. Die Fragen einer
    // Funktion zu stellen, die gerade nicht läuft, hieße zu fragen, ohne
    // dass die Antwort etwas bewirkt.
    if (stand.kalenderAn) ...[
      _importAbschnitt(stand),
      _wofuerAbschnitt(context, stand),
      _verhuetungAbschnitt(context, stand),
      _datenAbschnitt(),
    ],
  ];

  // ───────────────────────────────────────────────────────────────────────
  // Der Schalter
  // ───────────────────────────────────────────────────────────────────────

  Widget _schalterAbschnitt(BuildContext context, ZyklusEinstellungen stand) =>
      _abschnitt(
        titel: zyklusSchalterTitel,
        karte: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _schalterZeile(
              schluessel: 'zyklus-einrichten-schalter',
              beschriftung: zyklusSchalterName,
              // Der Satz sagt, **was der Schalter bewirkt**, nicht was er
              // bedeutet (Entwurf).
              detail: stand.kalenderAn ? zyklusSchalterAn : zyklusSchalterAus,
              an: stand.kalenderAn,
              aufAenderung: (an) => _schreibe(stand.kopieMit(kalenderAn: an)),
            ),
            // **Bleibt sichtbar, solange der Kalender aus ist:** eine
            // Folge, die man vor dem Umlegen wissen muss — keine
            // Erklärung (Fassung C). Eingeschaltet hat sie keinen Anlass.
            if (!stand.kalenderAn) ...[
              _trenner(context),
              const PflichtZeile(
                key: Key('zyklus-einrichten-ausblenden'),
                text: zyklusAusblendenFolge,
              ),
            ],
          ],
        ),
      );

  // ───────────────────────────────────────────────────────────────────────
  // Aus Apple Health
  // ───────────────────────────────────────────────────────────────────────

  /// Die Zeile steht **immer**, auch wenn Health nichts hergibt: Eine
  /// fehlende Zeile sähe aus wie eine Funktion, die es nicht gibt
  /// (`CLAUDE.md`). Nur die Füllung unterscheidet sich.
  ///
  /// **Keine Tür, sondern eine Anzeige** — `FormZeile` ohne `aufTipp`
  /// trägt deshalb keinen Winkel. Das Übernehmen selbst kommt mit der
  /// HealthKit-Stufe; bis dahin sagt die Zeile ehrlich, dass niemand
  /// nachgesehen hat.
  Widget _importAbschnitt(ZyklusEinstellungen stand) {
    final importStand = ref.watch(zyklusImportStandProvider);
    return _abschnitt(
      schluessel: 'zyklus-einrichten-import',
      titel: zyklusImportTitel,
      karte: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormZeile(
            key: const Key('zyklus-einrichten-import-zeile'),
            beschriftung: zyklusImportZeile,
            wert: switch (importStand) {
              ZyklusImportOffen() => zyklusImportOffen,
              ZyklusImportGefunden(:final monate) => zyklusImportMonate(monate),
              ZyklusImportNichts() => zyklusImportNichts,
              ZyklusImportGelaufen() => zyklusImportUebernommen,
            },
            // Gedämpft, solange der Wert keine Antwort ist, sondern das
            // Fehlen einer.
            platzhalter: switch (importStand) {
              ZyklusImportOffen() || ZyklusImportNichts() => true,
              ZyklusImportGefunden() || ZyklusImportGelaufen() => false,
            },
          ),
          // **Der Fund steht als Zeile in der Karte** (Fassung C, #356):
          // Dass etwas auf eine Entscheidung wartet, ist eine Lage und
          // gehört sichtbar.
          if (importStand is ZyklusImportGefunden)
            const PflichtZeile(
              key: Key('zyklus-einrichten-import-wartet'),
              text: zyklusImportWartet,
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────
  // Die zwei Fragen
  // ───────────────────────────────────────────────────────────────────────

  Widget _wofuerAbschnitt(BuildContext context, ZyklusEinstellungen stand) =>
      _abschnitt(
        schluessel: 'zyklus-einrichten-wofuer',
        titel: zyklusWofuerTitel,
        karte: _Segmentiert(
          praefix: 'zyklus-einrichten-sicht',
          felder: const {
            'ueberblick': zyklusSichtUeberblick,
            'kinderwunsch': zyklusSichtKinderwunsch,
          },
          gewaehlt: stand.sicht.name,
          aufWahl: (name) =>
              _schreibe(stand.kopieMit(sicht: ZyklusSicht.values.byName(name))),
        ),
      );

  Widget _verhuetungAbschnitt(
    BuildContext context,
    ZyklusEinstellungen stand,
  ) => Column(
    key: const Key('zyklus-einrichten-verhuetung'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HilfeKopf(titel: zyklusVerhuetungTitel, aufHilfe: _zeigeHilfe),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InsetCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _schalterZeile(
                schluessel: 'zyklus-einrichten-verhuetung-schalter',
                beschriftung: zyklusVerhuetungName,
                an: stand.verhuetungAn,
                aufAenderung: _verhuetung,
              ),
              // **„Seit" steht erst, wenn verhütet wird** — ein Feld ohne
              // seinen Anlass fragt etwas, das niemand beantworten kann.
              if (stand.verhuetungAn) ...[
                _trenner(context),
                FormZeile(
                  key: const Key('zyklus-einrichten-seit'),
                  beschriftung: zyklusVerhuetungSeit,
                  wert: stand.verhuetungSeit == null
                      ? zyklusVerhuetungDatumWaehlen
                      : Format.datumAusgeschrieben(
                          datumZumAnzeigen(stand.verhuetungSeit!),
                        ),
                  platzhalter: stand.verhuetungSeit == null,
                  aufTipp: () => setState(() => _seitOffen = !_seitOffen),
                ),
                if (_seitOffen) ...[
                  _trenner(context),
                  _DatumsRad(
                    tag: stand.verhuetungSeit ?? _heute(),
                    aufWahl: (tag) =>
                        _schreibe(stand.kopieMit(verhuetungSeit: tag)),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
      // Die Tür zu den Erinnerungen (#589). Sie steht hier und nicht in
      // einer eigenen Gruppe, weil Art und Takt dieselbe Angabe sind
      // (Entwurf). Abgeblendet, solange es den Schirm nicht gibt.
      const SizedBox(height: 10),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Opacity(
          opacity: 0.5,
          child: InsetCard(
            child: IconRow(
              key: const Key('zyklus-einrichten-erinnerungen'),
              symbol: 'bell',
              accent: CupertinoDynamicColor.resolve(Palette.bib, context),
              title: zyklusErinnerungenTitel,
              subtitle:
                  (stand.verhuetungAn
                      ? zyklusErinnerungenMitVerhuetung
                      : zyklusErinnerungenOhneVerhuetung) +
                  zyklusFolgtHinweis,
            ),
          ),
        ),
      ),
    ],
  );

  // ───────────────────────────────────────────────────────────────────────
  // Daten
  // ───────────────────────────────────────────────────────────────────────

  /// „Alle Zyklusdaten löschen" — abgeblendet, bis es das Löschen gibt.
  ///
  /// **Löschen ist nicht dasselbe wie Ausschalten**, und genau deshalb
  /// steht die Zeile hier, auch wenn sie noch nicht trägt: Bei diesen
  /// Daten ist „weg" eine Antwort, die man ausdrücklich geben muss
  /// (Entwurf). Ein Knopf, der löscht, bevor jemand geprüft hat, was mit
  /// dem Health-Spiegel passiert (Spec 4.3.3), wäre der schlechtere
  /// Platzhalter.
  Widget _datenAbschnitt() => Column(
    key: const Key('zyklus-einrichten-daten'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HilfeKopf(titel: zyklusDatenTitel, aufHilfe: _zeigeHilfe),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Opacity(
          opacity: 0.5,
          child: InsetCard(
            child: const FormZeile(
              key: Key('zyklus-einrichten-loeschen'),
              beschriftung: zyklusLoeschen,
              unterzeile: zyklusFolgtZeile,
            ),
          ),
        ),
      ),
      const PflichtZeile(
        key: Key('zyklus-einrichten-loeschen-folge'),
        text: zyklusLoeschenFolge,
      ),
    ],
  );

  // ───────────────────────────────────────────────────────────────────────
  // Bausteine
  // ───────────────────────────────────────────────────────────────────────

  /// Kopf **und** Karte eines Abschnitts — sie gehören zusammen.
  Widget _abschnitt({
    required String titel,
    required Widget karte,
    String? schluessel,
  }) => Column(
    key: schluessel == null ? null : Key(schluessel),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HilfeKopf(titel: titel, aufHilfe: _zeigeHilfe),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InsetCard(child: karte),
      ),
    ],
  );

  /// Eine Schalterzeile, **in ganzer Breite antippbar**: Ein Schieber von
  /// 50 Punkt am rechten Rand ist das kleinere Ziel, und die Zeile sagt
  /// ohnehin dasselbe (wie auf „Tag eintragen").
  Widget _schalterZeile({
    required String schluessel,
    required String beschriftung,
    required bool an,
    required ValueChanged<bool> aufAenderung,
    String? detail,
  }) => GestureDetector(
    key: Key(schluessel),
    behavior: HitTestBehavior.opaque,
    onTap: () => aufAenderung(!an),
    child: SchalterZeile(
      beschriftung: beschriftung,
      an: an,
      detail: detail,
      aufAenderung: aufAenderung,
    ),
  );

  Widget _trenner(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 14),
    child: Container(
      height: 0.5,
      color: CupertinoDynamicColor.resolve(Palette.line, context),
    ),
  );

  /// Heute, **aus der Uhr der App** — nie `DateTime.now()`.
  String _heute() => BerlinCalendar.dayKey(ref.read(heutigerTagProvider));

  // ───────────────────────────────────────────────────────────────────────
  // Schreiben
  // ───────────────────────────────────────────────────────────────────────

  /// Legt den ganzen Einstellungswert ab. Neu gelesen wird nichts von
  /// Hand — die Provider hängen an der Tabelle und melden sich selbst.
  Future<void> _schreibe(ZyklusEinstellungen neu) =>
      ref.read(zyklusRepositoryProvider).schreibeEinstellungen(neu);

  /// Das Umschalten der Verhütung.
  ///
  /// **Zurückgenommen wird der ganze Wert, nicht das Flag allein:** Ein
  /// stehengebliebener Zeitpunkt behauptete eine Verhütung, die es nicht
  /// mehr gibt — und `kopieMit` kann `null` nicht setzen (siehe dessen
  /// Doc-Kommentar). Mit dem Zeitpunkt klappt das Rad zu.
  void _verhuetung(bool an) {
    final stand = ref.read(zyklusEinstellungenProvider);
    if (an) {
      _schreibe(stand.kopieMit(verhuetungAn: true));
      return;
    }
    setState(() => _seitOffen = false);
    _schreibe(
      ZyklusEinstellungen(
        kalenderAn: stand.kalenderAn,
        sicht: stand.sicht,
        verhuetungAn: false,
        verhuetungSeit: null,
        verhuetungArt: null,
        importGelaufen: stand.importGelaufen,
        vorhersagePausiert: stand.vorhersagePausiert,
      ),
    );
  }

  /// Was erklärt, steht hinter dem `?` (Fassung C, `CLAUDE.md`). Alle
  /// Köpfe öffnen **dasselbe** Blatt: Es ist eine Erklärung des Schirms,
  /// keine fünf.
  void _zeigeHilfe() => zeigeHilfeBlatt(
    context,
    titel: zyklusEinrichtenHilfeTitel,
    pflicht: zyklusEinrichtenHilfePflicht,
    bloecke: const [
      HilfeBlock(
        titel: zyklusEinrichtenHilfeDazuTitel,
        text: zyklusEinrichtenHilfeDazuText,
        ton: Palette.blut,
      ),
      HilfeBlock(
        titel: zyklusEinrichtenHilfeOrtTitel,
        text: zyklusEinrichtenHilfeOrtText,
        ton: Palette.muted,
      ),
      HilfeBlock(
        titel: zyklusEinrichtenHilfeSichtTitel,
        text: zyklusEinrichtenHilfeSichtText,
        ton: Palette.river,
      ),
      HilfeBlock(
        titel: zyklusEinrichtenHilfeVerhuetungTitel,
        text: zyklusEinrichtenHilfeVerhuetungText,
        ton: Palette.river2,
      ),
      HilfeBlock(
        titel: zyklusEinrichtenHilfeImportTitel,
        text: zyklusEinrichtenHilfeImportText,
        ton: Palette.ok,
      ),
    ],
  );
}

/// Eine Wahl aus zwei Feldern — `segmented` im Entwurf.
///
/// Dieselbe Form wie die Stufen auf „Tag eintragen", aber ohne das
/// Rücknahme-Feld: „Wofür" hat keine leere Antwort, es ist immer eines von
/// beiden (`ZyklusEinstellungen.vorbelegung` sagt welches).
class _Segmentiert extends StatelessWidget {
  const _Segmentiert({
    required this.praefix,
    required this.felder,
    required this.gewaehlt,
    required this.aufWahl,
  });

  /// Schlüssel des Falls → Beschriftung.
  final Map<String, String> felder;
  final String praefix;
  final String gewaehlt;
  final ValueChanged<String> aufWahl;

  @override
  Widget build(BuildContext context) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final flaeche = CupertinoDynamicColor.resolve(Palette.surface, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: line.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            for (final feld in felder.entries)
              Expanded(
                child: GestureDetector(
                  key: Key('$praefix-${feld.key}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aufWahl(feld.key),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: feld.key == gewaehlt
                        ? BoxDecoration(
                            color: flaeche,
                            borderRadius: BorderRadius.circular(7),
                          )
                        : null,
                    child: Text(
                      feld.value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: feld.key == gewaehlt
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: feld.key == gewaehlt ? ink : muted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Das Datumsrad unter „Seit", Modus Datum.
///
/// **Der ISO-Tag kommt aus den Kalenderfeldern des Rades** — wer den
/// Zeitpunkt nach UTC dreht, verschiebt den Tag um einen (`CLAUDE.md`,
/// „Der Datumsschlüssel ist der ISO-Tagesstring"). Dasselbe Muster wie im
/// Auszeit-Blatt.
class _DatumsRad extends StatelessWidget {
  const _DatumsRad({required this.tag, required this.aufWahl});

  final String tag;
  final ValueChanged<String> aufWahl;

  static DateTime _lokal(String tag) => DateTime(
    int.parse(tag.substring(0, 4)),
    int.parse(tag.substring(5, 7)),
    int.parse(tag.substring(8, 10)),
  );

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 180,
    child: CupertinoDatePicker(
      mode: CupertinoDatePickerMode.date,
      initialDateTime: _lokal(tag),
      onDateTimeChanged: (wert) => aufWahl(_iso(wert)),
    ),
  );
}
