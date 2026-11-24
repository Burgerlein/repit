// Das Blatt „Modell für Fotos" des KI-Zugangs (#339), gezeichnet in
// `docs/screens/screens/ki-zugang.js` (Zustände `modell-waehlen`,
// `modelle-laden`). Spec „Modellwahl": Die Liste wird **live** geholt,
// wenn das Blatt öffnet; gewählt ist ein Modell erst, wenn es das
// Testbild mit 200 beantwortet.
//
// API und Verhalten sind durch `app/test/ki/ki_zugang_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`).
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/palette.dart';
import '../design/platzhalter.dart';
import 'gemini_client.dart';
import 'ki_zugang_bausteine.dart';
import 'ki_zugang_provider.dart';

/// Öffnet „Modell für Fotos". Die Liste wird **jetzt** live geholt, nicht
/// aus einem Zwischenspeicher.
Future<void> zeigeModellWahl(BuildContext context) {
  final container = ProviderScope.containerOf(context, listen: false);
  final liste = container.read(kiZugangProvider.notifier).ladeModelle()
    // Scheitert der Abruf, bevor das Blatt zuhört, gilt der Fehler sonst
    // als unbehandelt. Das Blatt bekommt ihn trotzdem.
    ..ignore();
  return showCupertinoModalPopup<void>(
    context: context,
    builder: (_) =>
        _ModellBlatt(key: const Key('ki-modell-blatt'), liste: liste),
  );
}

class _ModellBlatt extends ConsumerStatefulWidget {
  const _ModellBlatt({super.key, required this.liste});

  final Future<List<KiModell>> liste;

  @override
  ConsumerState<_ModellBlatt> createState() => _ModellZustand();
}

/// Wie weit die Liste ist — eigener Zustand, kein `AsyncValue`.
sealed class _Liste {
  const _Liste();
}

final class _Laedt extends _Liste {
  const _Laedt();
}

final class _Da extends _Liste {
  const _Da(this.modelle);
  final List<KiModell> modelle;
}

final class _Fehler extends _Liste {
  const _Fehler(this.fehler);
  final KiFehler fehler;
}

class _ModellZustand extends ConsumerState<_ModellBlatt> {
  _Liste _liste = const _Laedt();

  /// Das Modell, dessen Testbild gerade läuft.
  String? _waehlt;

  /// Warum das zuletzt gewählte nicht übernommen wurde.
  String? _grund;

  /// Der Platz des Grunds — damit er ins Bild gerollt werden kann (#346).
  final _grundSchluessel = GlobalKey();

  @override
  void initState() {
    super.initState();
    widget.liste.then(
      (modelle) {
        if (mounted) setState(() => _liste = _Da(modelle));
      },
      onError: (Object fehler) {
        if (!mounted) return;
        if (fehler is! KiFehler) throw fehler;
        setState(() => _liste = _Fehler(fehler));
      },
    );
  }

  Future<void> _waehle(String id) async {
    setState(() {
      _waehlt = id;
      _grund = null;
    });
    final wahl = await ref.read(kiZugangProvider.notifier).waehleModell(id);
    if (!mounted) return;
    if (wahl == KiWahl.gewaehlt) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _waehlt = null;
      _grund = switch (wahl) {
        KiWahl.gewaehlt => null,
        KiWahl.abgelehnt =>
          'Google lehnt den Schlüssel ab. Es bleibt beim bisherigen Modell.',
        KiWahl.keinNetz =>
          'Kein Netz — Google ist nicht erreichbar. Es bleibt beim '
              'bisherigen Modell.',
        KiWahl.kontingent =>
          'Google meldet: Kontingent erschöpft. Es bleibt beim bisherigen '
              'Modell.',
        KiWahl.limit =>
          'Das Monatslimit ist erreicht — das Testbild startet nicht. Es '
              'bleibt beim bisherigen Modell.',
        KiWahl.gestoert =>
          '$id hat das Testbild nicht angenommen. Es bleibt beim bisherigen '
              'Modell.',
      };
    });
    // Der Grund steht unter der Liste. Mit 22 Modellen liegt er auf dem
    // Telefon weit unterhalb des Blatts — Tim sah nur den Kringel
    // verschwinden und das Häkchen bleiben (#346). Darum wird er ins Bild
    // gerollt, sobald er steht.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ort = _grundSchluessel.currentContext;
      if (!mounted || ort == null) return;
      unawaited(
        Scrollable.ensureVisible(
          ort,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(kiZugangProvider);
    final gewaehlt = zustand is MitSchluessel ? zustand.modell : null;
    final grund = _grund;

    final (kopf, zeilen) = switch (_liste) {
      _Laedt() => ('Wird von Google geladen …', _graueZeilen()),
      _Fehler(:final fehler) => (_fehlerKopf(fehler), _graueZeilen()),
      _Da(:final modelle) => (
        'Von Google, eben geladen',
        [
          for (final m in modelle)
            _ModellZeile(
              key: Key('ki-modell-${m.id}'),
              modell: m,
              gewaehlt: m.id == gewaehlt,
              prueft: m.id == _waehlt,
              onTap: _waehlt != null || m.id == gewaehlt
                  ? null
                  : () => _waehle(m.id),
            ),
        ],
      ),
    };

    return KiBlatt(
      titel: 'Modell für Fotos',
      abbrechen: KiLeistenKnopf(
        titel: 'Abbrechen',
        onPressed: () => Navigator.of(context).pop(),
      ),
      inhalt: [
        KiFormKopf(kopf),
        KiFormKarte(zeilen: zeilen),
        if (grund != null)
          KeyedSubtree(
            key: _grundSchluessel,
            child: KiNotiz(
              key: const Key('ki-modell-grund'),
              ton: KiTon.warnung,
              text: grund,
              rand: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            ),
          ),
        const KiFormFuss(
          'Nur Modelle, die ein Foto annehmen. Beim Auswählen schickt die '
          'App ein winziges Testbild mit — das kostet einen Bruchteil eines '
          'Cents und zeigt, ob das Modell Bilder wirklich nimmt.',
        ),
      ],
    );
  }

  static String _fehlerKopf(KiFehler fehler) => switch (fehler) {
    KeinNetz() => 'Kein Netz — Google ist nicht erreichbar',
    SchluesselAbgelehnt() => 'Google lehnt den Schlüssel ab',
    Kontingent() => 'Google meldet: Kontingent erschöpft',
    AntwortUnbrauchbar() ||
    Sonstiges() => 'Google antwortet nicht wie erwartet',
  };

  /// Dieselben Zeilen in Grau, dieselbe Höhe — so viele, wie der Entwurf
  /// zeichnet.
  static List<Widget> _graueZeilen() => [
    // Alle tragen denselben Schlüssel (`ki-modell-grau`); als Geschwister
    // brauchen sie trotzdem je einen eigenen.
    for (var i = 0; i < 5; i++)
      KeyedSubtree(
        key: ValueKey('ki-modell-grau-$i'),
        child: const _GraueZeile(key: Key('ki-modell-grau')),
      ),
  ];
}

class _ModellZeile extends StatelessWidget {
  const _ModellZeile({
    super.key,
    required this.modell,
    required this.gewaehlt,
    required this.prueft,
    required this.onTap,
  });

  final KiModell modell;
  final bool gewaehlt;
  final bool prueft;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final unter = modell.vorschau
        ? 'Vorschau — kann sich ändern oder wegfallen'
        : '${modell.anzeigeName} · stabil';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
        child: Row(
          children: [
            Expanded(
              child: _ZweiZeilen(oben: Text(modell.id), unten: Text(unter)),
            ),
            SizedBox(
              width: 24,
              child: prueft
                  ? const CupertinoActivityIndicator(radius: 8)
                  : Text(
                      gewaehlt ? '✓' : '',
                      textAlign: TextAlign.end,
                      style: TextStyle(color: river),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GraueZeile extends StatelessWidget {
  const _GraueZeile({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.fromLTRB(14, 9, 14, 9),
    child: Row(
      children: [
        Expanded(
          child: _ZweiZeilen(
            oben: Platzhalter(beispiel: 'gemini-3.5-flash-lite'),
            unten: Platzhalter(
              beispiel: 'Gemini 3.5 Flash-Lite · stabil',
              stil: _ZweiZeilen.klein,
            ),
          ),
        ),
        SizedBox(width: 24),
      ],
    ),
  );
}

/// Name und kleine Zeile darunter — `.formrow .l small`.
class _ZweiZeilen extends StatelessWidget {
  const _ZweiZeilen({required this.oben, required this.unten});

  final Widget oben;
  final Widget unten;

  static const klein = TextStyle(fontSize: 12);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      oben,
      const SizedBox(height: 2),
      DefaultTextStyle.merge(
        style: klein.copyWith(
          color: CupertinoDynamicColor.resolve(Palette.muted, context),
        ),
        child: unten,
      ),
    ],
  );
}
