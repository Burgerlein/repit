import 'package:test/test.dart';
import 'package:trainings_core/trainings_core.dart';

/// Tests für die **Modellliste des KI-Zugangs** (#334) — welche Modelle aus
/// `models.list` für die Foto-Schätzung angeboten werden, in welcher
/// Reihenfolge, und welches gilt, wenn das gemerkte weggefallen ist.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Diese Datei darf **ausgeführt, nie verändert** werden.
///
/// ## Woher die Regeln kommen
///
/// Spec `docs/superpowers/specs/2026-11-04-ki-zugang-design.md`, Abschnitt
/// „Modellwahl", und Plan `docs/superpowers/plans/2026-11-04-ki-zugang.md`,
/// Task 3.
///
/// - **Filter:** `name` beginnt mit `models/gemini-`;
///   `supportedGenerationMethods` enthält `generateContent`; der Name
///   enthält keinen der Bausteine `image`, `tts`, `audio`, `live`,
///   `embedding`, `veo`, `imagen`, `aqa`, `computer-use`.
/// - **Sortierung:** stabil vor Vorschau (`-preview`, `-exp` im Namen),
///   innerhalb dessen nach `name` absteigend.
/// - **Auflösen:** Steht das gemerkte Modell in der Liste, gilt es; sonst
///   die Voreinstellung, falls in der Liste; sonst das erste. Ist das
///   gemerkte weggefallen, sagt der Schirm es (`gemerktFehlt`).
///
/// Die Rohliste ist, was der Client aus der JSON-Antwort dekodiert — der
/// Kern nimmt Maps, nie JSON-Text. Die Felder entsprechen der Doku von
/// `models.list`; Modellnamen außer der Voreinstellung aus dem Plan sind
/// **erfunden** und behaupten nicht, dass es ein solches Modell gibt.
///
/// ## API, die diese Tests verbindlich vorgeben
///
/// Neu in `Packages/trainings_core/lib/src/ki_modelle.dart`, exportiert über
/// `lib/trainings_core.dart`:
///
/// ```dart
/// class KiModell {
///   const KiModell({
///     required this.id,           // ohne `models/`
///     required this.anzeigeName,
///     required this.vorschau,
///   });
///   final String id;
///   final String anzeigeName;
///   final bool vorschau;
///   // == und hashCode über alle drei Felder
/// }
///
/// List<KiModell> fotoModelle(List<Map<String, Object?>> rohListe);
///
/// ({KiModell? modell, bool gemerktFehlt}) loeseModell({
///   required List<KiModell> liste,
///   String? gemerkt,              // eine id, ohne `models/`
///   required String voreinstellung,
/// });
/// ```
///
/// ## Entscheidungen des Test-Agenten, wo der Auftrag offen ist
///
/// **Nicht von Tim freigegeben** — jede mit Begründung.
///
/// - **Der Konstruktor von [KiModell] ist benannt und `required`.**
/// - **`anzeigeName` ist `displayName`; fehlt der, ist es die `id`.** Ein
///   Modell ohne Anzeigenamen ist trotzdem wählbar — eine leere Zeile im
///   Blatt wäre es nicht.
/// - **Ein Eintrag mit `name: null` gilt wie einer ohne `name`** und wird
///   übersprungen.
/// - **Fehlt `supportedGenerationMethods`, ist das Modell draußen.** Ohne
///   die Angabe steht nicht fest, dass es `generateContent` kann.
/// - **Ein gemerktes Vorschau-Modell gilt, solange es angeboten wird.**
///   „Ein Vorschau-Modell ist nie Voreinstellung" betrifft die
///   Voreinstellung, nicht Tims eigene Wahl.
/// - **Leere Liste und ein gemerktes Modell → `gemerktFehlt: true`.** Das
///   gemerkte wird nicht angeboten; ob die Liste deshalb leer ist, weil
///   Google nichts mehr anbietet, weiß der Kern nicht und behauptet es
///   nicht weg.
/// - **„Das erste" heißt das erste der übergebenen Liste.** [loeseModell]
///   sortiert nicht selbst; die Reihenfolge kommt aus [fotoModelle].
void main() {
  Map<String, Object?> roh(
    String id, {
    String? anzeige,
    List<String> methoden = const ['generateContent', 'countTokens'],
  }) => {
    'name': 'models/$id',
    'baseModelId': id,
    'version': '001',
    'displayName': anzeige ?? 'Anzeige $id',
    'description': 'erfundene Beschreibung',
    'inputTokenLimit': 1048576,
    'outputTokenLimit': 65536,
    'supportedGenerationMethods': methoden,
    'temperature': 1.0,
    'maxTemperature': 2.0,
    'topP': 0.95,
    'topK': 64,
    'thinking': true,
  };

  List<String> ids(List<KiModell> liste) => [for (final m in liste) m.id];

  KiModell modell(String id, {bool vorschau = false}) =>
      KiModell(id: id, anzeigeName: 'Anzeige $id', vorschau: vorschau);

  // ═════════════════════════════════════════════════════════════════════
  group('KiModell', () {
    test('Wertgleichheit über alle Felder', () {
      expect(modell('gemini-3.6-flash'), equals(modell('gemini-3.6-flash')));
      expect(
        modell('gemini-3.6-flash').hashCode,
        modell('gemini-3.6-flash').hashCode,
      );
      expect(modell('gemini-3.6-flash'), isNot(modell('gemini-3.6-pro')));
      expect(
        modell('gemini-3.6-flash'),
        isNot(
          const KiModell(
            id: 'gemini-3.6-flash',
            anzeigeName: 'anders',
            vorschau: false,
          ),
        ),
      );
      expect(
        modell('gemini-3.6-flash'),
        isNot(modell('gemini-3.6-flash', vorschau: true)),
      );
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('fotoModelle — Felder', () {
    test('id ohne `models/`, Anzeigename aus displayName', () {
      final liste = fotoModelle([
        roh('gemini-3.6-flash', anzeige: 'Gemini 3.6 Flash'),
      ]);
      expect(liste, hasLength(1));
      expect(liste.single.id, 'gemini-3.6-flash');
      expect(liste.single.anzeigeName, 'Gemini 3.6 Flash');
      expect(liste.single.vorschau, isFalse);
    });

    test('`-preview` im Namen ist Vorschau', () {
      final liste = fotoModelle([roh('gemini-3.7-pro-preview')]);
      expect(liste.single.vorschau, isTrue);
    });

    test('`-exp` im Namen ist Vorschau', () {
      final liste = fotoModelle([roh('gemini-3.7-flash-exp')]);
      expect(liste.single.vorschau, isTrue);
    });

    test('ohne displayName ist der Anzeigename die id', () {
      final eintrag = roh('gemini-3.6-flash')..remove('displayName');
      final liste = fotoModelle([eintrag]);
      expect(liste.single.anzeigeName, 'gemini-3.6-flash');
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('fotoModelle — Filter', () {
    test('ein Gemini-Modell mit generateContent ist drin', () {
      expect(ids(fotoModelle([roh('gemini-3.6-flash')])), ['gemini-3.6-flash']);
    });

    test('ohne generateContent ist es draußen', () {
      expect(
        fotoModelle([
          roh(
            'gemini-3.6-flash',
            methoden: ['countTokens', 'createCachedContent'],
          ),
        ]),
        isEmpty,
      );
    });

    test('ohne supportedGenerationMethods ist es draußen', () {
      final eintrag = roh('gemini-3.6-flash')
        ..remove('supportedGenerationMethods');
      expect(fotoModelle([eintrag]), isEmpty);
    });

    test('was nicht mit `models/gemini-` beginnt, ist draußen', () {
      expect(
        fotoModelle([
          roh('gemma-4-27b-it'),
          roh('text-embedding-005'),
          roh('veo-4.0-generate'),
          roh('imagen-5.0-generate'),
          roh('aqa'),
          // Ohne das Präfix `models/` trifft die Regel auch nicht.
          {
            'name': 'gemini-3.6-flash',
            'displayName': 'ohne Präfix',
            'supportedGenerationMethods': ['generateContent'],
          },
        ]),
        isEmpty,
      );
    });

    for (final id in [
      'gemini-3.1-flash-image',
      'gemini-3.1-pro-image-preview',
      'gemini-3.1-flash-preview-tts',
      'gemini-3.1-flash-native-audio',
      'gemini-3.1-flash-live',
      'gemini-live-3.1-flash',
      'gemini-embedding-002',
      'gemini-veo-test',
      'gemini-imagen-test',
      'gemini-aqa-test',
      'gemini-3.1-computer-use-preview',
    ]) {
      test('Baustein im Namen: $id ist draußen', () {
        expect(fotoModelle([roh(id)]), isEmpty);
      });
    }

    test('ein Eintrag ohne `name` wird übersprungen und wirft nicht', () {
      final ohneName = roh('gemini-3.6-pro')..remove('name');
      expect(ids(fotoModelle([ohneName, roh('gemini-3.6-flash')])), [
        'gemini-3.6-flash',
      ]);
    });

    test('ein Eintrag mit `name: null` wird übersprungen und wirft nicht', () {
      final nullName = roh('gemini-3.6-pro')..['name'] = null;
      expect(ids(fotoModelle([nullName, roh('gemini-3.6-flash')])), [
        'gemini-3.6-flash',
      ]);
    });

    test('leere Rohliste → leere Liste', () {
      expect(fotoModelle(const []), isEmpty);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('fotoModelle — Reihenfolge', () {
    test('stabil vor Vorschau, je Gruppe nach Name absteigend', () {
      final liste = fotoModelle([
        roh('gemini-2.5-flash'),
        roh('gemini-3.7-pro-preview'),
        roh('gemini-3.6-flash'),
        roh('gemini-3.1-flash-exp'),
        roh('gemini-3.6-pro'),
        roh('gemini-3.5-flash-preview'),
      ]);
      expect(ids(liste), [
        'gemini-3.6-pro',
        'gemini-3.6-flash',
        'gemini-2.5-flash',
        'gemini-3.7-pro-preview',
        'gemini-3.5-flash-preview',
        'gemini-3.1-flash-exp',
      ]);
    });

    test(
      'ein neueres Vorschau-Modell steht nicht vor einem älteren stabilen',
      () {
        final liste = fotoModelle([
          roh('gemini-9.0-pro-preview'),
          roh('gemini-1.0-flash'),
        ]);
        expect(ids(liste), ['gemini-1.0-flash', 'gemini-9.0-pro-preview']);
      },
    );

    test('absteigend heißt: Zeichenfolge, nicht Eingangsreihenfolge', () {
      final liste = fotoModelle([
        roh('gemini-3.6-flash'),
        roh('gemini-3.6-flash-lite'),
      ]);
      // `gemini-3.6-flash-lite` > `gemini-3.6-flash` als Zeichenfolge.
      expect(ids(liste), ['gemini-3.6-flash-lite', 'gemini-3.6-flash']);
    });
  });

  // ═════════════════════════════════════════════════════════════════════
  group('loeseModell', () {
    final liste = [
      modell('gemini-3.6-pro'),
      modell('gemini-3.6-flash'),
      modell('gemini-3.7-pro-preview', vorschau: true),
    ];

    test('gemerkt und angeboten → gemerkt', () {
      final r = loeseModell(
        liste: liste,
        gemerkt: 'gemini-3.6-pro',
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, modell('gemini-3.6-pro'));
      expect(r.gemerktFehlt, isFalse);
    });

    test('gemerkt fehlt, Voreinstellung angeboten → Voreinstellung', () {
      final r = loeseModell(
        liste: liste,
        gemerkt: 'gemini-2.0-flash',
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, modell('gemini-3.6-flash'));
      expect(r.gemerktFehlt, isTrue);
    });

    test('gemerkt und Voreinstellung fehlen → das erste', () {
      final r = loeseModell(
        liste: liste,
        gemerkt: 'gemini-2.0-flash',
        voreinstellung: 'gemini-1.5-flash',
      );
      expect(r.modell, modell('gemini-3.6-pro'));
      expect(r.gemerktFehlt, isTrue);
    });

    test('nichts gemerkt → Voreinstellung, und es fehlt nichts', () {
      final r = loeseModell(
        liste: liste,
        gemerkt: null,
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, modell('gemini-3.6-flash'));
      expect(r.gemerktFehlt, isFalse);
    });

    test('ohne gemerkt-Argument wie null', () {
      final r = loeseModell(liste: liste, voreinstellung: 'gemini-3.6-flash');
      expect(r.modell, modell('gemini-3.6-flash'));
      expect(r.gemerktFehlt, isFalse);
    });

    test(
      'nichts gemerkt, Voreinstellung fehlt → das erste, es fehlt nichts',
      () {
        final r = loeseModell(
          liste: liste,
          gemerkt: null,
          voreinstellung: 'gemini-1.5-flash',
        );
        expect(r.modell, modell('gemini-3.6-pro'));
        expect(r.gemerktFehlt, isFalse);
      },
    );

    test('ein gemerktes Vorschau-Modell gilt, solange es angeboten wird', () {
      final r = loeseModell(
        liste: liste,
        gemerkt: 'gemini-3.7-pro-preview',
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, modell('gemini-3.7-pro-preview', vorschau: true));
      expect(r.gemerktFehlt, isFalse);
    });

    test('das erste ist das erste der übergebenen Liste', () {
      final r = loeseModell(
        liste: [modell('gemini-1.0-flash'), modell('gemini-9.0-pro')],
        gemerkt: null,
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, modell('gemini-1.0-flash'));
    });

    test('leere Liste, nichts gemerkt → kein Modell, es fehlt nichts', () {
      final r = loeseModell(
        liste: const [],
        gemerkt: null,
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, isNull);
      expect(r.gemerktFehlt, isFalse);
    });

    test('leere Liste, gemerkt → kein Modell, das gemerkte fehlt', () {
      final r = loeseModell(
        liste: const [],
        gemerkt: 'gemini-3.6-pro',
        voreinstellung: 'gemini-3.6-flash',
      );
      expect(r.modell, isNull);
      expect(r.gemerktFehlt, isTrue);
    });
  });
}
