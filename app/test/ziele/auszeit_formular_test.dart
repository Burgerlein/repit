import 'package:flutter_test/flutter_test.dart';
import 'package:trainings_core/trainings_core.dart';

import 'package:repit/data/ereignisse.dart';
import 'package:repit/ziele/auszeit_formular.dart';

/// Tests für die **Formularlogik der Auszeit** (#448 unter #404) — der
/// Werttyp `AuszeitFormular` in `lib/ziele/auszeit_formular.dart`:
/// Vorbelegung, Nachziehen des Endes, Notiz und der Weg zum `Ereignis`.
///
/// **Wer Tests schreibt, schreibt nicht die Implementierung** (`CLAUDE.md`).
/// Die Formularlogik ist laut Plan ein Fall für **zwei Agenten**. Diese
/// Datei darf ausgeführt, aber nicht verändert werden — keine Zeile, kein
/// Erwartungswert, kein Testname. Hält der Implementierende einen Fall für
/// falsch, meldet er ihn.
///
/// ## Woher die Anforderung kommt
///
/// Spec `docs/superpowers/specs/2026-11-10-auszeit-design.md`, Abschnitt
/// „Formular ‚Auszeit eintragen‘“, dazu die Vorgaben V4 (Vorbelegung und
/// Nachziehen), V5 (das Ende liegt nie vor dem Beginn) und V6 (Notiz).
/// Entscheidung 4 (Tim, 10.11.2026): Das Ende einer OP ist mit OP-Tag + 14
/// vorbelegt, als Regel, kein Datum. Die Vorgaben V1–V20 hat der Planende
/// formuliert; Tim hat sie am 10.11.2026 übernommen („Ja, so bauen“). Die
/// Schnittstelle steht im Plan `docs/superpowers/plans/2026-11-10-auszeit.md`,
/// Task 5:
///
/// ```dart
/// factory AuszeitFormular.neu({required String heute});
/// factory AuszeitFormular.fuer(Ereignis e);
/// AuszeitFormular mitArt(EreignisArt art);
/// AuszeitFormular mitVon(String von);
/// AuszeitFormular mitBis(String bis);
/// AuszeitFormular mitNotiz(String notiz);
/// EreignisArt get art; String get von; String get bis; String? get notiz;
/// bool get bisVonHand;
/// Ereignis alsEreignis({int? id, DateTime? angelegt});
/// ```
///
/// Das OP-Ende rechnet der Kern (`opErholungBis`); die Fälle mit
/// Zeitumstellung und Jahreswechsel prüfen hier nur, dass das Formular
/// diese Regel benutzt und nicht selbst `+ 14 · 24 h` rechnet.
///
/// ## Festlegungen des Test-Agenten — nicht von Tim freigegeben
///
/// Plan und Spec lassen die folgenden Punkte offen; diese Datei legt sie
/// fest:
///
/// - **Die `mit…`-Methoden geben ein neues Formular zurück** und lassen das
///   alte unverändert. Der Plan nennt `AuszeitFormular` einen Werttyp.
/// - **`==` und `hashCode`** vergleichen über den Inhalt (Plan, „Global
///   Constraints“: `AuszeitFormular` braucht beides).
/// - **Ein Beginn, der hinter ein von Hand gesetztes Ende rückt, nimmt das
///   Ende mit (V5) — und das Ende bleibt danach „von Hand“.** Ein späterer
///   Wechsel der Art zieht es also weiter nicht nach. Das Ende hat der
///   Nutzer angefasst; dass V5 es verschoben hat, macht es nicht wieder zu
///   einer Vorbelegung.
/// - **`mitBis` setzt `bisVonHand`.** V4 nennt das Ende nach einer Wahl
///   „von Hand geändert“.
/// - **`alsEreignis` übernimmt Art, Zeitraum, die getrimmte Notiz, `id`
///   und `angelegt`; `geaendert` bleibt `null`.** Den Zeitstempel einer
///   Änderung setzt das Repository (`aendere`), nicht das Formular.
/// - **`fuer` übernimmt Art, Zeitraum und Notiz des Ereignisses**, nicht
///   nur das Ende.
///
/// **Alle Daten hier sind erfunden und liegen im Jahr 2099** (Plan,
/// „Global Constraints“).
void main() {
  group('Ein neues Formular (V4)', () {
    test('ist eine OP vom Esstag bis 14 Tage danach, Ende vorbelegt', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14');

      expect(f.art, EreignisArt.op);
      expect(f.von, '2099-10-14');
      expect(f.bis, '2099-10-28');
      expect(
        f.bisVonHand,
        isFalse,
        reason: 'Die Vorbelegung ist keine Wahl des Nutzers (V4).',
      );
      expect(f.notiz, isNull, reason: 'Ohne Eingabe keine Notiz (V6).');
    });

    test('rechnet das Ende über den Kalender, nicht über 14 · 24 h', () {
      // Ende Oktober 2099 endet die Sommerzeit. 14 · 24 h ab dem 20.10.
      // landeten eine Stunde neben dem Kalendertag.
      expect(AuszeitFormular.neu(heute: '2099-10-20').bis, '2099-11-03');
      expect(AuszeitFormular.neu(heute: '2099-03-20').bis, '2099-04-03');
    });

    test('rechnet das Ende auch über einen Jahreswechsel', () {
      expect(AuszeitFormular.neu(heute: '2099-12-25').bis, '2100-01-08');
    });

    test('nimmt dieselbe Regel wie der Kern (`opErholungBis`)', () {
      const heute = '2099-06-30';
      expect(AuszeitFormular.neu(heute: heute).bis, opErholungBis(heute));
    });
  });

  group('Das Ende zieht nach, solange es niemand angefasst hat (V4)', () {
    test('ein neuer Beginn zieht das Ende einer OP nach, über die '
        'Zeitumstellung', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitVon('2099-10-20');

      expect(f.von, '2099-10-20');
      expect(f.bis, '2099-11-03');
      expect(f.bisVonHand, isFalse);
    });

    test('ein früherer Beginn zieht das Ende einer OP ebenfalls nach', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitVon('2099-10-01');

      expect(f.von, '2099-10-01');
      expect(f.bis, '2099-10-15');
    });

    test('Krankheit setzt das Ende auf den Beginn', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.krankheit);

      expect(f.art, EreignisArt.krankheit);
      expect(f.von, '2099-10-14');
      expect(
        f.bis,
        '2099-10-14',
        reason: 'Außer bei der OP zieht das Ende auf den Beginn selbst (V4).',
      );
      expect(f.bisVonHand, isFalse);
    });

    test('Verletzung und Urlaub setzen das Ende ebenfalls auf den Beginn', () {
      final neu = AuszeitFormular.neu(heute: '2099-10-14');

      expect(neu.mitArt(EreignisArt.verletzung).bis, '2099-10-14');
      expect(neu.mitArt(EreignisArt.urlaub).bis, '2099-10-14');
    });

    test('zurück auf OP setzt das Ende wieder auf Beginn + 14', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.krankheit)
          .mitArt(EreignisArt.op);

      expect(f.art, EreignisArt.op);
      expect(f.bis, '2099-10-28');
      expect(f.bisVonHand, isFalse);
    });

    test('ein neuer Beginn bei einer Krankheit zieht das Ende auf ihn', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.krankheit)
          .mitVon('2099-10-17');

      expect(f.von, '2099-10-17');
      expect(f.bis, '2099-10-17');
    });

    test('Art und Beginn in beliebiger Folge: das Ende folgt dem Letzten', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitVon('2099-10-20')
          .mitArt(EreignisArt.urlaub)
          .mitVon('2099-10-22')
          .mitArt(EreignisArt.op);

      expect(f.von, '2099-10-22');
      expect(f.bis, '2099-11-05');
    });
  });

  group('Ein von Hand gesetztes Ende bleibt (V4, V5)', () {
    test('`mitBis` setzt das Ende und merkt sich, dass es von Hand kam', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitBis('2099-11-02');

      expect(f.bis, '2099-11-02');
      expect(f.bisVonHand, isTrue);
    });

    test('danach zieht die Art das Ende nicht mehr nach', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitBis('2099-11-02')
          .mitArt(EreignisArt.krankheit);

      expect(f.art, EreignisArt.krankheit);
      expect(
        f.bis,
        '2099-11-02',
        reason: 'Das Ende wurde von Hand geändert — V4 zieht dann nicht nach.',
      );

      expect(f.mitArt(EreignisArt.op).bis, '2099-11-02');
    });

    test('danach zieht ein Beginn vor dem Ende das Ende nicht nach', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitBis('2099-11-02')
          .mitVon('2099-10-20');

      expect(f.von, '2099-10-20');
      expect(f.bis, '2099-11-02');
    });

    test('ein Beginn auf dem Ende lässt das Ende stehen', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitBis('2099-11-02')
          .mitVon('2099-11-02');

      expect(f.von, '2099-11-02');
      expect(f.bis, '2099-11-02');
    });

    test('rückt der Beginn hinter das Ende, rückt das Ende mit (V5)', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitBis('2099-10-20')
          .mitVon('2099-10-25');

      expect(f.von, '2099-10-25');
      expect(
        f.bis,
        '2099-10-25',
        reason:
            'Das Ende liegt nie vor dem Beginn (V5), und von Hand '
            'gesetzt heißt: auf den Beginn, nicht auf Beginn + 14.',
      );
    });

    test('auch danach bleibt das Ende „von Hand“ (Festlegung)', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitBis('2099-10-20')
          .mitVon('2099-10-25')
          .mitArt(EreignisArt.krankheit)
          .mitArt(EreignisArt.op);

      expect(f.bisVonHand, isTrue);
      expect(f.bis, '2099-10-25');
    });
  });

  group('Das Ende liegt nie vor dem Beginn (V5)', () {
    test('`mitBis` vor dem Beginn setzt das Ende auf den Beginn', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitBis('2099-10-10');

      expect(f.von, '2099-10-14');
      expect(f.bis, '2099-10-14');
    });

    test('`mitBis` auf den Beginn ist erlaubt — ein einzelner Tag', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitBis('2099-10-14');

      expect(f.bis, '2099-10-14');
    });

    test('der Vergleich gilt über einen Jahreswechsel', () {
      final f = AuszeitFormular.neu(heute: '2099-12-30')
          .mitBis('2100-01-02')
          .mitVon('2100-01-05');

      expect(f.von, '2100-01-05');
      expect(f.bis, '2100-01-05');
    });
  });

  group('Die Notiz (V6)', () {
    test('nur Leerzeichen heißt keine Notiz', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitNotiz('  ');

      expect(f.notiz, isNull);
    });

    test('ein leerer Text heißt keine Notiz', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitNotiz('');

      expect(f.notiz, isNull);
    });

    test('wird an den Rändern getrimmt, innen nicht', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitNotiz('  Knie, links  ');

      expect(f.notiz, 'Knie, links');
    });

    test('eine geleerte Notiz ist wieder keine', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14')
          .mitNotiz('Knie')
          .mitNotiz(' ');

      expect(f.notiz, isNull);
    });

    test('die Notiz ändert am Zeitraum nichts', () {
      final f = AuszeitFormular.neu(heute: '2099-10-14').mitNotiz('Knie');

      expect(f.von, '2099-10-14');
      expect(f.bis, '2099-10-28');
      expect(f.bisVonHand, isFalse);
    });
  });

  group('Das Ändern-Blatt (`fuer`, V4, V7)', () {
    final abgelegt = Ereignis(
      id: 7,
      art: EreignisArt.verletzung,
      von: '2099-09-21',
      bis: '2099-09-24',
      notiz: 'Knöchel',
      angelegt: DateTime.utc(2099, 9, 21, 8),
      geaendert: DateTime.utc(2099, 9, 22, 8),
    );

    test('übernimmt Art, Zeitraum und Notiz', () {
      final f = AuszeitFormular.fuer(abgelegt);

      expect(f.art, EreignisArt.verletzung);
      expect(f.von, '2099-09-21');
      expect(f.bis, '2099-09-24');
      expect(f.notiz, 'Knöchel');
    });

    test('das Ende gilt als von Hand gesetzt', () {
      expect(AuszeitFormular.fuer(abgelegt).bisVonHand, isTrue);
    });

    test('ein Wechsel der Art zieht das Ende darum nicht nach', () {
      final f = AuszeitFormular.fuer(abgelegt).mitArt(EreignisArt.op);

      expect(f.art, EreignisArt.op);
      expect(f.bis, '2099-09-24');
    });

    test('ein Beginn hinter dem Ende nimmt es trotzdem mit (V5)', () {
      final f = AuszeitFormular.fuer(abgelegt).mitVon('2099-09-30');

      expect(f.von, '2099-09-30');
      expect(f.bis, '2099-09-30');
    });

    test('eine OP ohne Notiz bleibt ohne Notiz', () {
      final f = AuszeitFormular.fuer(
        const Ereignis(
          art: EreignisArt.op,
          von: '2099-10-14',
          bis: '2099-10-30',
        ),
      );

      expect(f.notiz, isNull);
      expect(f.bis, '2099-10-30');
    });
  });

  group('Der Weg zum Ereignis (`alsEreignis`)', () {
    test('ein neues Formular wird ein Ereignis ohne id und Zeitstempel', () {
      final e = AuszeitFormular.neu(heute: '2099-10-14')
          .mitNotiz('  Knie ')
          .alsEreignis();

      expect(
        e,
        const Ereignis(
          art: EreignisArt.op,
          von: '2099-10-14',
          bis: '2099-10-28',
          notiz: 'Knie',
        ),
      );
    });

    test('nimmt `id` und `angelegt` mit, `geaendert` nicht', () {
      final angelegt = DateTime.utc(2099, 9, 21, 8);
      final e = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.krankheit)
          .alsEreignis(id: 4, angelegt: angelegt);

      expect(e.id, 4);
      expect(e.angelegt, angelegt);
      expect(
        e.geaendert,
        isNull,
        reason: 'Den Zeitstempel einer Änderung setzt das Repository.',
      );
      expect(e.art, EreignisArt.krankheit);
      expect(e.von, '2099-10-14');
      expect(e.bis, '2099-10-14');
      expect(e.notiz, isNull);
    });

    test('eine Notiz aus Leerzeichen kommt als `null` an (V6)', () {
      final e = AuszeitFormular.neu(heute: '2099-10-14')
          .mitNotiz('   ')
          .alsEreignis();

      expect(e.notiz, isNull);
    });

    test('ein geändertes Ereignis kommt mit seiner id zurück', () {
      final abgelegt = Ereignis(
        id: 9,
        art: EreignisArt.op,
        von: '2099-10-14',
        bis: '2099-10-28',
        notiz: 'Knie',
        angelegt: DateTime.utc(2099, 10, 13, 18),
      );

      final e = AuszeitFormular.fuer(abgelegt)
          .mitNotiz('Knie, beide')
          .alsEreignis(id: abgelegt.id, angelegt: abgelegt.angelegt);

      expect(
        e,
        Ereignis(
          id: 9,
          art: EreignisArt.op,
          von: '2099-10-14',
          bis: '2099-10-28',
          notiz: 'Knie, beide',
          angelegt: DateTime.utc(2099, 10, 13, 18),
        ),
      );
    });
  });

  group('Werttyp', () {
    test('gleiche Wege ergeben gleiche Formulare', () {
      final a = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.verletzung)
          .mitNotiz('Knie');
      final b = AuszeitFormular.neu(heute: '2099-10-14')
          .mitArt(EreignisArt.verletzung)
          .mitNotiz('Knie');

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('ein anderer Inhalt ist ungleich', () {
      final a = AuszeitFormular.neu(heute: '2099-10-14');

      expect(a == a.mitNotiz('Knie'), isFalse);
      expect(a == a.mitArt(EreignisArt.urlaub), isFalse);
      expect(a == a.mitVon('2099-10-15'), isFalse);
      expect(a == AuszeitFormular.neu(heute: '2099-10-15'), isFalse);
    });

    test('`mit…` lässt das alte Formular unverändert', () {
      final a = AuszeitFormular.neu(heute: '2099-10-14');

      a
        ..mitArt(EreignisArt.krankheit)
        ..mitVon('2099-10-20')
        ..mitBis('2099-12-01')
        ..mitNotiz('Knie');

      expect(a.art, EreignisArt.op);
      expect(a.von, '2099-10-14');
      expect(a.bis, '2099-10-28');
      expect(a.notiz, isNull);
      expect(a.bisVonHand, isFalse);
    });
  });
}
