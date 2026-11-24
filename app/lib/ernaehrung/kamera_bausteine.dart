// Die Bausteine des Kamera-Schirms (#324, #340) — Sucherfenster, Rahmen
// und Lampe. Kopf und Kachelreihe liegen seit #439 in
// `erfassen_kacheln.dart`, die Abläufe in `kamera_seite.dart`, die Ansicht
// `unbekannt` in `kamera_unbekannt.dart`, der KI-Modus in `ki_sucher.dart`;
// hier wird nur gezeichnet.
//
// Vorlage ist `docs/screens/screens/erfassen.js` (Zustände `barcode`,
// `unbekannt`, `foto*` und `vorschlag-kamera`) und
// `docs/screens/components.css` (`.cam`).
//
// **Das Fenster hat eine Form in jedem Zustand** (`CLAUDE.md`, „Eine
// Anzeige, die es gibt, hat genau eine Form"): Kamera, „wird
// nachgesehen", „kein Netz" und „Kamera verweigert" sitzen in derselben
// Fläche derselben Höhe. Nur die Füllung wechselt; nichts darunter
// rutscht.
import 'package:flutter/cupertino.dart';

/// Fast schwarz, nicht grau: Eine Kamera-Ansicht, die wie ein Schirm
/// aussieht, lässt einen auf „zurück" suchen statt zu zielen
/// (`components.css`, `.cam`).
const kameraSchwarz = Color(0xFF07090A);

const _weiss = Color(0xFFFFFFFF);
const _weissGedaempft = Color(0xD1FFFFFF); // rgba(255,255,255,.82)

/// Der Zustand des Kamera-Schirms.
sealed class KameraLage {
  const KameraLage();
}

/// Die Kamera läuft und wartet auf einen Strichcode.
final class Sucht extends KameraLage {
  const Sucht();
}

/// Ein Code ist erkannt, eigene Tabelle und Open Food Facts werden
/// gefragt.
final class Prueft extends KameraLage {
  const Prueft(this.code);
  final String code;
}

/// Open Food Facts war nicht zu erreichen — **niemand hat nachgesehen**.
/// Kein „unbekannt", und kein Anlegen, als sei es unbekannt.
final class OhneNetz extends KameraLage {
  const OhneNetz(this.code);
  final String code;
}

/// Der Strichcode ist nicht hinterlegt — oder hinterlegt, aber ohne
/// Kalorien; dann trägt [name] den Namen aus Open Food Facts.
final class Unbekannt extends KameraLage {
  const Unbekannt(this.code, {this.name});
  final String code;
  final String? name;
}

/// Die Kamerafreigabe ist verweigert.
final class Verweigert extends KameraLage {
  const Verweigert();
}

// Der Kopf des Suchers ist seit #439 `ErfassenKopf` (`erfassen_kacheln
// .dart`): Zähler, Mahlzeit, „Abbrechen". „Suchen" ist eine Kachel.

/// Das Sucherfenster — Vorschau, Rahmen und darunter, was gerade gilt.
class SucherFenster extends StatelessWidget {
  const SucherFenster({
    super.key,
    required this.lage,
    required this.sucher,
    required this.aufNochmal,
    required this.aufEinstellungen,
  });

  final KameraLage lage;

  /// Die Vorschau aus `StrichcodeLeser.sucher` — `null`, wenn die Kamera
  /// verweigert ist. Dann steht sie nicht im Baum.
  final Widget? sucher;

  final VoidCallback? aufNochmal;
  final VoidCallback aufEinstellungen;

  /// Die Höhe aus `components.css` (`.cam .view`) — dieselbe im KI-Modus.
  static const hoehe = 330.0;

  @override
  Widget build(BuildContext context) {
    final sucher = this.sucher;

    return SizedBox(
      height: hoehe,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (sucher == null)
            KameraVerweigert(aufEinstellungen: aufEinstellungen)
          else ...[
            sucher,
            // Der Rahmen nimmt keine Berührung an — die Taschenlampe der
            // Vorschau liegt darunter.
            const IgnorePointer(
              child: CustomPaint(painter: RahmenMaler.breit()),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 18,
              child: _Fuss(lage: lage, aufNochmal: aufNochmal),
            ),
          ],
        ],
      ),
    );
  }
}

/// Was unter dem Rahmen steht: der Hinweis, „wird nachgesehen" oder
/// „kein Netz".
class _Fuss extends StatelessWidget {
  const _Fuss({required this.lage, required this.aufNochmal});

  final KameraLage lage;
  final VoidCallback? aufNochmal;

  @override
  Widget build(BuildContext context) {
    const stil = TextStyle(color: _weissGedaempft, fontSize: 13, height: 1.4);

    return switch (lage) {
      OhneNetz() => Container(
        key: const Key('kamera-kein-netz'),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
        decoration: BoxDecoration(
          color: const Color(0xCC07090A),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Open Food Facts ist gerade nicht erreichbar. Ob es diesen '
              'Strichcode kennt, lässt sich so nicht sagen.',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: stil,
            ),
            CupertinoButton(
              key: const Key('kamera-nochmal'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
              onPressed: aufNochmal,
              child: const Text(
                'Nochmal versuchen',
                style: TextStyle(color: _weiss, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
      Prueft() => const Text(
        'Strichcode erkannt — wird nachgesehen …',
        textAlign: TextAlign.center,
        style: stil,
      ),
      _ => const Text(
        'Strichcode in den Rahmen halten. Wird automatisch erkannt.',
        textAlign: TextAlign.center,
        style: stil,
      ),
    };
  }
}

/// Ohne Kamera: ein Satz und der Weg in die Einstellungen — kein
/// schwarzer Schirm. Die Kachel „Suchen" bleibt, ohne Kamera ist sie der
/// einzige Weg. Derselbe Satz in beiden Modi: Die Freigabe gilt für die
/// Kamera, nicht für Barcode oder KI.
class KameraVerweigert extends StatelessWidget {
  const KameraVerweigert({super.key, required this.aufEinstellungen});

  final VoidCallback aufEinstellungen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.camera, size: 30, color: _weissGedaempft),
          const SizedBox(height: 12),
          Semantics(
            key: const Key('kamera-verweigert'),
            container: true,
            child: const Text(
              'Die Kamera ist für diese App nicht freigegeben. Erlauben '
              'kannst du sie in den Einstellungen unter „Kamera" — bis '
              'dahin findest du deine Lebensmittel über „Suchen" unten.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _weissGedaempft,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          CupertinoButton(
            key: const Key('kamera-einstellungen'),
            onPressed: aufEinstellungen,
            child: const Text(
              'Einstellungen öffnen',
              style: TextStyle(color: _weiss, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Der Rahmen, außen abgedunkelt: schmal und quer, weil ein Strichcode
/// breit und flach ist (`erfassen.js`, Zustand `barcode`); quadratisch,
/// weil ein Teller rund ist (Zustand `foto`).
class RahmenMaler extends CustomPainter {
  /// `components.css`: `.cam .cutout.wide`.
  const RahmenMaler.breit() : _breite = 250, _hoehe = 110;

  /// `components.css`: `.cam .cutout.square`.
  const RahmenMaler.quadratisch() : _breite = 246, _hoehe = 246;

  /// Der Rahmen des KI-Modus. **Was in ihm steht, geht an Gemini und ins
  /// Prüfblatt** (#391) — der Sucher zeichnet ihn, die Kamera schneidet
  /// danach zu, und das Standbild steht darin. Eine Stelle für alle drei.
  static const ki = RahmenMaler.quadratisch();

  final double _breite;
  final double _hoehe;

  static const _radius = Radius.circular(12);

  /// Wo der Rahmen in einem Fenster der Größe [size] steht: waagerecht
  /// mittig, die Mitte bei 46 % der Höhe, wie `.cam .cutout`.
  Rect rahmenIn(Size size) => Rect.fromCenter(
    center: Offset(size.width / 2, size.height * 0.46),
    width: _breite,
    height: _hoehe,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rahmen = RRect.fromRectAndRadius(rahmenIn(size), _radius);
    final aussen = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addRRect(rahmen);
    canvas
      ..drawPath(aussen, Paint()..color = const Color(0x73000000))
      ..drawRRect(
        rahmen,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xE6FFFFFF),
      );
  }

  @override
  bool shouldRepaint(RahmenMaler oldDelegate) =>
      oldDelegate._breite != _breite || oldDelegate._hoehe != _hoehe;
}

/// Was der Sucher gerade sucht — „Barcode" und „KI-Foto" der Kachelreihe.
enum KameraModus { barcode, ki }

/// Der Knopf für die Taschenlampe, oben links im Sucher (`.cam .torch` in
/// `components.css`) — **ein Baustein für beide Modi** (#347): Barcode
/// schaltet über `mobile_scanner`, KI über `camera` mit `FlashMode.torch`.
/// Welche Kamera dahinter schaltet, weiß der Knopf nicht.
///
/// Ob das Gerät eine Lampe hat, entscheidet der Sucher: Ohne Lampe stellt
/// er den Knopf gar nicht erst hin — ein Knopf, der nichts tun kann, stünde
/// da wie einer, der kaputt ist.
class LampenKnopf extends StatelessWidget {
  const LampenKnopf({super.key, required this.an, required this.aufWechsel});

  final bool an;

  /// Ein Tipp schaltet um; `null` dämpft nichts, der Knopf tut dann nur
  /// nichts.
  final VoidCallback? aufWechsel;

  @override
  Widget build(BuildContext context) => Semantics(
    label: an ? 'Taschenlampe ausschalten' : 'Taschenlampe einschalten',
    button: true,
    excludeSemantics: true,
    child: CupertinoButton(
      padding: EdgeInsets.zero,
      minimumSize: const Size(40, 40),
      onPressed: aufWechsel,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: an ? const Color(0xFFFFFFFF) : const Color(0x33FFFFFF),
        ),
        child: Icon(
          an ? CupertinoIcons.bolt_fill : CupertinoIcons.bolt,
          size: 18,
          color: an ? kameraSchwarz : const Color(0xFFFFFFFF),
        ),
      ),
    ),
  );
}
