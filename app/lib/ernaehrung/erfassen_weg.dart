// Die Türen des Eintragwegs (#285, #300) — wie man von (+), Tag-Schirm
// und Mahlzeiten-Schirm in die Suche kommt und aus ihr ins
// Buchungsblatt. Suche und Blätter selbst liegen in `suche_view.dart`,
// `anlegen_blatt.dart` und `buchungs_blatt.dart`; geprüft wird die
// Verdrahtung in `app/test/ernaehrung/eintragweg_verdrahtung_test.dart`.
//
// **Der (+) öffnet die Kamera** (`erfassen.js`, #324, `kamera_seite.dart`),
// ebenso „Zu dieser Mahlzeit hinzufügen" (#344); hierher führen „Suchen"
// in der Kamera, die Kachel „Suchen" und der Bogeneintrag.
//
// **Seit #439 trägt die Suche den Kopf mit Zähler und die Kachelreihe**
// (`erfassen_kacheln.dart`; Entscheidung 9, V21–V23): Barcode und KI-Foto
// schließen die Suche und öffnen die Kamera im gewählten Modus, der Zähler
// geht mit.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../data/lebensmittel_repository.dart';
import '../design/glas_abstand.dart';
import '../design/palette.dart';
import '../health/health_provider.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import '../tag/laufender_tag_provider.dart';
import 'buchungs_blatt.dart';
// `ErfassenKopf` ist hier der Kopf mit Zähler (`erfassen_kacheln.dart`),
// nicht der gleichnamige Kopf der Blätter.
import 'erfassen_bausteine.dart' hide ErfassenKopf;
import 'erfassen_formular.dart';
import 'erfassen_kacheln.dart';
import 'erfassen_provider.dart';
import 'ernaehrung_abschnitte.dart' show mahlzeitName;
import 'ernaehrung_provider.dart';
import 'kamera_bausteine.dart' show KameraModus;
import 'kamera_seite.dart';
import 'plus_bausteine.dart';
import 'portions_abruf.dart';
import 'portions_text.dart';
import 'suche_view.dart';

/// Öffnet die Suche auf dem Stapel des **aktuell gewählten** Tabs.
///
/// Über `AppTarget.aktuell(...)`, nie über einen Tab-Wechsel: Sonst führte
/// „zurück" in ein Menü, das der Nutzer nie geöffnet hat (`CLAUDE.md`).
///
/// [tagesSchluessel] ist der Tag, auf den gebucht wird. Ohne ihn gilt der
/// offene Tag des Ernährungs-Schirms ([offenerTagProvider]) — so beim (+),
/// der keinen eigenen Tag kennt. [mahlzeit] wählt im Buchungsblatt die
/// Mahlzeit vor, die Uhrzeit bleibt die des Trackens (#328); ohne sie
/// ergibt sich die Mahlzeit aus der Uhrzeit. [gebucht] ist der Zähler der
/// Sitzung, den ein Wechsel aus der Kamera mitgibt (V21).
void oeffneSuche(
  AppRouter router, {
  String? tagesSchluessel,
  Mahlzeit? mahlzeit,
  int gebucht = 0,
}) {
  router.open(
    AppTarget.aktuell(
      (context) => SucheSeite(
        router: router,
        tagesSchluessel: tagesSchluessel,
        mahlzeit: mahlzeit,
        gebucht: gebucht,
      ),
    ),
  );
}

/// Was das Suchfeld fragt (V23) — nach der Mahlzeit, auf die gebucht wird.
String suchfrage(Mahlzeit mahlzeit) =>
    'Was hattest du ${mahlzeitBezug(mahlzeit)}?';

/// Der Rahmen um die Suche: Gerüst, Kopf mit Zähler, Kachelreihe, „+" je
/// Zeile mit Band und „Fertig", und der Weg aus einem Treffer ins
/// Buchungsblatt.
///
/// **Die Suche bleibt nach jeder Buchung offen** (V26, von Tim bestätigt),
/// per „+" wie per Blatt: Haken an der Zeile, Zähler +1, Band mit
/// „Rückgängig" für 8 s. Schließen tun „Fertig" und „Abbrechen", und beide
/// nehmen nichts zurück (V29).
///
/// **Kein eigener `Navigator`:** Die Seite wird auf den Stapel eines Tabs
/// geschoben, der Stapel gehört weiter `RootView`.
class SucheSeite extends ConsumerStatefulWidget {
  const SucheSeite({
    super.key,
    this.router,
    this.tagesSchluessel,
    this.mahlzeit,
    this.gebucht = 0,
  });

  /// Für Barcode und KI-Foto: Die Kamera wird über den Router geöffnet
  /// (`CLAUDE.md`, „Sprünge laufen über `AppRouter`"). Ohne Router tun die
  /// beiden Kacheln nichts.
  final AppRouter? router;

  final String? tagesSchluessel;
  final Mahlzeit? mahlzeit;

  /// Was vor dieser Seite in der Sitzung gebucht wurde — der Zähler, den
  /// die Kamera mitgibt (V21, V22).
  final int gebucht;

  @override
  ConsumerState<SucheSeite> createState() => _SucheSeiteZustand();
}

/// Eine Buchung dieser Sitzung — woran die Zeile ihren Haken erkennt.
/// Ein Online-Treffer wird beim Buchen übernommen; danach steht er als
/// eigene Zeile da, deshalb zählt der Strichcode mit.
typedef _Buchung = ({int eintragId, int? lebensmittelId, String? barcode});

class _SucheSeiteZustand extends ConsumerState<SucheSeite> {
  /// Was in dieser Seite gebucht und nicht zurückgenommen ist.
  final _sitzung = <_Buchung>[];

  /// Das Band: die letzte Buchung und was es über sie sagt. Nur sie lässt
  /// sich zurücknehmen; eine neue ersetzt es (V27).
  ({int eintragId, String text})? _band;

  Timer? _uhr;

  int get _gebucht => widget.gebucht + _sitzung.length;

  @override
  void dispose() {
    _uhr?.cancel();
    super.dispose();
  }

  /// Barcode und KI-Foto: **statt** der Suche, nicht über ihr (V21). Ist
  /// schon irgendwo eine Kamera offen, bleibt die Suche stehen — sonst
  /// schlösse sie sich, und nichts ginge auf (#326).
  void _aufWeg(ErfassenWeg weg) {
    final router = widget.router;
    final modus = switch (weg) {
      ErfassenWeg.barcode => KameraModus.barcode,
      ErfassenWeg.ki => KameraModus.ki,
      ErfassenWeg.suchen || ErfassenWeg.nurKcal => null,
    };
    if (router == null || modus == null || kameraOffen(router)) return;
    final gebucht = _gebucht;
    Navigator.of(context).pop();
    oeffneKamera(
      router,
      tagesSchluessel: widget.tagesSchluessel,
      mahlzeit: widget.mahlzeit,
      modus: modus,
      gebucht: gebucht,
    );
  }

  /// Ob die Zeile dieser Vorlage in der Sitzung etwas gebucht hat (V27,
  /// V28).
  bool _istGebucht(LebensmittelVorlage vorlage) => _sitzung.any(
    (b) =>
        (vorlage.id != null && b.lebensmittelId == vorlage.id) ||
        (vorlage.barcode != null && b.barcode == vorlage.barcode),
  );

  /// „+" und der Haken (V25, V28): ohne Blatt, mit der Vorwahl, die die
  /// Zeile zeigt.
  Future<void> _plus(LebensmittelVorlage vorlage, String tag) async {
    final int eintragId;
    try {
      eintragId = await ref
          .read(erfassenProvider.notifier)
          .bucheDirekt(
            vorlage: vorlage,
            tagesSchluessel: tag,
            jetzt: ref.read(clockProvider)(),
            mahlzeit: widget.mahlzeit,
          );
    } catch (fehler) {
      // Nichts gebucht, nichts gezählt — die Zeile bleibt, wie sie war.
      debugPrint('Mit „+" nicht gebucht: $fehler');
      return;
    }
    await _gebuchtWorden(eintragId, vorlage);
    if (!mounted) return;
    // Wie im Blatt: Fehlte die Freigabe für Health, sagt das **ein**
    // Hinweis (`erfassen.js`, `keine-freigabe`). Gebucht ist trotzdem.
    if (ref.read(healthSchreibHinweisProvider)) {
      await zeigeHealthSchreibHinweis(context);
      ref.read(healthSchreibHinweisProvider.notifier).gesehen();
    }
  }

  /// Ein Tipp auf die Zeile: das Blatt, wie bisher. Nach dem Buchen bleibt
  /// die Suche offen (V26).
  Future<void> _blatt(LebensmittelVorlage vorlage, String tag) async {
    // Die vorgewählte Mahlzeit ändert die Uhrzeit nicht — es bleibt die
    // des Trackens (#328, #344). Samt Portionen und Vorwahl aus der
    // letzten Buchung (#325).
    final formular = await ref
        .read(erfassenProvider.notifier)
        .oeffneFormular(
          vorlage: vorlage,
          tagesSchluessel: tag,
          jetzt: ref.read(clockProvider)(),
          mahlzeit: widget.mahlzeit,
        );
    if (!mounted) return;
    int? eintragId;
    // Ein Online-Treffer fragt einmal nach seinen Portionen, ebenso ein
    // übernommenes Produkt, das nie gefragt wurde.
    await zeigeBuchungsBlatt(
      context,
      formular,
      abruf: brauchtAbruf(vorlage),
      onGebucht: (id) => eintragId = id,
    );
    final neu = eintragId;
    if (neu != null) await _gebuchtWorden(neu, vorlage);
  }

  /// Zählt eine Buchung, setzt den Haken und zeigt das Band.
  Future<void> _gebuchtWorden(
    int eintragId,
    LebensmittelVorlage vorlage,
  ) async {
    // Frisch gelesen: Das Band nennt, was tatsächlich gebucht ist — die
    // Menge und die Mahlzeit, die im Blatt auch geändert sein können, und
    // das übernommene Lebensmittel eines Online-Treffers.
    final eintrag = await ref
        .read(ernaehrungRepositoryProvider)
        .eintrag(eintragId);
    if (!mounted) return;
    setState(() {
      _sitzung.add((
        eintragId: eintragId,
        lebensmittelId: eintrag?.lebensmittelId ?? vorlage.id,
        barcode: vorlage.barcode,
      ));
      _band = (
        eintragId: eintragId,
        text: eintrag == null
            ? '${vorlage.name} gebucht.'
            : '${eintrag.name} · ${_menge(eintrag)} '
                  '${mahlzeitBezug(eintrag.mahlzeit)} gebucht.',
      );
    });
    _uhr?.cancel();
    // Das Band ist ein Hinweis, kein Abschnitt — es geht von selbst, wie
    // auf dem Mahlzeiten-Schirm.
    _uhr = Timer(const Duration(seconds: 8), () {
      if (mounted) setState(() => _band = null);
    });
  }

  /// Rückgängig (V27): über den bestehenden Löschweg, samt Kopie in
  /// Health. Zähler −1; der Haken geht, wenn die Zeile sonst nichts
  /// gebucht hat.
  Future<void> _rueckgaengig() async {
    final band = _band;
    if (band == null) return;
    _uhr?.cancel();
    setState(() {
      _band = null;
      _sitzung.removeWhere((b) => b.eintragId == band.eintragId);
    });
    await ref.read(erfassenProvider.notifier).nimmZurueck(band.eintragId);
  }

  @override
  Widget build(BuildContext context) {
    // Zwei Zeilen statt `tagesSchluessel ?? ref.watch(…)`: In dieser
    // Form leitet der Analyzer den Typ von `watch` aus dem nullbaren
    // Kontext ab, und `tag` würde `String?`.
    final offen = ref.watch(offenerTagProvider);
    final tag = widget.tagesSchluessel ?? offen;
    // Dieselbe Mahlzeit, die das Buchungsblatt vorwählt (V22, V23) — mit
    // demselben Grund des laufenden Tages (#456).
    final fuer = vorgewaehlteMahlzeit(
      jetzt: ref.watch(clockProvider)(),
      mahlzeit: widget.mahlzeit,
      grund: ref.watch(
        laufenderTagProvider.select((s) => buchungsgrund(s, tag)),
      ),
    );
    final band = _band;

    return PopScope(
      // **Die Suche beginnt jedes Mal leer.** Das Suchfeld hat keinen
      // Controller und steht beim nächsten Öffnen leer da; ein stehen
      // gebliebener Suchtext filterte dann unsichtbar weiter.
      onPopInvokedWithResult: (gegangen, _) {
        if (gegangen) ref.read(suchtextProvider.notifier).setze('');
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
        // Der Kopf ersetzt die Leiste „Erfassen" (V22) — ohne Zurück; aus
        // der Suche führen „Abbrechen" und „Fertig", und die Wischgeste
        // bleibt.
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErfassenKopf(
                gebucht: _gebucht,
                titel: mahlzeitName(fuer),
                aufAbbrechen: () => Navigator.of(context).pop(),
                dunkel: false,
              ),
              Expanded(
                // Oben hat `SafeArea` den Rand schon genommen — `context`
                // liegt außerhalb und kennt ihn noch —, unten trägt ihn
                // „Fertig"; die Liste endet darüber.
                child: MediaQuery.removePadding(
                  context: context,
                  removeTop: true,
                  removeBottom: true,
                  child: SucheView(
                    kacheln: ErfassenKacheln(
                      aktiv: ErfassenWeg.suchen,
                      dunkel: false,
                      aufWeg: _aufWeg,
                    ),
                    platzhalter: suchfrage(fuer),
                    umrandet: true,
                    plus: SuchePlus(
                      mahlzeit: fuer,
                      aufPlus: (vorlage) => _plus(vorlage, tag),
                      istGebucht: _istGebucht,
                    ),
                    band: band == null
                        ? null
                        : ErfassenBand(
                            text: band.text,
                            aufRueckgaengig: _rueckgaengig,
                          ),
                    onGewaehlt: (vorlage) => _blatt(vorlage, tag),
                  ),
                ),
              ),
              const _FertigLeiste(),
            ],
          ),
        ),
      ),
    );
  }
}

/// Die Menge eines gebuchten Eintrags, wie die Zeile sie sagt: „2 Bon
/// (11,8 g)" mit Portion, sonst „80 g" bzw. „250 ml".
String _menge(Eintrag eintrag) {
  final mengeG = eintrag.mengeG;
  // Ein Eintrag aus dem Erfassen hat immer eine Menge; fehlte sie doch,
  // steht ein Strich da und keine erfundene Zahl.
  if (mengeG == null) return '–';
  final fluessig = eintrag.fluessig ?? false;
  final name = eintrag.portionName;
  final portionG = eintrag.portionG;
  if (name != null && portionG != null) {
    return gebuchtePortion(
      mengeG: mengeG,
      name: name,
      portionG: portionG,
      fluessig: fluessig,
    );
  }
  return portionsMenge(mengeG, fluessig: fluessig);
}

/// „Fertig" unten, fest (`FERTIG`, V29): schließt die Suche und nimmt
/// nichts zurück. Über der Tableiste samt (+), so wie die Liste sonst
/// endet ([GlasAbstand]).
class _FertigLeiste extends StatelessWidget {
  const _FertigLeiste();

  @override
  Widget build(BuildContext context) {
    final rand = GlasAbstand.of(context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    // `.btn.fill`: Schrift in der Flächenfarbe. Ohne sie wählte der Knopf
    // eine eigene, die auf `river` nicht zu lesen ist.
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, rand.bottom + 6),
      child: CupertinoButton(
        key: const Key('erfassen-fertig'),
        color: river,
        borderRadius: BorderRadius.circular(12),
        padding: const EdgeInsets.symmetric(vertical: 13),
        onPressed: () => Navigator.of(context).pop(),
        child: Text(
          'Fertig',
          style: TextStyle(fontWeight: FontWeight.w600, color: surface),
        ),
      ),
    );
  }
}

/// Zeigt das Buchungsblatt — für eine neue Buchung wie für einen
/// gebuchten Eintrag (`BuchungsFormular.fuer`).
///
/// Gibt `true` zurück, wenn gebucht, geändert oder gelöscht wurde, und
/// `false` nach „Abbrechen". [abruf] ist `brauchtAbruf(vorlage)` — ohne
/// fragt das Blatt nicht bei Open Food Facts nach.
Future<bool> zeigeBuchungsBlatt(
  BuildContext context,
  BuchungsFormular formular, {
  PortionsQuelle? abruf,
  void Function(int eintragId)? onGebucht,
}) async {
  var fertig = false;
  await zeigeErfassenBlatt(
    context,
    (blattKontext) => BuchungsBlatt(
      formular: formular,
      abruf: abruf,
      onGebucht: onGebucht,
      onFertig: () {
        fertig = true;
        Navigator.pop(blattKontext);
      },
    ),
  );
  return fertig;
}
