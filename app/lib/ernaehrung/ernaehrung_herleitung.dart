// „Woher das Ziel kommt" — der Inhalt des eingeklappten Abschnitts auf dem
// Ernährungs-Tag (#314). Drei Zeilen wie im Entwurf
// (`docs/screens/screens/ernaehrung.js`, `HERLEITUNG`): Grundumsatz,
// Aktiv, Körperziel. Die Zahlen kommen aus `kalorienzielAnteile` im Kern
// über [ernaehrungsHerleitungProvider]; ihre Summe ist das Ziel im Ring.
//
// Darüber seit #410 die Zeile **Quelle**: woher die Zahl stammt und seit
// wann — „fest seit …" mit „berechnet" oder „von Hand", vor der ersten
// Festlegung „berechnet". Vorgegeben durch
// `test/ernaehrung/kalorienziel_herleitung_quelle_test.dart`
// (Festlegungen des Test-Agenten, nicht von Tim).
//
// Seit #449 (unter #404) die **Auszeit**: Liegt der Tag in einer OP,
// Krankheit oder Verletzung, sagt die Körperziel-Zeile „pausiert“ und bis
// wann, und die Erklärung trägt den Hinweis auf die ärztliche Freigabe.
// Entwurf `HERLEITUNG_PAUSIERT` in `docs/screens/screens/ernaehrung.js`,
// Spec „Herleitung auf dem Ernährungs-Tag“, V15–V17; vorgegeben durch
// `test/ernaehrung/herleitung_pausiert_test.dart`.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ereignisse.dart';
import '../data/kalorienziele.dart';
import '../data/stammdaten.dart';
import '../design/formatierung.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/typografie.dart';
import '../design/zahlen.dart';
import '../shell/mess_abschnitte.dart' show datumZumAnzeigen;
import '../ziele/auszeit_texte.dart';
import 'ernaehrung_provider.dart';

/// Der Inhalt von „Woher das Ziel kommt".
///
/// **Eine Schätzung gibt sich nicht als Messung aus.** Für heute fällt
/// das Ziel immer auf Mifflin-St Jeor zurück (#229); die Grundumsatz-Zeile
/// sagt dann „geschätzt" und nennt keine Uhr, die Aktiv-Zeile „Planwert".
///
/// **Ohne Körperziel steht die Zeile mit `–/–`**, nicht mit `+ 0 kcal`:
/// Kein Körperziel ist etwas anderes als eines, das gerade keinen
/// Aufschlag ergibt (erreicht, OP-Erholung) — dort steht die `0` zu Recht.
/// Ist gar kein Ziel berechenbar, stehen alle drei Zeilen mit `–/–`, und
/// der Grund steht einmal, nicht je Zeile.
///
/// **An einem festen Tag (#410)** zeigen die drei Zeilen die beim
/// Festlegen gespeicherten Anteile — ihre Summe bleibt die Zahl im Ring
/// (#314). Ein Ziel von Hand hat keine Anteile; dann stehen die drei
/// Zeilen mit `–/–`, und die Quelle sagt, warum.
///
/// **In der Auszeit (#449)** sagt die Körperziel-Zeile „pausiert“ und bis
/// wann — nicht `+ 0 kcal`: Eine Null hieße „das Körperziel bringt
/// nichts“, die Wahrheit ist „es ist ausgesetzt, und zwar bis dann“. Ob
/// pausiert ist, entscheidet [ErnaehrungsTag.pausiertDurch], nicht diese
/// Datei; ohne Körperziel bleibt es bei „kein Körperziel eingetragen“.
/// Ein Ziel von Hand bleibt, wie es ist (V15) — die Erklärung trägt dann
/// trotzdem den Hinweis auf die Freigabe.
class ErnaehrungHerleitung extends ConsumerWidget {
  const ErnaehrungHerleitung({super.key, required this.tag});

  final ErnaehrungsTag tag;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final erklaerStil = TextStyle(fontSize: 12, color: muted, height: 1.4);
    final anteile = ref.watch(
      ernaehrungsHerleitungProvider(tag.tagesSchluessel),
    );
    final stammdaten = stammdatenAusProvider(ref.watch(stammdatenProvider))
        .stammdaten;
    final pause = tag.pausiertDurch;

    String kcal(double wert) => '${formatNumber(wert)} kcal';

    final _Zeile grundumsatz;
    final _Zeile aktiv;
    final _Zeile koerperziel;
    final String erklaerung;
    final aktivTitel = tag.istHeute ? 'Aktiv heute' : 'Aktiv';
    final fest = tag.zielFestlegung;
    final quelle = _quelle(tag, fest);

    if (fest != null && fest.herkunft == KalorienzielHerkunft.hand) {
      // Von Hand gibt es keine Aufteilung — die drei Zeilen stehen trotzdem,
      // ungefüllt, und der Grund steht einmal in der Erklärung.
      grundumsatz = const _Zeile('Grundumsatz', null, '');
      aktiv = _Zeile(aktivTitel, null, '');
      koerperziel = const _Zeile('Körperziel', null, '');
      const vonHand =
          'Dieses Ziel ist von Hand gesetzt, nicht aus Grundumsatz, Aktivität '
          'und Körperziel gerechnet — eine Aufteilung gibt es dafür nicht.';
      // V15: Die Zahl von Hand bleibt auch in einer OP, Krankheit oder
      // Verletzung — `pausiertDurch` ist dann `null`. Der Hinweis auf die
      // Freigabe steht trotzdem da; welche Auszeit gilt, liest nur dieser
      // Fall selbst nach.
      final auszeit = ref.watch(
        auszeitenProvider.select(
          (s) => s.laden
              ? null
              : pausierendeAuszeitAm(s.auszeiten, tag.tagesSchluessel),
        ),
      );
      erklaerung = auszeit == null ? vonHand : '$vonHand $auszeitFreigabe';
    } else if (fest != null && anteile != null) {
      grundumsatz = _Zeile(
        'Grundumsatz',
        kcal(anteile.grundumsatzKcal),
        'geschätzt',
      );
      aktiv = _Zeile(
        aktivTitel,
        'Planwert ${kcal(anteile.aktivKcal)}',
        'nicht gemessen',
      );
      // Der Aufschlag von **damals**: Die Stammdaten können sich seither
      // geändert haben, die Zahl im Ring nicht. Nur ein Aufschlag von 0
      // ohne eingetragenes Körperziel heißt „keins" — `+ 0 kcal` behauptete
      // sonst ein Körperziel ohne Aufschlag (#314).
      final keinKoerperziel =
          anteile.koerperzielKcal == 0 &&
          (stammdaten.zielgewichtKg == null || stammdaten.zieldatum == null);
      koerperziel = pause != null
          ? _pausiert(pause)
          : keinKoerperziel
          ? const _Zeile('Körperziel', null, 'kein Körperziel eingetragen')
          : _Zeile(
              'Körperziel',
              '+ ${formatNumber(anteile.koerperzielKcal)} kcal',
              'beim Festlegen',
            );
      erklaerung = pause != null
          ? auszeitHerleitungFreigabe(pause.art)
          : 'Einmal mit dem Planwert gerechnet und seitdem fest. Neue '
                'Messwerte ändern das Ziel nicht — nur eine neue Zahl in '
                '„Vorläufige Werte".';
    } else if (anteile == null) {
      // Solange der Health-Lauf aussteht, ist nichts entschieden — kein
      // Grund, nur die ungefüllte Form (Fehler `01`).
      grundumsatz = _Zeile(
        'Grundumsatz',
        null,
        tag.zielLaedt ? '' : 'kein Ziel berechenbar',
      );
      aktiv = _Zeile(aktivTitel, null, '');
      koerperziel = _Zeile('Körperziel', null, '');
      erklaerung = tag.zielLaedt
          ? ''
          : 'Ohne Gewicht, Größe und Geburtsjahr lässt sich kein '
                'Kalorienziel rechnen.';
    } else if (anteile.gemessen) {
      grundumsatz = _Zeile(
        'Grundumsatz',
        kcal(anteile.grundumsatzKcal),
        'Apple Watch',
      );
      aktiv = _Zeile(aktivTitel, kcal(anteile.aktivKcal), 'Apple Watch');
      koerperziel = pause != null
          ? _pausiert(pause)
          : _koerperziel(
              anteile.koerperzielKcal,
              stammdaten.zielgewichtKg,
              stammdaten.zieldatum,
            );
      erklaerung = pause != null
          ? auszeitHerleitungFreigabe(pause.art)
          : 'An einem abgeschlossenen Tag zählt, was die Apple Watch den '
                'ganzen Tag gemessen hat.';
    } else {
      grundumsatz = _Zeile(
        'Grundumsatz',
        kcal(anteile.grundumsatzKcal),
        'geschätzt',
      );
      aktiv = _Zeile(
        aktivTitel,
        'Planwert ${kcal(anteile.aktivKcal)}',
        'nicht gemessen',
      );
      koerperziel = pause != null
          ? _pausiert(pause)
          : _koerperziel(
              anteile.koerperzielKcal,
              stammdaten.zielgewichtKg,
              stammdaten.zieldatum,
            );
      erklaerung = pause != null
          ? auszeitHerleitungFreigabe(pause.art)
          : tag.istHeute
          ? 'Der Aktivwert ist der Planwert für heute, nicht der bisher '
                'gemessene — sonst wüchse das Ziel über den Tag und stünde '
                'morgens anders da als abends.'
          : 'Für diesen Tag fehlt eine ganztägige Messung der Apple Watch; '
                'Grundumsatz und Aktivwert sind geschätzt.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _StatZeile(
          key: const Key('ernaehrung-herleitung-quelle'),
          zeile: quelle,
        ),
        _StatZeile(
          key: const Key('ernaehrung-herleitung-grundumsatz'),
          zeile: grundumsatz,
        ),
        _StatZeile(key: const Key('ernaehrung-herleitung-aktiv'), zeile: aktiv),
        _StatZeile(
          key: const Key('ernaehrung-herleitung-koerperziel'),
          zeile: koerperziel,
        ),
        Padding(
          key: const Key('ernaehrung-herleitung-erklaerung'),
          padding: const EdgeInsets.only(top: 8),
          // Feste Zeilenzahl, **fünf in jedem Zustand** (V17): Die
          // Erklärung wechselt mit dem Tag, die Karte soll dabei nicht
          // springen, und der Freigabe-Hinweis der Auszeit braucht bei
          // Standardschrift vier bis fünf Zeilen — abgeschnitten wäre er
          // schlimmer als keiner. Die unsichtbare Fassung gibt die Höhe
          // vor, die sichtbare füllt sie.
          child: Stack(
            children: [
              ExcludeSemantics(
                child: Opacity(
                  opacity: 0,
                  child: Text('\n\n\n\n', style: erklaerStil),
                ),
              ),
              Text(
                erklaerung,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: erklaerStil,
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Woher die Zahl stammt und seit wann — **in jedem Zustand eine
  /// Zeile**, auch ohne Ziel und während des Ladens (dieselbe Form).
  ///
  /// - fest, gerechnet: „fest seit 13.07.2026", Hinweis „berechnet";
  /// - fest, von Hand: „fest seit …", Hinweis „von Hand";
  /// - vor der ersten Festlegung: „berechnet", Hinweis „für diesen Tag" —
  ///   der Tag rechnete für sich und ist nie festgelegt worden;
  /// - kein Ziel oder noch nicht gelesen: `–/–` ohne Grund — der steht
  ///   schon einmal in der Grundumsatz-Zeile.
  _Zeile _quelle(ErnaehrungsTag tag, KalorienzielFestlegung? fest) {
    if (fest != null) {
      final seit = 'fest seit ${Format.tag(datumZumAnzeigen(fest.abTag))}';
      return switch (fest.herkunft) {
        KalorienzielHerkunft.berechnet => _Zeile('Quelle', seit, 'berechnet'),
        KalorienzielHerkunft.hand => _Zeile('Quelle', seit, 'von Hand'),
      };
    }
    if (tag.zielKcal == null) return const _Zeile('Quelle', null, '');
    return const _Zeile('Quelle', 'berechnet', 'für diesen Tag');
  }

  /// Die Körperziel-Zeile in der Auszeit: „pausiert“, rechts bis wann —
  /// vorgelesen mit dem Ende als Wort („Körperziel, pausiert, OP-Erholung
  /// bis 28. Oktober“).
  _Zeile _pausiert(AuszeitTage pause) => _Zeile(
    'Körperziel',
    'pausiert',
    auszeitPauseBis(pause.art, pause.bis),
    vorlesen:
        'Körperziel, pausiert, '
        '${auszeitPauseBisVorlesen(pause.art, pause.bis)}',
  );

  /// Ein Körperziel braucht Zielgewicht **und** Zieldatum (wie im Kern);
  /// fehlt eins, gibt es keins — und dann `–/–` statt `+ 0 kcal`.
  _Zeile _koerperziel(double kcal, double? zielgewichtKg, String? zieldatum) {
    if (zielgewichtKg == null || zieldatum == null) {
      return const _Zeile('Körperziel', null, 'kein Körperziel eingetragen');
    }
    final kg = formatNumber(
      zielgewichtKg,
      nachkommastellen: zielgewichtKg % 1 == 0 ? 0 : 1,
    );
    return _Zeile('Körperziel', '+ ${formatNumber(kcal)} kcal', 'Ziel $kg kg');
  }
}

/// Titel, Wert (`null` heißt „kein Wert") und Hinweis einer Zeile.
class _Zeile {
  const _Zeile(this.titel, this.wert, this.hinweis, {this.vorlesen});

  final String titel;
  final String? wert;
  final String hinweis;

  /// Der Vorlesetext, wenn er anders klingen soll als die Zeile aussieht
  /// (ein Datum als Wort statt als Ziffern). Sonst aus den drei Teilen.
  final String? vorlesen;
}

class _StatZeile extends StatelessWidget {
  const _StatZeile({super.key, required this.zeile});

  final _Zeile zeile;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final wert = zeile.wert;

    // Der Vorlesetext nennt den Zustand, nicht das Zeichen: „Körperziel,
    // kein Körperziel eingetragen", nicht „Strich Schrägstrich Strich".
    final vorlesen =
        zeile.vorlesen ??
        [
          zeile.titel,
          ?wert,
          if (zeile.hinweis.isNotEmpty)
            zeile.hinweis
          else if (wert == null)
            'kein Wert',
        ].join(', ');

    return Semantics(
      container: true,
      label: vorlesen,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(zeile.titel, style: TextStyle(fontSize: 14, color: muted)),
            const Spacer(),
            Text(
              wert ?? ohneWert,
              style: Typografie.tabularNumbers(
                TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(zeile.hinweis, style: TextStyle(fontSize: 12, color: muted)),
          ],
        ),
      ),
    );
  }
}
