// Die Bausteine des Prüfblatts der Foto-Schätzung (#341) — Bild, Zeilen,
// Grund, Knöpfe, Mahlzeit und Uhrzeit, und die kleinen Blätter, mit denen
// eine Zeile geändert wird. Vorlage: `docs/screens/screens/erfassen.js`
// (`TELLER`, `grauZeile`, `ERKANNT`, `FEHLER`, `hinweisZeile`, `ZIEL`,
// `knopfZeile`) und `docs/screens/components.js` (`foodRow`, `noteBox`).
//
// **Eine eigene Datei, damit das Prüfblatt klein bleibt** (`CLAUDE.md`,
// „Views bleiben klein").
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/lebensmittel_repository.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import 'erfassen_bausteine.dart';
import 'erfassen_formular.dart';
import 'foto_kamera.dart' show jpegMasse;
import 'ki_pruefblatt_naehrwerte.dart';
import 'ki_schaetzung_provider.dart';
import 'suche_view.dart';
import 'wann_auswahl.dart';

/// Das Foto, oben im Blatt, in jedem Zustand an derselben Stelle (`TELLER`).
///
/// **Im Format der übergebenen Bilddaten, bei voller Breite** (#353),
/// nichts wird beschnitten. Die Kamera liefert seit #391 nur noch, was im
/// Sucher-Rahmen stand — im KI-Modus also ein Quadrat, nicht mehr das ganze
/// Hochkantfoto. Das Seitenverhältnis kommt aus dem Bildkopf ([jpegMasse]),
/// nicht aus dem dekodierten Bild — so steht die Form vom ersten Bild an
/// und springt weder beim Dekodieren noch, wenn der Vorschlag kommt.
class PruefBild extends StatefulWidget {
  const PruefBild(this.foto, {super.key});

  /// `null`, sobald es verworfen ist — dann bleibt die Fläche, dunkel, in
  /// der Form des zuletzt gezeigten Fotos.
  final List<int>? foto;

  /// Die Höhe, wenn der Bildkopf kein Format hergibt — der flache Streifen
  /// von vor #353. Ein Foto ohne lesbaren Kopf lässt sich in aller Regel
  /// auch nicht zeigen, und eine dunkle Fläche soll nicht das halbe Blatt
  /// füllen. Das echte Foto (aus `verkleinere`) hat immer einen lesbaren
  /// Kopf.
  static const ersatzHoehe = 150.0;

  @override
  State<PruefBild> createState() => _PruefBildZustand();
}

class _PruefBildZustand extends State<PruefBild> {
  /// Breite durch Höhe; `null`, solange kein Format bekannt ist.
  late double? _verhaeltnis = _aus(widget.foto);

  static double? _aus(List<int>? foto) {
    if (foto == null) return null;
    final masse = jpegMasse(foto);
    return masse == null ? null : masse.breite / masse.hoehe;
  }

  @override
  void didUpdateWidget(PruefBild alt) {
    super.didUpdateWidget(alt);
    if (!identical(alt.foto, widget.foto) && widget.foto != null) {
      _verhaeltnis = _aus(widget.foto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final foto = widget.foto;
    final verhaeltnis = _verhaeltnis;
    final flaeche = ColoredBox(
      color: const Color(0xFF2E3A2C),
      child: foto == null
          ? null
          : Image.memory(
              foto is Uint8List ? foto : Uint8List.fromList(foto),
              // Die Fläche hat schon das Verhältnis des Fotos; `cover`
              // schneidet deshalb nichts ab und füllt nur Rundungs-
              // reste.
              fit: BoxFit.cover,
              gaplessPlayback: true,
              // Was sich nicht zeigen lässt, bleibt dunkel; die Zeilen
              // darunter sind der Inhalt.
              errorBuilder: (_, _, _) => const SizedBox.expand(),
            ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: verhaeltnis == null
          ? SizedBox(height: PruefBild.ersatzHoehe, child: flaeche)
          : AspectRatio(aspectRatio: verhaeltnis, child: flaeche),
    );
  }
}

/// Eine Zeile des Vorschlags (`foodRow` mit Abzeichen), seit #392 mit
/// Eiweiß, Kohlenhydraten und Fett unter der Menge.
class PruefZeile extends StatelessWidget {
  const PruefZeile({super.key, required this.posten, this.aufTippen});

  final SchaetzPosten posten;
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final kcal = posten.werte.kcal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    posten.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, color: ink),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Text(
                      _menge(posten),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ),
                  PruefMakros(
                    makroText(posten.werte),
                    vorlesen: makroVorlesen(posten.werte),
                  ),
                ],
              ),
            ),
            PruefAbzeichen(_abzeichen(posten)),
            const SizedBox(width: 10),
            Text(
              // `null` bleibt `null` — nie `0` (`01`).
              kcal == null ? ohneWert : formatNumber(kcal),
              style: TextStyle(fontSize: 16, color: ink),
            ),
          ],
        ),
      ),
    );
  }

  static String _menge(SchaetzPosten p) {
    final gramm = p.gramm;
    if (gramm == null) return 'Menge nicht schätzbar';
    final text = '${formatNumber(gramm)} g';
    return p.herkunft == PostenHerkunft.erkannt ? 'geschätzt $text' : text;
  }

  static String _abzeichen(SchaetzPosten p) => switch (p.herkunft) {
    PostenHerkunft.vonDir => 'von dir',
    PostenHerkunft.ergaenzt => 'ergänzt',
    PostenHerkunft.erkannt => p.sicher ? 'sicher' : 'unsicher',
  };
}

/// Das graue Kästchen rechts in einer Zeile (`.foodrow .tag`) — dieselbe
/// Form wie „Apple Health" im Mahlzeiten-Schirm.
class PruefAbzeichen extends StatelessWidget {
  const PruefAbzeichen(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: line,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(text, style: TextStyle(fontSize: 11, color: muted)),
      ),
    );
  }
}

/// Dieselbe Zeile in Grau, solange geschätzt wird (`grauZeile`). **Kein
/// Text** — während gelesen wird, ist nichts entschieden (`01`).
class PruefGrauZeile extends StatelessWidget {
  const PruefGrauZeile({super.key, required this.beispiel});

  /// Wie lang der Name ungefähr wird — für die Breite der grauen Form.
  final String beispiel;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Platzhalter(
                beispiel: beispiel,
                stil: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 3),
              const Platzhalter(
                beispiel: 'geschätzt 140 g',
                stil: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 3),
              const Platzhalter(
                beispiel: 'E 43 g · KH 0 g · F 5 g',
                stil: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const Platzhalter(beispiel: '231', stil: TextStyle(fontSize: 16)),
      ],
    ),
  );
}

/// „Zeile hinzufügen" — unter den Zeilen, in derselben Karte.
class PruefZeileDazu extends StatelessWidget {
  const PruefZeileDazu({super.key, this.aufTippen});

  /// `null` sperrt die Zeile: während geschätzt wird, gibt es nichts, dem
  /// eine Zeile hinzuzufügen wäre.
  final VoidCallback? aufTippen;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return GestureDetector(
      key: const Key('ki-pruef-zeile-dazu'),
      behavior: HitTestBehavior.opaque,
      onTap: aufTippen,
      child: Opacity(
        opacity: aufTippen == null ? 0.45 : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Icon(CupertinoIcons.plus_circle, size: 20, color: river),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Zeile hinzufügen', style: TextStyle(color: river)),
                    Text(
                      'was die Erkennung übersehen hat',
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Der Grund in der Ergebnisfläche — `FEHLER(ton, text)`: eine Karte mit
/// Hinweiskasten. Steht **nie**, während geschätzt wird.
class PruefGrund extends StatelessWidget {
  const PruefGrund({super.key, required this.warnung, required this.text});

  final bool warnung;
  final String text;

  @override
  Widget build(BuildContext context) => InsetCard(
    key: const Key('ki-pruef-grund'),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: PruefNotiz(warnung: warnung, text: text),
    ),
  );
}

/// `noteBox` — Fläche mit farbiger Kante links. Die Kante liegt **in** der
/// beschnittenen Form; ein gerundeter Balken liefe über die Ecke.
class PruefNotiz extends StatelessWidget {
  const PruefNotiz({
    super.key,
    required this.text,
    this.warnung = false,
    this.rand = EdgeInsets.zero,
  });

  final String text;
  final bool warnung;
  final EdgeInsets rand;

  @override
  Widget build(BuildContext context) {
    final farbe = CupertinoDynamicColor.resolve(
      warnung ? Palette.warn : Palette.bib,
      context,
    );
    final flaeche = Color.alphaBlend(
      farbe.withValues(alpha: 0.07),
      CupertinoDynamicColor.resolve(Palette.surface, context),
    );
    return Padding(
      padding: rand,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: flaeche,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: farbe.withValues(alpha: 0.22),
              width: 0.5,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: farbe),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 13, 11),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.42,
                        color: CupertinoDynamicColor.resolve(
                          Palette.ink,
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Ein Knopf des Blatts (`btn`) — **der Schlüssel sitzt am
/// `CupertinoButton`**, weil an seinem `onPressed` hängt, ob er wirkt.
Widget pruefKnopf(
  BuildContext context, {
  required Key key,
  required String titel,
  required bool voll,
  required VoidCallback? onPressed,
  Color farbe = Palette.river,
}) {
  final ton = CupertinoDynamicColor.resolve(farbe, context);
  final flaeche = CupertinoDynamicColor.resolve(Palette.surface, context);
  return CupertinoButton(
    key: key,
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
    color: voll ? ton : ton.withValues(alpha: 0.13),
    disabledColor: voll
        ? ton.withValues(alpha: 0.45)
        : ton.withValues(alpha: 0.06),
    borderRadius: BorderRadius.circular(10),
    onPressed: onPressed,
    child: Text(
      titel,
      textAlign: TextAlign.center,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: voll ? flaeche : ton,
      ),
    ),
  );
}

/// Das Hinweisfeld (`hinweisZeile`) — dieselbe Zeile wie im Blatt vor der
/// Schätzung. **Wird nie gespeichert.**
class PruefHinweisFeld extends StatelessWidget {
  const PruefHinweisFeld({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) => InsetCard(
    child: Padding(
      key: const Key('ki-pruef-hinweis'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          const Text('Hinweis an die KI'),
          const SizedBox(width: 12),
          Expanded(
            child: CupertinoTextField.borderless(
              controller: controller,
              placeholder: 'z. B. halbe Portion, mit Butter',
              textAlign: TextAlign.end,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.done,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Mahlzeit und Uhrzeit (`ZIEL`) — wie im Buchungsblatt änderbar; der Tag
/// ist der offene Tag und steht nicht zur Wahl.
class PruefZiel extends StatelessWidget {
  const PruefZiel({
    super.key,
    required this.ziel,
    required this.aufMahlzeit,
    required this.aufUhrzeit,
  });

  final KiZiel ziel;
  final ValueChanged<Mahlzeit>? aufMahlzeit;
  final ValueChanged<int>? aufUhrzeit;

  @override
  Widget build(BuildContext context) {
    final mahlzeit = aufMahlzeit;
    final uhrzeit = aufUhrzeit;
    return InsetCard(
      child: Column(
        children: [
          ErfassenWertZeile(
            key: const Key('ki-pruef-mahlzeit'),
            titel: 'Mahlzeit',
            wert: mahlzeitText(ziel.mahlzeit),
            aufTippen: mahlzeit == null
                ? null
                : () async {
                    final gewaehlt = await waehleMahlzeit(context);
                    if (gewaehlt != null) mahlzeit(gewaehlt);
                  },
          ),
          const ErfassenTrenner(),
          ErfassenWertZeile(
            key: const Key('ki-pruef-uhrzeit'),
            titel: 'Uhrzeit',
            wert: uhrzeitText(ziel.minuten),
            aufTippen: uhrzeit == null
                ? null
                : () async =>
                      uhrzeit(await waehleUhrzeit(context, ziel.minuten)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Eine Zeile ändern
// ─────────────────────────────────────────────────────────────────────────

enum ZeilenAktion { menge, tauschen, streichen }

/// Zeile antippen → Menge ändern, Lebensmittel austauschen, streichen
/// (Tim, 03.11.2026). `null` nach „Abbrechen".
Future<ZeilenAktion?> zeigeZeilenAktionen(BuildContext context, String name) =>
    showCupertinoModalPopup<ZeilenAktion>(
      context: context,
      builder: (blatt) => CupertinoActionSheet(
        title: Text(name),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(blatt, ZeilenAktion.menge),
            child: const Text('Menge ändern'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(blatt, ZeilenAktion.tauschen),
            child: const Text('Lebensmittel austauschen'),
          ),
          CupertinoActionSheetAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.pop(blatt, ZeilenAktion.streichen),
            child: const Text('Streichen'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(blatt),
          child: const Text('Abbrechen'),
        ),
      ),
    );

/// Die neue Menge in Gramm; `null` nach „Abbrechen" oder ohne lesbare
/// Zahl größer 0 — 0 g ist keine Portion (wie im Buchungsblatt).
Future<double?> zeigeMengenDialog(BuildContext context, double? gramm) async {
  final feld = TextEditingController(
    text: gramm == null ? '' : formatNumber(gramm),
  );
  double? ergebnis;
  try {
    await showCupertinoDialog<void>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Menge'),
        content: Padding(
          padding: const EdgeInsets.only(top: 10),
          child: CupertinoTextField(
            key: const Key('ki-pruef-menge-feld'),
            controller: feld,
            autofocus: true,
            suffix: const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('g'),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.pop(dialog),
            child: const Text('Abbrechen'),
          ),
          CupertinoDialogAction(
            key: const Key('ki-pruef-menge-ok'),
            isDefaultAction: true,
            onPressed: () {
              final wert = liesZahl(feld.text).wert;
              if (wert != null && wert > 0) ergebnis = wert;
              Navigator.pop(dialog);
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  } finally {
    feld.dispose();
  }
  return ergebnis;
}

/// Die Suche als Blatt, mit `onGewaehlt` — für „austauschen" und „Zeile
/// hinzufügen". `null` nach „Abbrechen". Den Suchtext leert der Aufrufer
/// danach (`suchtextProvider`), wie `SucheSeite` es beim Schließen tut.
Future<LebensmittelVorlage?> waehleLebensmittel(BuildContext context) async {
  LebensmittelVorlage? gewaehlt;
  await zeigeErfassenBlatt(
    context,
    (blatt) => CupertinoPageScaffold(
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, blatt),
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(blatt),
          child: const Text('Abbrechen'),
        ),
        middle: const Text('Lebensmittel'),
      ),
      child: SucheView(
        onGewaehlt: (vorlage) {
          gewaehlt = vorlage;
          Navigator.pop(blatt);
        },
      ),
    ),
  );
  return gewaehlt;
}
