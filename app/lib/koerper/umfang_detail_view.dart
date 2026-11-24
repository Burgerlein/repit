// Der Verlauf **eines** Maßes (#479 unter #88) — der Schirm, den jede
// Maß-Zeile der Übersicht öffnet.
//
// API und Verhalten sind durch `app/test/shell/umfang_detail_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf) — diese Datei darf die
// Tests ausführen, aber nicht verändern (`CLAUDE.md`, „Wer Tests schreibt,
// schreibt nicht die Implementierung").
//
// Aufbau nach `docs/screens/screens/umfang-detail.js`; die Abschnitte
// stehen daneben in `umfang_detail_abschnitte.dart`, damit diese Datei
// klein bleibt (`CLAUDE.md`, „Views bleiben klein").
//
// **Dreizehn Diagramme auf der Übersicht wären vier Bildschirmlängen** —
// hier bekommt jedes Maß seinen Platz, und das Gegenstück der anderen Seite
// liegt als zweite, blasse Linie darin.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/umfaenge_repository.dart';
import '../design/glas_abstand.dart';
import '../design/hinweisfuss.dart';
import '../design/palette.dart';
import '../design/section_header.dart';
import '../shell/router.dart';
import '../shell/ziele.dart';
import 'umfaenge_notiz.dart';
import 'umfaenge_provider.dart';
import 'umfang_detail_abschnitte.dart';
import 'umfang_detail_provider.dart';

/// Öffnet den Verlauf von [mass] auf dem Stapel des **aktuell gewählten**
/// Tabs — die eine Stelle, die das weiß.
///
/// `AppTarget.aktuell`, nicht `.detail`: Gepusht wird in den Stapel des
/// Tabs, aus dem man kommt, sonst führte „zurück" in ein Menü, das der
/// Nutzer nie geöffnet hat (`CLAUDE.md`).
void oeffneUmfangDetail(AppRouter router, Umfang mass) =>
    router.open(AppTarget.aktuell((context) => UmfangDetailSeite(mass: mass)));

/// Der Rahmen: Gerüst und Navigationsleiste um [UmfangDetailView].
///
/// **Kein eigener `Navigator`:** Diese Ansicht wird auf den Stapel eines
/// Tabs geschoben, der Stapel gehört weiter `RootView`.
///
/// Die Leiste nennt das **Maß**, nicht „Verlauf": Den Schirm gibt es
/// fünfzehnmal, und fünfzehn gleich beschriftete Leisten sagen nicht, auf
/// welchem man steht — dieselbe Entscheidung wie bei `MessungDetailSeite`.
///
/// **Der Schlüssel trägt den stabilen Schlüssel des Maßes**, nicht einen
/// laufenden Index und nicht den deutschen Namen: Ein Schirm, der sein Maß
/// nicht kennt, ist der Schirm eines anderen Maßes.
class UmfangDetailSeite extends StatelessWidget {
  const UmfangDetailSeite({super.key, required this.mass});

  final Umfang mass;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      key: Key('umfang-detail-${mass.schluessel}'),
      backgroundColor: CupertinoDynamicColor.resolve(Palette.bg, context),
      navigationBar: CupertinoNavigationBar(
        middle: Text(mass.deutsch, overflow: TextOverflow.ellipsis),
      ),
      child: UmfangDetailView(mass: mass),
    );
  }
}

/// Der Schirm selbst — ohne Gerüst, ohne Leiste, ohne Navigator.
///
/// **Er besorgt seine Daten selbst** ([umfangsVerlaufProvider]): Jeder
/// Schirm ist aus jedem Tab erreichbar, niemand darf sich darauf verlassen,
/// dass eine Übersicht vorher geladen hat.
class UmfangDetailView extends ConsumerWidget {
  const UmfangDetailView({super.key, required this.mass});

  final Umfang mass;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final zustand = ref.watch(umfangsVerlaufProvider(mass));
    // **Zustand und Nutzlast getrennt.** Ein `is … ? … : null` ebnete beide
    // in einem Schritt ein: „lädt" und „nicht lesbar" sähen gleich aus, und
    // beide sähen aus wie „nie gemessen" — in dieser Scheibe war das schon
    // zweimal das Loch (#489).
    final lage = verlaufLageAus(zustand);
    final gelesen = verlaufWerte(zustand);

    return SingleChildScrollView(
      padding: GlasAbstand.of(context) + const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (lage == VerlaufLage.unlesbar)
            const UmfangsNotiz(
              key: Key('umfang-detail-unlesbar'),
              ton: UmfangsNotizTon.warnung,
              text:
                  'Die gespeicherten Messungen ließen sich nicht lesen. '
                  'Versuch es gleich noch einmal — eintragen kannst du '
                  'trotzdem.',
            ),
          UmfangDetailDiagramm(mass: mass, lage: lage, gelesen: gelesen),
          // Während gelesen wird, steht keiner der beiden Sätze da: Ob
          // dieses Maß je gemessen wurde, weiß die App dann nicht (`01`).
          if (gelesen != null && gelesen.istLeer)
            const UmfangsNotiz(
              key: Key('umfang-detail-leer'),
              ton: UmfangsNotizTon.neutral,
              text:
                  'Dieses Maß ist noch nie gemessen worden. Es steht im '
                  'Formular bereit.',
            ),
          if (gelesen != null && gelesen.istErsteMessung)
            const UmfangsNotiz(
              key: Key('umfang-detail-erste'),
              ton: UmfangsNotizTon.neutral,
              text:
                  'Ein Punkt ist noch kein Verlauf. Ab der zweiten Messung '
                  'steht hier ein Diagramm.',
            ),
          const SectionHeader('Veränderung'),
          UmfangDetailKennzahlen(mass: mass, lage: lage, gelesen: gelesen),
          UmfangDetailMessungen(
            mass: mass,
            lage: lage,
            gelesen: gelesen,
            // Löschen ist Ablage, keine Rechnung: Das Repository nimmt den
            // Messpunkt **dieses** Maßes (über alle Quellen), und
            // [umfaengeNeuGelesenIm] lässt Kurve, Veränderung und
            // Kennzahlen neu rechnen — gehalten im Provider, nicht je Bild
            // (Hausregel 2).
            //
            // **Der Behälter, nicht `ref`:** Wer löscht und sofort
            // zurückgeht, nimmt diesem Widget sein `ref` weg, bevor das
            // Löschen durch ist — die Invalidierung hängt deshalb am
            // Behälter, der weiterlebt, und die Übersicht darunter zeigt
            // den neuen Stand. Ein Fehler wandert nach oben: Die Liste
            // nimmt dann den Merker zurück und sagt es.
            aufLoeschen: (tag) async {
              final behaelter = ProviderScope.containerOf(
                context,
                listen: false,
              );
              await ref
                  .read(umfaengeRepositoryProvider)
                  .loescheMass(tag: tag, mass: mass);
              umfaengeNeuGelesenIm(behaelter);
            },
          ),
          // **Die Messanleitung dieses Maßes** — hier gehört sie hin und
          // nicht in einen Sammelabsatz, den man beim Messen nicht liest
          // (Spec, Detailschirm Punkt 5). Sie hängt am Maß, nicht an den
          // Daten, und steht deshalb in jeder Lage da.
          UmfangsNotiz(
            key: const Key('umfang-detail-messhinweis'),
            ton: UmfangsNotizTon.neutral,
            text: mass.messhinweis,
          ),
          const Hinweisfuss(umfangMassbandHinweis),
        ],
      ),
    );
  }
}
