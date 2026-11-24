// Der KI-Modus der Kamera (#340) — `docs/screens/screens/erfassen.js`,
// Zustände `foto`, `foto-ohne-schluessel` und `foto-limit`; Spec
// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, „Foto-Schätzung
// als erste Aktion", Schritte 1–3.
//
// **Kein Blatt zwischen Auslöser und Schätzung** (#355, Tim, 04.11.2026):
// Das Foto geht direkt ins Prüfblatt; einen Hinweis an die KI gibt Tim
// dort, wenn das Ergebnis nicht passt. Der Satz zum Datenweg, der bis
// dahin im Blatt „Noch etwas dazu?" stand, steht im Fuß unter dem
// Auslöser (`ki_sucher_fuss_test.dart`).
//
// API und Verhalten sind durch `app/test/ernaehrung/ki_sucher_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf, „Die Naht zur
// Fotokamera" — Festlegung des Agenten von #340, **nicht von Tim**) —
// diese Datei darf die Tests ausführen, aber nicht verändern (`CLAUDE.md`).
//
// **Ein Sucher, zwei Modi.** „KI-Foto" baut die Vorschau des
// Barcode-Lesers ab — `mobile_scanner` gibt die Kamera frei — und startet
// `camera`; „Barcode" umgekehrt. Beides hängt allein daran, welche Vorschau im Baum
// steht (`kamera_seite.dart`).
//
// **Kein Auslöser, der scheitert.** Ohne Schlüssel oder über dem
// Monatslimit steht an seiner Stelle der Weg in den KI-Zugang — und die
// Kamera läuft dann gar nicht erst.
//
// **Das Foto liegt nur im Arbeitsspeicher**, in genau einem Provider
// ([kiFotoProvider]). Die Kamera selbst und das Verkleinern liegen in
// `foto_kamera.dart`.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/formatierung.dart';
import '../design/icon_row.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../ki/ki_zugang_provider.dart';
import '../ki/ki_zugang_view.dart';
import '../shell/router.dart';
import 'foto_kamera.dart';
import 'kamera_bausteine.dart';
import 'ki_pruefblatt.dart';

export 'foto_kamera.dart';

// ─────────────────────────────────────────────────────────────────────────
// Das Foto und die Übergabe an das Prüfblatt
// ─────────────────────────────────────────────────────────────────────────

/// Hält das Foto zwischen Aufnahme und Buchen.
class KiFotoNotifier extends Notifier<List<int>?> {
  @override
  List<int>? build() => null;

  void halte(List<int> foto) => state = foto;

  /// „Neues Foto", Abbrechen, nach dem Buchen.
  void verwirf() => state = null;
}

/// Das Foto zwischen Aufnahme und Buchen — **der einzige Ort, an dem es
/// liegt**. `null` heißt: keins.
///
/// `autoDispose`: Schließt die Kamera, ist das Foto weg, ohne dass jemand
/// daran denken muss.
final kiFotoProvider = NotifierProvider.autoDispose<KiFotoNotifier, List<int>?>(
  KiFotoNotifier.new,
);

/// Was nach dem Auslöser an das Prüfblatt geht. **Das Foto steht nicht
/// darin** — es liegt in [kiFotoProvider], und nur dort. Einen Hinweis an
/// die KI trägt er seit #355 nicht mehr: Den gibt es erst im Prüfblatt.
@immutable
class KiAuftrag {
  const KiAuftrag({required this.tagesSchluessel, required this.mahlzeit});

  /// Der Tag, auf den gebucht wird.
  final String tagesSchluessel;

  /// Die vorgewählte Mahlzeit, `null` beim (+).
  final Mahlzeit? mahlzeit;

  @override
  bool operator ==(Object other) =>
      other is KiAuftrag &&
      other.tagesSchluessel == tagesSchluessel &&
      other.mahlzeit == mahlzeit;

  @override
  int get hashCode => Object.hash(tagesSchluessel, mahlzeit);
}

/// Der Übergabepunkt an das Prüfblatt (#341).
typedef KiSchaetzungStarten = Future<void> Function(
  BuildContext context,
  KiAuftrag auftrag,
);

/// Öffnet das Prüfblatt (#341, `ki_pruefblatt.dart`). Ein Provider, damit
/// `ki_sucher_test.dart` den Übergang ersetzen kann.
final kiSchaetzungStartenProvider = Provider<KiSchaetzungStarten>(
  (ref) => zeigeKiPruefblatt,
);

// ─────────────────────────────────────────────────────────────────────────
// Der Sucher im KI-Modus
// ─────────────────────────────────────────────────────────────────────────

/// Wohin das Foto geht — eine Zusage, keine Beschreibung (`CLAUDE.md`,
/// „Niemals tun"). Steht unter dem Auslöser (#355).
const kiDatenweg =
    'Das Foto geht zur Schätzung an Google Gemini und wird nach dem Buchen '
    'verworfen.';

/// Fenster, Kachelreihe und Fuß des KI-Modus. Der Kopf gehört der
/// `KameraSeite`.
///
/// **Eine Form in jedem Zustand:** Das Fenster ist so hoch wie im
/// Barcode-Modus, der Fuß ist fest hoch — Auslöser, Verweis oder graue
/// Form, nichts darunter rutscht.
class KiSucher extends ConsumerStatefulWidget {
  const KiSucher({
    super.key,
    required this.router,
    required this.kacheln,
    required this.tag,
    required this.mahlzeit,
    required this.verweigert,
    required this.aufVerweigert,
    required this.aufEinstellungen,
  });

  final AppRouter router;

  /// Die Kachelreihe der Wege (#439), wo bis dahin der Umschalter
  /// Barcode ⇄ KI stand — gesperrt, solange ein Foto aufgenommen wird oder
  /// vorliegt.
  final Widget kacheln;

  /// Der Tag, auf den gebucht wird — gelesen erst beim Auslösen.
  final String Function() tag;

  final Mahlzeit? mahlzeit;

  /// Die Kamerafreigabe ist verweigert — für beide Modi dieselbe.
  final bool verweigert;
  final VoidCallback aufVerweigert;
  final VoidCallback aufEinstellungen;

  @override
  ConsumerState<KiSucher> createState() => _KiSucherZustand();
}

class _KiSucherZustand extends ConsumerState<KiSucher> {
  /// Gesetzt, sobald die Vorschau läuft.
  FotoAufnahme? _aufnahme;

  /// **Synchron gesetzt**, bevor aufgenommen wird: Der zweite Tipp eines
  /// Doppeltipps fällt genau in die Lücke des `await`.
  bool _nimmtAuf = false;

  static bool _darfSchaetzen(KiZugangZustand zugang) =>
      zugang is MitSchluessel && !zugang.topf.erreicht;

  Future<void> _loese() async {
    final aufnahme = _aufnahme;
    if (aufnahme == null || _nimmtAuf) return;
    if (ref.read(kiFotoProvider) != null) return;
    if (!_darfSchaetzen(ref.read(kiZugangProvider))) return;

    setState(() => _nimmtAuf = true);
    final List<int> foto;
    try {
      foto = await aufnahme.nimmAuf();
    } on Object catch (fehler) {
      // Eine Aufnahme, die scheitert (Kamera eben abgebaut, App im
      // Hintergrund), lässt den Sucher stehen — der nächste Tipp versucht
      // es neu.
      debugPrint('KI-Sucher: Aufnahme gescheitert ($fehler)');
      if (mounted) setState(() => _nimmtAuf = false);
      return;
    }
    if (!mounted) return;
    ref.read(kiFotoProvider.notifier).halte(foto);
    setState(() => _nimmtAuf = false);

    // Direkt in die Schätzung (#355) — kein Blatt dazwischen.
    await ref.read(kiSchaetzungStartenProvider)(
      context,
      KiAuftrag(tagesSchluessel: widget.tag(), mahlzeit: widget.mahlzeit),
    );
  }

  @override
  Widget build(BuildContext context) {
    final zugang = ref.watch(kiZugangProvider);
    final foto = ref.watch(kiFotoProvider);
    final kamera = ref.watch(fotoKameraProvider);

    // Die Kamera läuft nur, wenn geschätzt werden darf — ohne Schlüssel
    // oder über dem Limit gäbe es nichts aufzunehmen.
    final kameraAn = !widget.verweigert && _darfSchaetzen(zugang);

    return Column(
      key: const Key('ki-sucher'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: SucherFenster.hoehe,
          child: widget.verweigert
              ? KameraVerweigert(aufEinstellungen: widget.aufEinstellungen)
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    if (kameraAn)
                      kamera.sucher(
                        aufBereit: (aufnahme) {
                          if (mounted) setState(() => _aufnahme = aufnahme);
                        },
                        aufVerweigert: widget.aufVerweigert,
                      ),
                    if (foto != null) _Standbild(foto),
                    const IgnorePointer(
                      child: CustomPaint(painter: RahmenMaler.ki),
                    ),
                    Positioned(
                      left: 30,
                      right: 30,
                      bottom: 22,
                      child: _Hinweis(zugang: zugang, mitFoto: foto != null),
                    ),
                  ],
                ),
        ),
        IgnorePointer(
          ignoring: _nimmtAuf || foto != null,
          child: widget.kacheln,
        ),
        // Ohne Kamera bleibt der Fuß leer, in derselben Höhe: Den Weg
        // nennt das Fenster, und ein Auslöser ohne Kamera wäre einer, der
        // scheitert.
        SizedBox(
          height: _KiFuss.hoehe,
          child: widget.verweigert
              ? null
              : _KiFuss(
                  zugang: zugang,
                  bereit:
                      kameraAn &&
                      _aufnahme != null &&
                      !_nimmtAuf &&
                      foto == null,
                  aufAusloesen: _loese,
                  aufZugang: () => oeffneKiZugang(widget.router),
                ),
        ),
      ],
    );
  }
}

/// Das aufgenommene Foto, solange es vorliegt — im Sucher unter dem
/// Prüfblatt.
///
/// **Im Rahmen, nicht im ganzen Fenster** (#391): Das Foto ist schon auf
/// den Rahmen zugeschnitten (`verkleinere`); über das ganze Fenster
/// gezogen, stünde es vergrößert da. Außen bleibt es schwarz.
class _Standbild extends StatelessWidget {
  const _Standbild(this.foto);

  final List<int> foto;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: kameraSchwarz,
    child: CustomSingleChildLayout(
      delegate: const _ImRahmen(),
      // Dieselbe Rundung wie der Rahmen darüber.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          foto is Uint8List ? foto as Uint8List : Uint8List.fromList(foto),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          // Was sich nicht zeigen lässt, bleibt schwarz — das Prüfblatt
          // darüber ist der eigentliche Inhalt.
          errorBuilder: (_, _, _) => const SizedBox.expand(),
        ),
      ),
    ),
  );
}

/// Legt das Standbild genau in [RahmenMaler.ki].
class _ImRahmen extends SingleChildLayoutDelegate {
  const _ImRahmen();

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints.tight(RahmenMaler.ki.rahmenIn(constraints.biggest).size);

  @override
  Offset getPositionForChild(Size size, Size childSize) =>
      RahmenMaler.ki.rahmenIn(size).topLeft;

  @override
  bool shouldRelayout(_ImRahmen oldDelegate) => false;
}

/// Der Satz unter dem Rahmen.
class _Hinweis extends StatelessWidget {
  const _Hinweis({required this.zugang, required this.mitFoto});

  final KiZugangZustand zugang;
  final bool mitFoto;

  @override
  Widget build(BuildContext context) {
    final text = switch (zugang) {
      // Während gelesen wird, steht kein Grund da (`01`).
      KiZugangLaedt() => '',
      OhneSchluessel() =>
        'Für die Schätzung braucht die App einen Gemini-Schlüssel. Barcode '
            'und Suche gehen ohne.',
      MitSchluessel(:final topf) when topf.erreicht =>
        'Das Monatslimit für KI ist erreicht. Bis zum '
            '${Format.tagMonatAusgeschrieben(kalendertag(topf.limitEnde))} '
            'schätzt die App nichts — Barcode und Suche gehen weiter.',
      MitSchluessel() when mitFoto => 'Foto aufgenommen.',
      MitSchluessel() =>
        'Teller von oben fotografieren. Mit Besteck oder einem bekannten '
            'Gegenstand daneben wird die Menge genauer.',
    };
    // Feste Zeilenzahl: Der Satz wechselt mit dem Zustand, die Fläche
    // nicht (`CLAUDE.md`, „Mehrzeilige Erläuterungen").
    return SizedBox(
      height: 3 * 13 * 1.4,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xD1FFFFFF),
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

/// Unter der Kachelreihe: der Auslöser — oder, wo er scheitern würde, der
/// Weg in den KI-Zugang.
class _KiFuss extends StatelessWidget {
  const _KiFuss({
    required this.zugang,
    required this.bereit,
    required this.aufAusloesen,
    required this.aufZugang,
  });

  final KiZugangZustand zugang;
  final bool bereit;
  final VoidCallback aufAusloesen;
  final VoidCallback aufZugang;

  /// `.camfoot` mit Auslöser und Zeile darunter — der Verweis passt in
  /// dieselbe Höhe.
  static const hoehe = 128.0;

  @override
  Widget build(BuildContext context) {
    return switch (zugang) {
      KiZugangLaedt() => const _Ausloeser(bereit: false, mitSchluessel: false),
      OhneSchluessel() => _Verweis(
        key: const Key('ki-ohne-schluessel'),
        titel: 'KI-Zugang einrichten',
        untertitel: 'Gemini-Schlüssel hinterlegen · einmalig',
        aufTippen: aufZugang,
      ),
      MitSchluessel(:final topf) when topf.erreicht => _Verweis(
        key: const Key('ki-limit'),
        titel: 'Limit im KI-Zugang',
        untertitel:
            '${topf.summe.unvollstaendig ? 'mind. ' : ''}'
            '${dollar(topf.summe.usd)} von ${dollar(topf.limitUsd)} '
            'diesen Monat',
        aufTippen: aufZugang,
      ),
      MitSchluessel() => _Ausloeser(
        bereit: bereit,
        mitSchluessel: true,
        aufTippen: aufAusloesen,
      ),
    };
  }
}

/// Der runde Auslöser (`.camfoot .shut`). **Er steht auch da, solange er
/// nicht kann** — während die Kamera startet oder ein Foto aufgenommen
/// wird —, nur gedämpft und ohne Wirkung.
class _Ausloeser extends StatelessWidget {
  const _Ausloeser({
    required this.bereit,
    required this.mitSchluessel,
    this.aufTippen,
  });

  final bool bereit;

  /// Ohne Schlüssel (noch nicht gelesen) ist es nur die graue Form: kein
  /// Schlüssel am Knopf, kein Satz darunter.
  final bool mitSchluessel;
  final VoidCallback? aufTippen;

  /// Zeilenhöhe des Satzes unter dem Knopf.
  static const _zeile = 1.35;

  @override
  Widget build(BuildContext context) {
    final knopf = Opacity(
      opacity: bereit ? 1 : 0.4,
      child: Container(
        width: 62,
        height: 62,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color(0xFFFFFFFF),
          boxShadow: [
            BoxShadow(color: kameraSchwarz, spreadRadius: 4),
            BoxShadow(color: Color(0xCCFFFFFF), spreadRadius: 7),
          ],
        ),
      ),
    );

    return Column(
      children: [
        const SizedBox(height: 16),
        if (mitSchluessel)
          Semantics(
            key: const Key('ki-ausloeser'),
            button: true,
            enabled: bereit,
            label: 'Foto aufnehmen',
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: bereit ? aufTippen : null,
              child: knopf,
            ),
          )
        else
          knopf,
        const SizedBox(height: 12),
        // **Der Datenweg, vor jedem Foto** (#355): iOS zeigt den
        // Kamera-Freigabetext nur einmal pro Installation (Spec, „Texte,
        // die Zusagen sind"). Bis #355 stand der Satz im Blatt „Noch etwas
        // dazu?"; mit dem Blatt ist er hierher gewandert. Er steht, solange
        // ein Foto möglich ist — ohne Schlüssel oder über dem Limit gibt
        // es keins, und dort steht der Verweis statt dieses Fußes.
        //
        // Feste Zeilenzahl: Der Fuß ist fest hoch, und der Satz darf ihn
        // nicht sprengen (`CLAUDE.md`, „Mehrzeilige Erläuterungen").
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: SizedBox(
            height: 2 * 12 * _zeile,
            child: Text(
              mitSchluessel ? kiDatenweg : '',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0x8CFFFFFF),
                fontSize: 12,
                height: _zeile,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Statt eines Auslösers, der scheitert: der Weg dorthin, wo es fehlt
/// (`SUCHER_VERWEIS` in `erfassen.js`).
class _Verweis extends StatelessWidget {
  const _Verweis({
    super.key,
    required this.titel,
    required this.untertitel,
    required this.aufTippen,
  });

  final String titel;
  final String untertitel;
  final VoidCallback aufTippen;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: Align(
      alignment: Alignment.topCenter,
      child: InsetCard(
        child: IconRow(
          title: titel,
          subtitle: untertitel,
          symbol: 'checkmark.seal',
          accent: CupertinoDynamicColor.resolve(Palette.bib, context),
          onTap: aufTippen,
        ),
      ),
    ),
  );
}
