import 'berlin_calendar.dart';
import 'mahlzeit.dart';

// Der Tag endet mit dem Einschlafen, spätestens um 04:00 — es sei denn, Tim
// ist dann nachweislich wach. Spec:
// `docs/superpowers/specs/2026-11-10-tagesgrenze-design.md`, „Die
// Kern-Rechnungen“ (Entscheidungen 1–4, Vorgaben V1–V5). Die Vorgaben V1–V5
// hat der Planende formuliert und Tim am 10.11.2026 übernommen.
//
// **Keine Nutzertexte:** Gründe und Quellen sind Enums, die Wörter setzt die
// App.
//
// **Grenzen kommen von der Wanduhr, Abstände sind Dauern.** K 00:00, 04:00,
// 08:00 und K−1 18:00 werden über `BerlinCalendar` gebildet, nie über
// `+ n · 24 h` — am Umstellungstag hat der Tag 23 oder 25 Stunden. Die
// 60 min der Wachkette und die 3 h Mindestschlaf dagegen sind echte
// Zeitspannen auf dem UTC-Zeitpunkt.
//
// **04:00 steht hier nicht.** Es ist [Mahlzeitfenster.tagesbeginnInMinuten],
// die Untergrenze des Frühstücks; eine zweite Konstante dafür gibt es nicht.

/// Die Obergrenze eines verlängerten Tages: 08:00 des Folgetags, in Minuten
/// seit Mitternacht der Berliner Wanduhr (Entscheidung 2).
const int tagesObergrenzeInMinuten = 8 * 60;

/// Der größte Abstand zweier Wachbelege, die noch eine Kette bilden; genau
/// 60 min zählt noch (Entscheidung 3, V3). Eine echte Dauer, keine
/// Wanduhrangabe.
const Duration wachLuecke = Duration(minutes: 60);

/// So viel Schlaf braucht eine gemeldete Nacht mindestens, damit der neue
/// Tag vor 04:00 beginnt (Entscheidung 4). Kürzeres nächtliches Aufwachen
/// bleibt beim Vortag.
const Duration nachtMindestschlaf = Duration(hours: 3);

/// Eine Nacht zählt nur, wenn sie ab 18:00 des Vortags beginnt, in Minuten
/// seit Mitternacht der Berliner Wanduhr (Entscheidung 4, V4).
const int nachtAbInMinuten = 18 * 60;

/// Ab so vielen Schritten in einer Stunde ist die Stunde ein Wachbeleg (V1).
/// Ein Gang zur Toilette bringt weniger und soll keinen Tag verlängern. Die
/// Abbildung auf [Wachbeleg] macht die App; der Beleg ist der **Beginn** der
/// Stunde.
const int wachSchritteJeStunde = 100;

/// Woher ein Wachbeleg stammt (Entscheidung 3). **Kein Puls**: Das Herz
/// schlägt auch im Schlaf.
enum WachQuelle {
  /// Eine eigene Buchung (Essen, Wasser), angelegt, geändert oder gelöscht.
  eintrag,

  /// Das Öffnen der App.
  app,

  /// Mindestens [wachSchritteJeStunde] Schritte in einer Stunde (V1).
  schritte,

  /// Ein Training, als Spanne (V2).
  training,
}

/// Ein Zeitpunkt oder eine Spanne, in der Tim nachweislich wach war
/// (Entscheidung 3).
///
/// Eine Buchung, das Öffnen der App und eine Schrittstunde (V1: deren
/// Beginn) sind Zeitpunkte; ein Training ist eine Spanne von seinem Start
/// bis zu seinem Ende (V2). Bei Zeitpunkten fehlt `bis` und ist dann [von].
class Wachbeleg {
  const Wachbeleg({required this.von, DateTime? bis, required this.quelle})
    : bis = bis ?? von;

  /// Beginn des Belegs.
  final DateTime von;

  /// Ende des Belegs; bei einem Zeitpunkt [von].
  final DateTime bis;

  final WachQuelle quelle;

  /// Zwei Belege sind gleich, wenn Beginn, Ende und Quelle übereinstimmen.
  /// Ein Zeitpunkt ist damit gleich der Spanne, die bei ihm beginnt und
  /// endet.
  @override
  bool operator ==(Object other) =>
      other is Wachbeleg &&
      other.von == von &&
      other.bis == bis &&
      other.quelle == quelle;

  @override
  int get hashCode => Object.hash(von, bis, quelle);

  @override
  String toString() => 'Wachbeleg($quelle, $von – $bis)';
}

/// Eine von Health gemeldete Nacht (V4): die Hauptnacht, ohne Nickerchen.
///
/// Die Abbildung macht die App: [beginn] ist der Beginn des ersten
/// Abschnitts, der nicht „wach“ ist, [ende] das Ende des letzten solchen,
/// [schlaf] die Summe ihrer Dauern.
class GemeldeteNacht {
  const GemeldeteNacht({
    required this.beginn,
    required this.ende,
    required this.schlaf,
  });

  final DateTime beginn;
  final DateTime ende;
  final Duration schlaf;

  @override
  bool operator ==(Object other) =>
      other is GemeldeteNacht &&
      other.beginn == beginn &&
      other.ende == ende &&
      other.schlaf == schlaf;

  @override
  int get hashCode => Object.hash(beginn, ende, schlaf);

  @override
  String toString() => 'GemeldeteNacht($beginn – $ende, Schlaf $schlaf)';
}

/// Warum der laufende Tag der ist, der er ist.
enum Tagesgrund {
  /// Der Kalendertag, ab 04:00 (bzw. ab 08:00 auch mit lebender Kette).
  normal,

  /// Vor 04:00, keine Nacht vorbei: Es gilt noch der Vortag.
  laeuftNoch,

  /// Zwischen 04:00 und 08:00 mit einer Wachkette aus der Nacht: Es gilt
  /// noch der Vortag (Entscheidung 1, V3).
  verlaengert,

  /// Vor 04:00, aber Health hat eine Nacht gemeldet, die schon vorbei ist:
  /// Es gilt der Kalendertag (Entscheidung 4).
  nachtVorbei,
}

/// Der laufende Tag, wie [laufenderTag] ihn bestimmt.
class Tagesstand {
  const Tagesstand({
    required this.tag,
    required this.grund,
    required this.endetSpaetestens,
    this.zuletztWach,
  });

  /// Der ISO-Tag (`2026-10-23`), auf den Tims Einträge jetzt gehören.
  final String tag;

  final Tagesgrund grund;

  /// Wann dieser Stand spätestens nicht mehr gilt, als UTC-Zeitpunkt. Die
  /// App setzt ihn als `staleDate` der Live-Aktivität (Entscheidung 9) und
  /// als Zeitgeber für das nächste Nachsehen (V9).
  final DateTime endetSpaetestens;

  /// Der Beleg mit dem spätesten Ende bis `jetzt`; ein Training, das noch
  /// läuft, endet für diese Frage bei `jetzt`. Ohne Belege `null`.
  ///
  /// Zurückgegeben wird der Beleg, wie er übergeben wurde — ein laufendes
  /// Training also mit seinem ursprünglichen Ende.
  final Wachbeleg? zuletztWach;

  @override
  bool operator ==(Object other) =>
      other is Tagesstand &&
      other.tag == tag &&
      other.grund == grund &&
      other.endetSpaetestens == endetSpaetestens &&
      other.zuletztWach == zuletztWach;

  @override
  int get hashCode => Object.hash(tag, grund, endetSpaetestens, zuletztWach);

  @override
  String toString() =>
      'Tagesstand($tag, $grund, endet spätestens $endetSpaetestens, '
      'zuletzt wach $zuletztWach)';
}

/// Womit ein vergangener Tag geendet hat (V5).
enum Endegrund {
  /// Mit dem Beginn der Nacht, nach Mitternacht.
  eingeschlafen,

  /// Die Nacht begann vor Mitternacht; der Tag endet frühestens dort
  /// (Entscheidung 1).
  mitternacht,

  /// Keine Nacht vor 04:00 und keine Wachkette über 04:00.
  festeGrenze,

  /// Eine Stunde nach dem Ende der Wachkette (Entscheidung 3, V5).
  wachkette,

  /// Die Wachkette lief bis zur Obergrenze 08:00 (Entscheidung 2).
  obergrenze,
}

/// Wie ein vergangener Tag geendet hat (V5), wie [tagesende] es bestimmt.
class Tagesende {
  const Tagesende({
    required this.tag,
    required this.endete,
    required this.grund,
    this.eingeschlafen,
    this.zuletztWach,
  });

  /// Der ISO-Tag D.
  final String tag;

  /// Wann D geendet hat, als UTC-Zeitpunkt.
  final DateTime endete;

  final Endegrund grund;

  /// Beginn der Nacht mit Aufwachtag D+1, falls es sie gibt — auch dann,
  /// wenn sie das Ende nicht bestimmt hat.
  final DateTime? eingeschlafen;

  /// Der jüngste Beleg mit Beginn bis [endete] (V5). „Jüngster“ heißt wie
  /// bei [Tagesstand.zuletztWach]: das späteste Ende, wobei eine Spanne über
  /// [endete] hinaus dort endet. Zurückgegeben wird der Beleg, wie er
  /// übergeben wurde. Ohne solche Belege `null`.
  final Wachbeleg? zuletztWach;

  @override
  bool operator ==(Object other) =>
      other is Tagesende &&
      other.tag == tag &&
      other.endete == endete &&
      other.grund == grund &&
      other.eingeschlafen == eingeschlafen &&
      other.zuletztWach == zuletztWach;

  @override
  int get hashCode =>
      Object.hash(tag, endete, grund, eingeschlafen, zuletztWach);

  @override
  String toString() =>
      'Tagesende($tag, endete $endete, $grund, eingeschlafen $eingeschlafen, '
      'zuletzt wach $zuletztWach)';
}

/// Welcher Tag gerade läuft (Entscheidungen 1–4, V3, V4).
///
/// K ist der Berliner Kalendertag von [jetzt], W seine Wanduhrzeit:
///
/// | W | Bedingung | tag | grund | endetSpaetestens |
/// |---|---|---|---|---|
/// | vor 04:00 | Nacht vorbei | K | `nachtVorbei` | K+1 04:00 |
/// | vor 04:00 | sonst | K−1 | `laeuftNoch` | K 04:00 |
/// | 04:00 bis vor 08:00 | Nacht vorbei | K | `normal` | K+1 04:00 |
/// | 04:00 bis vor 08:00 | Kette verlängert | K−1 | `verlaengert` | früher von Ketten-Ende + 60 min und K 08:00 |
/// | 04:00 bis vor 08:00 | sonst | K | `normal` | K+1 04:00 |
/// | ab 08:00 | — | K | `normal` | K+1 04:00 |
///
/// - **Nacht vorbei** (Entscheidung 4, V4): Unter [naechte] ist eine, die
///   nach K 00:00 und spätestens [jetzt] endet, ab K−1 18:00 beginnt und
///   mindestens [nachtMindestschlaf] Schlaf hat. „Nach Mitternacht“ ist
///   „frühestens Mitternacht“ aus Entscheidung 1: Ein Nickerchen von 18:30
///   bis 21:45 beendet den Abend nicht.
/// - **Kette verlängert** (Entscheidung 3, V2, V3): Nur Belege, die bis
///   [jetzt] beginnen, zählen; eine Spanne, die über [jetzt] hinausreicht,
///   endet bei [jetzt]. Die Kette mit dem jüngsten Beleg beginnt vor K 04:00,
///   und [jetzt] liegt vor ihrem Ende + [wachLuecke].
///
/// **`esstag()` ist der Sonderfall ohne Belege und Nächte** (Entscheidung
/// 11): Für jeden Zeitpunkt t ist `laufenderTag(jetzt: t).tag == esstag(t)`
/// und `endetSpaetestens == naechsterEsstagBeginn(t)`; beide rechnen über
/// diese Funktion.
Tagesstand laufenderTag({
  required DateTime jetzt,
  Iterable<Wachbeleg> belege = const [],
  Iterable<GemeldeteNacht> naechte = const [],
}) {
  final nun = jetzt.toUtc();
  final mitternachtK = BerlinCalendar.startOfDay(nun);
  final mitternachtVortag = BerlinCalendar.addDays(nun, -1);
  final mitternachtFolgetag = BerlinCalendar.addDays(nun, 1);

  final tagesbeginnK = _wanduhrAm(
    mitternachtK,
    Mahlzeitfenster.tagesbeginnInMinuten,
  );
  final obergrenzeK = _wanduhrAm(mitternachtK, tagesObergrenzeInMinuten);
  final naechsterTagesbeginn = _wanduhrAm(
    mitternachtFolgetag,
    Mahlzeitfenster.tagesbeginnInMinuten,
  );
  final nachtFruehestens = _wanduhrAm(mitternachtVortag, nachtAbInMinuten);

  final bisJetzt = _bisZeitpunkt(belege, nun);
  final zuletztWach = _zuletztWach(bisJetzt);

  final nachtVorbei = naechte.any((n) {
    final beginn = n.beginn.toUtc();
    final ende = n.ende.toUtc();
    return ende.isAfter(mitternachtK) &&
        !ende.isAfter(nun) &&
        !beginn.isBefore(nachtFruehestens) &&
        n.schlaf >= nachtMindestschlaf;
  });

  final kalendertag = BerlinCalendar.dayKey(nun);
  final vortag = BerlinCalendar.dayKey(mitternachtVortag);

  Tagesstand neuerTag(Tagesgrund grund) => Tagesstand(
    tag: kalendertag,
    grund: grund,
    endetSpaetestens: naechsterTagesbeginn,
    zuletztWach: zuletztWach,
  );

  // Vor 04:00 entscheidet allein die Nacht; eine Kette verschiebt hier nichts.
  if (nun.isBefore(tagesbeginnK)) {
    if (nachtVorbei) return neuerTag(Tagesgrund.nachtVorbei);
    return Tagesstand(
      tag: vortag,
      grund: Tagesgrund.laeuftNoch,
      endetSpaetestens: tagesbeginnK,
      zuletztWach: zuletztWach,
    );
  }

  // Ab 08:00 gilt der Kalendertag, wie lange die Kette auch lebt
  // (Entscheidung 2). Eine Nacht, die vorbei ist, schlägt die Kette
  // (Spec-Tabelle).
  if (!nun.isBefore(obergrenzeK) || nachtVorbei) {
    return neuerTag(Tagesgrund.normal);
  }

  final kette = _juengsteKette(bisJetzt.map((b) => b.gekappt));
  if (kette != null && kette.beginn.isBefore(tagesbeginnK)) {
    final kettenfrist = kette.ende.add(wachLuecke);
    if (nun.isBefore(kettenfrist)) {
      return Tagesstand(
        tag: vortag,
        grund: Tagesgrund.verlaengert,
        endetSpaetestens: kettenfrist.isBefore(obergrenzeK)
            ? kettenfrist
            : obergrenzeK,
        zuletztWach: zuletztWach,
      );
    }
  }

  return neuerTag(Tagesgrund.normal);
}

/// Wie der vergangene Tag [tag] (ein ISO-Tag D) geendet hat (V5).
///
/// [nacht] ist die Nacht mit Aufwachtag D+1, falls Health eine gemeldet hat.
/// Mit M = D+1 00:00, G = D+1 04:00, O = D+1 08:00 (alle von der Wanduhr):
///
/// 1. [nacht] beginnt vor G → `endete` = später von `nacht.beginn` und M;
///    `grund` = [Endegrund.mitternacht], wenn `nacht.beginn` ≤ M, sonst
///    [Endegrund.eingeschlafen] (Entscheidung 1: „frühestens Mitternacht“
///    schützt davor, dass ein Dösen auf dem Sofa den Abend abschneidet).
/// 2. Sonst: Gibt es eine Kette, die vor G beginnt und deren Ende
///    + [wachLuecke] nach G liegt (Entscheidung 3, V2, V3) → `endete` =
///    frühester von Ende + 60 min ([Endegrund.wachkette]), `nacht?.beginn`
///    ([Endegrund.eingeschlafen]) und O ([Endegrund.obergrenze],
///    Entscheidung 2). Bei Gleichstand gewinnt `eingeschlafen`, dann
///    `wachkette`.
/// 3. Sonst `endete` = G, [Endegrund.festeGrenze].
///
/// Die 3-Stunden-Regel gilt hier nicht: Welche Nacht die Hauptnacht ist, hat
/// `SleepGrouping` schon entschieden (V5).
///
/// Wirft einen [ArgumentError], wenn [tag] kein ISO-Tag ist.
Tagesende tagesende({
  required String tag,
  Iterable<Wachbeleg> belege = const [],
  GemeldeteNacht? nacht,
}) {
  final mittag = DateTime.tryParse('${tag}T12:00:00Z');
  if (mittag == null || BerlinCalendar.dayKey(mittag) != tag) {
    throw ArgumentError.value(tag, 'tag', 'kein ISO-Tag');
  }
  // 12:00 UTC liegt in Berlin immer auf demselben Kalendertag.
  final mitternacht = BerlinCalendar.addDays(mittag, 1);
  final grenze = _wanduhrAm(mitternacht, Mahlzeitfenster.tagesbeginnInMinuten);
  final obergrenze = _wanduhrAm(mitternacht, tagesObergrenzeInMinuten);
  final eingeschlafen = nacht?.beginn.toUtc();

  Tagesende ende(DateTime endete, Endegrund grund) => Tagesende(
    tag: tag,
    endete: endete,
    grund: grund,
    eingeschlafen: eingeschlafen,
    zuletztWach: _zuletztWach(_bisZeitpunkt(belege, endete)),
  );

  // 1. Die Nacht beginnt vor G.
  if (eingeschlafen != null && eingeschlafen.isBefore(grenze)) {
    return eingeschlafen.isAfter(mitternacht)
        ? ende(eingeschlafen, Endegrund.eingeschlafen)
        : ende(mitternacht, Endegrund.mitternacht);
  }

  // 2. Eine Kette lebt um 04:00 noch. Höchstens eine kann das: Die nächste
  // Kette beginnt erst mehr als 60 min nach dem Ende der vorigen.
  final spannen = belege.map((b) => (von: b.von.toUtc(), ende: b.bis.toUtc()));
  final kette = _ketten(spannen).where(
    (k) => k.beginn.isBefore(grenze) && k.ende.add(wachLuecke).isAfter(grenze),
  );
  if (kette.isNotEmpty) {
    final kettenfrist = kette.first.ende.add(wachLuecke);
    // Reihenfolge = Vorrang bei Gleichstand.
    final kandidaten = [
      if (eingeschlafen != null) (eingeschlafen, Endegrund.eingeschlafen),
      (kettenfrist, Endegrund.wachkette),
      (obergrenze, Endegrund.obergrenze),
    ];
    var frueheste = kandidaten.first;
    for (final k in kandidaten.skip(1)) {
      if (k.$1.isBefore(frueheste.$1)) frueheste = k;
    }
    return ende(frueheste.$1, frueheste.$2);
  }

  // 3. Die feste Grenze.
  return ende(grenze, Endegrund.festeGrenze);
}

// --- Teil 2: Uhrzeit und Mahlzeit im Tag ---------------------------------
//
// Spec „Uhrzeit und Mahlzeit im Tag“, V14, Entscheidung 6. Wer auf einem Tag
// eine Uhrzeit wählt (Buchungsblatt, Foto-Schätzung, Wasser auf einem
// geblätterten Tag), bekommt hier den Zeitpunkt und die Mahlzeit.

/// Eine Berliner Wanduhrzeit [minuten] (seit Mitternacht) am Kalendertag
/// [tag] (ISO-Tag, `2026-10-23`), als UTC-Zeitpunkt.
///
/// Zog als `_alsZeitpunkt` aus `app/lib/ernaehrung/erfassen_formular.dart`
/// in den Kern (#453).
///
/// **Warum nicht `startOfDay(…) + Minuten`:** Der 29.03.2026 hat 23
/// Stunden. Wer Minuten auf den Tagesbeginn addiert, landet an einem
/// Umstellungstag eine Stunde daneben, und zwar lautlos.
///
/// Der Versatz wird nicht gerechnet, sondern **geprüft**: Beide möglichen
/// Versätze werden durchgespielt, und es gilt der, dessen Wanduhrzeit
/// wieder die gesuchte ergibt. Damit kennt diese Funktion die
/// Sommerzeitregel nicht — `BerlinCalendar._versatz` bleibt die einzige
/// Stelle, die sie kennt.
///
/// Zwei Grenzfälle, beide an den zwei Umstellungstagen des Jahres:
/// In der **übersprungenen Stunde** (letzter Sonntag im März, 02:00–02:59)
/// gibt es den Zeitpunkt nicht — dann gilt der Sommerversatz (UTC+2), die
/// Uhrzeit rutscht um eine Stunde nach vorn: 02:30 wird 00:30 UTC, was die
/// Wanduhr als 01:30 liest. In der **doppelten Stunde** (letzter Sonntag im
/// Oktober, 02:00–02:59) gibt es ihn zweimal — dann gilt der erste, also
/// ebenfalls der Sommerversatz. Beides liegt mitten in der Nacht und unter
/// jeder Mahlzeitmitte.
///
/// Geprüft wird [tag] nicht; ein Tag, der sich nicht als `JJJJ-MM-TT` lesen
/// lässt, wirft beim Zerlegen.
DateTime wanduhrZeitpunkt(String tag, int minuten) {
  final (jahr, monat, tagImMonat) = _isoTeile(tag);
  final alsWaereEsUtc = DateTime.utc(
    jahr,
    monat,
    tagImMonat,
  ).add(Duration(minutes: minuten));

  for (final versatz in const [2, 1]) {
    final kandidat = alsWaereEsUtc.subtract(Duration(hours: versatz));
    if (_wanduhrInMinuten(kandidat) == minuten &&
        BerlinCalendar.dayKey(kandidat) == tag) {
      return kandidat;
    }
  }
  // Die übersprungene Stunde: Der Zeitpunkt existiert nicht. Der
  // Sommerversatz ist die Seite, auf der der Tag weitergeht.
  return alsWaereEsUtc.subtract(const Duration(hours: 2));
}

/// Welcher Zeitpunkt die Wanduhrzeit [minuten] auf dem Tag [tag] ist (V14),
/// als UTC.
///
/// Ein Tag reicht über Mitternacht hinaus; welche Uhrzeiten noch ihm
/// gehören und deshalb auf dem **Folgetag** des Kalenders liegen, hängt am
/// [grund]:
///
/// | grund | Folgetag | sonst |
/// |---|---|---|
/// | `normal`, `laeuftNoch` | vor 04:00 | der Tag selbst |
/// | `verlaengert` | vor 08:00 | der Tag selbst |
/// | `nachtVorbei` | nie | der Tag selbst |
///
/// Die Grenze selbst gehört dem Tag (04:00 bzw. 08:00). Den Grund übergibt
/// nur, wer auf den **laufenden** Tag bucht; jeder andere Tag rechnet
/// `normal`.
DateTime zeitpunktImTag({
  required String tag,
  required int minuten,
  Tagesgrund grund = Tagesgrund.normal,
}) {
  final folgetagVor = switch (grund) {
    Tagesgrund.normal ||
    Tagesgrund.laeuftNoch => Mahlzeitfenster.tagesbeginnInMinuten,
    Tagesgrund.verlaengert => tagesObergrenzeInMinuten,
    Tagesgrund.nachtVorbei => 0,
  };
  final kalendertag = minuten < folgetagVor ? _folgetag(tag) : tag;
  return wanduhrZeitpunkt(kalendertag, minuten);
}

/// Zu welcher Mahlzeit die Wanduhrzeit [minuten] auf einem Tag mit [grund]
/// gehört (Entscheidung 6).
///
/// - `verlaengert` und vor 08:00 → Abend: Der Tag läuft noch, also ist es
///   der späte Abend, nicht das Frühstück.
/// - `nachtVorbei` und vor 04:00 → Frühstück: Die Nacht ist vorbei, der
///   neue Tag hat begonnen.
/// - sonst [Mahlzeitfenster.fuer].
///
/// Die Mahlzeit bleibt im Blatt änderbar; dies ist nur die Vorwahl.
Mahlzeit mahlzeitImTag({
  required int minuten,
  Tagesgrund grund = Tagesgrund.normal,
}) {
  return switch (grund) {
    Tagesgrund.verlaengert when minuten < tagesObergrenzeInMinuten =>
      Mahlzeit.abend,
    Tagesgrund.nachtVorbei
        when minuten < Mahlzeitfenster.tagesbeginnInMinuten =>
      Mahlzeit.fruehstueck,
    _ => Mahlzeitfenster.fuer(minuten),
  };
}

/// Der ISO-Tag nach [tag], über den Kalender — nicht über `+ 24 h`.
String _folgetag(String tag) {
  final (jahr, monat, tagImMonat) = _isoTeile(tag);
  // `DateTime.utc` rollt Monats- und Jahresenden selbst; 12:00 UTC liegt in
  // Berlin immer auf demselben Kalendertag.
  return BerlinCalendar.dayKey(DateTime.utc(jahr, monat, tagImMonat + 1, 12));
}

(int, int, int) _isoTeile(String tag) {
  final teile = tag.split('-').map(int.parse).toList();
  return (teile[0], teile[1], teile[2]);
}

/// Die Berliner Wanduhrzeit [minuten] (seit Mitternacht) am Kalendertag,
/// dessen Mitternacht [mitternacht] ist (ein UTC-Zeitpunkt aus
/// `BerlinCalendar`).
///
/// Mitternacht plus Minuten stimmt nur, wenn dazwischen keine Umstellung
/// liegt. An deren Tagen (02:00 bzw. 03:00 Wanduhr) landet der erste Schritt
/// eine Stunde daneben; die Wanduhr dort sagt, wie weit. Eine Korrektur
/// genügt für die Uhrzeiten, die hier gebraucht werden (00:00, 04:00, 08:00,
/// 18:00): Keine liegt in der übersprungenen oder doppelten Stunde, und
/// keine kurz genug vor Mitternacht, dass der erste Schritt in den Folgetag
/// fiele.
DateTime _wanduhrAm(DateTime mitternacht, int minuten) {
  final ungefaehr = mitternacht.toUtc().add(Duration(minutes: minuten));
  return ungefaehr.add(
    Duration(minutes: minuten - _wanduhrInMinuten(ungefaehr)),
  );
}

int _wanduhrInMinuten(DateTime zeitpunkt) {
  final (stunde, minute) = BerlinCalendar.wallClock(zeitpunkt);
  return stunde * 60 + minute;
}

/// Ein Beleg samt seinem Ende, gekappt an einer Schranke (`jetzt` bzw.
/// `endete`). Die Kappung gilt nur fürs Rechnen; nach außen geht [beleg].
class _Gekappt {
  const _Gekappt(this.beleg, this.ende);

  final Wachbeleg beleg;
  final DateTime ende;

  DateTime get von => beleg.von.toUtc();

  /// Der gekappte Beleg als Spanne in UTC.
  ({DateTime von, DateTime ende}) get gekappt => (von: von, ende: ende);
}

/// Die Belege, die bis [schranke] beginnen, jeder mit einem Ende von
/// höchstens [schranke]. Ein Training, das noch läuft, endet hier bei
/// `jetzt`.
List<_Gekappt> _bisZeitpunkt(Iterable<Wachbeleg> belege, DateTime schranke) {
  return [
    for (final b in belege)
      if (!b.von.toUtc().isAfter(schranke))
        _Gekappt(b, b.bis.toUtc().isAfter(schranke) ? schranke : b.bis.toUtc()),
  ];
}

/// Der Beleg mit dem spätesten (gekappten) Ende; bei Gleichstand der mit dem
/// späteren Beginn. Ohne Belege `null`.
Wachbeleg? _zuletztWach(List<_Gekappt> belege) {
  _Gekappt? bester;
  for (final b in belege) {
    if (bester == null ||
        b.ende.isAfter(bester.ende) ||
        (b.ende == bester.ende && b.von.isAfter(bester.von))) {
      bester = b;
    }
  }
  return bester?.beleg;
}

typedef _Kette = ({DateTime beginn, DateTime ende});

/// Die Ketten aus [spannen], nach Beginn sortiert (V3): Zwei Belege gehören
/// zusammen, wenn der nächste höchstens [wachLuecke] nach dem **bisher
/// spätesten Ende** beginnt — genau 60 min zählt. Gemessen wird vom Ende
/// einer Spanne, nicht von ihrem Beginn (V2).
List<_Kette> _ketten(Iterable<({DateTime von, DateTime ende})> spannen) {
  final sortiert = spannen.toList()..sort((a, b) => a.von.compareTo(b.von));
  final ketten = <_Kette>[];
  DateTime? beginn;
  DateTime? ende;
  for (final s in sortiert) {
    if (beginn == null || ende == null) {
      beginn = s.von;
      ende = s.ende;
    } else if (s.von.difference(ende) <= wachLuecke) {
      if (s.ende.isAfter(ende)) ende = s.ende;
    } else {
      ketten.add((beginn: beginn, ende: ende));
      beginn = s.von;
      ende = s.ende;
    }
  }
  if (beginn != null && ende != null) ketten.add((beginn: beginn, ende: ende));
  return ketten;
}

/// Die Kette mit dem jüngsten Beleg (V3), also die letzte. Sie hat zugleich
/// das späteste Ende: Reichte eine frühere weiter, gehörte die letzte zu ihr.
_Kette? _juengsteKette(Iterable<({DateTime von, DateTime ende})> spannen) {
  final ketten = _ketten(spannen);
  return ketten.isEmpty ? null : ketten.last;
}
