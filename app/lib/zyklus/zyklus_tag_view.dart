// Der Schirm „Tag eintragen" (#572 unter #539) — was an einem Tag war:
// Blutung, Schmerzen, Symptome, Sex, Test, Notiz.
//
// API und Verhalten sind durch `app/test/zyklus/zyklus_tag_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/zyklus-tag.js`, Varianten `leer`,
// `periodentag`, `test-positiv` und `hilfe`. Spec:
// `docs/superpowers/specs/2026-11-23-zyklus-spec.md`, Abschnitte 4.1, 4.3.2
// und 7.
//
// **Ein geschobener Schirm, kein Blatt** (Entwurf): Es sind sechs
// Abschnitte, und ein Blatt, das fast den ganzen Schirm füllt, ist ein
// Schirm mit einem Griff obendrauf.
//
// **Löschen heißt leeren.** Es gibt keinen „Eintrag löschen"-Knopf; wer
// alles abwählt und sichert, hinterlässt keinen Tag (Spec 4.1 —
// `ZyklusRepository.schreibe` löscht die Zeile dann). Darum ist „Sichern"
// auch dann an, wenn der Schirm **weniger** zeigt als die Ablage: Ohne das
// ließe sich ein Tag über diesen Schirm nie zurücknehmen.
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/zyklus_repository.dart';
import '../design/formatierung.dart';
import '../design/formular.dart';
import '../design/glas_abstand.dart';
import '../design/hilfe.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'zyklus_symptome.dart';
import 'zyklus_texte.dart';
import 'zyklus_zustand.dart';

/// Öffnet „Tag eintragen" für [tag] auf dem Stapel des **aktuell
/// gewählten** Tabs.
///
/// [tag] ist der ISO-Tagesstring des Tages, der eingetragen wird — nie
/// „heute": Jeder Kalendertag ist eine Tür, und welcher gemeint ist,
/// entscheidet der Aufrufer (Spec 7).
void oeffneZyklusTag(AppRouter router, {required String tag}) =>
    router.open(AppTarget.aktuell((context) => ZyklusTagSeite(tag: tag)));

/// **Kein eigener `Navigator`:** Dieser Schirm wird geschoben.
class ZyklusTagSeite extends ConsumerStatefulWidget {
  const ZyklusTagSeite({super.key, required this.tag});

  /// Der Tag, der eingetragen wird, als ISO-Tagesstring.
  final String tag;

  @override
  ConsumerState<ZyklusTagSeite> createState() => _ZyklusTagZustand();
}

class _ZyklusTagZustand extends ConsumerState<ZyklusTagSeite> {
  /// Was im Formular steht. `null`, solange nichts gelesen **und** nichts
  /// angefasst ist — dann steht überall die leere Form.
  _Stand? _stand;

  /// Was in der Ablage steht — der Maßstab für „gibt es etwas zu sichern".
  /// `null`, solange das nicht feststeht.
  _Stand? _abgelegt;

  /// Ob die Nutzerin schon etwas angefasst hat. Wer tippt, während noch
  /// gelesen wird, behält seine Wahl.
  bool _bearbeitet = false;

  bool _testOffen = false;
  bool _notizOffen = false;

  final TextEditingController _notizFeld = TextEditingController();

  @override
  void dispose() {
    _notizFeld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(zyklusTagProvider(widget.tag));
    final gelesen = switch (zustand) {
      final ZyklusTagGelesen g => g,
      ZyklusTagLaedt() || ZyklusTagUnlesbar() => null,
    };
    if (gelesen != null) _uebernimmNachDemBild(gelesen);

    final form = _stand ?? const _Stand();
    final abgelegt = _abgelegt;

    return CupertinoPageScaffold(
      key: const Key('zyklus-tag'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: const Text(zyklusTagTitel),
        trailing: CupertinoButton(
          key: const Key('zyklus-tag-sichern'),
          padding: EdgeInsets.zero,
          minimumSize: const Size(44, 36),
          // **Aus, solange nichts gelesen ist** (`01`): Ein Sichern, das
          // schreibt, bevor feststeht, was abgelegt ist, überschriebe den
          // Tag mit Leere — und leer heißt gelöscht (Spec 4.1).
          onPressed: abgelegt == null || form == abgelegt ? null : _sichere,
          child: const Text('Sichern'),
        ),
      ),
      // **`Builder`, damit der Abstand unter der Leiste stimmt:**
      // `CupertinoPageScaffold` schreibt die Höhe seiner durchscheinenden
      // Navigationsleiste in die `MediaQuery` seines **Kindes**. Mit dem
      // Kontext des Schirms selbst läge der Kopf unter der Leiste.
      child: Builder(
        builder: (context) => SingleChildScrollView(
          // Unten durchzeichnen statt abschneiden (`CLAUDE.md`,
          // flutter#179482): Unter der halbtransparenten Tastatur zeichnet
          // Flutter sonst nicht, und dort steht dann Schwarz.
          padding:
              GlasAbstand.of(context) +
              EdgeInsets.only(
                bottom: 32 + MediaQuery.of(context).viewInsets.bottom,
              ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _abschnitte(context, form, gelesen),
          ),
        ),
      ),
    );
  }

  List<Widget> _abschnitte(
    BuildContext context,
    _Stand form,
    ZyklusTagGelesen? gelesen,
  ) => [
    _kopf(context, gelesen),
    _abschnitt(
      name: 'blutung',
      titel: zyklusAbschnittBlutung,
      marke: _marke(gelesen, form.blutung == null),
      karte: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _stufen(
            context,
            praefix: 'zyklus-tag-blutung',
            namen: [null, ...Blutungsstaerke.values.map((s) => s.name)],
            gewaehlt: form.blutung?.name,
            aufWahl: (name) => _aendere(
              form.kopieMit(
                blutung: name == null
                    ? null
                    : Blutungsstaerke.values.byName(name),
              ),
            ),
          ),
          _trenner(context),
          _schalter(
            schluessel: 'zyklus-tag-zwischenblutung',
            beschriftung: zyklusZwischenblutung,
            an: form.zwischenblutung,
            aufAenderung: (an) => _aendere(form.kopieMit(zwischenblutung: an)),
          ),
        ],
      ),
    ),
    _abschnitt(
      name: 'schmerzen',
      titel: zyklusAbschnittSchmerzen,
      marke: _marke(gelesen, form.schmerz == null),
      karte: _stufen(
        context,
        praefix: 'zyklus-tag-schmerz',
        namen: [null, ...Schmerzstaerke.values.map((s) => s.name)],
        gewaehlt: form.schmerz?.name,
        aufWahl: (name) => _aendere(
          form.kopieMit(
            schmerz: name == null ? null : Schmerzstaerke.values.byName(name),
          ),
        ),
      ),
    ),
    _abschnitt(
      name: 'symptome',
      titel: zyklusAbschnittSymptome,
      karte: _symptome(context, form),
    ),
    _abschnitt(
      name: 'sex',
      titel: zyklusAbschnittSex,
      karte: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _schalter(
            schluessel: 'zyklus-tag-sex',
            beschriftung: zyklusSexGehabt,
            an: form.sex,
            aufAenderung: (an) => _aendere(form.kopieMit(sex: an)),
          ),
          // **„Verhütet" steht erst, wenn „Sex gehabt" an ist** (Spec
          // 4.1): Ein Schalter ohne seinen Anlass fragt etwas, das
          // niemand beantworten kann.
          if (form.sex) ...[
            _trenner(context),
            _schalter(
              schluessel: 'zyklus-tag-verhuetet',
              beschriftung: zyklusVerhuetet,
              an: form.verhuetet ?? false,
              aufAenderung: (an) => _aendere(form.kopieMit(verhuetet: an)),
            ),
          ],
        ],
      ),
    ),
    _abschnitt(
      name: 'test',
      titel: zyklusAbschnittTest,
      karte: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormZeile(
            key: const Key('zyklus-tag-test'),
            beschriftung: zyklusTestErgebnis,
            // Solange nichts gelesen ist, steht hier **nichts** — „nicht
            // gemacht" wäre eine Aussage über den Tag (`01`).
            wert: gelesen == null
                ? ''
                : form.test?.name ?? zyklusTestNichtGemacht,
            platzhalter: form.test == null,
            aufTipp: () => setState(() => _testOffen = !_testOffen),
          ),
          if (_testOffen) ...[
            _trenner(context),
            _stufen(
              context,
              praefix: 'zyklus-tag-test',
              namen: [null, ...Testergebnis.values.map((e) => e.name)],
              keinName: 'keins',
              gewaehlt: form.test?.name,
              aufWahl: (name) => _aendere(
                form.kopieMit(
                  test: name == null ? null : Testergebnis.values.byName(name),
                ),
              ),
            ),
          ],
          // **Bleibt sichtbar: was dieser Eintrag auslöst.** Eine Wirkung
          // auf einen anderen Schirm hinter einem Fragezeichen wäre eine
          // verschwiegene Wirkung, und eine Vorhersage, die
          // stillschweigend aufhört, ein Fehler, den niemand findet.
          if (form.test == Testergebnis.positiv) ...[
            _trenner(context),
            const PflichtZeile(
              key: Key('zyklus-tag-test-wirkung'),
              text: zyklusTestWirkung,
            ),
          ],
        ],
      ),
    ),
    _abschnitt(
      name: 'notiz',
      titel: zyklusAbschnittNotiz,
      karte: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FormZeile(
            key: const Key('zyklus-tag-notiz'),
            beschriftung: zyklusNotizFreitext,
            wert: gelesen == null ? '' : form.notiz ?? zyklusNichtsNotiert,
            platzhalter: form.notiz == null,
            aufTipp: () => setState(() {
              _notizOffen = !_notizOffen;
              if (_notizOffen) _notizFeld.text = form.notiz ?? '';
            }),
          ),
          if (_notizOffen) ...[
            _trenner(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: CupertinoTextField(
                controller: _notizFeld,
                maxLines: 3,
                minLines: 2,
                placeholder: zyklusNichtsNotiert,
                onChanged: (text) => _aendere(
                  (_stand ?? const _Stand()).kopieMit(
                    notiz: text.trim().isEmpty ? null : text,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  ];

  /// Der Kopf: Datum und Zyklustag des Tages, **für den der Schirm
  /// geöffnet wurde** — nicht für heute.
  ///
  /// Die zweite Zeile hat eine **feste Höhe**: Solange nicht feststeht,
  /// welcher Zyklustag das ist, steht dort nichts, und ohne reservierte
  /// Höhe rutschte der ganze Schirm, sobald die Zahl eintrifft.
  Widget _kopf(BuildContext context, ZyklusTagGelesen? gelesen) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 14, 20, 2),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Format.wochentagUndDatum(datumZumAnzeigen(widget.tag)),
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: CupertinoDynamicColor.resolve(Palette.ink, context),
          ),
        ),
        SizedBox(
          height: 18,
          child: Text(
            _zyklustagText(gelesen),
            style: TextStyle(
              fontSize: 13,
              color: CupertinoDynamicColor.resolve(Palette.muted, context),
            ),
          ),
        ),
      ],
    ),
  );

  /// „Zyklustag 9", am Periodenstart „Zyklustag 1 · Periodenbeginn".
  ///
  /// Leer, solange nichts gelesen ist, und leer vor der ersten bekannten
  /// Periode: Dort **gibt** es keinen Zyklustag, und eine erfundene Zahl
  /// wäre schlechter als keine.
  String _zyklustagText(ZyklusTagGelesen? gelesen) {
    final zyklustag = gelesen?.zyklustag;
    if (zyklustag == null) return '';
    if (zyklustag == 1) return 'Zyklustag 1 · Periodenbeginn';
    return 'Zyklustag $zyklustag';
  }

  /// Die Marke am Abschnittskopf — **nur, wenn feststeht, dass nichts
  /// gewählt ist**. Während des Lesens blitzte sie sonst auf, bevor der
  /// Wert dasteht, und das ist Fehler `01`.
  String? _marke(ZyklusTagGelesen? gelesen, bool leer) =>
      gelesen != null && leer ? zyklusNichtsGewaehlt : null;

  /// Kopf **und** Karte eines Abschnitts — sie gehören zusammen.
  Widget _abschnitt({
    required String name,
    required String titel,
    required Widget karte,
    String? marke,
  }) => Column(
    key: Key('zyklus-tag-abschnitt-$name'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      HilfeKopf(titel: titel, marke: marke, aufHilfe: _zeigeHilfe),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: InsetCard(child: karte),
      ),
    ],
  );

  /// Eine Wahl aus wenigen Stufen — `segmented` im Entwurf.
  ///
  /// Der erste Eintrag ist **keine Stufe, sondern die Rücknahme**: Er
  /// nimmt zurück, was gewählt war („Löschen heißt leeren").
  Widget _stufen(
    BuildContext context, {
    required String praefix,
    required List<String?> namen,
    required String? gewaehlt,
    required ValueChanged<String?> aufWahl,
    String keinName = 'keine',
  }) {
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
            for (final name in namen)
              Expanded(
                child: GestureDetector(
                  key: Key('$praefix-${name ?? keinName}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => aufWahl(name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    alignment: Alignment.center,
                    decoration: name == gewaehlt
                        ? BoxDecoration(
                            color: flaeche,
                            borderRadius: BorderRadius.circular(7),
                          )
                        : null,
                    child: Text(
                      name ?? keinName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: name == gewaehlt
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: name == gewaehlt ? ink : muted,
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

  /// Die zwölf Symptome als Chips — `wahlChips` im Entwurf.
  ///
  /// Eine eigene Form neben den Stufen, weil dort genau eine Wahl gilt:
  /// Bei zwölf Einträgen wäre jede Spalte drei Zeichen breit.
  Widget _symptome(BuildContext context, _Stand form) {
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Wrap(
        spacing: 7,
        runSpacing: 7,
        children: [
          for (final symptom in zyklusSymptome)
            GestureDetector(
              key: Key('zyklus-tag-symptom-${symptom.schluessel}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _aendere(form.mitSymptom(symptom.schluessel)),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: form.symptome.contains(symptom.schluessel)
                      ? river.withValues(alpha: 0.16)
                      : line.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  symptom.name,
                  style: TextStyle(
                    fontSize: 13.5,
                    color: form.symptome.contains(symptom.schluessel)
                        ? river
                        : ink,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Eine Schalterzeile, **in ganzer Breite antippbar**: Ein Schieber von
  /// 50 Punkt am rechten Rand ist das kleinere Ziel, und die Zeile sagt
  /// ohnehin dasselbe.
  Widget _schalter({
    required String schluessel,
    required String beschriftung,
    required bool an,
    required ValueChanged<bool> aufAenderung,
  }) => GestureDetector(
    key: Key(schluessel),
    behavior: HitTestBehavior.opaque,
    onTap: () => aufAenderung(!an),
    child: SchalterZeile(
      beschriftung: beschriftung,
      an: an,
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

  /// Was erklärt, steht hinter dem `?` (Fassung C, `CLAUDE.md`). Alle
  /// sechs Köpfe öffnen **dasselbe** Blatt: Es ist eine Erklärung des
  /// Schirms, keine sechs.
  void _zeigeHilfe() => zeigeHilfeBlatt(
    context,
    titel: zyklusTagHilfeTitel,
    pflicht: zyklusTagHilfePflicht,
    bloecke: const [
      HilfeBlock(
        titel: zyklusTagHilfeBlutungTitel,
        text: zyklusTagHilfeBlutungText,
        ton: Palette.blut,
      ),
      HilfeBlock(
        titel: zyklusTagHilfeJederTagTitel,
        text: zyklusTagHilfeJederTagText,
        ton: Palette.river2,
      ),
      HilfeBlock(
        titel: zyklusTagHilfeNichtsTitel,
        text: zyklusTagHilfeNichtsText,
        ton: Palette.muted,
      ),
      HilfeBlock(
        titel: zyklusTagHilfeSymptomeTitel,
        text: zyklusTagHilfeSymptomeText,
        ton: Palette.iron,
      ),
      HilfeBlock(
        titel: zyklusTagHilfeSexTitel,
        text: zyklusTagHilfeSexText,
        ton: Palette.ok,
      ),
      HilfeBlock(
        titel: zyklusTagHilfeTestTitel,
        text: zyklusTagHilfeTestText,
        ton: Palette.river,
      ),
    ],
  );

  // ───────────────────────────────────────────────────────────────────────
  // Übernehmen und Sichern
  // ───────────────────────────────────────────────────────────────────────

  void _aendere(_Stand neu) => setState(() {
    _bearbeitet = true;
    _stand = neu;
  });

  /// Der gelesene Stand wandert **nach** dem Bild ins Formular:
  /// `setState` während des Bauens löste einen zweiten Aufbau aus, während
  /// der erste noch läuft.
  ///
  /// Übernommen wird **jedes Mal, wenn sich die Ablage ändert**, nicht nur
  /// beim ersten Lesen: Der Schirm kann aufgehen, während die Tabelle noch
  /// gelesen wird oder während sie sich an ihm vorbei ändert. Ein einmal
  /// gesetzter Merker ließe ihn dann für immer das Falsche zeigen (`32`).
  ///
  /// Was schon gewählt wurde, bleibt dabei stehen — wer tippt, während
  /// gelesen wird, behält seine Wahl. Der Maßstab [_abgelegt] wandert
  /// trotzdem mit: Sonst vergliche „Sichern" gegen einen Stand, den es
  /// nicht mehr gibt.
  void _uebernimmNachDemBild(ZyklusTagGelesen gelesen) {
    final frisch = _Stand.aus(gelesen.eintrag);
    if (frisch == _abgelegt) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || frisch == _abgelegt) return;
      setState(() {
        _abgelegt = frisch;
        if (!_bearbeitet) _stand = frisch;
      });
    });
  }

  /// Schreibt den **ganzen** Tag und geht zu.
  ///
  /// Ist nichts mehr gewählt, löscht das Repository die Zeile (Spec 4.1):
  /// Ein leerer Tag ist ein Tag ohne Zeile. Neu gelesen wird nichts von
  /// Hand — die Provider hängen an der Tabelle und melden sich selbst.
  Future<void> _sichere() async {
    final eintrag = (_stand ?? const _Stand()).alsEintrag(widget.tag);
    await ref.read(zyklusRepositoryProvider).schreibe(eintrag);
    if (!mounted) return;
    Navigator.of(context).pop();
  }
}

/// Was im Formular steht — die editierbaren Felder eines Tageseintrags.
///
/// **Werttyp mit `==`**, denn genau daran hängt „gibt es etwas zu
/// sichern": Der Stand wird mit dem verglichen, was in der Ablage steht.
/// `quelle` und `geaendert` gehören nicht dazu — sie sagen etwas über die
/// Zeile, nicht über den Tag.
@immutable
class _Stand {
  const _Stand({
    this.blutung,
    this.zwischenblutung = false,
    this.schmerz,
    this.symptome = const {},
    this.sex = false,
    this.verhuetet,
    this.test,
    this.notiz,
  });

  /// Der Stand eines abgelegten Tages — oder der leere, wenn es ihn nicht
  /// gibt.
  factory _Stand.aus(ZyklusEintrag? eintrag) {
    if (eintrag == null) return const _Stand();
    return _Stand(
      blutung: eintrag.blutung,
      zwischenblutung: eintrag.zwischenblutung,
      schmerz: eintrag.schmerz,
      // **Auch unbekannte Schlüssel** (etwa aus einer späteren Fassung):
      // Angezeigt werden sie nicht, aber beim Sichern gehen sie wieder
      // mit — sonst löschte ein Besuch dieses Schirms sie still.
      symptome: Set.unmodifiable(eintrag.symptome),
      sex: eintrag.sex,
      verhuetet: eintrag.verhuetet,
      test: eintrag.test,
      notiz: eintrag.notiz,
    );
  }

  final Blutungsstaerke? blutung;
  final bool zwischenblutung;
  final Schmerzstaerke? schmerz;

  /// Die gewählten Symptomschlüssel. **Eine Menge, keine Liste:** Welche
  /// gewählt sind, ist eine Auswahl; ihre Reihenfolge trägt nichts, und
  /// zwei gleich befüllte Listen in anderer Ordnung wären sonst ungleich
  /// und machten „Sichern" grundlos an.
  final Set<String> symptome;

  final bool sex;

  /// `null`, wenn dazu nichts eingetragen ist — nur sinnvoll, wenn [sex]
  /// (Spec 4.1).
  final bool? verhuetet;

  final Testergebnis? test;
  final String? notiz;

  /// Steht für „dieses Feld bleibt, wie es ist" — `null` ist hier ein
  /// gültiger Wert und taugt dafür nicht.
  static const Object _unveraendert = Object();

  _Stand kopieMit({
    Object? blutung = _unveraendert,
    bool? zwischenblutung,
    Object? schmerz = _unveraendert,
    Set<String>? symptome,
    bool? sex,
    Object? verhuetet = _unveraendert,
    Object? test = _unveraendert,
    Object? notiz = _unveraendert,
  }) => _Stand(
    blutung: identical(blutung, _unveraendert)
        ? this.blutung
        : blutung as Blutungsstaerke?,
    zwischenblutung: zwischenblutung ?? this.zwischenblutung,
    schmerz: identical(schmerz, _unveraendert)
        ? this.schmerz
        : schmerz as Schmerzstaerke?,
    symptome: symptome ?? this.symptome,
    sex: sex ?? this.sex,
    verhuetet: identical(verhuetet, _unveraendert)
        ? this.verhuetet
        : verhuetet as bool?,
    test: identical(test, _unveraendert) ? this.test : test as Testergebnis?,
    notiz: identical(notiz, _unveraendert) ? this.notiz : notiz as String?,
  );

  /// Nimmt ein Symptom dazu oder wieder heraus.
  _Stand mitSymptom(String schluessel) => kopieMit(
    symptome: {
      for (final gewaehlt in symptome)
        if (gewaehlt != schluessel) gewaehlt,
      if (!symptome.contains(schluessel)) schluessel,
    },
  );

  /// Der Tageseintrag, der abgelegt wird.
  ///
  /// `verhuetet` geht nur mit, wenn [sex] an ist (Spec 4.1), und die
  /// Symptome gehen in **Katalogreihenfolge** hinein — unbekannte
  /// Schlüssel hinten dran, damit sie nicht verloren gehen. Ohne feste
  /// Reihenfolge stünde derselbe Tag je nach Tippfolge anders in der
  /// Spalte.
  ///
  /// `quelle` ist [ZyklusQuelle.eigen]: Was über diesen Schirm geht, hat
  /// die Nutzerin eingetragen — auch wenn der Tag einmal aus Apple Health
  /// kam.
  ZyklusEintrag alsEintrag(String tag) => ZyklusEintrag(
    tag: tag,
    blutung: blutung,
    zwischenblutung: zwischenblutung,
    schmerz: schmerz,
    symptome: [
      for (final symptom in zyklusSymptome)
        if (symptome.contains(symptom.schluessel)) symptom.schluessel,
      for (final schluessel in symptome)
        if (symptomZu(schluessel) == null) schluessel,
    ],
    sex: sex,
    verhuetet: sex ? verhuetet : null,
    test: test,
    notiz: notiz,
  );

  @override
  bool operator ==(Object other) =>
      other is _Stand &&
      other.blutung == blutung &&
      other.zwischenblutung == zwischenblutung &&
      other.schmerz == schmerz &&
      setEquals(other.symptome, symptome) &&
      other.sex == sex &&
      other.verhuetet == verhuetet &&
      other.test == test &&
      other.notiz == notiz;

  @override
  int get hashCode => Object.hash(
    blutung,
    zwischenblutung,
    schmerz,
    Object.hashAllUnordered(symptome),
    sex,
    verhuetet,
    test,
    notiz,
  );
}
