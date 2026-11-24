// Die Verdrahtung des Eintragwegs (#285): was im Suchfeld steht, was die
// Suche findet, und der **eine** Schreibweg des Erfassens. Die Rechnung
// liegt in `erfassen_formular.dart`, die Oberfläche in `suche_view.dart`,
// `anlegen_blatt.dart` und `buchungs_blatt.dart`.
//
// API und Vertrag sind durch
// `app/test/ernaehrung/erfassen_rundweg_test.dart` und
// `app/test/ernaehrung/erfassen_view_test.dart` verbindlich vorgegeben
// (siehe deren Dateiköpfe) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Alles hier sind Notifier, keine Provider mit gehaltenem `Ref`.** `ref`
// darf nur in `build` und in Notifiern benutzt werden (`CLAUDE.md`,
// Hausregel 3, durchgesetzt über `riverpod_lint`).
//
// **Kein `Messwert`.** Das sind Tims eigene Lebensmittel und Tims eigene
// Einträge; dahinter steht kein Lauf aus Apple Health, der leer ausgehen
// könnte. Leer heißt hier schlicht leer.
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ernaehrung_repository.dart';
import '../data/lebensmittel_repository.dart';
import '../data/portion.dart';
import '../data/portionen_repository.dart';
import '../data/wach_belege.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';
import '../tag/laufender_tag_provider.dart';
import 'erfassen_formular.dart';
import 'ernaehrung_provider.dart';
import 'vorwahl_text.dart';

/// Was im Suchfeld steht.
final suchtextProvider = NotifierProvider<SuchtextNotifier, String>(
  SuchtextNotifier.new,
);

class SuchtextNotifier extends Notifier<String> {
  /// **Beim Start leer** — und das ist keine leere Seite, sondern der
  /// Zustand „zuletzt benutzt" (`erfassen.js`, `SUCHE`).
  @override
  String build() => '';

  void setze(String text) => state = text;
}

/// Die Treffer zum aktuellen Suchtext — ohne Eingabe die zuletzt
/// benutzten.
///
/// Gefiltert und sortiert wird in SQL, nicht hier
/// (`LebensmittelRepository.suche`).
final suchtrefferProvider =
    AsyncNotifierProvider<SuchtrefferNotifier, List<LebensmittelVorlage>>(
      SuchtrefferNotifier.new,
    );

class SuchtrefferNotifier extends AsyncNotifier<List<LebensmittelVorlage>> {
  @override
  Future<List<LebensmittelVorlage>> build() {
    final text = ref.watch(suchtextProvider);
    return ref.watch(lebensmittelRepositoryProvider).suche(text);
  }

  /// Der Weg, den [ErfassenNotifier] nach jedem Schreibvorgang nimmt: Er
  /// schreibt und sagt dann Bescheid.
  ///
  /// Ohne ihn stünde ein frisch angelegtes Lebensmittel erst nach einem
  /// Neustart in der Suche — und genau das ist der Fall, auf den es in
  /// diesem Zuschnitt ankommt, weil es keinen anderen Weg zu einem
  /// Lebensmittel gibt.
  Future<void> neuLesen() async {
    final text = ref.read(suchtextProvider);
    final repo = ref.read(lebensmittelRepositoryProvider);
    state = await AsyncValue.guard(() => repo.suche(text));
  }
}

/// Die jüngste Buchung je **sichtbarem eigenen Treffer** — die Grundlage
/// der Trefferzeile „2 Bon (11,8 g)" (#401, V9). Ein Treffer ohne Buchung
/// fehlt in der Map.
///
/// **Gehalten, nicht je Bild gerechnet** (Hausregel 2): Neu gelesen wird,
/// wenn sich die **Menge** der sichtbaren IDs ändert — nicht bei jedem
/// neuen Listenobjekt aus [suchtrefferProvider] —, und nach jedem
/// Schreibvorgang über [LetztePortionenNotifier.neuLesen]. Eine Abfrage für
/// alle Treffer ([ErnaehrungRepository.letzteBuchungen]), keine je Zeile.
///
/// **Online-Treffer fragt hier niemand nach**: Sie haben keine ID und
/// keine Buchung, und eine Anfrage je Zeile an Open Food Facts wäre die
/// Massenabfrage, die der Plan ausschließt.
final letztePortionenProvider =
    AsyncNotifierProvider<LetztePortionenNotifier, Map<int, Eintrag>>(
      LetztePortionenNotifier.new,
    );

class LetztePortionenNotifier extends AsyncNotifier<Map<int, Eintrag>> {
  @override
  Future<Map<int, Eintrag>> build() {
    final ids = ref.watch(
      suchtrefferProvider.select((treffer) => _TrefferIds.aus(treffer.value)),
    );
    return ref.watch(ernaehrungRepositoryProvider).letzteBuchungen(ids.ids);
  }

  /// Liest nach einem Schreibvorgang neu. Die Menge der Treffer ist dabei
  /// oft dieselbe — dann rechnete [build] nicht neu, und die Zeile hielte
  /// „2 Bon" fest, nachdem eben 3 gebucht wurden.
  Future<void> neuLesen() async {
    final ids = _TrefferIds.aus(ref.read(suchtrefferProvider).value).ids;
    final repo = ref.read(ernaehrungRepositoryProvider);
    state = await AsyncValue.guard(() => repo.letzteBuchungen(ids));
  }
}

/// Die Portionen **eines** Lebensmittels, wie das Blatt sie aus der Tabelle
/// bekäme — die zweite Hälfte dessen, was die Trefferzeile braucht, um zu
/// sagen, was „+" bucht (V24).
///
/// **Je Lebensmittel gehalten**, nicht je Bild gefragt (Hausregel 2):
/// gelesen, wenn eine Zeile es zum ersten Mal braucht, und neu nach jedem
/// Schreibvorgang an seinen Portionen ([ErfassenNotifier.legePortionAn],
/// [ErfassenNotifier.aenderePortion], [ErfassenNotifier.loeschePortion]).
/// `autoDispose`: Verschwindet die Zeile aus der Suche, wird nichts mehr
/// gehalten.
final lebensmittelPortionenProvider = FutureProvider.autoDispose
    .family<List<Portion>, int>(
      (ref, lebensmittelId) =>
          ref.watch(portionenRepositoryProvider).fuer(lebensmittelId),
    );

/// Was die Trefferzeile unter dem Namen sagt und rechts an Kalorien zeigt
/// — **genau das, was „+" bucht** (V24, [vorwahlAnzeige]).
///
/// Je Vorlage gehalten und nur neu gerechnet, wenn sich die letzte Buchung
/// dieses Lebensmittels ([letztePortionenProvider]) oder seine Portionen
/// ([lebensmittelPortionenProvider]) ändern — nicht je Bild (Hausregel 2).
///
/// **Die Portionen gehen mit** (offener Punkt aus #438): Ist die Portion
/// der letzten Buchung inzwischen gelöscht oder geändert, wählt das Blatt
/// anders vor, als der Schnappschuss der Buchung sagt — und „+" bucht, was
/// das Blatt vorwählt. Bis die Portionen gelesen sind, gilt der
/// Schnappschuss; das ist fast immer dasselbe.
///
/// `null` heißt „noch nicht nachgesehen": Die letzte Buchung ist noch
/// nicht gelesen. Ein „100 g" an dieser Stelle wäre eine Behauptung, die
/// gleich wieder umspringt.
final trefferVorwahlProvider = Provider.autoDispose
    .family<({String menge, double? kcal})?, LebensmittelVorlage>((
      ref,
      vorlage,
    ) {
      final id = vorlage.id;
      // Ein Online-Treffer hat weder Buchung noch Portionen in der Tabelle.
      if (id == null) return vorwahlAnzeige(vorlage: vorlage);

      final letzte = ref.watch(
        letztePortionenProvider.select(
          (stand) => (gelesen: stand.hasValue, eintrag: stand.value?[id]),
        ),
      );
      if (!letzte.gelesen) return null;
      final portionen = ref.watch(lebensmittelPortionenProvider(id)).value;
      return vorwahlAnzeige(
        vorlage: vorlage,
        letzte: letzte.eintrag,
        portionen: portionen,
      );
    });

/// Die IDs der eigenen Treffer als Wert mit [==] und [hashCode] — sonst
/// wäre jede neu gelesene Trefferliste eine neue Abhängigkeit und
/// [LetztePortionenNotifier.build] fragte bei jedem Lesen erneut.
@immutable
class _TrefferIds {
  const _TrefferIds(this.ids);

  factory _TrefferIds.aus(List<LebensmittelVorlage>? treffer) => _TrefferIds({
    for (final vorlage in treffer ?? const <LebensmittelVorlage>[])
      if (vorlage.id != null) vorlage.id!,
  });

  final Set<int> ids;

  @override
  bool operator ==(Object other) =>
      other is _TrefferIds && setEquals(other.ids, ids);

  @override
  int get hashCode => Object.hashAllUnordered(ids);
}

/// Der **einzige** Schreibweg des Erfassens.
///
/// Ein `Notifier` und kein `Provider` mit gehaltenem `Ref`: siehe
/// Dateikopf. Der Zustand ist `void` — hier wird nichts gehalten, hier
/// wird geschrieben.
final erfassenProvider = NotifierProvider<ErfassenNotifier, void>(
  ErfassenNotifier.new,
);

class ErfassenNotifier extends Notifier<void> {
  @override
  void build() {}

  /// Die Health-Arbeit läuft **nacheinander**, nie überlappend. Zwei
  /// Nachläufe zugleich läsen dieselben `offen`en Einträge und schrieben
  /// jeden zweimal; ein Löschen mitten in einem Nachlauf ließe eine Probe
  /// in Health zurück, deren Zeile es nicht mehr gibt.
  Future<void> _healthKette = Future<void>.value();

  Future<void> _nacheinander(Future<void> Function() arbeit) {
    final lauf = _healthKette.then((_) => arbeit());
    // Die Kette selbst bricht nie: Ein gescheiterter Schritt hält den
    // nächsten nicht auf.
    _healthKette = lauf.catchError((Object _) {});
    return lauf;
  }

  /// Legt ein Lebensmittel an und gibt seinen Schlüssel zurück.
  ///
  /// Die Suche wird **im selben Zug** neu gelesen, damit das Angelegte
  /// sofort dasteht — auch dann, wenn im Suchfeld schon etwas steht.
  ///
  /// [portionen] aus dem Abschnitt „Portionen · freiwillig" gehen in
  /// derselben Transaktion mit (#325).
  Future<int> legeLebensmittelAn(
    LebensmittelVorlage vorlage, {
    List<Portion> portionen = const [],
  }) async {
    final id = await ref
        .read(lebensmittelRepositoryProvider)
        .legeAn(vorlage, portionen: portionen);
    await ref.read(suchtrefferProvider.notifier).neuLesen();
    return id;
  }

  /// Das Buchungsblatt für eine Vorlage, **samt Portionen und Vorwahl**
  /// (#325, Entscheidung 7).
  ///
  /// Mit [LebensmittelVorlage.id] liest es die Portionen aus der Tabelle
  /// und die letzte Buchung; was vorgewählt ist, rechnet der Kern
  /// ([portionsVorwahl]). Ohne ID — ein Treffer aus Open Food Facts, der
  /// noch nicht übernommen ist — gibt es keine Vorwahl, und die Portionen
  /// kommen aus der Vorlage.
  ///
  /// **Open Food Facts wird hier nicht gefragt.** Die eine Anfrage je
  /// Öffnen gehört dem Abruf (`portionsAbrufProvider`); fragte auch dieser
  /// Weg, wären es zwei.
  ///
  /// **Den Grund des laufenden Tages holt das Formular hier** (#456, V14),
  /// nicht beim Aufrufer: Jedes Blatt und jedes „+" läuft durch diese
  /// Stelle, also kann keiner ihn vergessen. Auf einem geblätterten Tag ist
  /// er `normal` ([buchungsgrund]).
  ///
  /// Hält niemand den laufenden Tag, legt das Öffnen eines Blatts ihn nicht
  /// an — samt Zeitgeber und, zwischen 04:00 und 08:00, Fragen an Health.
  /// Dann gilt, was der Kern aus [jetzt] allein sagt (`laufenderTag` ohne
  /// Belege und Nächte, der Esstag). Auf dem Schirm kommt das nicht vor:
  /// Suche und Kamera lesen den offenen Tag und damit den laufenden.
  Future<BuchungsFormular> oeffneFormular({
    required LebensmittelVorlage vorlage,
    required String tagesSchluessel,
    required DateTime jetzt,
    Mahlzeit? mahlzeit,
  }) async {
    final grund = buchungsgrund(
      ref.exists(laufenderTagProvider)
          ? ref.read(laufenderTagProvider)
          : laufenderTag(jetzt: jetzt.toUtc()),
      tagesSchluessel,
    );
    final id = vorlage.id;
    if (id == null) {
      return BuchungsFormular.neu(
        vorlage: vorlage,
        tagesSchluessel: tagesSchluessel,
        jetzt: jetzt,
        mahlzeit: mahlzeit,
        grund: grund,
      );
    }
    final portionen = await ref.read(portionenRepositoryProvider).fuer(id);
    final letzte = await ref
        .read(ernaehrungRepositoryProvider)
        .letzteBuchung(id);
    final vorwahl = portionsVorwahl(
      letzte: letzte,
      vorhandenePortionen: {
        for (final p in portionen)
          if (p.id != null) p.id!,
      },
    );
    return BuchungsFormular.neu(
      vorlage: vorlage,
      tagesSchluessel: tagesSchluessel,
      jetzt: jetzt,
      mahlzeit: mahlzeit,
      portionen: portionen,
      vorwahl: vorwahl,
      grund: grund,
    );
  }

  /// Legt eine Portion an einem gespeicherten Lebensmittel an und gibt
  /// die neue Liste **aus der Tabelle** zurück, samt Schlüsseln.
  Future<List<Portion>> legePortionAn(int lebensmittelId, Portion p) async {
    final repo = ref.read(portionenRepositoryProvider);
    await repo.legeAn(lebensmittelId, p);
    ref.invalidate(lebensmittelPortionenProvider(lebensmittelId));
    return repo.fuer(lebensmittelId);
  }

  /// Schreibt Name und Menge einer gespeicherten Portion neu und gibt die
  /// neue Liste aus der Tabelle zurück. Gebuchte Einträge behalten ihren
  /// Schnappschuss.
  Future<List<Portion>> aenderePortion(int lebensmittelId, Portion p) async {
    final repo = ref.read(portionenRepositoryProvider);
    await repo.aendere(p);
    ref.invalidate(lebensmittelPortionenProvider(lebensmittelId));
    return repo.fuer(lebensmittelId);
  }

  /// Löscht eine gespeicherte Portion und gibt die neue Liste aus der
  /// Tabelle zurück. Wirft bei fehlendem Schlüssel — eine Portion ohne
  /// Schlüssel ist nicht gespeichert.
  Future<List<Portion>> loeschePortion(int lebensmittelId, Portion p) async {
    final id = p.id;
    if (id == null) {
      throw ArgumentError.notNull('p.id');
    }
    final repo = ref.read(portionenRepositoryProvider);
    await repo.loesche(id);
    ref.invalidate(lebensmittelPortionenProvider(lebensmittelId));
    return repo.fuer(lebensmittelId);
  }

  /// Bucht einen neuen Eintrag auf [BuchungsFormular.tagesSchluessel] —
  /// den **offenen** Tag, nicht heute.
  ///
  /// **Gebucht wird immer**, auch ohne Schreibfreigabe: Der Eintrag steht
  /// danach auf [HealthStand.offen], und das heißt „noch nicht nach Health
  /// geschrieben", nicht „nicht gespeichert".
  ///
  /// Dass die Benutzung gemerkt wird, gehört hierher und nicht ins Blatt:
  /// Buchen **ist** das Benutzen, und die Vorlage steht danach obenan.
  ///
  /// **Ein Treffer aus Open Food Facts wird hier übernommen** (#284) —
  /// vor dem Buchen, damit der Eintrag auf die übernommene Zeile zeigt und
  /// nicht wie ein Schnelleintrag ohne Vorlage dasteht. Liegt der
  /// Strichcode schon in der Tabelle, gilt die vorhandene Zeile
  /// ([LebensmittelRepository.uebernimm]).
  ///
  /// **Die Portionen gehen mit der Übernahme** (#325, V3). Hat Open Food
  /// Facts noch nicht geantwortet, gehen die im Blatt angelegten trotzdem
  /// mit, nur ohne Marke `portionen_abgefragt_am`
  /// ([LebensmittelRepository.uebernimm], `ohneAntwort`). Danach sucht
  /// `buche` die gewählte, noch ungespeicherte Portion über Name und Menge
  /// in der Tabelle; ohne Fund — der Strichcode lag schon da — bucht sie
  /// `portion_id: null` mit Schnappschuss (Spec, „eintraege").
  ///
  /// Gibt die ID des neuen Eintrags zurück — die braucht, wer die Buchung
  /// gleich wieder zurücknehmen können soll ([nimmZurueck], V27).
  Future<int> buche(BuchungsFormular formular) async {
    var zuBuchen = formular;
    final uebernahme = formular.uebernahme;
    if (formular.lebensmittelId == null && uebernahme != null) {
      final id = await ref
          .read(lebensmittelRepositoryProvider)
          .uebernimm(
            uebernahme,
            jetzt: ref.read(clockProvider)(),
            ohneAntwort: uebernahme.offPortionen == null
                ? formular.portionen
                : const [],
          );
      zuBuchen = formular.uebernommenAls(id);
    }

    var eintrag = zuBuchen.alsEintrag();
    final portion = zuBuchen.portion;
    final lebensmittelId = zuBuchen.lebensmittelId;
    if (portion != null && portion.id == null && lebensmittelId != null) {
      final inTabelle = await ref
          .read(portionenRepositoryProvider)
          .fuer(lebensmittelId);
      int? gefunden;
      for (final p in inTabelle) {
        if (p.name == portion.name && p.mengeG == portion.mengeG) {
          gefunden = p.id;
          break;
        }
      }
      eintrag = eintrag.copyWith(portionId: () => gefunden);
    }
    // Ein neuer Eintrag hat keine Kopie — gleich, was im Formular stand.
    final eintragId = await ref
        .read(ernaehrungRepositoryProvider)
        .buche(_mitKopie(eintrag, healthUuid: null));

    final vorlage = zuBuchen.lebensmittelId;
    if (vorlage != null) {
      await ref
          .read(lebensmittelRepositoryProvider)
          .merkeBenutzung(vorlage, ref.read(clockProvider)());
      await ref.read(suchtrefferProvider.notifier).neuLesen();
    }

    await _nachSchreiben({eintrag.tagesSchluessel});
    await _nacheinander(() => _kopiereNachHealth(hinweis: true));
    return eintragId;
  }

  /// Bucht eine Vorlage **ohne Blatt** — das „+" der Trefferzeile (V25).
  ///
  /// **Genau [oeffneFormular] plus [buche], ohne Änderung dazwischen.**
  /// Damit gelten Tag, Uhrzeit, Mahlzeit, Vorwahl, Übernahme und
  /// Health-Kopie wie im Blatt, und was die Zeile über
  /// `vorwahlAnzeige` sagt, ist, was hier gebucht wird (V24). Ein eigener
  /// Weg hier liefe beim ersten neuen Feld des Blatts auseinander.
  ///
  /// Ein Online-Treffer wird dabei **ohne Portionen** übernommen:
  /// [oeffneFormular] fragt Open Food Facts nicht, also bleibt
  /// `portionen_abgefragt_am` leer, und das nächste Öffnen des Blatts fragt
  /// einmal nach (#325, Entscheidung 6).
  ///
  /// Gibt die ID des neuen Eintrags zurück, wie [buche].
  Future<int> bucheDirekt({
    required LebensmittelVorlage vorlage,
    required String tagesSchluessel,
    required DateTime jetzt,
    Mahlzeit? mahlzeit,
  }) async {
    final formular = await oeffneFormular(
      vorlage: vorlage,
      tagesSchluessel: tagesSchluessel,
      jetzt: jetzt,
      mahlzeit: mahlzeit,
    );
    return buche(formular);
  }

  /// Nimmt eine eben gebuchte Buchung zurück — „Rückgängig" im Band der
  /// Suche (V27). Fehlt der Eintrag, tut sie nichts: ein zweiter Tipp,
  /// oder er ist inzwischen anderswo gelöscht.
  ///
  /// **Der Eintrag wird frisch gelesen**, nicht aus dem Stand beim Buchen
  /// genommen: Die Kopie in Health kann erst danach geschrieben worden sein
  /// (Freigabe kam später, Nachlauf), und mit der alten, leeren Kennung
  /// bliebe sie in Health stehen. Gelesen wird **in der Health-Kette** —
  /// so kann zwischen Lesen und Löschen kein Nachlauf die Kennung noch
  /// ändern.
  ///
  /// Gelöscht wird über denselben Weg wie [loesche]: Zeile weg, Kopie weg,
  /// Tag und Trefferzeilen neu gelesen.
  Future<void> nimmZurueck(int eintragId) async {
    Eintrag? weg;
    await _nacheinander(() async {
      weg = await ref.read(ernaehrungRepositoryProvider).eintrag(eintragId);
      final eintrag = weg;
      if (eintrag != null) await _streiche(eintrag);
    });
    final eintrag = weg;
    if (eintrag == null) return;
    await _nachSchreiben({eintrag.tagesSchluessel});
  }

  /// Bucht die Einträge eines bestätigten KI-Vorschlags (#341) — **alle
  /// in einer Transaktion** ([ErnaehrungRepository.bucheAlle]), danach
  /// derselbe Nachlauf wie bei [buche].
  ///
  /// Aufgerufen nur von `KiAktionen` (`lib/ki/ki_aktionen.dart`), dem
  /// einzigen Ausführer eines `KiVorschlag`s. Hier wird nichts gefiltert
  /// oder umgerechnet: Was hereinkommt, ist bestätigt.
  ///
  /// Wie bei [buche]: **gebucht wird immer**, der Health-Stand steht
  /// danach auf `offen`, und fehlt die Freigabe, schlägt der Hinweis an —
  /// Tim hat gerade selbst getippt. Kein `merkeBenutzung`: Ein
  /// geschätzter Posten hat keine Vorlage.
  ///
  /// Eine leere Liste bucht nichts und fragt Health nicht.
  Future<void> bucheBestaetigt(List<Eintrag> eintraege) async {
    if (eintraege.isEmpty) return;
    await ref.read(ernaehrungRepositoryProvider).bucheAlle([
      for (final e in eintraege) _mitKopie(e, healthUuid: null),
    ]);
    await _nachSchreiben({for (final e in eintraege) e.tagesSchluessel});
    await _nacheinander(() => _kopiereNachHealth(hinweis: true));
  }

  /// Schreibt einen bestehenden Eintrag neu.
  ///
  /// **Kein zweites Buchen**, sondern ein Ersetzen: Dieselbe Zeile, derselbe
  /// Schlüssel. Und **kein Benutzen** — `zuletzt_benutzt` bleibt, wo es
  /// steht; eine Mengenkorrektur ist keine Mahlzeit.
  ///
  /// **Die Kopie wird ersetzt, nicht geändert** — HealthKit kennt kein
  /// Ändern. Der Eintrag steht danach wieder auf `offen` und **behält die
  /// alte Kennung als Merker**: Der Nachlauf räumt die veraltete Probe weg,
  /// bevor er die neue schreibt. Fehlt die Freigabe, bleibt der Merker
  /// stehen, bis sie kommt — sonst stünde dieselbe Mahlzeit zweimal in
  /// Health.
  Future<void> aendere(BuchungsFormular formular) async {
    final eintrag = formular.alsEintrag();
    await ref
        .read(ernaehrungRepositoryProvider)
        .aktualisiere(_mitKopie(eintrag, healthUuid: eintrag.healthUuid));
    await _nachSchreiben({eintrag.tagesSchluessel});
    await _nacheinander(() => _kopiereNachHealth(hinweis: true));
  }

  /// Nimmt einen gebuchten Eintrag weg.
  ///
  /// Wirft bei fehlendem Schlüssel, aus demselben Grund wie
  /// [ErnaehrungRepository.aktualisiere]: Ein Eintrag ohne Schlüssel ist
  /// nicht gebucht.
  Future<void> loesche(Eintrag eintrag) async {
    final id = eintrag.id;
    if (id == null) {
      throw ArgumentError.notNull('eintrag.id');
    }
    await _nacheinander(() => _streiche(eintrag));
    await _nachSchreiben({eintrag.tagesSchluessel});
  }

  /// Der eine Löschweg: Zeile weg, dann die Kopie in Health, wenn der
  /// Eintrag eine kennt. Läuft nur innerhalb von [_nacheinander].
  Future<void> _streiche(Eintrag eintrag) async {
    await ref.read(ernaehrungRepositoryProvider).loesche(eintrag.id!);
    final kopie = eintrag.healthUuid;
    if (kopie != null) await _loescheKopie(kopie);
  }

  /// Holt einen gerade gestrichenen Eintrag zurück (Rückgängig auf dem
  /// Mahlzeiten-Schirm).
  ///
  /// **Ohne die alte Kennung:** Beim Streichen ist die Probe in Health
  /// gelöscht worden. Stünde die Zeile danach mit ihr auf `geschrieben`,
  /// glaubte die App an eine Kopie, die fehlt, und der Nachlauf holte sie
  /// nie nach. Sie kommt deshalb als `offen` zurück und wird gleich neu
  /// geschrieben, wenn die Freigabe da ist.
  ///
  /// Ein neuer Schlüssel, kein alter: Die Zeile gibt es nicht mehr;
  /// zurückgeschrieben wird ihr Inhalt, nicht ihr Platz.
  Future<void> stelleWiederHer(Eintrag eintrag) async {
    await _nacheinander(() async {
      await ref
          .read(ernaehrungRepositoryProvider)
          .buche(
            Eintrag(
              tagesSchluessel: eintrag.tagesSchluessel,
              mahlzeit: eintrag.mahlzeit,
              zeitpunkt: eintrag.zeitpunkt,
              lebensmittelId: eintrag.lebensmittelId,
              name: eintrag.name,
              mengeG: eintrag.mengeG,
              naehrwerte: eintrag.naehrwerte,
              // Die Herkunft gehört zum Inhalt, nicht zum Platz — ein
              // zurückgeholter KI-Eintrag bleibt als Schätzung erkennbar.
              vorschlag: eintrag.vorschlag,
              // Der Portions-Schnappschuss ebenso (#325): „2 Bon" kommt
              // als „2 Bon" zurück, nicht als nackte Gramm.
              portionId: eintrag.portionId,
              portionName: eintrag.portionName,
              portionG: eintrag.portionG,
              // Und die Einheit (#403): ein Getränk kommt in ml zurück.
              fluessig: eintrag.fluessig,
            ),
          );
    });
    await _nachSchreiben({eintrag.tagesSchluessel});
    await _nacheinander(() => _kopiereNachHealth(hinweis: false));
  }

  /// Trägt alle Einträge mit [HealthStand.offen] nach — **über alle
  /// Tage**. Fragt die Freigabe nur, wenn es etwas nachzutragen gibt: Wer
  /// nie etwas einträgt, wird nie gefragt.
  ///
  /// Wirft nicht. Was scheitert, bleibt `offen` und kommt beim nächsten
  /// Mal wieder dran; nur eine endgültige Ablehnung durch HealthKit macht
  /// `nicht_moeglich`.
  Future<void> healthNachlauf() =>
      _nacheinander(() => _kopiereNachHealth(hinweis: false));

  /// Der eine Weg, auf dem Einträge nach Health kommen — beim Buchen,
  /// beim Ändern und im Nachlauf derselbe. Deshalb nimmt, wer mit Freigabe
  /// bucht, die älteren `offen`en Einträge mit: Das ist der Moment, in dem
  /// die App erfährt, dass die Freigabe inzwischen da ist.
  ///
  /// [hinweis] sagt, ob eine fehlende Freigabe den Hinweis auslöst. Nur
  /// wer gerade selbst bucht oder ändert, bekommt ihn zu sehen.
  Future<void> _kopiereNachHealth({required bool hinweis}) async {
    try {
      final repo = ref.read(ernaehrungRepositoryProvider);
      final offene = await repo.offeneHealthEintraege();

      final zuSchreiben = <Eintrag>[];
      for (final eintrag in offene) {
        if (_hatSchreibbarenWert(eintrag.naehrwerte)) {
          zuSchreiben.add(eintrag);
          continue;
        }
        // Nichts zu kopieren — `offen` hieße, dass jeder Nachlauf ihn
        // wieder anfasst. Eine veraltete Kopie darf trotzdem nicht stehen
        // bleiben.
        final veraltet = eintrag.healthUuid;
        if (veraltet != null) await _loescheKopie(veraltet);
        await repo.setzeHealthKopie(
          eintrag.id!,
          healthUuid: null,
          stand: HealthStand.nichtMoeglich,
        );
      }
      if (zuSchreiben.isEmpty) return;

      final health = ref.read(healthProvider);
      final freigabe = await health.requestNutritionWriteAuthorization();
      if (freigabe != WriteAuthorization.granted) {
        if (hinweis) ref.read(healthSchreibHinweisProvider.notifier).zeige();
        return;
      }

      for (final eintrag in zuSchreiben) {
        await _schreibe(eintrag);
      }
    } catch (fehler) {
      // Gebucht ist gebucht — eine fehlende Kopie hält niemanden auf. Die
      // Einträge bleiben `offen` und kommen beim nächsten Mal wieder dran.
      debugPrint('Ernährung nach Health: $fehler');
    }
  }

  /// Schreibt **einen** Eintrag und hält fest, was daraus wurde.
  Future<void> _schreibe(Eintrag eintrag) async {
    final repo = ref.read(ernaehrungRepositoryProvider);
    final health = ref.read(healthProvider);
    final id = eintrag.id!;

    var merker = eintrag.healthUuid;
    if (merker != null && await _loescheKopie(merker)) merker = null;
    // Scheitert das Löschen, wird trotzdem geschrieben: Meist ist die
    // Probe in der Health-App schon weg. Der Merker bleibt dann stehen,
    // bis eine neue Kopie ihn ablöst.

    try {
      final kopie = await health.writeMeal(
        werte: eintrag.naehrwerte,
        name: eintrag.name,
        at: eintrag.zeitpunkt,
      );
      await repo.setzeHealthKopie(
        id,
        healthUuid: kopie,
        stand: HealthStand.geschrieben,
      );
    } on HealthWriteRejected catch (fehler) {
      debugPrint('Ernährung nach Health abgelehnt: $fehler');
      await repo.setzeHealthKopie(
        id,
        healthUuid: null,
        stand: HealthStand.nichtMoeglich,
      );
    } catch (fehler) {
      debugPrint('Ernährung nach Health, später erneut: $fehler');
      if (merker != eintrag.healthUuid) {
        await repo.setzeHealthKopie(
          id,
          healthUuid: merker,
          stand: HealthStand.offen,
        );
      }
    }
  }

  /// Löscht eine Kopie in Health. **Ein Fehlschlag ist kein Fehler für
  /// den Nutzer** (Spec, „Löschen"): Der eigene Eintrag ist weg, und das
  /// ist die Wahrheit. Protokollzeile, kein Dialog.
  ///
  /// Sagt, ob das Löschen geklappt hat.
  Future<bool> _loescheKopie(String kennung) async {
    try {
      await ref.read(healthProvider).deleteMeal(kennung);
      return true;
    } catch (fehler) {
      debugPrint('Kopie $kennung in Health nicht gelöscht: $fehler');
      return false;
    }
  }

  /// **Was nach jedem Anlegen, Ändern und Löschen eines Eintrags
  /// passiert**, an einer Stelle statt in jedem Schreibweg: ein Wachbeleg
  /// `buchung` (V13), dann lesen die [tage] und die Trefferzeilen neu.
  Future<void> _nachSchreiben(Set<String> tage) async {
    await _merkeBuchung();
    for (final tag in tage) {
      await _zeigeTagNeu(tag);
    }
    await _zeigeLetzteNeu();
  }

  /// Ein Wachbeleg `buchung` mit der Uhr (V13): Wer bucht, ist wach — auch
  /// auf einem geblätterten Tag. **Ein Fehler hier hält niemanden auf:**
  /// Gebucht ist gebucht; ohne Beleg wird der Tag höchstens nicht
  /// verlängert, und das ist die vorsichtige Seite (V11).
  Future<void> _merkeBuchung() async {
    try {
      await ref.read(wachbelegProvider.notifier).merke(WachArt.buchung);
    } catch (fehler) {
      debugPrint('Wachbeleg nach Buchung: $fehler');
    }
  }

  /// Lässt den Tag-Schirm nachlesen. Ohne das stünde die neue Zahl erst
  /// nach einem Neustart da.
  Future<void> _zeigeTagNeu(String tagesSchluessel) =>
      ref.read(eigeneEintraegeProvider(tagesSchluessel).notifier).neuLesen();

  /// Lässt die Trefferzeilen der Suche nachlesen, damit „2 Bon" nach dem
  /// Buchen von drei zu „3 Bon" wird — ohne Neustart (#401).
  ///
  /// **Nur, wenn es den Provider schon gibt.** Wer nie gesucht hat, dem
  /// wird hier keine Suche samt Abfrage angestoßen; beim ersten Öffnen
  /// liest [LetztePortionenNotifier.build] ohnehin frisch.
  Future<void> _zeigeLetzteNeu() async {
    if (!ref.exists(letztePortionenProvider)) return;
    await ref.read(letztePortionenProvider.notifier).neuLesen();
  }
}

/// Derselbe Eintrag mit frischem Health-Stand `offen` und der angegebenen
/// Kennung; alles andere bleibt, wie es ist.
Eintrag _mitKopie(Eintrag eintrag, {required String? healthUuid}) => eintrag
    .copyWith(healthUuid: () => healthUuid, healthStand: HealthStand.offen);

/// Ob einer der acht Werte da ist, die nach Health gehen. Mikronährstoffe
/// aus `extra` zählen nicht — sie stehen nicht im Schreibkatalog.
bool _hatSchreibbarenWert(Naehrwerte werte) => [
  werte.kcal,
  werte.eiweissG,
  werte.kohlenhydrateG,
  werte.fettG,
  werte.gesaettigtG,
  werte.zuckerG,
  werte.ballaststoffeG,
  werte.wasserMl,
].any((wert) => wert != null);

/// Ob der Hinweis „Ernährung darf nicht nach Health" ansteht (#283).
///
/// **Einmal, nicht je Eintrag** (Spec, „Wenn die Schreibfreigabe fehlt").
/// Nach [HealthSchreibHinweisNotifier.gesehen] kommt er in diesem Lauf
/// nicht wieder, auch wenn weiter ohne Freigabe gebucht wird. Gezeigt wird
/// er im Buchungsblatt (`buchungs_blatt.dart`), gezeichnet in
/// `docs/screens/screens/erfassen.js`, Zustand `keine-freigabe`.
final healthSchreibHinweisProvider =
    NotifierProvider<HealthSchreibHinweisNotifier, bool>(
      HealthSchreibHinweisNotifier.new,
    );

class HealthSchreibHinweisNotifier extends Notifier<bool> {
  var _schonGesehen = false;

  @override
  bool build() => false;

  /// Die Freigabe fehlte gerade. Steht der Hinweis schon einmal da
  /// gewesen, bleibt er weg.
  void zeige() {
    if (!_schonGesehen) state = true;
  }

  /// Der Hinweis wurde gezeigt; er kommt in diesem Lauf nicht wieder.
  void gesehen() {
    _schonGesehen = true;
    state = false;
  }
}
