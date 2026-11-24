// Das Prüfblatt der Foto-Schätzung (#341, #330) — `docs/screens/screens/
// erfassen.js`, Zustände `foto-schaetzt`, `foto-ergebnis`,
// `foto-geaendert`, `foto-unbrauchbar`, `foto-fehler`, `foto-schluessel`,
// `foto-kontingent`; Spec `docs/superpowers/specs/2026-11-04-ki-zugang-
// design.md`, „Foto-Schätzung als erste Aktion", Schritte 4–7.
//
// Verhalten durch `app/test/ernaehrung/ki_pruefblatt_test.dart`
// vorgegeben — diese Datei darf die Tests ausführen, aber nicht verändern
// (`CLAUDE.md`).
//
// **Die KI legt nichts selbst an.** Ihre Antwort ist ein Vorschlag, und
// gebucht wird erst mit Tims Tipp: Der Knopf hier ist der **einzige**
// Aufrufer von `KiAktionen.fuehreAus` (`ki_aktionen_test.dart` wacht
// darüber).
//
// **Eine Form in jedem Zustand** (`CLAUDE.md`): Bild, „Schätzung, keine
// exakten Werte", eine Ergebnisfläche fester Mindesthöhe, darunter die
// Knöpfe — und „Buchen" immer ganz unten an derselben Stelle, aus, solange
// es nichts zu buchen gibt. Nur die Füllung wechselt. Ausnahme seit
// #349: Der Vorschlag ist so hoch wie seine Posten (siehe [_Flaeche]).
//
// **Das Foto wird nach dem Buchen verworfen** (Tim, 04.11.2026) — und
// ebenso, wenn das Blatt auf anderem Weg geht. Es liegt nur in
// `kiFotoProvider`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../design/glas_abstand.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../ki/gemini_client.dart';
import '../ki/ki_aktionen.dart';
import '../ki/ki_zugang_provider.dart';
import '../ki/ki_zugang_view.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'buchungs_blatt.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_provider.dart';
import 'erfassen_weg.dart';
import 'ki_pruefblatt_naehrwerte.dart';
import 'ki_pruefblatt_zeilen.dart';
import 'ki_schaetzung_provider.dart';
import 'ki_sucher.dart';

/// Die echte Fassung von `kiSchaetzungStartenProvider`: schiebt das
/// Prüfblatt auf den Stapel des Tabs, in dem die Kamera liegt.
///
/// [context] ist der des `KiSucher` — **nur von dort** wird gestartet. Von
/// ihm kommen der Router (Sprünge laufen über `AppRouter`, `CLAUDE.md`)
/// und die Route der Kamera, zu der das Blatt zurückkehrt.
Future<void> zeigeKiPruefblatt(BuildContext context, KiAuftrag auftrag) async {
  final sucher = context.widget;
  if (sucher is! KiSucher) {
    throw StateError('Das Prüfblatt startet nur aus dem KI-Sucher.');
  }
  final wege = KiPruefWege(
    router: sucher.router,
    kamera: ModalRoute.of(context),
    auftrag: auftrag,
  );
  sucher.router.open(
    AppTarget.aktuell((_) => KiPruefSeite(auftrag: auftrag, wege: wege)),
  );
}

/// Die Wege aus dem Prüfblatt hinaus.
class KiPruefWege {
  const KiPruefWege({
    required this.router,
    required this.kamera,
    required this.auftrag,
  });

  final AppRouter router;

  /// Die Route der Kamera unter dem Blatt.
  final ModalRoute<Object?>? kamera;

  final KiAuftrag auftrag;

  /// Zurück in den Sucher — für ein neues Foto.
  void zurKamera(BuildContext context) =>
      Navigator.of(context).popUntil((route) => route == kamera);

  /// Blatt **und** Kamera zu — zurück, woher man kam. Nach dem Buchen wie
  /// beim Barcode (`KameraSeite._buche`).
  void schliesseKamera(BuildContext context) {
    final navigator = Navigator.of(context)
      ..popUntil((route) => route == kamera);
    if (navigator.canPop()) navigator.pop();
  }

  /// „Stattdessen suchen": **statt** der Kamera, nicht über ihr — wie
  /// „Suchen" im Sucher.
  void zurSuche(BuildContext context) {
    schliesseKamera(context);
    oeffneSuche(
      router,
      tagesSchluessel: auftrag.tagesSchluessel,
      mahlzeit: auftrag.mahlzeit,
    );
  }

  /// „Zum KI-Zugang" — über der Kamera; zurück steht der Sucher bereit.
  void zumZugang(BuildContext context) {
    zurKamera(context);
    oeffneKiZugang(router);
  }
}

/// Gerüst, Navigationsleiste und Inhalt des Prüfblatts. **Kein eigener
/// `Navigator`** — den stellt `RootView`.
class KiPruefSeite extends ConsumerStatefulWidget {
  const KiPruefSeite({super.key, required this.auftrag, required this.wege});

  final KiAuftrag auftrag;
  final KiPruefWege wege;

  @override
  ConsumerState<KiPruefSeite> createState() => _KiPruefSeiteZustand();
}

class _KiPruefSeiteZustand extends ConsumerState<KiPruefSeite> {
  /// Der Hinweis an die KI — seit #355 der einzige Ort dafür; „Neu
  /// berechnen" schickt ihn mit. Beginnt leer.
  final _hinweis = TextEditingController();

  bool _bucht = false;

  @override
  void dispose() {
    _hinweis.dispose();
    super.dispose();
  }

  KiSchaetzungNotifier get _schaetzung =>
      ref.read(kiSchaetzungProvider(widget.auftrag).notifier);

  /// Gebucht wird über den einen Ausführer. Danach: Foto verwerfen, Blatt
  /// und Kamera zu — den Tag liest der Ausführer selbst neu.
  Future<void> _buche(Vorschlag vorschlag) async {
    setState(() => _bucht = true);
    try {
      await ref
          .read(kiAktionenProvider.notifier)
          .fuehreAus(vorschlag.vorschlag);
    } catch (_) {
      // Ein gescheitertes Buchen schließt nichts — sonst wäre der
      // Vorschlag weg.
      if (mounted) setState(() => _bucht = false);
      return;
    }
    if (!mounted) return;
    // Gebucht ist gebucht. Fehlte die Freigabe für Health, sagt das **ein**
    // Hinweis — wie im Buchungsblatt (`keine-freigabe`).
    if (ref.read(healthSchreibHinweisProvider)) {
      await zeigeHealthSchreibHinweis(context);
      ref.read(healthSchreibHinweisProvider.notifier).gesehen();
      if (!mounted) return;
    }
    ref.read(kiFotoProvider.notifier).verwirf();
    widget.wege.schliesseKamera(context);
  }

  Future<void> _aendereZeile(int index, SchaetzPosten posten) async {
    final aktion = await zeigeZeilenAktionen(context, posten.name);
    if (aktion == null || !mounted) return;
    switch (aktion) {
      case ZeilenAktion.menge:
        final gramm = await zeigeMengenDialog(context, posten.gramm);
        if (gramm != null && mounted) _schaetzung.aendereMenge(index, gramm);
      case ZeilenAktion.tauschen:
        final vorlage = await _waehle();
        if (vorlage != null && mounted) _schaetzung.tausche(index, vorlage);
      case ZeilenAktion.streichen:
        _schaetzung.streiche(index);
    }
  }

  Future<void> _ergaenze() async {
    final vorlage = await _waehle();
    if (vorlage != null && mounted) _schaetzung.ergaenze(vorlage);
  }

  Future<LebensmittelVorlage?> _waehle() async {
    final vorlage = await waehleLebensmittel(context);
    if (mounted) ref.read(suchtextProvider.notifier).setze('');
    return vorlage;
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(kiSchaetzungProvider(widget.auftrag));
    final foto = ref.watch(kiFotoProvider);
    final zugang = ref.watch(kiZugangProvider);
    // Eine laufende Anfrage läuft zu Ende; eine neue startet über dem
    // Limit nicht (Spec, „Verbrauch und Limit").
    final limit = zugang is MitSchluessel && zugang.topf.erreicht
        ? zugang.topf
        : null;

    return PopScope(
      // Wie auch immer das Blatt geht — Abbrechen, Zurück, Wischen,
      // Buchen —, das Foto geht mit.
      onPopInvokedWithResult: (gegangen, _) {
        if (gegangen) ref.read(kiFotoProvider.notifier).verwirf();
      },
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
        navigationBar: const CupertinoNavigationBar(middle: Text('Erfassen')),
        // `GlasAbstand` liest den Rand **innerhalb** des Gerüsts (#348):
        // Erst `CupertinoPageScaffold` zählt die Höhe der durchscheinenden
        // Navigationsleiste in `MediaQuery.padding`. Mit dem `context` der
        // Seite fehlte sie, und das Foto begann 44 Punkte hinter der Leiste
        // — oben abgeschnitten, bevor überhaupt gescrollt war.
        child: Builder(
          builder: (innen) => SingleChildScrollView(
            key: const Key('ki-pruefblatt'),
            padding:
                GlasAbstand.of(innen) +
                const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PruefBild(foto),
                const SizedBox(height: 10),
                const PruefNotiz(
                  key: Key('ki-pruef-schaetzung'),
                  text:
                      'Schätzung, keine exakten Werte. Gebucht wird erst, wenn '
                      'du tippst.',
                ),
                ..._inhalt(context, zustand, limit),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: pruefKnopf(
                    context,
                    key: const Key('ki-pruef-buchen'),
                    titel: switch (zustand) {
                      Vorschlag(:final aktion) => _buchenText(
                        uebernommen(aktion.posten).length,
                      ),
                      _ => 'Buchen',
                    },
                    voll: true,
                    onPressed: switch (zustand) {
                      final Vorschlag v
                          when !_bucht &&
                              uebernommen(v.aktion.posten).isNotEmpty =>
                        () => _buche(v),
                      _ => null,
                    },
                  ),
                ),
                const ErfassenHinweis(
                  'Die Erkennung schätzt. Sie ersetzt kein Wiegen und ist keine '
                  'medizinische Bewertung. Gebuchte Einträge tragen die Marke '
                  '„KI-Schätzung", auch nach dem Ändern; das Foto wird nach dem '
                  'Buchen verworfen.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _buchenText(int n) =>
      n == 1 ? '1 Eintrag buchen' : '$n Einträge buchen';

  List<Widget> _inhalt(
    BuildContext context,
    SchaetzungZustand zustand,
    KiTopf? limit,
  ) {
    final neu = limit == null && !_bucht
        ? () => _schaetzung.neuBerechnen(_hinweis.text)
        : null;
    final wege = widget.wege;

    Widget zeile(List<Widget> knoepfe) => Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          for (var i = 0; i < knoepfe.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: knoepfe[i]),
          ],
        ],
      ),
    );

    Widget knopf(String key, String titel, VoidCallback? aktion) => pruefKnopf(
      context,
      key: Key(key),
      titel: titel,
      voll: false,
      onPressed: aktion,
    );

    final limitSatz = limit == null
        ? null
        : const PruefNotiz(
            rand: EdgeInsets.only(top: 10),
            text:
                'Das Monatslimit für KI ist erreicht — neu geschätzt wird erst '
                'im nächsten Monat. Buchen geht.',
          );

    return switch (zustand) {
      Laeuft(:final ziel) => [
        const ErfassenKapitel('Gemini schätzt …'),
        _Flaeche(
          child: InsetCard(
            child: Column(
              children: [
                // Die Summe steht schon, ohne Zahl — kommt der Vorschlag,
                // springt sie nicht (#392).
                const PruefSumme.laeuft(),
                const ErfassenTrenner(),
                for (final name in const [
                  'Hähnchenbrust, gegrillt',
                  'Reis, gekocht',
                  'Brokkoli',
                  'Soße',
                ]) ...[PruefGrauZeile(beispiel: name), const ErfassenTrenner()],
                const PruefZeileDazu(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        PruefHinweisFeld(controller: _hinweis),
        const SizedBox(height: 10),
        _ziel(ziel),
        zeile([
          pruefKnopf(
            context,
            key: const Key('ki-pruef-abbrechen'),
            titel: 'Abbrechen',
            voll: false,
            farbe: Palette.muted,
            onPressed: () => wege.zurKamera(context),
          ),
        ]),
      ],
      final Vorschlag v => [
        ErfassenKapitel(
          v.geaendert
              ? 'Vorschlag · von dir geändert'
              : 'Vorschlag · ${uebernommen(v.aktion.posten).length} von '
                    '${v.aktion.posten.length} übernommen',
        ),
        // **Ohne** Mindesthöhe (#349): Die Karte ist so hoch wie ihre
        // Posten. Bei zwei Posten stand unter „Zeile hinzufügen" sonst eine
        // leere Fläche bis zum Hinweisfeld. Eine Liste mit N Einträgen hat
        // ohnehin keine feste Höhe — die Mindesthöhe hält nur die Zustände
        // ohne Liste (läuft, nichts erkannt, Fehler) in einer Form.
        InsetCard(
          child: Column(
            children: [
              // Oben, über den Posten: Dort bleibt sie stehen, wenn eine
              // Zeile dazukommt oder geht (#392).
              PruefSumme(posten: uebernommen(v.aktion.posten)),
              const ErfassenTrenner(),
              for (var i = 0; i < v.aktion.posten.length; i++) ...[
                PruefZeile(
                  key: Key('ki-pruef-zeile-$i'),
                  posten: v.aktion.posten[i],
                  aufTippen: _bucht
                      ? null
                      : () => _aendereZeile(i, v.aktion.posten[i]),
                ),
                const ErfassenTrenner(),
              ],
              PruefZeileDazu(aufTippen: _bucht ? null : _ergaenze),
            ],
          ),
        ),
        if (limitSatz != null)
          limitSatz
        else if (v.geaendert)
          PruefNotiz(
            rand: const EdgeInsets.only(top: 10),
            text:
                'Du hast ${v.geaenderteZeilen == 1 ? 'eine Zeile' : '${v.geaenderteZeilen} Zeilen'} '
                'geändert. Die KI kann mit deinen Korrekturen nochmal über '
                'das Bild schauen — oft findet sie dann auch die Mengen der '
                'übrigen Zeilen genauer.',
          )
        else if (v.notiz case final notiz?)
          PruefNotiz(rand: const EdgeInsets.only(top: 10), text: notiz),
        const SizedBox(height: 10),
        PruefHinweisFeld(controller: _hinweis),
        const SizedBox(height: 10),
        _ziel(v.ziel),
        zeile([knopf('ki-pruef-neu-berechnen', 'Neu berechnen', neu)]),
      ],
      NichtsErkannt() => [
        const ErfassenKapitel('Nichts erkannt'),
        const _Flaeche(
          child: PruefGrund(
            warnung: false,
            text:
                'Auf dem Foto ist kein Essen zu erkennen — oder es ist zu '
                'dunkel oder unscharf. Ist doch etwas drauf, sag kurz was; '
                'sonst hilft ein neues Foto.',
          ),
        ),
        ?limitSatz,
        const SizedBox(height: 10),
        PruefHinweisFeld(controller: _hinweis),
        zeile([
          knopf('ki-pruef-neu-berechnen', 'Neu berechnen', neu),
          knopf(
            'ki-pruef-neues-foto',
            'Neues Foto',
            () => wege.zurKamera(context),
          ),
        ]),
      ],
      Gescheitert(:final fehler) => [
        ErfassenKapitel(switch (fehler) {
          SchluesselAbgelehnt() => 'Schlüssel abgelehnt',
          Kontingent() => 'Google sagt: später',
          KeinNetz() ||
          AntwortUnbrauchbar() ||
          Sonstiges() => 'Hat nicht geklappt',
        }),
        _Flaeche(
          child: PruefGrund(
            warnung: fehler is SchluesselAbgelehnt || fehler is Kontingent,
            text: _grund(fehler),
          ),
        ),
        if (fehler is! SchluesselAbgelehnt && fehler is! Kontingent) ?limitSatz,
        zeile([
          knopf(
            'ki-pruef-suchen',
            'Stattdessen suchen',
            () => wege.zurSuche(context),
          ),
          switch (fehler) {
            SchluesselAbgelehnt() || Kontingent() => knopf(
              'ki-pruef-zugang',
              'Zum KI-Zugang',
              () => wege.zumZugang(context),
            ),
            KeinNetz() ||
            AntwortUnbrauchbar() ||
            Sonstiges() => knopf('ki-pruef-nochmal', 'Nochmal versuchen', neu),
          },
        ]),
      ],
    };
  }

  Widget _ziel(KiZiel ziel) => PruefZiel(
    ziel: ziel,
    aufMahlzeit: _bucht ? null : _schaetzung.setzeMahlzeit,
    aufUhrzeit: _bucht ? null : _schaetzung.setzeUhrzeit,
  );

  static String _grund(KiFehler fehler) => switch (fehler) {
    KeinNetz() =>
      'Google war nicht erreichbar — kein Netz oder keine Antwort innerhalb '
          'einer Minute. Das Foto ist noch da; ein zweiter Versuch braucht '
          'keine neue Aufnahme.',
    AntwortUnbrauchbar() =>
      'Die Antwort von Google passte nicht zur erwarteten Form. Das Foto ist '
          'noch da; ein zweiter Versuch braucht keine neue Aufnahme.',
    Sonstiges(:final status) =>
      'Google hat die Anfrage nicht beantwortet'
          '${status == null ? '' : ' (Status $status)'}. Das Foto ist noch '
          'da; ein zweiter Versuch braucht keine neue Aufnahme.',
    SchluesselAbgelehnt() =>
      'Google nimmt den hinterlegten Schlüssel nicht mehr an — vielleicht '
          'widerrufen oder das Projekt gelöscht. Gebucht wird nichts.',
    Kontingent() =>
      'Google hat die Anfrage abgelehnt: Kontingent erschöpft. Das klärt '
          'sich bei Google oder nach einer Weile, nicht hier. Das Foto bleibt '
          'bis zum Verlassen des Schirms.',
  };
}

/// Die Ergebnisfläche der Zustände ohne Vorschlag — **gleich hoch**, ob
/// graue Formen oder ein Grund darin stehen (`FLAECHE` im Entwurf). Der
/// Vorschlag selbst trägt keine Mindesthöhe (#349).
class _Flaeche extends StatelessWidget {
  const _Flaeche({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 276),
    child: Align(alignment: Alignment.topCenter, child: child),
  );
}
