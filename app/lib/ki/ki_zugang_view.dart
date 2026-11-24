// Der Schirm „KI-Zugang" (#339) — Gemini-Schlüssel hinterlegen, prüfen,
// entfernen; Modell für die Foto-Schätzung; Verbrauch als Selbstzählung.
//
// API und Verhalten sind durch `app/test/ki/ki_zugang_view_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/ki-zugang.js`: **drei Gruppen in jedem
// Zustand** (Gemini · Modell · Verbrauch), Fehlendes als `–/–`, Ladendes
// als graue Form. Begründungen in
// `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`.
//
// **Der Satz zur bezahlten Stufe steht wörtlich aus dem Entwurf** und ist
// offen zum Gegenlesen durch Tim (Spec, „Was der Schirm über die Stufe
// sagt"). Wer ihn ändert, ändert ihn im Entwurf mit.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/formatierung.dart';
import '../design/glas_abstand.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart';
import '../design/zahlen.dart';
import '../health/health_provider.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gemini_preise.dart';
import 'ki_zugang_bausteine.dart';
import 'ki_zugang_blaetter.dart';
import 'ki_zugang_provider.dart';

/// Öffnet den KI-Zugang auf dem Stapel des **aktuell gewählten** Tabs —
/// die eine Stelle, die das weiß (wie `oeffneVorlaeufigeWerte`). Auf
/// diesen Schirm verweist jedes Feature, das KI braucht.
///
/// **Benannte Abweichung vom Board:** Dort hängt er unter Mehr ›
/// Einstellungen › KI-Zugang (`docs/screens/screens/einstellungen.js`).
/// Den Einstellungs-Schirm gibt es im Flutter-Neubau noch nicht; bis dahin
/// steht der Eingang unter Mehr › Verwalten, wie „Vorläufige Werte".
void oeffneKiZugang(AppRouter router) =>
    router.open(AppTarget.aktuell((context) => const KiZugangSeite()));

/// Gerüst und Navigationsleiste um [KiZugangView]. **Kein eigener
/// `Navigator`** — den stellt `RootView`.
class KiZugangSeite extends StatelessWidget {
  const KiZugangSeite({super.key});

  @override
  Widget build(BuildContext context) => CupertinoPageScaffold(
    backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
    navigationBar: const CupertinoNavigationBar(middle: Text('KI-Zugang')),
    child: const KiZugangView(),
  );
}

/// Der Schirm selbst. **Er besorgt seine Daten selbst**
/// ([kiZugangProvider]).
class KiZugangView extends ConsumerStatefulWidget {
  const KiZugangView({super.key});

  @override
  ConsumerState<KiZugangView> createState() => _KiZugangViewZustand();
}

class _KiZugangViewZustand extends ConsumerState<KiZugangView> {
  @override
  void initState() {
    super.initState();
    // Kam der letzte Nachlauf nicht durch (kein Netz, Störung), läuft er
    // beim Wiederkommen noch einmal — „sobald Google erreichbar ist",
    // wie der Hinweis zusagt. Nach dem ersten Bild, nicht im Aufbau.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(kiZugangProvider.notifier).pruefeErneut();
    });
  }

  @override
  Widget build(BuildContext context) {
    final zustand = ref.watch(kiZugangProvider);
    final jetzt = ref.watch(clockProvider)();

    final mit = zustand is MitSchluessel ? zustand : null;
    final topf = switch (zustand) {
      MitSchluessel(:final topf) || OhneSchluessel(:final topf) => topf,
      KiZugangLaedt() => null,
    };
    final oben = mit == null ? null : _hinweisOben(mit);

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (oben != null)
            KiNotiz(
              key: const Key('ki-zugang-hinweis-oben'),
              ton: oben.$1,
              text: oben.$2,
            ),
          _GruppeGemini(zustand: zustand, jetzt: jetzt),
          _GruppeModell(zustand: zustand),
          _GruppeVerbrauch(topf: topf, jetzt: jetzt),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: KeyedSubtree(
              key: const Key('ki-zugang-knopf'),
              child: switch (zustand) {
                KiZugangLaedt() => KiKnopf(
                  titel: null,
                  farbe: Palette.river,
                  voll: true,
                  onPressed: null,
                ),
                OhneSchluessel() => KiKnopf(
                  titel: 'Schlüssel hinterlegen',
                  farbe: Palette.river,
                  voll: true,
                  onPressed: () => zeigeSchluesselEintragen(context),
                ),
                MitSchluessel() => KiKnopf(
                  titel: 'Schlüssel entfernen',
                  farbe: Palette.warn,
                  voll: false,
                  onPressed: () => zeigeSchluesselEntfernen(context),
                ),
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Höchstens **ein** Hinweis über den Gruppen, der wichtigste zuerst.
  (KiTon, String)? _hinweisOben(MitSchluessel m) {
    switch (m.pruefung?.ergebnis) {
      case 'abgelehnt':
        return (
          KiTon.warnung,
          'Google hat den Schlüssel bei der letzten Anfrage abgelehnt. Die '
              'Foto-Schätzung ruht, bis du einen neuen hinterlegst.',
        );
      case 'kontingent':
        // Der Satz zur kostenlosen Stufe aus dem Entwurf kommt erst, wenn
        // die Form des 429 an einem echten Fehler geprüft ist (Plan,
        // Task 11).
        return (
          KiTon.warnung,
          'Google hat die letzte Anfrage abgelehnt: Kontingent erschöpft.',
        );
    }
    switch (m.nachlauf) {
      case KiNachlauf.keinNetz:
        return (
          KiTon.neutral,
          'Kein Netz. Gezeigt wird der Stand der letzten Prüfung; '
              'Modellliste und Prüfung laufen wieder, sobald Google '
              'erreichbar ist.',
        );
      case KiNachlauf.gestoert:
        return (
          KiTon.neutral,
          'Google antwortet gerade nicht wie erwartet. Gezeigt wird der '
              'Stand der letzten Prüfung; Modellliste und Prüfung laufen '
              'wieder, sobald Google erreichbar ist.',
        );
      case KiNachlauf.laeuft || KiNachlauf.fertig:
        break;
    }
    final weg = m.gemerktFehlt;
    if (weg != null) {
      final ersatz = m.modell == voreingestelltesModell
          ? 'die Voreinstellung'
          : m.modell;
      return (
        KiTon.warnung,
        'Google bietet $weg nicht mehr an. Die Foto-Schätzung nutzt jetzt '
            '$ersatz — wählen kannst du unter „Modell".',
      );
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// 1. Schlüssel

/// Der Satz zur bezahlten Stufe — **wörtlich aus `ki-zugang.js`**, offen
/// zum Gegenlesen durch Tim.
const _stufe =
    'Gedacht für die bezahlte Stufe: Nur dort sagt Google ohne Ausnahme '
    'zu, Fotos und Antworten nicht für eigene Produkte zu verwenden. '
    'Abrechnung einrichten in Google AI Studio unter „Projekte" — ob dieser '
    'Schlüssel daran hängt, kann die App nicht abfragen.';

class _GruppeGemini extends StatelessWidget {
  const _GruppeGemini({required this.zustand, required this.jetzt});

  final KiZugangZustand zustand;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final (schluessel, schluesselFarbe) = switch (zustand) {
      KiZugangLaedt() => (null, null),
      OhneSchluessel() => ('nicht hinterlegt', Palette.muted),
      MitSchluessel(:final endung) => ('··············$endung', null),
    };
    final (status, statusFarbe) = _status(zustand, jetzt);

    return Column(
      key: const Key('ki-zugang-gruppe-gemini'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KiGruppenKopf('Gemini · Google'),
        KiKarte(
          zeilen: [
            KiZeile(
              key: const Key('ki-zugang-schluessel'),
              titel: 'Schlüssel',
              wert: schluessel,
              farbe: schluesselFarbe,
              tuer: true,
              onTap: zustand is KiZugangLaedt
                  ? null
                  : () => zeigeSchluesselEintragen(context),
            ),
            KiZeile(
              key: const Key('ki-zugang-geprueft'),
              titel: 'Geprüft',
              wert: status,
              farbe: statusFarbe,
              semantik: status == ohneWert ? 'Geprüft, keine Werte' : null,
            ),
          ],
        ),
        const KiNotiz(ton: KiTon.neutral, text: _stufe),
        const KiFussnote(
          'Der Schlüssel liegt in der Keychain, nur auf diesem iPhone. Er '
          'steht in keinem Export und keinem Backup und zieht nicht mit auf '
          'ein neues Gerät.',
        ),
      ],
    );
  }

  static (String?, Color?) _status(KiZugangZustand z, DateTime jetzt) {
    switch (z) {
      case KiZugangLaedt():
        return (null, null);
      case OhneSchluessel():
        return (ohneWert, Palette.muted);
      case MitSchluessel(:final pruefung, :final nachlauf):
        if (pruefung == null) return (ohneWert, Palette.muted);
        final wann = _wann(pruefung.am, jetzt, komma: true);
        final (wort, farbe) = switch (pruefung.ergebnis) {
          'gueltig' => ('gültig', Palette.ok),
          'abgelehnt' => ('abgelehnt', Palette.warn),
          'kontingent' => ('Kontingent erschöpft', Palette.warn),
          final anders => (anders, Palette.muted),
        };
        // Ohne Netz bleibt der letzte Stand stehen — gedämpft, weil er
        // gerade nicht bestätigt werden kann.
        final gedaempft =
            nachlauf == KiNachlauf.keinNetz || nachlauf == KiNachlauf.gestoert;
        return ('$wann · $wort', gedaempft ? Palette.muted : farbe);
    }
  }
}

// ---------------------------------------------------------------------------
// 2. Modell

class _GruppeModell extends StatelessWidget {
  const _GruppeModell({required this.zustand});

  final KiZugangZustand zustand;

  @override
  Widget build(BuildContext context) {
    final (wert, farbe, unter) = switch (zustand) {
      KiZugangLaedt() => (null, null, null),
      OhneSchluessel() => ('erst mit Schlüssel', Palette.muted, null),
      MitSchluessel(:final modell, :final gemerktFehlt) => (
        modell,
        gemerktFehlt != null ? Palette.warn : null,
        gemerktFehlt != null && modell == voreingestelltesModell
            ? 'Voreinstellung'
            : null,
      ),
    };
    return Column(
      key: const Key('ki-zugang-gruppe-modell'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KiGruppenKopf('Modell'),
        KiKarte(
          zeilen: [
            KiZeile(
              key: const Key('ki-zugang-modell'),
              titel: 'Foto-Schätzung',
              wert: wert,
              farbe: farbe,
              unterWert: unter,
              tuer: true,
              onTap: zustand is MitSchluessel
                  ? () => zeigeModellWahl(context)
                  : null,
            ),
          ],
        ),
        const KiFussnote(
          'Die Liste kommt live von Google, nur mit Modellen, die ein Foto '
          'annehmen. Chat und Tagescheck bekommen ihre eigene Wahl, sobald '
          'es den Coach gibt.',
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Verbrauch

class _GruppeVerbrauch extends StatelessWidget {
  const _GruppeVerbrauch({required this.topf, required this.jetzt});

  /// `null` heißt „lädt".
  final KiTopf? topf;
  final DateTime jetzt;

  @override
  Widget build(BuildContext context) {
    final topf = this.topf;
    return Column(
      key: const Key('ki-zugang-gruppe-verbrauch'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const KiGruppenKopf('Verbrauch dieser App'),
        KiKarte(
          zeilen: [
            KiStatZeile(
              titel: 'Diesen Monat',
              wert: topf == null ? null : _monat(topf),
              wertSchluessel: const Key('ki-zugang-monat'),
            ),
            KiStatZeile(
              titel: 'Anfragen',
              wert: topf == null ? null : _anfragen(topf, jetzt),
              wertSchluessel: const Key('ki-zugang-anfragen'),
            ),
          ],
        ),
        KiKarte(
          abstandOben: 9,
          zeilen: [
            KiZeile(
              key: const Key('ki-zugang-limit'),
              titel: 'Monatslimit',
              wert: topf == null ? null : dollar(topf.limitUsd),
              tuer: true,
              onTap: topf == null ? null : () => zeigeLimit(context, topf),
            ),
            KiZeile(
              key: const Key('ki-zugang-preis'),
              titel: 'Preis je Mio. Token',
              wert: topf == null ? null : _preis(topf),
              tuer: true,
              semantik: topf != null && topf.preis == null
                  ? 'Preis, keine Werte'
                  : null,
              onTap: topf == null ? null : () => zeigePreis(context, topf),
            ),
          ],
        ),
        if (topf != null && topf.erreicht)
          KiNotiz(
            key: const Key('ki-zugang-limit-hinweis'),
            ton: KiTon.warnung,
            text:
                'Das Monatslimit ist erreicht. Bis zum '
                '${Format.tagMonatAusgeschrieben(kalendertag(topf.limitEnde))} '
                'startet keine neue Anfrage — die Foto-Schätzung ruht. Eine '
                'Anfrage, die gerade läuft, läuft zu Ende.',
          ),
        const KiFussnote(
          'Gezählt aus den Token jeder Antwort mal den Preisen oben — kein '
          'Kontostand. Benutzt du denselben Schlüssel woanders, sieht die '
          'App das nicht. Google gibt die Preise nicht über die '
          'Schnittstelle heraus; sie sind mit dem Stand dieser App-Fassung '
          'vorbelegt und änderbar.',
        ),
      ],
    );
  }

  /// „1,84 $ von 10,00 $". Fehlen Beträge (Modell ohne Preis), zählt die
  /// Summe nur die bekannten und sagt es mit „mind." — eine Zahl, die
  /// vollständig aussieht und es nicht ist, wäre schlimmer.
  static String _monat(KiTopf t) {
    final summe = '${dollar(t.summe.usd)} von ${dollar(t.limitUsd)}';
    return t.summe.unvollstaendig ? 'mind. $summe' : summe;
  }

  static String _anfragen(KiTopf t, DateTime jetzt) {
    final zuletzt = t.zuletzt;
    if (t.summe.anfragen == 0 && zuletzt == null) return 'noch keine';
    final anzahl = formatNumber(t.summe.anfragen.toDouble());
    if (zuletzt == null) return anzahl;
    return '$anzahl · zuletzt ${_wann(zuletzt, jetzt, komma: false)}';
  }

  static String _preis(KiTopf t) {
    final p = t.preis;
    if (p == null) return ohneWert;
    return 'ein ${dollar(p.eingabeJeMio)} · aus ${dollar(p.ausgabeJeMio)}';
  }
}

/// US-Dollar mit zwei Stellen, deutsche Schreibweise: „1,84 $". Gerundet
/// wird nur hier, in der Anzeige.
String dollar(double usd) => '${formatNumber(usd, nachkommastellen: 2)} \$';

/// „heute, 06:48" (bzw. ohne Komma), „gestern 21:58", „27.10., 21:58".
///
/// Als Ortszeit: In der Datenbank liegen UTC-Zeitpunkte, angezeigt wird
/// die Wanduhr des Geräts — dieselbe Lesart wie `clockProvider`.
String _wann(DateTime utc, DateTime jetzt, {required bool komma}) {
  final stand = utc.toLocal();
  final bezug = jetzt.toLocal();
  final selberTag =
      stand.year == bezug.year &&
      stand.month == bezug.month &&
      stand.day == bezug.day;
  if (selberTag) return 'heute${komma ? ',' : ''} ${Format.uhrzeit(stand)}';
  return Format.standZeitpunkt(stand, jetzt: bezug);
}
