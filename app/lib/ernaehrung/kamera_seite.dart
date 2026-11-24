// Der Kamera-Schirm (#324) — `docs/screens/screens/erfassen.js`, Zustände
// `barcode` und `unbekannt`. Was der (+) öffnet, und die Kachel „Barcode".
//
// API und Verhalten sind durch `app/test/ernaehrung/barcode_kamera_test
// .dart` verbindlich vorgegeben (siehe dessen Dateikopf, samt der
// Entscheidungen des Koordinators — **nicht von Tim**) — diese Datei darf
// die Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests
// schreibt, schreibt nicht die Implementierung").
//
// **Je Code ein Befund, in dieser Reihenfolge:** erst die eigene Tabelle
// (ohne Netz, sofort), dann Open Food Facts. Daraus einer von drei Wegen:
// buchbar → Buchungsblatt; nicht hinterlegt oder ohne Kalorien →
// `unbekannt`; nicht erreichbar → „kein Netz". Die letzten beiden werden
// nie vermischt — „nicht hinterlegt" behauptete etwas, das in dem Moment
// niemand weiß.
//
// **Ein Code wird je Kamera-Sitzung einmal ausgewertet.** Die Naht meldet
// roh, jedes Bild (`strichcode_leser.dart`); entprellt wird hier. Die
// Sitzung endet, wenn der Schirm geht.
//
// Die Bausteine des Schirms liegen in `kamera_bausteine.dart` und
// `kamera_unbekannt.dart`.
//
// **Ein Sucher, zwei Modi** (#340): Unten schaltet die Kachelreihe (#439)
// zwischen „Barcode" und „KI-Foto" um, auf derselben Seite. Im KI-Modus
// steht statt der Vorschau des Barcode-Lesers der KI-Sucher
// (`ki_sucher.dart`) im Baum — `mobile_scanner` gibt die Kamera frei, und
// `camera` übernimmt sie. Zurück auf „Barcode" läuft der Leser wieder,
// dieselbe Sitzung: Was schon ausgewertet ist, bleibt ausgewertet.
// „Suchen" in derselben Reihe schließt die Kamera und öffnet die Suche
// (V21); „Nur kcal" tut nichts (V20).
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../design/glas_abstand.dart';
import '../health/health_provider.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import '../tag/laufender_tag_provider.dart';
import 'anlegen_blatt.dart';
// `ErfassenKopf` ist hier der Kopf mit Zähler (`erfassen_kacheln.dart`),
// nicht der gleichnamige Kopf der Blätter.
import 'erfassen_bausteine.dart' hide ErfassenKopf;
import 'erfassen_formular.dart';
import 'erfassen_kacheln.dart';
import 'erfassen_provider.dart';
import 'erfassen_weg.dart';
import 'ernaehrung_abschnitte.dart' show mahlzeitName;
import 'ernaehrung_provider.dart';
import 'kamera_bausteine.dart';
import 'kamera_unbekannt.dart';
import 'ki_sucher.dart';
import 'off_client.dart';
import 'portions_abruf.dart';
import 'strichcode_leser.dart';

/// Öffnet die Kamera auf dem Stapel des **aktuell gewählten** Tabs — wie
/// [oeffneSuche], aus demselben Grund: Ein Tab-Wechsel führte „zurück" in
/// ein Menü, das Tim nie geöffnet hat (`CLAUDE.md`).
///
/// [tagesSchluessel] ist der Tag, auf den gebucht wird; ohne ihn der
/// offene Tag des Ernährungs-Schirms ([offenerTagProvider]). [mahlzeit]
/// wählt im Buchungsblatt die Mahlzeit vor — nach dem Scan wie auf dem
/// Weg über „Suchen" (#344, vom Mahlzeiten-Schirm); ohne sie ergibt sie
/// sich aus der Uhrzeit.
///
/// [modus] ist der Weg, mit dem der Sucher öffnet — `ki` aus der Kachel
/// „KI-Foto" der Suche (#439). [gebucht] ist der Zähler der Sitzung, den
/// ein Wechsel aus der Suche mitgibt (V21).
///
/// **Ist schon eine Kamera offen, tut der Aufruf nichts** (#326) — sonst
/// legte jeder Tipp auf den (+) eine weitere Kamera auf den Stapel, und
/// „Abbrechen" führte in die nächste statt zurück. Das gilt für jede
/// Kamera dieser App, auch eine, die auf dem Stapel eines anderen Tabs
/// liegt.
///
/// *Vorgabe des Koordinators der Nachtrunde vom 05.11.2026, von Tim
/// **noch nicht entschieden**:* Das Ticket lässt offen, ob der (+) bei
/// offener Kamera nichts tut oder sie wie ein Umschalter schließt; „nichts
/// tun" nennt es die kleinere Überraschung. Entscheidet Tim anders, ändert
/// sich nur diese eine Abfrage.
void oeffneKamera(
  AppRouter router, {
  String? tagesSchluessel,
  Mahlzeit? mahlzeit,
  KameraModus modus = KameraModus.barcode,
  int gebucht = 0,
}) {
  if (kameraOffen(router)) return;
  router.open(
    AppTarget.aktuell(
      (context) => KameraSeite(
        router: router,
        tagesSchluessel: tagesSchluessel,
        mahlzeit: mahlzeit,
        modus: modus,
        gebucht: gebucht,
      ),
    ),
  );
}

/// Ob unter [router] schon eine Kamera im Baum steht (#326) — dann tut
/// [oeffneKamera] nichts. Die Suche fragt vorher, damit „Barcode" sie
/// nicht schließt, ohne dass eine Kamera aufgeht (#439).
bool kameraOffen(AppRouter router) => (_offeneKameras[router] ?? 0) > 0;

/// Wie viele Kameras je [AppRouter] gerade im Baum stehen (#326). Am
/// Router statt global, damit zwei Apps — etwa zwei Widget-Tests
/// nacheinander — einander nicht sehen.
final _offeneKameras = Expando<int>('offene Kameras');

/// Der Kamera-Schirm samt seiner Zustände.
///
/// **Kein eigener `Navigator`:** Er liegt auf dem Stapel eines Tabs, der
/// Stapel gehört weiter `RootView`.
class KameraSeite extends ConsumerStatefulWidget {
  const KameraSeite({
    super.key,
    required this.router,
    this.tagesSchluessel,
    this.mahlzeit,
    this.modus = KameraModus.barcode,
    this.gebucht = 0,
  });

  /// Für „Suchen": Die Suche wird über den Router geöffnet, nicht von
  /// diesem Schirm selbst geschoben (`CLAUDE.md`, „Sprünge laufen über
  /// `AppRouter`").
  final AppRouter router;

  final String? tagesSchluessel;

  /// Die vorgewählte Mahlzeit, `null` beim (+).
  final Mahlzeit? mahlzeit;

  /// Der Weg, mit dem der Sucher öffnet.
  final KameraModus modus;

  /// Was in dieser Sitzung schon gebucht ist — der Zähler im Kopf (V22).
  /// Die Kamera schließt nach einer Buchung (V26), zählt also selbst nicht
  /// weiter; sie zeigt und gibt weiter.
  final int gebucht;

  @override
  ConsumerState<KameraSeite> createState() => _KameraSeiteZustand();
}

class _KameraSeiteZustand extends ConsumerState<KameraSeite> {
  KameraLage _lage = const Sucht();

  /// Der (+) öffnet im Barcode-Modus — beim Markenprodukt ist er
  /// schneller und genauer (`erfassen.js`, Kopfkommentar). Aus der Suche
  /// kommt auch „KI-Foto" an (#439).
  late KameraModus _modus = widget.modus;

  /// Was in dieser Sitzung schon ausgewertet wurde. **Synchron gesetzt**,
  /// bevor irgendetwas gelesen wird: Die Nachfrage ist asynchron, und
  /// genau in diese Lücke fielen die nächsten Bilder derselben Packung.
  final _ausgewertet = <String>{};

  /// Solange nachgesehen wird oder ein Blatt offen ist, wird kein
  /// **anderer** Code angefangen — sonst lägen zwei Blätter übereinander.
  /// Ein so übergangener Code gilt nicht als ausgewertet; hält Tim ihn
  /// danach noch ins Bild, kommt er dran.
  bool _beschaeftigt = false;

  String get _tag => widget.tagesSchluessel ?? ref.read(offenerTagProvider);

  /// Der Router, unter dem diese Kamera gezählt ist — festgehalten, damit
  /// `dispose` dort abzieht, wo `initState` hinzugezählt hat.
  late final AppRouter _gezaehltBei;

  @override
  void initState() {
    super.initState();
    _gezaehltBei = widget.router;
    _offeneKameras[_gezaehltBei] = (_offeneKameras[_gezaehltBei] ?? 0) + 1;
  }

  @override
  void dispose() {
    _offeneKameras[_gezaehltBei] = (_offeneKameras[_gezaehltBei] ?? 1) - 1;
    super.dispose();
  }

  void _aufCode(String code) {
    if (_lage is Verweigert || _lage is Unbekannt) return;
    if (_ausgewertet.contains(code) || _beschaeftigt) return;
    _ausgewertet.add(code);
    _werteAus(code);
  }

  Future<void> _werteAus(String code) async {
    setState(() {
      _lage = Prueft(code);
      _beschaeftigt = true;
    });

    final befund = await _befundZu(
      code,
      ref.read(lebensmittelRepositoryProvider),
      ref.read(offClientProvider),
    );
    if (!mounted) return;

    switch (befund) {
      case _Buchbar(:final vorlage):
        await _buche(vorlage);
      case _Anders(:final lage):
        setState(() {
          _lage = lage;
          _beschaeftigt = false;
        });
    }
  }

  /// Öffnet das Buchungsblatt. **Nach dem Buchen ist die Kamera zu** —
  /// zurück, woher man kam (Entscheidung 1 des Koordinators). Nach
  /// „Abbrechen" steht die Kamera wieder da, die Sitzung läuft weiter.
  Future<void> _buche(LebensmittelVorlage vorlage) async {
    setState(() {
      _lage = const Sucht();
      _beschaeftigt = true;
    });

    // Samt Portionen und Vorwahl aus der letzten Buchung (#325).
    final formular = await ref
        .read(erfassenProvider.notifier)
        .oeffneFormular(
          vorlage: vorlage,
          tagesSchluessel: _tag,
          jetzt: ref.read(clockProvider)(),
          mahlzeit: widget.mahlzeit,
        );
    if (!mounted) return;
    // Ein vor #325 übernommenes Produkt fragt hier einmal nach seinen
    // Portionen (Entscheidung 6); das Nachschlagen selbst lief schon
    // über die eigene Tabelle. Ohne Bedarf ist [brauchtAbruf] `null`.
    final gebucht = await zeigeBuchungsBlatt(
      context,
      formular,
      abruf: brauchtAbruf(vorlage),
    );
    if (!mounted) return;
    if (gebucht) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _beschaeftigt = false);
  }

  /// „Produkt anlegen" aus `unbekannt` — Strichcode vorbelegt, bei einem
  /// Treffer ohne Kalorien auch der Name. **Danach direkt ins
  /// Buchungsblatt**: Wer eine Packung scannt, will sie essen, nicht nur
  /// ablegen (Entscheidung 1 des Koordinators).
  Future<void> _legeAn(Unbekannt lage) async {
    int? neu;
    await zeigeErfassenBlatt(
      context,
      (blattKontext) => AnlegenBlatt(
        name: lage.name,
        barcode: lage.code,
        onFertig: (id) {
          neu = id;
          Navigator.pop(blattKontext);
        },
      ),
    );
    final id = neu;
    if (id == null || !mounted) return;

    final vorlage = await ref.read(lebensmittelRepositoryProvider).lies(id);
    if (vorlage == null || !mounted) return;
    await _buche(vorlage);
  }

  /// In die Suche — **statt** der Kamera, nicht über ihr: Nach dem Buchen
  /// aus der Suche geht es zurück, woher man kam, und dort steht keine
  /// Kamera mehr dazwischen. Der Zähler geht mit (V21).
  void _zurSuche() {
    Navigator.of(context).pop();
    oeffneSuche(
      widget.router,
      tagesSchluessel: widget.tagesSchluessel,
      mahlzeit: widget.mahlzeit,
      gebucht: widget.gebucht,
    );
  }

  void _abbrechen() => Navigator.of(context).pop();

  /// Barcode ⇄ KI. „kein Netz" gehört zum Strichcode, den Tim gerade
  /// nicht mehr hinhält; die Verweigerung gilt für die Kamera und bleibt.
  void _wechsle(KameraModus modus) => setState(() {
    _modus = modus;
    if (_lage is OhneNetz) _lage = const Sucht();
  });

  /// Ein Tipp auf eine Kachel. Den Weg, auf dem man ist, und „Nur kcal"
  /// meldet die Reihe gar nicht erst.
  ///
  /// Barcode und KI-Foto sind gesperrt, solange ein Strichcode nachgesehen
  /// wird oder sein Blatt offen ist — sonst käme das Buchungsblatt über dem
  /// KI-Sucher an. „Suchen" bleibt offen, wie bis #439 oben rechts.
  void _aufWeg(ErfassenWeg weg) {
    switch (weg) {
      case ErfassenWeg.barcode when !_beschaeftigt:
        _wechsle(KameraModus.barcode);
      case ErfassenWeg.ki when !_beschaeftigt:
        _wechsle(KameraModus.ki);
      case ErfassenWeg.suchen:
        _zurSuche();
      case ErfassenWeg.barcode || ErfassenWeg.ki || ErfassenWeg.nurKcal:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final leser = ref.watch(strichcodeLeserProvider);
    final lage = _lage;

    if (lage is Unbekannt) {
      return UnbekanntAnsicht(
        key: const Key('kamera'),
        lage: lage,
        aufAbbrechen: _abbrechen,
        aufAnlegen: () => _legeAn(lage),
        aufSuchen: _zurSuche,
      );
    }

    final kacheln = ErfassenKacheln(
      aktiv: _modus == KameraModus.ki ? ErfassenWeg.ki : ErfassenWeg.barcode,
      dunkel: true,
      aufWeg: _aufWeg,
    );
    // Zwei Zeilen wie in `erfassen_weg.dart`: `?? ref.watch(…)` ließe den
    // Analyzer `String?` ableiten.
    final offen = ref.watch(offenerTagProvider);
    final tag = widget.tagesSchluessel ?? offen;
    // Dieselbe Mahlzeit, die das Buchungsblatt vorwählt (V22) — mit
    // demselben Grund des laufenden Tages (#456).
    final titel = mahlzeitName(
      vorgewaehlteMahlzeit(
        jetzt: ref.watch(clockProvider)(),
        mahlzeit: widget.mahlzeit,
        grund: ref.watch(
          laufenderTagProvider.select((s) => buchungsgrund(s, tag)),
        ),
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Helle Statusleiste auf dem fast schwarzen Sucher.
      value: SystemUiOverlayStyle.light,
      child: ColoredBox(
        key: const Key('kamera'),
        color: kameraSchwarz,
        child: Padding(
          padding: GlasAbstand.of(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ErfassenKopf(
                gebucht: widget.gebucht,
                titel: titel,
                aufAbbrechen: _abbrechen,
                dunkel: true,
                abbrechenSchluessel: const Key('kamera-abbrechen'),
              ),
              if (_modus == KameraModus.ki)
                KiSucher(
                  router: widget.router,
                  kacheln: kacheln,
                  tag: () => _tag,
                  mahlzeit: widget.mahlzeit,
                  verweigert: lage is Verweigert,
                  aufVerweigert: () =>
                      setState(() => _lage = const Verweigert()),
                  aufEinstellungen: leser.oeffneEinstellungen,
                )
              else ...[
                SucherFenster(
                  lage: lage,
                  sucher: lage is Verweigert
                      ? null
                      : leser.sucher(
                          aufCode: _aufCode,
                          aufVerweigert: () =>
                              setState(() => _lage = const Verweigert()),
                        ),
                  aufNochmal: lage is OhneNetz
                      ? () => _werteAus(lage.code)
                      : null,
                  aufEinstellungen: leser.oeffneEinstellungen,
                ),
                kacheln,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Was ein Code ergibt — buchbar, oder ein anderer Zustand des Schirms.
sealed class _Befund {
  const _Befund();
}

final class _Buchbar extends _Befund {
  const _Buchbar(this.vorlage);
  final LebensmittelVorlage vorlage;
}

final class _Anders extends _Befund {
  const _Anders(this.lage);
  final KameraLage lage;
}

/// Erst die eigene Tabelle, dann Open Food Facts.
///
/// **Ein Treffer aus der eigenen Tabelle fragt das Netz nicht** — auch
/// dann nicht, wenn er aus Open Food Facts übernommen ist: Die eigene
/// Tabelle ist die Wahrheit, und offline ist das Produkt sofort da.
///
/// **Ein Treffer aus Open Food Facts bleibt ohne Schlüssel** —
/// `OffProdukt.alsVorlage()`; übernommen wird erst beim Buchen
/// (`ErfassenNotifier.buche`). Wer nur scannt und abbricht, hat nichts
/// angelegt.
Future<_Befund> _befundZu(
  String code,
  LebensmittelRepository repo,
  OffClient off,
) async {
  final eigen = await repo.zuBarcode(code);
  if (eigen != null) return _Buchbar(eigen);

  return switch (await off.produktZuBarcode(code)) {
    Treffer(:final produkte) when produkte.first.buchbar => _Buchbar(
      produkte.first.alsVorlage(),
    ),
    // Gelieferte, aber unbrauchbare Angabe: derselbe Weg wie „nicht
    // hinterlegt", mit dem Namen vorbelegt (Entscheidung 3 des
    // Koordinators). Kein „kein Netz" — OFF hat geantwortet.
    Treffer(:final produkte) => _Anders(
      Unbekannt(code, name: produkte.first.name),
    ),
    NichtGefunden() => _Anders(Unbekannt(code)),
    KeinNetz() => _Anders(OhneNetz(code)),
  };
}
