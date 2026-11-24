// Der Editor eines Trainings (#534 unter #531, Task 3.6/3.7; Spec 9, 22 Nr. 3,
// 27) — Aufbau, Abschnitte und Beschriftungen nach `docs/screens/screens/
// gym-training-editor.js`, Varianten `neu`, `gefuellt` und `kopie` (die
// Blätter `uebung-einstellen` und `uebung-waehlen` stehen in
// `gym_editor_blaetter.dart`).
//
// API und Verhalten sind durch `app/test/gym/gym_editor_view_test.dart`
// verbindlich vorgegeben — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`).
//
// **Ein Schirm mit Blatt-Kopf**: Abbrechen links, Speichern rechts, der Titel
// in der Mitte — „Neues Training" (neu und Kopie), „Training bearbeiten". Er
// liegt auf dem Stapel des Tabs, aus dem man kommt ([oeffneGymEditor],
// `AppTarget.aktuell`). Der Entwurf zeichnet ihn als Blatt; hier ist es ein
// Schirm des Stapels, damit der Weg zurück ein Pop ist wie überall.
//
// **Von oben nach unten, jeder Abschnitt in jedem Zustand** (Spec 9.1):
// Kopie-Hinweis (nur bei Kopie), Stamm, Muskelfigur (Spec 28 Nr. 3, fester
// Rahmen), Übungen, „Übung hinzufügen",
// „Training löschen" (nur bei einem bestehenden), der Satz, was dem Speichern
// fehlt. Der Satz steht **an derselben Stelle in jedem Zustand** und ist leer,
// wenn nichts fehlt — die Karte springt nicht. **Solange gelesen wird, steht
// kein Grund da** (Fehler `01`).
//
// **Der Stand liegt im Notifier** ([gymEditorProvider]), nicht in diesem
// `State` (Fehler `32`); der `State` hält nur, was dem Auge gehört — welche
// Meldung steht.
//
// **Abbrechen ohne Änderung fragt nichts. Mit Änderung** fragt eine
// System-Rückfrage: „Als Entwurf behalten", „Verwerfen", „Weiter bearbeiten" —
// auch bei einem bestehenden Training (Spec 22 Nr. 3). Die Zurück-Geste und
// der Hardware-Zurück-Knopf gehen denselben Weg; beim Wechsel in den
// Hintergrund wird sofort gesichert.
//
// **Wohin nach dem Speichern** (Spec 9.6, 17 Nr. 13): neu und Kopie → die
// Übersicht, eine Änderung → das Detail. Kommt der Editor aus dem Detail
// ([GymTrainingEditorView.ausDetail]), schließt er bei Kopie und Löschen auch
// dieses.
import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/glas_abstand.dart';
import '../design/inset_card.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../shell/mess_abschnitte.dart' show Notizflaeche;
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'gym_editor_blaetter.dart';
import 'gym_editor_figur.dart';
import 'gym_editor_provider.dart';
import 'gym_editor_stamm.dart';
import 'gym_editor_texte.dart';
import 'gym_editor_uebung_zeile.dart';
import 'gym_training_editor_schluessel.dart';
import 'gym_trainings_provider.dart' show GymLoeschErgebnis;

/// Öffnet den Editor auf dem Stapel des **aktuell gewählten** Tabs.
///
/// [ausDetail]: Der Editor kommt aus dem Detail des Trainings („Bearbeiten"),
/// das unter ihm liegt.
void oeffneGymEditor(
  AppRouter router,
  GymEditorQuelle quelle, {
  bool ausDetail = false,
}) => router.open(
  AppTarget.aktuell(
    (_) => GymTrainingEditorView(quelle: quelle, ausDetail: ausDetail),
  ),
);

/// Was gerade gemeldet wird.
enum _Meldung { keine, gesperrt, fehler }

/// Die Antworten der Rückfrage beim Abbrechen.
enum _Antwort { behalten, verwerfen, weiter }

class GymTrainingEditorView extends ConsumerStatefulWidget {
  const GymTrainingEditorView({
    super.key,
    required this.quelle,
    this.ausDetail = false,
  });

  final GymEditorQuelle quelle;
  final bool ausDetail;

  @override
  ConsumerState<GymTrainingEditorView> createState() => _EditorZustand();
}

class _EditorZustand extends ConsumerState<GymTrainingEditorView>
    with WidgetsBindingObserver {
  _Meldung _meldung = _Meldung.keine;

  /// Eine Rückfrage oder ein Schreibvorgang läuft — keine zweite darüber.
  bool _beschaeftigt = false;

  GymEditorQuelle get _quelle => widget.quelle;
  GymEditorNotifier get _notifier =>
      ref.read(gymEditorProvider(_quelle).notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // „Beim Wechsel in den Hintergrund": Der Stand geht sofort in die
    // Ablage, nicht erst nach den 1,5 Sekunden.
    if (state != AppLifecycleState.resumed) {
      unawaited(_notifier.schreibeSofort());
    }
  }

  // --- Wege hinaus -----------------------------------------------------------

  /// Schließt den Editor — und, wo es dazugehört, das Detail darunter.
  void _schliesse({bool mitDetail = false}) {
    final navigator = Navigator.of(context);
    navigator.pop();
    if (mitDetail && widget.ausDetail) navigator.pop();
  }

  Future<void> _abbrechen() async {
    if (_beschaeftigt) return;
    _beschaeftigt = true;
    try {
      await _notifier.bereit;
      if (!mounted) return;
      final stand = ref.read(gymEditorProvider(_quelle));
      if (!stand.geaendert) {
        // Nichts geändert: kein Dialog, nichts neu angelegt. Was die
        // Selbstsicherung eben zurückgenommen hat, ist längst geschrieben.
        await _notifier.schreibeSofort();
        if (mounted) _schliesse();
        return;
      }
      final antwort = await showCupertinoDialog<_Antwort>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          key: kGymEditorAbbrechenFrage,
          title: const Text(gymEditorAbbrechenTitel),
          content: const Text(gymEditorAbbrechenText),
          actions: [
            CupertinoDialogAction(
              key: kGymEditorEntwurfBehalten,
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialog, _Antwort.behalten),
              child: const Text(gymEditorEntwurfBehalten),
            ),
            CupertinoDialogAction(
              key: kGymEditorVerwerfen,
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialog, _Antwort.verwerfen),
              child: const Text(gymEditorVerwerfen),
            ),
            CupertinoDialogAction(
              key: kGymEditorWeiter,
              onPressed: () => Navigator.pop(dialog, _Antwort.weiter),
              child: const Text(gymEditorWeiter),
            ),
          ],
        ),
      );
      if (!mounted) return;
      switch (antwort) {
        case _Antwort.behalten:
          await _notifier.behalteAlsEntwurf();
          // Eine Kopie hat ihren Entwurf als eigene Kachel in der Übersicht;
          // das Template, aus dem sie kam, hat damit nichts mehr zu zeigen.
          if (mounted) _schliesse(mitDetail: _quelle is GymEditorKopie);
        case _Antwort.verwerfen:
          await _notifier.verwirf();
          if (mounted) _schliesse();
        case _Antwort.weiter || null:
          break;
      }
    } finally {
      _beschaeftigt = false;
    }
  }

  Future<void> _speichere() async {
    if (_beschaeftigt) return;
    _beschaeftigt = true;
    try {
      final ergebnis = await _notifier.speichere();
      if (!mounted) return;
      switch (ergebnis) {
        case GymEditorErgebnis.gespeichert:
          // Neu und Kopie führen in die Übersicht, eine Änderung ins Detail.
          _schliesse(mitDetail: _quelle is GymEditorKopie);
        case GymEditorErgebnis.nichtSpeicherbar:
          break;
        case GymEditorErgebnis.gesperrt:
          setState(() => _meldung = _Meldung.gesperrt);
        case GymEditorErgebnis.fehlgeschlagen:
          setState(() => _meldung = _Meldung.fehler);
      }
    } finally {
      _beschaeftigt = false;
    }
  }

  Future<void> _loesche() async {
    if (_beschaeftigt) return;
    _beschaeftigt = true;
    try {
      final bestaetigt = await showCupertinoDialog<bool>(
        context: context,
        builder: (dialog) => CupertinoAlertDialog(
          key: kGymEditorLoeschenFrage,
          title: const Text(gymEditorLoeschenTitel),
          content: const Text(gymEditorLoeschenText),
          actions: [
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text(gymEditorAbbrechen),
            ),
            CupertinoDialogAction(
              key: kGymEditorLoeschenBestaetigen,
              isDestructiveAction: true,
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text(gymEditorLoeschenBestaetigen),
            ),
          ],
        ),
      );
      if (bestaetigt != true || !mounted) return;
      final ergebnis = await _notifier.loesche();
      if (!mounted) return;
      switch (ergebnis) {
        case GymLoeschErgebnis.geloescht:
          _schliesse(mitDetail: true);
        case GymLoeschErgebnis.laeuft:
          setState(() => _meldung = _Meldung.gesperrt);
        case GymLoeschErgebnis.fehlgeschlagen:
          setState(() => _meldung = _Meldung.fehler);
      }
    } finally {
      _beschaeftigt = false;
    }
  }

  // --- Aufbau ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final stand = ref.watch(gymEditorProvider(_quelle));
    final bg = CupertinoDynamicColor.resolve(Palette.bg, context);
    final ink = CupertinoDynamicColor.resolve(Palette.ink, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final padding = MediaQuery.paddingOf(context);
    final bearbeite = _quelle is GymEditorBearbeite;
    final grund = stand.laedt ? '' : gymEditorGrund(stand.probleme);
    final speicherbar = !stand.laedt && stand.probleme.isEmpty;

    return PopScope(
      // Zurück-Geste und Hardware-Zurück: Wer etwas geändert hat, wird
      // gefragt; sonst schließt der Editor ohne Rückfrage.
      canPop: !stand.geaendert,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_abbrechen());
      },
      child: CupertinoPageScaffold(
        key: kGymEditor,
        backgroundColor: bg,
        // Unter der Tastatur durchzeichnen statt abschneiden (flutter#179482).
        resizeToAvoidBottomInset: false,
        navigationBar: CupertinoNavigationBar(
          automaticallyImplyLeading: false,
          leading: CupertinoButton(
            key: kGymEditorAbbrechen,
            padding: EdgeInsets.zero,
            minimumSize: const Size(44, 44),
            onPressed: () => unawaited(_abbrechen()),
            child: Text(gymEditorAbbrechen, style: TextStyle(color: river)),
          ),
          middle: Text(
            bearbeite ? gymEditorTitelBearbeiten : gymEditorTitelNeu,
            style: TextStyle(fontWeight: FontWeight.w600, color: ink),
          ),
          trailing: Semantics(
            button: true,
            enabled: speicherbar,
            excludeSemantics: true,
            label: speicherbar
                ? gymEditorSpeichern
                : gymEditorSpeichernNichtMoeglich(grund),
            onTap: speicherbar ? () => unawaited(_speichere()) : null,
            child: Opacity(
              opacity: speicherbar ? 1 : 0.45,
              child: CupertinoButton(
                key: kGymEditorSpeichern,
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                onPressed: speicherbar ? () => unawaited(_speichere()) : null,
                child: Text(
                  gymEditorSpeichern,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              // `Builder`: `GlasAbstand.of` muss den `MediaQuery` **unterhalb**
              // des Gerüsts lesen — erst dort steht die Höhe der Leiste im
              // oberen Rand. Aus dem `context` von `build` käme nur die
              // Statusleiste, und die Überschrift läge unter der
              // Navigationsleiste (#546, #549).
              child: Builder(
                builder: (inner) => SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: GlasAbstand.of(inner).copyWith(
                    left: 14,
                    right: 14,
                    bottom:
                        24 +
                        padding.bottom +
                        MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: _inhalt(stand, grund, bearbeite),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inhalt(GymEditorStand stand, String grund, bool bearbeite) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    final river = CupertinoDynamicColor.resolve(Palette.river, context);
    final warn = CupertinoDynamicColor.resolve(Palette.warn, context);
    Widget fuss(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(6, 7, 6, 0),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, height: 1.33, color: muted),
      ),
    );

    final kopieVon = stand.kopieVon;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Nur beim Laden: das Zeichen, dass noch gelesen wird. Es trägt
        // keinen Text und keine Zahl.
        if (stand.laedt) const SizedBox.shrink(key: kGymEditorLaedt),
        if (kopieVon != null)
          Notizflaeche(
            key: kGymEditorKopieHinweis,
            text: gymEditorKopieHinweis(kopieVon),
            oben: 4,
          ),
        const SectionHeader(gymEditorStammKopf),
        GymEditorStamm(quelle: _quelle),
        fuss(gymEditorStammFuss),
        // Die Muskelfigur (Spec 28 Nr. 3): fester Rahmen, in jedem Zustand
        // dieselben Maße.
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: GymEditorFigur(quelle: _quelle),
        ),
        const SectionHeader(gymEditorUebungenKopf),
        _Uebungen(quelle: _quelle, stand: stand),
        const SizedBox(height: 14),
        InsetCard(
          child: _Aktionszeile(
            schluessel: kGymEditorHinzufuegen,
            text: gymEditorUebungHinzufuegen,
            farbe: river,
            onTap: stand.laedt
                ? null
                : () => zeigeGymEditorBlatt(
                    context,
                    GymEditorWahlBlatt(quelle: _quelle),
                  ),
          ),
        ),
        fuss(
          stand.uebungen.isEmpty
              ? gymEditorUebungenFussNeu
              : gymEditorUebungenFuss,
        ),
        if (bearbeite) ...[
          const SizedBox(height: 18),
          InsetCard(
            child: _Aktionszeile(
              schluessel: kGymEditorLoeschen,
              text: gymEditorLoeschen,
              farbe: warn,
              onTap: stand.laedt ? null : () => unawaited(_loesche()),
            ),
          ),
          fuss(gymEditorLoeschenFuss),
        ],
        const SizedBox(height: 16),
        // Der Satz, was dem Speichern fehlt: **in jedem Zustand an derselben
        // Stelle, in derselben Größe**, leer, wenn nichts fehlt (Spec 9.6).
        SizedBox(
          key: kGymEditorSpeichernGrund,
          height: 64,
          child: grund.isEmpty
              ? null
              : Notizflaeche(text: grund, oben: 0, zeilen: 3),
        ),
        if (_meldung == _Meldung.gesperrt)
          Notizflaeche(
            key: kGymEditorGesperrt,
            text: gymEditorGesperrt,
            ton: Palette.warn,
            oben: 0,
          ),
        if (_meldung == _Meldung.fehler)
          Notizflaeche(
            key: kGymEditorFehler,
            text: gymEditorFehler,
            ton: Palette.warn,
            oben: 0,
          ),
      ],
    );
  }
}

/// Eine Zeile „Übung hinzufügen" / „Training löschen": Text in einer Karte,
/// 48 pt hoch.
class _Aktionszeile extends StatelessWidget {
  const _Aktionszeile({
    required this.schluessel,
    required this.text,
    required this.farbe,
    required this.onTap,
  });

  final Key schluessel;
  final String text;
  final Color farbe;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap == null ? 0.45 : 1,
    child: CupertinoButton(
      key: schluessel,
      padding: const EdgeInsets.symmetric(horizontal: 13),
      minimumSize: const Size.fromHeight(48),
      alignment: Alignment.centerLeft,
      onPressed: onTap,
      child: Text(text, style: TextStyle(fontSize: 15, color: farbe)),
    ),
  );
}

/// Die Liste der Übungen — ziehbar am Griff. **`ReorderableList` aus
/// `widgets`**, nicht `ReorderableListView`: Die braucht Material-Lokalisierung,
/// die diese App nicht hat. Der Griff ist unser eigener (≡), nicht der
/// Standard.
class _Uebungen extends ConsumerWidget {
  const _Uebungen({required this.quelle, required this.stand});

  final GymEditorQuelle quelle;
  final GymEditorStand stand;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(gymEditorProvider(quelle).notifier);
    final line = CupertinoDynamicColor.resolve(Palette.line, context);
    final uebungen = stand.uebungen;
    final surface = CupertinoDynamicColor.resolve(Palette.surface, context);

    return InsetCard(
      child: ReorderableList(
        key: kGymEditorUebungen,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: uebungen.length,
        // Ohne Standard-Griff: Er sitzt links in der Zeile.
        proxyDecorator: (child, index, animation) =>
            ColoredBox(color: surface, child: child),
        // `onReorderItem` zählt den Zielindex bereits **nach** dem
        // Herausnehmen — wie `verschiebeUebung`.
        onReorderItem: notifier.verschiebeUebung,
        itemBuilder: (context, i) {
          final e = uebungen[i];
          // Die Trennlinie gehört zur Zeile, damit sie beim Ziehen mitwandert.
          return _MitLinie(
            key: ValueKey('editor-zeile-${e.exerciseId}'),
            linie: i > 0 ? line : null,
            child: GymEditorUebungZeile(
              uebung: e,
              index: i,
              von: uebungen.length,
              onTap: () => zeigeGymEditorBlatt(
                context,
                GymEditorEinstellBlatt(quelle: quelle, uebungId: e.exerciseId),
              ),
              onHoch: i > 0 ? () => notifier.verschiebeUebung(i, i - 1) : null,
              onRunter: i < uebungen.length - 1
                  ? () => notifier.verschiebeUebung(i, i + 1)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class _MitLinie extends StatelessWidget {
  const _MitLinie({super.key, required this.linie, required this.child});

  final Color? linie;
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      border: linie == null
          ? null
          : Border(top: BorderSide(color: linie!, width: 0.5)),
    ),
    child: child,
  );
}
