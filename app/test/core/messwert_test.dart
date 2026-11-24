import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:repit/core/async_bruecke.dart';
import 'package:repit/core/messwert.dart';

/// Tests für `Messwert<T>` (Spec 5.3/5.3a/5.3b) und `alsMesswert`
/// (`async_bruecke.dart`, Spec 5.3d/5.3e), das Dart-Gegenstück zur
/// Leerstand/Ladezustand-Unterscheidung, die in #55 („Das Schritte-Detail
/// hängt") als Fehler gemeldet ist:
/// `StepsView.swift:20` prüft nur `series.isEmpty` und zeigt dann einen
/// „keine Daten"-Grund an, obwohl `BodyStore.load()` noch läuft. Eine leere
/// Liste und „nichts da" sind in `[T]` schlicht nicht unterscheidbar.
///
/// `Messwert<T>` behebt das im Typ: `NochNie` hat gar keinen Wert, den man
/// befragen könnte, `Bekannt` trägt `laeuft` als Feld am Wert selbst (keine
/// zweite, davon unabhängige Flagge), und nur `LeerNachLauf`/`Fehlgeschlagen`
/// dürfen einen "keine Daten"-Grund zeigen.
///
/// `alsMesswert` ist laut Spec 5.4 **die einzige** Stelle, an der
/// `AsyncValue` in einen `Messwert` übergeht — deshalb werden unten nicht nur
/// die Konstruktoren geprüft, sondern vor allem diese Brücke.
///
/// **Signatur-Historie (zur Einordnung, warum die Tests aussehen, wie sie
/// aussehen — Details in den Fixberichten zu Task 5):**
///
/// - 5.3a: vierter Zustand `Fehlgeschlagen<T>` ergänzt (`AsyncValue` hat
///   einen Fehlerzweig, der erste Entwurf keinen).
/// - 5.3b: `stand` (Cache-Stand, nur in `Bekannt`) und `gelaufen`
///   (Zeitpunkt des Laufs, in `LeerNachLauf`/`Fehlgeschlagen`) sind zwei
///   Namen für zwei Bedeutungen, die vorher unter einem Namen liefen.
/// - 5.3d (aktuelle Form, Commit `da8c83c`): `AsyncValue<T?> v` und
///   `DateTime? stand` waren in der vorherigen Fassung **unabhängig**
///   nullbar, obwohl der Vertrag sie koppelt — die Signatur ließ Zustände
///   zu ("Stand da, Wert null" und umgekehrt), die es laut Vertrag nicht
///   geben darf. Jetzt kommt der Cache als **ein** Stück:
///   `({T wert, DateTime stand})? cache`. Zwei Entscheidungen darin, unten
///   gezielt getestet:
///   1. Ein frisch geholter Wert trägt `stand: jetzt`, nicht den
///      Cache-Stand — `stand ?? jetzt` war eine Krücke und entfällt.
///   2. Ein `null`-Wert in `v` gilt als leer, unabhängig von `istLeer`.
/// - 5.3e: Während eines Wiederholungslaufs ist ein `AsyncValue` zugleich
///   `isLoading` und `hasError`. `isLoading` gewinnt — ein laufender
///   Versuch ist noch kein Ergebnis.
/// - **#224 (Tim, 03.11.2026): Ein erfolgreicher, aber leerer Lauf lässt
///   einen vorhandenen Cache-Wert stehen** — `Bekannt(…, laeuft: false)`
///   mit dem Cache-Stand, genau wie ein gescheiterter Lauf. `LeerNachLauf`
///   gilt seither nur noch **ohne** Cache; der fertige Zweig ignoriert den
///   `cache` also nicht mehr, sondern verzweigt wie der Fehlerzweig an
///   ihm. Begründung: Apple verrät den Lesestatus nicht — entzieht iOS
///   oder Tim die Freigabe, kommen alle Reihen leer, aber erfolgreich
///   zurück, und davor waren damit sämtliche zwischengespeicherten Werte
///   auf einen Schlag weg. Der Preis ist benannt und angenommen: Ein
///   wirklich gelöschter Health-Eintrag bleibt stehen, bis ein Lauf etwas
///   anderes findet. Die Wirkung auf die Provider steht in
///   `test/health/leerer_lauf_behaelt_cache_test.dart`.
///
/// **Was absichtlich nicht getestet wird:** Dass `Bekannt` nie leere Daten
/// trägt, kann `alsMesswert` bei generischem `T` nicht selbst durchsetzen —
/// genau deshalb gibt es den Parameter `istLeer`. Die Brücke **verlässt
/// sich** auf dieses vom Aufrufer gelieferte Flag, sie **prüft** `T` nicht.
/// Ruft jemand mit `istLeer: false` auf, obwohl der Wert eine leere Liste
/// ist, entsteht `Bekannt([])` — das ist kein Fehler der Brücke, sondern
/// ein falscher Aufruf, den kein Test hier verhindern kann.
///
/// **`jetzt` wird überall von außen hereingereicht, nie aus
/// `DateTime.now()` geholt** — sonst wäre die Funktion nicht
/// deterministisch testbar, und an ihr hängt die ganze Zustandslogik.
///
/// **Zum Testaufbau:** Mit dem Cache als explizitem, von `v` unabhängigem
/// Parameter lassen sich fast alle Zeilen der Tabelle aus Spec 5.3d mit
/// einfachen `const AsyncValue.data(...)/.loading()/.error(...)`
/// konstruieren — kein `ProviderContainer` mehr nötig. Die einzige
/// Ausnahme ist Spec 5.3e: `isLoading == true && hasError == true`
/// gleichzeitig auf **einem** `AsyncValue` lässt sich über die öffentliche
/// API nicht direkt konstruieren (siehe eigene Gruppe unten) und braucht
/// einen echten, zweimal angestoßenen Refresh. Automatische Retries sind
/// dabei über `ProviderContainer(retry: (_, _) => null)` abgeschaltet
/// (Spec 5.3c) — nicht weil der Test einen Retry bräuchte (die Assertions
/// laufen, bevor ein Retry-Timer überhaupt feuern könnte), sondern damit
/// kein unabhängiger Hintergrundlauf den gelesenen Zustand zwischen zwei
/// `expect`s verändert.
void main() {
  final t0 = DateTime(2026, 10, 23, 14, 32);
  final t1 = DateTime(2026, 10, 23, 14, 33);
  final tAlt = DateTime(2026, 10, 23, 9);

  group('Die vier Zustände lassen sich wie in Spec 5.3/5.3a/5.3b vorgegeben '
      'bauen', () {
    test('NochNie ist ein Messwert ohne jeden Wert', () {
      const m = NochNie<int>();
      expect(m, isA<Messwert<int>>());
    });

    test('Bekannt traegt Wert, Stand und laeuft als ein Paket', () {
      final m = Bekannt<int>(7, stand: t0, laeuft: false);
      expect(m.wert, 7);
      expect(m.stand, t0);
      expect(m.laeuft, isFalse);
      expect(m, isA<Messwert<int>>());
    });

    test('LeerNachLauf traegt nur "gelaufen" (Zeitpunkt des Laufs), '
        'keinen Wert', () {
      final m = LeerNachLauf<int>(gelaufen: t0);
      expect(m.gelaufen, t0);
      expect(m, isA<Messwert<int>>());
    });

    test('Fehlgeschlagen traegt Fehler und "gelaufen", keinen Wert', () {
      final fehler = Exception('kaputt');
      final m = Fehlgeschlagen<int>(fehler: fehler, gelaufen: t0);
      expect(m.fehler, fehler);
      expect(m.gelaufen, t0);
      expect(m, isA<Messwert<int>>());
    });
  });

  group('Pflichtfälle aus task-5-brief.md', () {
    test('Nachladen faellt nie nach NochNie zurueck', () {
      Messwert<int> m = const NochNie<int>();
      m = Bekannt(42, stand: t0, laeuft: false);
      m = Bekannt(42, stand: t0, laeuft: true); // Aktualisierung laeuft
      expect(m, isA<Bekannt<int>>());
      expect((m as Bekannt<int>).wert, 42); // der alte Wert steht weiter da
    });

    test(
      'ein fertiger Lauf ohne Treffer wird LeerNachLauf, '
      'nicht Bekannt mit leerer Liste',
      () {
        final m = alsMesswert<List<int>>(
          const AsyncValue.data(<int>[]),
          cache: null,
          jetzt: t0,
          istLeer: true,
        );
        expect(m, isA<LeerNachLauf<List<int>>>());
        expect((m as LeerNachLauf<List<int>>).gelaufen, t0);
      },
    );

    test('ein laufender Lauf ohne Cache wird NochNie, nie LeerNachLauf', () {
      final m = alsMesswert<List<int>>(
        const AsyncValue.loading(),
        cache: null,
        jetzt: t0,
        istLeer: true,
      );
      expect(m, isA<NochNie<List<int>>>());
    });

    test(
      'ein laufender Lauf mit Cache behaelt den Wert und setzt laeuft '
      '(Cache jetzt als eigener Parameter, kein AsyncValue-Zustand nötig — '
      'Spec 5.3d)',
      () {
        final m = alsMesswert<int>(
          const AsyncValue.loading(),
          cache: (wert: 7, stand: t0),
          jetzt: t1,
          istLeer: false,
        );
        expect((m as Bekannt<int>).laeuft, isTrue);
        expect(m.wert, 7);
        expect(
          m.stand,
          t0,
          reason: 'Bekannt.stand ist der Cache-Stand, auch während eines '
              'Nachladens — "jetzt" fließt hier nirgends ein',
        );
      },
    );
  });

  group(
    'Tims Beschwerde in einem Satz: Nachladen springt nie über NochNie',
    () {
      test(
        'Bekannt(laeuft:false) → Bekannt(laeuft:true) → Bekannt(laeuft:false) '
        '— der Wert bleibt an jeder Stelle sichtbar, NochNie kommt nicht vor',
        () {
          // Drei unabhängige Aufrufe von alsMesswert, wie ein Provider sie
          // nacheinander produzieren würde: Schritt 2 übergibt als `cache`
          // genau das, was aus Schritt 1 fertig wurde — so, wie der
          // Aufrufer (ein Riverpod-Notifier in Task 13) seinen eigenen
          // Cache zwischen zwei Läufen weiterreicht.

          // Schritt 1: Erster, erfolgreicher Lauf. Noch kein Cache davor.
          final geladen = alsMesswert<int>(
            const AsyncValue.data(42),
            cache: null,
            jetzt: t0,
            istLeer: false,
          );
          expect(geladen, isNot(isA<NochNie<int>>()));
          expect(geladen, isA<Bekannt<int>>());
          expect((geladen as Bekannt<int>).laeuft, isFalse);
          expect(geladen.wert, 42);
          expect(geladen.stand, t0);

          // Schritt 2: Ein Nachladen beginnt. Was aus Schritt 1 fertig
          // wurde, ist jetzt der Cache.
          final aktualisiert = alsMesswert<int>(
            const AsyncValue.loading(),
            cache: (wert: geladen.wert, stand: geladen.stand),
            jetzt: t0,
            istLeer: false,
          );
          expect(
            aktualisiert,
            isNot(isA<NochNie<int>>()),
            reason: 'ein Nachladen mit Cache darf nie auf NochNie springen',
          );
          expect(aktualisiert, isA<Bekannt<int>>());
          expect((aktualisiert as Bekannt<int>).laeuft, isTrue);
          expect(
            aktualisiert.wert,
            42,
            reason: 'der alte Wert bleibt sichtbar, solange geladen wird',
          );
          expect(aktualisiert.stand, t0, reason: 'der Cache-Stand bleibt');

          // Schritt 3: Der Lauf ist fertig, ein neuer Wert liegt vor.
          final fertig = alsMesswert<int>(
            const AsyncValue.data(43),
            cache: (wert: aktualisiert.wert, stand: aktualisiert.stand),
            jetzt: t1,
            istLeer: false,
          );
          expect(fertig, isNot(isA<NochNie<int>>()));
          expect(fertig, isA<Bekannt<int>>());
          expect((fertig as Bekannt<int>).laeuft, isFalse);
          expect(fertig.wert, 43);
          expect(
            fertig.stand,
            t1,
            reason: 'ein frisch geholter Wert trägt "jetzt", nicht den '
                'alten Cache-Stand (Spec 5.3d, Entscheidung 1)',
          );
        },
      );
    },
  );

  group(
    'Der fertige Zweig: istLeer, ein null-Wert und "jetzt" — nie T selbst '
    '(Spec 5.3d, #224)',
    () {
      // `alsMesswert<T>` ist nicht auf Iterable o. Ä. eingeschränkt — die
      // Brücke kann "leer" bei einem generischen T gar nicht selbst
      // feststellen. "Bekannt trägt nie leere Daten" ist ein Vertrag des
      // Stores, auf den sich die Brücke über das Flag `istLeer` *verlässt*
      // — sie setzt ihn nicht durch (siehe Dateikopf). Diese Tests
      // konstruieren absichtlich Fälle, die in der echten App so nicht
      // vorkämen, um die Grenzen dieses Vertrags und die Entscheidungen
      // aus Spec 5.3d präzise zu belegen.
      test(
        'istLeer:true ohne cache ergibt LeerNachLauf mit "gelaufen" aus '
        'jetzt',
        () {
          final m = alsMesswert<List<int>>(
            const AsyncValue.data(<int>[1, 2, 3]), // nicht leer!
            cache: null, // kein Cache — die Bedingung für diesen Fall
            jetzt: t0,
            istLeer: true,
          );
          expect(m, isA<LeerNachLauf<List<int>>>());
          expect((m as LeerNachLauf<List<int>>).gelaufen, t0);
        },
      );

      test(
        'ein null-Wert gilt als leer, auch wenn istLeer:false übergeben '
        'wird (Spec 5.3d, Entscheidung 2)',
        () {
          final m = alsMesswert<int>(
            const AsyncValue<int?>.data(null),
            cache: null,
            jetzt: t0,
            istLeer: false,
          );
          expect(m, isA<LeerNachLauf<int>>());
          expect((m as LeerNachLauf<int>).gelaufen, t0);
        },
      );

      test(
        'istLeer:false mit vorhandenem Wert ergibt Bekannt mit stand: '
        'jetzt — ein mitgegebener cache wird ignoriert, auch sein Stand '
        '(Spec 5.3d, Entscheidung 1)',
        () {
          final m = alsMesswert<List<int>>(
            const AsyncValue.data(<int>[1, 2, 3]),
            cache: (wert: const [9, 9], stand: tAlt), // irrelevant hier
            jetzt: t0,
            istLeer: false,
          );
          expect(m, isA<Bekannt<List<int>>>());
          expect((m as Bekannt<List<int>>).wert, [1, 2, 3]);
          expect(m.laeuft, isFalse);
          expect(
            m.stand,
            t0,
            reason: 'ein frisch geholter Wert trägt "jetzt", nicht den '
                'Stand eines (hier ohnehin ignorierten) cache',
          );
        },
      );
    },
  );

  group(
    'Der vierte Zustand: Fehlgeschlagen (Spec 5.3a/5.3b/5.3d)',
    () {
      test(
        'ein gescheiterter Lauf ohne Cache wird Fehlgeschlagen, '
        '"gelaufen" kommt aus jetzt',
        () {
          final m = alsMesswert<int>(
            AsyncValue<int?>.error(
              Exception('HealthKit nicht erreichbar'),
              StackTrace.empty,
            ),
            cache: null, // kein Cache — das ist die Bedingung für diesen Fall
            jetzt: t0,
            istLeer: false,
          );
          expect(m, isA<Fehlgeschlagen<int>>());
          expect((m as Fehlgeschlagen<int>).gelaufen, t0);
        },
      );

      test(
        'ein gescheiterter Nachlauf MIT Cache bleibt Bekannt mit dem alten '
        'Wert und dem alten Stand, nicht Fehlgeschlagen',
        () {
          final m = alsMesswert<int>(
            AsyncValue<int?>.error(
              Exception('HealthKit nicht erreichbar'),
              StackTrace.empty,
            ),
            cache: (wert: 7, stand: t0),
            jetzt: t1, // Zeitpunkt des gescheiterten Nachlaufs
            istLeer: false,
          );
          expect(
            m,
            isNot(isA<Fehlgeschlagen<int>>()),
            reason:
                'Tims Beschwerde: ein gescheiterter Nachlauf darf einen '
                'sichtbaren Wert nicht wegnehmen',
          );
          expect(m, isA<Bekannt<int>>());
          expect((m as Bekannt<int>).wert, 7);
          expect(m.laeuft, isFalse);
          expect(
            m.stand,
            t0,
            reason: 'der alte Cache-Stand bleibt, kein neuer ohne Erfolg — '
                'und insbesondere nicht "jetzt" (t1)',
          );
        },
      );
    },
  );

  group(
    '#224: Ein erfolgreicher, aber leerer Lauf nimmt keinen sichtbaren '
    'Wert weg — der Zwilling zum Fehlerzweig',
    () {
      test(
        'istLeer:true MIT Cache bleibt Bekannt mit dem alten Wert und dem '
        'alten Stand, nicht LeerNachLauf',
        () {
          final m = alsMesswert<List<int>>(
            const AsyncValue.data(<int>[]),
            cache: (wert: const [9, 9], stand: tAlt),
            jetzt: t0, // Zeitpunkt des leeren Laufs
            istLeer: true,
          );
          expect(
            m,
            isNot(isA<LeerNachLauf<List<int>>>()),
            reason:
                'Apple verrät den Lesestatus nicht: eine entzogene '
                'Freigabe liefert alle Reihen leer, aber erfolgreich — '
                'und nähme so auf einen Schlag jeden gespeicherten Wert '
                'mit (Tim, 03.11.2026)',
          );
          expect(m, isA<Bekannt<List<int>>>());
          expect((m as Bekannt<List<int>>).wert, [9, 9]);
          expect(
            m.laeuft,
            isFalse,
            reason: 'der Lauf ist fertig — er hat nur nichts gefunden',
          );
          expect(
            m.stand,
            tAlt,
            reason: 'der alte Cache-Stand bleibt, kein neuer ohne Fund — '
                'und insbesondere nicht "jetzt" (t0). Sonst behauptete die '
                'Stand-Zeile einen Lauf, der diesen Wert nie gesehen hat',
          );
          expect(m.stand, isNot(t0));
        },
      );

      test(
        'ein null-Wert MIT Cache ebenso — derselbe Zweig, dieselbe Regel',
        () {
          final m = alsMesswert<int>(
            const AsyncValue<int?>.data(null),
            cache: (wert: 7, stand: tAlt),
            jetzt: t0,
            istLeer: false,
          );
          expect(m, isNot(isA<LeerNachLauf<int>>()));
          expect(m, isA<Bekannt<int>>());
          expect((m as Bekannt<int>).wert, 7);
          expect(m.laeuft, isFalse);
          expect(m.stand, tAlt);
        },
      );

      test(
        'LeerNachLauf verschwindet dabei nicht: ohne Cache ist "Lauf '
        'fertig, nichts gefunden" weiterhin genau das',
        () {
          final ohneCache = alsMesswert<List<int>>(
            const AsyncValue.data(<int>[]),
            cache: null,
            jetzt: t0,
            istLeer: true,
          );
          expect(ohneCache, isA<LeerNachLauf<List<int>>>());
          expect((ohneCache as LeerNachLauf<List<int>>).gelaufen, t0);

          // Derselbe Aufruf, nur mit Cache — der eine Unterschied, an dem
          // die Regel hängt.
          final mitCache = alsMesswert<List<int>>(
            const AsyncValue.data(<int>[]),
            cache: (wert: const [9, 9], stand: tAlt),
            jetzt: t0,
            istLeer: true,
          );
          expect(mitCache, isA<Bekannt<List<int>>>());
        },
      );

      test(
        'die Folge, wie ein Provider sie produziert: Bekannt(laeuft:false) '
        '→ Bekannt(laeuft:true) → leerer Lauf — Wert und Stand stehen am '
        'Ende unverändert da',
        () {
          // Schritt 1: ein erfolgreicher Lauf.
          final geladen =
              alsMesswert<int>(
                    const AsyncValue.data(42),
                    cache: null,
                    jetzt: tAlt,
                    istLeer: false,
                  )
                  as Bekannt<int>;
          expect(geladen.stand, tAlt);

          // Schritt 2: ein Nachladen beginnt.
          final aktualisiert =
              alsMesswert<int>(
                    const AsyncValue.loading(),
                    cache: (wert: geladen.wert, stand: geladen.stand),
                    jetzt: t0,
                    istLeer: false,
                  )
                  as Bekannt<int>;
          expect(aktualisiert.laeuft, isTrue);

          // Schritt 3: der Lauf ist fertig — und leer.
          final fertig = alsMesswert<int>(
            const AsyncValue<int?>.data(null),
            cache: (wert: aktualisiert.wert, stand: aktualisiert.stand),
            jetzt: t1,
            istLeer: true,
          );
          expect(
            fertig,
            isA<Bekannt<int>>(),
            reason: 'genau hier stand vorher LeerNachLauf, und der Wert war '
                'weg — der beobachtete Lauf aus #224',
          );
          expect((fertig as Bekannt<int>).wert, 42);
          expect(fertig.laeuft, isFalse);
          expect(
            fertig.stand,
            tAlt,
            reason: 'der Stand gehört zu dem Lauf, der die 42 gesehen hat '
                '— nicht zu dem leeren von t1',
          );
        },
      );
    },
  );

  group(
    'Spec 5.3e: isLoading und hasError zugleich — isLoading gewinnt',
    () {
      test(
        'ein Wiederholungslauf (isLoading und hasError auf demselben '
        'AsyncValue) wird ohne Cache NochNie und mit Cache Bekannt mit '
        'laeuft:true — nie Fehlgeschlagen, nie Bekannt mit laeuft:false',
        () async {
          // isLoading==true && hasError==true gleichzeitig lässt sich über
          // die öffentliche AsyncValue-API nicht direkt konstruieren
          // (`AsyncValue.loading()` hat `hasError:false`, `AsyncValue.
          // error(...)` hat `isLoading:false`). Riverpod merged beide
          // Flags aber selbst, wenn ein bereits gescheiterter Provider
          // erneut angestoßen wird, bevor der neue Versuch fertig ist —
          // genau das bildet dieser Ablauf nach: ein echter
          // ProviderContainer, ein gescheiterter erster Versuch, ein
          // zweiter Versuch, der absichtlich nicht abgeschlossen wird.
          //
          // Automatische Retries sind abgeschaltet (Spec 5.3c); sie werden
          // hier nicht gebraucht, weil beide `refresh`-Aufrufe von Hand
          // erfolgen und die Assertions laufen, bevor ein Retry-Timer
          // überhaupt feuern könnte.
          Completer<int?>? aktuell;
          final provider = FutureProvider<int?>((ref) {
            final completer = Completer<int?>();
            aktuell = completer;
            return completer.future;
          });
          final container = ProviderContainer(retry: (_, _) => null);
          addTearDown(container.dispose);
          container.listen(provider, (prev, next) {});

          aktuell!.completeError(Exception('erster Versuch scheitert'));
          await pumpEventQueue();
          container.refresh(provider);

          final v = container.read(provider);
          expect(v.isLoading, isTrue, reason: 'Testvoraussetzung');
          expect(v.hasError, isTrue, reason: 'Testvoraussetzung');

          // Ohne Cache: isLoading gewinnt -> NochNie, nicht Fehlgeschlagen.
          final ohneCache = alsMesswert<int>(
            v,
            cache: null,
            jetzt: t0,
            istLeer: false,
          );
          expect(ohneCache, isA<NochNie<int>>());

          // Mit Cache: isLoading gewinnt -> Bekannt(laeuft:true), nicht
          // Bekannt(laeuft:false) — Letzteres wäre das Ergebnis, wenn
          // hasError fälschlich zuerst geprüft würde.
          final mitCache = alsMesswert<int>(
            v,
            cache: (wert: 7, stand: t0),
            jetzt: t1,
            istLeer: false,
          );
          expect(mitCache, isA<Bekannt<int>>());
          expect((mitCache as Bekannt<int>).laeuft, isTrue);
          expect(mitCache.wert, 7);
          expect(mitCache.stand, t0);
        },
      );
    },
  );

  group(
    'Vollständigkeit: ein switch über Messwert<T> deckt alle vier Zweige ab',
    () {
      // Dart erzwingt die Vollständigkeit eines `switch` über einen
      // `sealed`-Typ zur Übersetzungszeit (Analyzer-Fehler bei fehlendem
      // Zweig), nicht zur Laufzeit. Ein Laufzeittest kann ein Weglassen eines
      // Zweigs deshalb nicht selbst provozieren — dafür bräuchte es eine
      // zweite, absichtlich unvollständige Funktion, die dann gar nicht
      // erst kompilierte, und ein Test, der nicht kompiliert, beweist
      // nichts. Was hier geprüft wird: Eine tatsächlich vollständige
      // Funktion ordnet jedem der vier Zustände korrekt seinen eigenen
      // Zweig zu — inklusive der Unterscheidung innerhalb von `Bekannt`
      // nach `laeuft`.
      String beschreibung(Messwert<int> m) => switch (m) {
        NochNie<int>() => 'laedt',
        Bekannt<int>(laeuft: true) => 'aktualisiert',
        Bekannt<int>() => 'bekannt',
        LeerNachLauf<int>() => 'leer',
        Fehlgeschlagen<int>() => 'fehlgeschlagen',
      };

      test('NochNie -> laedt', () {
        expect(beschreibung(const NochNie<int>()), 'laedt');
      });

      test('Bekannt mit laeuft:true -> aktualisiert', () {
        expect(
          beschreibung(Bekannt<int>(7, stand: t0, laeuft: true)),
          'aktualisiert',
        );
      });

      test('Bekannt mit laeuft:false -> bekannt', () {
        expect(
          beschreibung(Bekannt<int>(7, stand: t0, laeuft: false)),
          'bekannt',
        );
      });

      test('LeerNachLauf -> leer', () {
        expect(beschreibung(LeerNachLauf<int>(gelaufen: t0)), 'leer');
      });

      test('Fehlgeschlagen -> fehlgeschlagen', () {
        expect(
          beschreibung(
            Fehlgeschlagen<int>(fehler: Exception(), gelaufen: t0),
          ),
          'fehlgeschlagen',
        );
      });
    },
  );
}
