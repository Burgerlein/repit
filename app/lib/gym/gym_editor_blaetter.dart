// Die übrigen Blätter des Editors (#534; Spec 9.3 bis 9.5, 28, 29; Entwurf
// `docs/screens/screens/gym-training-editor.js`, Varianten `uebung-waehlen`
// und das Eingabeblatt für eigene Minuten): die **Auswahl** aus der
// Bibliothek und die eigenen Minuten.
//
// **Auswahl und Blatt liegen übereinander** (Spec 28 Nr. 1, in Nachtrag 29
// Nr. 1 geändert): Antippen in der Auswahl **fügt nichts hinzu**, es öffnet
// die **Vorschau** ([GymEditorVorschauBlatt]) über der Auswahl. Erst deren
// „Speichern" fügt die Übung mit den eingestellten Werten hinzu und kehrt
// zur Auswahl zurück — samt Suchtext und Scrollposition; „Zurück" verwirft.
// Die Auswahl selbst schließt über ihr „Zurück".
//
// **Standard-iOS-Elemente, nicht eigens entworfen** (Tim, 19.11.2026, Spec 22
// Nr. 4); die Wortlaute sind Vorschläge der Spec und stehen in
// `gym_editor_texte.dart`.
//
// **Die Blätter halten nichts** (außer die Vorschau ihren noch nicht
// gespeicherten Umfang): Sie lesen den Stand des Editors
// ([gymEditorProvider]) und schreiben durch dessen Notifier. Darum übersteht
// der Stand das Öffnen und Schließen (Fehler `32`).
//
// Rahmen und Bauteile stehen in `gym_editor_blatt_bausteine.dart`, die
// beiden Zustände des Übungsblatts in `gym_editor_einstellblatt.dart`
// (#559 — diese Datei trug vorher alles zusammen und war über 900 Zeilen).
// Beide werden hier **weitergereicht**, damit die Aufrufer unverändert
// `gym_editor_blaetter.dart` importieren können.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../design/inset_card.dart';
import '../design/karten_flaeche.dart';
import '../design/palette.dart';
import '../design/platzhalter.dart' show FesteZeilen;
import 'gym_editor_blatt_bausteine.dart';
import 'gym_editor_einstellblatt.dart';
import 'gym_editor_provider.dart';
import 'gym_editor_texte.dart';
import 'gym_training_editor_schluessel.dart';
import 'uebungsbilder_provider.dart';

export 'gym_editor_blatt_bausteine.dart';
export 'gym_editor_einstellblatt.dart';

// ─────────────────────────────────────────────────────────────────────────
// Auswahl
// ─────────────────────────────────────────────────────────────────────────

/// Ein Eintrag der **flachen** Auswahl-Liste (#551, Spec 9.4): Gruppenkopf,
/// Zeile, der Leer-Satz oder der Fuß. Flach, damit `SliverList.builder` je
/// Eintrag baut, wenn er ins Bild kommt — keine `Column` aus 581 Widgets.
sealed class _WahlEintrag {
  const _WahlEintrag();
}

class _WahlKopf extends _WahlEintrag {
  const _WahlKopf(this.muskel);

  final Muscle muskel;
}

class _WahlUebung extends _WahlEintrag {
  const _WahlUebung(this.uebung, {required this.erste, required this.letzte});

  final Exercise uebung;

  /// Erste bzw. letzte Zeile ihrer Gruppe: Die Kartenform liegt **je Zeile**
  /// (oben bzw. unten gerundet, dazwischen Trenner), weil eine lazy Liste
  /// kein Widget hat, das alle Kinder einer Gruppe kennt (Spec 9.4). Das
  /// Aussehen ist das der `InsetCard`.
  final bool erste;
  final bool letzte;
}

class _WahlLeer extends _WahlEintrag {
  const _WahlLeer();
}

class _WahlFussEintrag extends _WahlEintrag {
  const _WahlFussEintrag();
}

/// Die Auswahl: Suche und **Bibliothek**, gruppiert nach Muskel (Variante
/// `uebung-waehlen`, #551). **Antippen fügt die Übung am Ende ein und öffnet
/// sofort ihr Einstellblatt** (Spec 28 Nr. 1); die Auswahl bleibt darunter
/// stehen, samt Suchtext und Scrollposition. Eine Übung, die schon im
/// Training ist, steht abgeblendet da — bis „Entfernen" im Blatt sie
/// zurücknimmt.
///
/// **Suche zuerst** (Spec 9.5): Das Suchfeld steht außerhalb des
/// Scrollbereichs, bleibt beim Scrollen oben und ist beim Öffnen fokussiert
/// (`autofocus` — kein Fokus von Hand gesetzt oder genommen).
class GymEditorWahlBlatt extends ConsumerStatefulWidget {
  const GymEditorWahlBlatt({super.key, required this.quelle});

  final GymEditorQuelle quelle;

  @override
  ConsumerState<GymEditorWahlBlatt> createState() => _WahlZustand();
}

class _WahlZustand extends ConsumerState<GymEditorWahlBlatt> {
  /// Die flache Liste zur aktuellen Anfrage — **einmal je Anfrage** gebaut
  /// (`onChanged`), im State gehalten, nie in `build` gerechnet
  /// (Hausregel 2; Fehler `03`).
  late List<_WahlEintrag> _eintraege = _baue('');

  static List<_WahlEintrag> _baue(String anfrage) {
    final treffer = ExerciseLibrary.search(anfrage);
    final eintraege = <_WahlEintrag>[];
    Muscle? gruppe;
    for (var i = 0; i < treffer.length; i++) {
      final uebung = treffer[i];
      final muskel = ExerciseLibrary.mainMuscle(uebung);
      if (muskel != gruppe) {
        eintraege.add(_WahlKopf(muskel));
        gruppe = muskel;
      }
      final naechster = i + 1 < treffer.length
          ? ExerciseLibrary.mainMuscle(treffer[i + 1])
          : null;
      eintraege.add(
        _WahlUebung(
          uebung,
          erste: eintraege.last is _WahlKopf,
          letzte: naechster != muskel,
        ),
      );
    }
    if (eintraege.isEmpty) eintraege.add(const _WahlLeer());
    eintraege.add(const _WahlFussEintrag());
    return eintraege;
  }

  @override
  Widget build(BuildContext context) {
    final drin = ref.watch(
      gymEditorProvider(widget.quelle)
          .select((s) => {for (final e in s.uebungen) e.exerciseId}.join('|')),
    );
    final schonDrin = drin.isEmpty ? <String>{} : drin.split('|').toSet();
    // Die gemischte Lage an **einer** Stelle gehalten (Nachtrag 17 Nr. 1):
    // Haben alle Übungen ein Bild, steht nirgends ein Icon.
    final gemischt = ref.watch(uebungsbilderGemischtProvider);
    final bilder = ref.watch(uebungsbilderProvider);
    // Die Liste läuft **unter** der Tastatur durch (Spec 9.4,
    // flutter#179482): unten Padding statt eines verkürzten Rahmens.
    final tastatur = MediaQuery.viewInsetsOf(context).bottom;

    return GymEditorBlattRahmen(
      key: kGymEditorWahl,
      titel: gymEditorWahlTitel,
      lead: gymEditorWahlZurueck,
      leadSchluessel: kGymEditorWahlZurueck,
      trail: null,
      tastaturAbstand: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: CupertinoTextField(
              key: kGymEditorWahlSuche,
              placeholder: gymEditorWahlSuche,
              autofocus: true,
              onChanged: (v) => setState(() {
                _eintraege = _baue(v);
              }),
              clearButtonMode: OverlayVisibilityMode.editing,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            ),
          ),
          Expanded(
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + tastatur),
                  sliver: SliverList.builder(
                    itemCount: _eintraege.length,
                    itemBuilder: (context, i) => switch (_eintraege[i]) {
                      _WahlKopf(:final muskel) => _WahlGruppenKopf(muskel),
                      _WahlUebung(
                        :final uebung,
                        :final erste,
                        :final letzte,
                      ) =>
                        _WahlZeile(
                          uebung: uebung,
                          erste: erste,
                          letzte: letzte,
                          schonDrin: schonDrin.contains(uebung.id),
                          mitIcon: gemischt && bilder.fuer(uebung.id) != null,
                          // **Antippen fügt nichts hinzu** (Nachtrag 29
                          // Nr. 1): Es öffnet die Vorschau über der
                          // Auswahl — erst deren „Speichern" trägt ein.
                          onTap: () => unawaited(
                            zeigeGymEditorBlatt(
                              context,
                              GymEditorVorschauBlatt(
                                quelle: widget.quelle,
                                uebungId: uebung.id,
                              ),
                            ),
                          ),
                        ),
                      _WahlLeer() => const _WahlLeerSatz(),
                      _WahlFussEintrag() => const _WahlFuss(),
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WahlGruppenKopf extends StatelessWidget {
  const _WahlGruppenKopf(this.muskel);

  final Muscle muskel;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      key: kGymEditorWahlGruppe(muskel.code),
      padding: const EdgeInsets.only(top: 18, bottom: 7, left: 4),
      child: Text(
        muskel.german.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: muted,
        ),
      ),
    );
  }
}

/// Ohne Treffer: ein Satz in der Form der Liste (Spec 9.5).
class _WahlLeerSatz extends StatelessWidget {
  const _WahlLeerSatz();

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: InsetCard(
        child: Padding(
          key: kGymEditorWahlLeer,
          padding: const EdgeInsets.all(14),
          child: Text(gymEditorWahlLeer, style: TextStyle(fontSize: 15, color: muted)),
        ),
      ),
    );
  }
}

/// Der Fuß am **Ende der Liste** (Spec 9.1): die gezählte Zahl der
/// Bibliothek, kein „mit Bild" (Spec 10).
class _WahlFuss extends StatelessWidget {
  const _WahlFuss();

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    return Padding(
      key: kGymEditorWahlFuss,
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        gymEditorWahlFuss(ExerciseLibrary.length),
        style: TextStyle(
          fontSize: 12,
          height: 1.33,
          color: ink.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _WahlZeile extends StatelessWidget {
  const _WahlZeile({
    required this.uebung,
    required this.schonDrin,
    required this.erste,
    required this.letzte,
    required this.mitIcon,
    required this.onTap,
  });

  final Exercise uebung;
  final bool schonDrin;
  final bool erste;
  final bool letzte;
  final bool mitIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final dosis =
        '${uebung.sets} × ${uebung.repLow}–${uebung.repHigh}'
        '${uebung.isTimed ? ' s' : ''}';

    final zeile = GestureDetector(
      key: kGymEditorWahlUebung(uebung.id),
      behavior: HitTestBehavior.opaque,
      onTap: schonDrin ? null : onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // **Zeilenhöhe fest** (Plan 3.5): Der Name bekommt genau
                    // zwei Zeilen Platz (`FesteZeilen`), die Dosis eine —
                    // jede Zeile ist gleich hoch, mit und ohne Icon, mit
                    // kurzem und langem Namen. Nichts springt beim Scrollen.
                    FesteZeilen(
                      zeilen: 2,
                      stil: TextStyle(fontSize: 15, color: ink),
                      child: Text(
                        uebung.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, color: ink),
                      ),
                    ),
                    Text(
                      dosis,
                      maxLines: 1,
                      style: TextStyle(fontSize: 12, color: muted),
                    ),
                  ],
                ),
              ),
              if (schonDrin)
                Text(
                  gymEditorWahlSchonDrin,
                  key: kGymEditorWahlSchonDrin(uebung.id),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              // 24 pt reservierter Platz, auch ohne Icon: dieselbe Form mit
              // und ohne Bild (Spec 9.6). Das Icon ist nicht tippbar — die
              // Zeile bleibt die Tippfläche.
              SizedBox(
                width: 24,
                height: 24,
                child: mitIcon
                    ? Icon(
                        CupertinoIcons.play_circle,
                        key: kGymEditorWahlBild(uebung.id),
                        size: 20,
                        color: muted,
                        semanticLabel: gymEditorWahlMitBild,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );

    // Die Kartenform trägt die Zeile selbst (Spec 9.4): erste oben, letzte
    // unten gerundet, dazwischen Trenner — optisch dieselbe `InsetCard`.
    return ClipRRect(
      borderRadius: BorderRadius.vertical(
        top: erste ? const Radius.circular(kartenRadius) : Radius.zero,
        bottom: letzte ? const Radius.circular(kartenRadius) : Radius.zero,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(Palette.surface, context),
        ),
        child: Column(
          children: [
            if (!erste) const GymEditorBlattTrenner(),
            Opacity(opacity: schonDrin ? 0.45 : 1, child: zeile),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────
// Eigene Minuten
// ─────────────────────────────────────────────────────────────────────────

/// Das einfache Eingabeblatt für eigene Minuten (Spec 9.3, Vorschlag): ein
/// Zahlenfeld und „Schätzung benutzen".
class GymEditorDauerBlatt extends ConsumerStatefulWidget {
  const GymEditorDauerBlatt({super.key, required this.quelle});

  final GymEditorQuelle quelle;

  @override
  ConsumerState<GymEditorDauerBlatt> createState() => _DauerZustand();
}

class _DauerZustand extends ConsumerState<GymEditorDauerBlatt> {
  late final TextEditingController _feld = TextEditingController(
    text: () {
      final s = ref.read(gymEditorProvider(widget.quelle));
      final m = s.dauerEingetragen ?? s.schaetzung;
      return m == null ? '' : '$m';
    }(),
  );

  @override
  void dispose() {
    _feld.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.read(gymEditorProvider(widget.quelle).notifier);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);

    return GymEditorBlattRahmen(
      key: kGymEditorDauerBlatt,
      titel: gymEditorDauerBlattTitel,
      lead: gymEditorBlattZurueck,
      trail: gymEditorDauerBlattFertig,
      trailSchluessel: kGymEditorDauerFertig,
      hoehe: 0.5,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InsetCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 4,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: CupertinoTextField(
                        key: kGymEditorDauerFeld,
                        controller: _feld,
                        decoration: null,
                        autofocus: true,
                        keyboardType: TextInputType.number,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        style: const TextStyle(fontSize: 22),
                        onChanged: (text) {
                          final minuten = int.tryParse(text.trim());
                          if (minuten != null &&
                              minuten >= 1 &&
                              minuten <= WorkoutRules.maxMinutes) {
                            notifier.setzeDauer(minuten);
                          }
                        },
                      ),
                    ),
                    const Text(gymEditorDauerBlattFeld),
                  ],
                ),
              ),
            ),
            GymEditorBlattFuss(gymEditorDauerBlattFuss()),
            const SizedBox(height: 14),
            InsetCard(
              child: CupertinoButton(
                key: kGymEditorDauerSchaetzung,
                padding: const EdgeInsets.symmetric(vertical: 12),
                onPressed: () {
                  notifier.dauerZuruecksetzen();
                  Navigator.of(context).pop();
                },
                child: Text(
                  gymEditorDauerBlattSchaetzung,
                  style: TextStyle(fontSize: 15, color: river),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
