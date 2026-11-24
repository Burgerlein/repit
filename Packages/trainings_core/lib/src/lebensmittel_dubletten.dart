import 'dart:math' show max;

/// Welche Online-Treffer der Lebensmittelsuche neben den eigenen
/// Lebensmitteln stehen, und in welcher Reihenfolge (#284, #327).
///
/// Tim auf dem Gerät, 04.11.2026: „man findet direkt 8000 mal das gleiche,
/// wenn ich nach Nutella suche." Die Regeln und ihre Begründung stehen im
/// Kopf von `test/lebensmittel_dubletten_test.dart` (#284) und
/// `test/lebensmittel_varianten_test.dart` (#327); die Tests geben die API
/// vor.
///
/// **Vier Schritte, in dieser Reihenfolge:** verwerfen (ohne Kalorien,
/// über 900 kcal je 100 g) → zusammenfassen → umsortieren (jedes Suchwort
/// trifft einen Wortanfang → nach vorn) → begrenzen. Jeder Übergang hat
/// einen Testfall, der nur in dieser Reihenfolge aufgeht.
///
/// **Zusammengefasst wird nach zwei Regeln**, verglichen wird immer mit dem
/// Vertreter einer Gruppe, der erste passende Vertreter gewinnt:
///
/// 1. **Namensregel:** gleicher [vergleichsName] — der Name ohne Größen-,
///    Packungswörter und Mengenangaben — und Kalorien innerhalb von 3 %.
///    Gilt auch zwischen eigenen Lebensmitteln und Online-Treffern.
/// 2. **Gleiche Marke, gleiche Nährwerte** (nur in [zeilen], nur zwischen
///    Online-Treffern): Die Marke liegt in der Markenmenge der Gruppe, und
///    Kalorien, Eiweiß, Kohlenhydrate und Fett liegen alle vier nah am
///    Vertreter — gleich, wie der Treffer heißt.
///
/// Die Regeln sehen nur Records, nicht die Typen der App, und geben
/// **Indizes** zurück — Online-Produkte und eigene Lebensmittel sind in der
/// App zwei verschiedene Typen.
abstract final class LebensmittelDubletten {
  /// Der Name, so wie die Regeln ihn vergleichen: Kleinbuchstaben, jede
  /// Folge von Zeichen, die weder Buchstabe noch Ziffer sind, wird **ein**
  /// Leerzeichen, Ränder weg.
  static String normalerName(String name) =>
      name.toLowerCase().replaceAll(_trenner, ' ').trim();

  /// Der Name, den die Namensregel vergleicht: [normalerName] ohne die
  /// Wörter aus [_groessenWoerter] und ohne Mengenangaben.
  ///
  /// Gestrichen werden nur ganze Wörter — „Glasur" bleibt. Mengenangaben
  /// sind „450g" (Zahl mit Einheit `g, gr, kg, ml, cl, l` in einem Wort),
  /// „450 g" (Zahl, dann Einheit), „x6" und „6x", „6 x" und „x 6". **Eine
  /// Zahl ohne Einheit bleibt**: „Milch 3,5 %" ist nicht „Milch 1,5 %".
  ///
  /// Bleibt nichts übrig, ist es der [normalerName] — sonst wären „Mini"
  /// und „Maxi" derselbe leere Name.
  static String vergleichsName(String name) {
    final normal = normalerName(name);
    if (normal.isEmpty) return normal;
    final woerter = normal.split(' ');
    final bleibt = <String>[];
    var i = 0;
    while (i < woerter.length) {
      final wort = woerter[i];
      final naechstes = i + 1 < woerter.length ? woerter[i + 1] : null;

      // Paare zuerst: „450 g", „6 x", „x 6".
      if (naechstes != null &&
          ((_zahl.hasMatch(wort) &&
                  (_einheit.hasMatch(naechstes) || naechstes == 'x')) ||
              (wort == 'x' && _zahl.hasMatch(naechstes)))) {
        i += 2;
        continue;
      }
      if (!_groessenWoerter.contains(wort) &&
          !_mengeInEinemWort.hasMatch(wort)) {
        bleibt.add(wort);
      }
      i++;
    }
    return bleibt.isEmpty ? normal : bleibt.join(' ');
  }

  /// Dasselbe Lebensmittel nach der Namensregel: gleicher
  /// [vergleichsName] **und** beide Kalorien vorhanden **und**
  /// `|a − b| ≤ 0,03 · max(a, b)`.
  ///
  /// Ohne Kalorien auf einer Seite nie gleich — die 3-%-Regel braucht zwei
  /// Zahlen.
  static bool gleich(
    ({String name, double? kcal}) a,
    ({String name, double? kcal}) b,
  ) => _gleich(vergleichsName(a.name), a.kcal, vergleichsName(b.name), b.kcal);

  /// Ob **jedes** Wort aus [suchtext] einen Wortanfang in [name] oder
  /// [marke] trifft. Alle drei werden wie in [normalerName] normalisiert
  /// und an den Leerzeichen in Wörter zerlegt; ein Suchwort trifft, wenn
  /// ein Wort aus Name oder Marke mit ihm beginnt.
  ///
  /// Ohne Suchwort trifft alles — es gibt nichts, was verfehlen könnte.
  static bool trifftWortanfaenge(
    String suchtext, {
    required String name,
    String? marke,
  }) => _trifft(_woerter(suchtext), name: name, marke: marke);

  /// [zeilen] ohne Makros — die Namensregel gilt, Regel 2 greift nie.
  static List<int> onlineVertreter({
    required String suchtext,
    required List<({String name, double? kcal})> eigene,
    required List<({String name, String? marke, double? kcal})> online,
    int hoechstens = 25,
  }) => zeilen(
    suchtext: suchtext,
    eigene: eigene,
    online: [
      for (final t in online)
        (
          name: t.name,
          marke: t.marke,
          kcal: t.kcal,
          eiweissG: null,
          kohlenhydrateG: null,
          fettG: null,
        ),
    ],
    hoechstens: hoechstens,
  );

  /// Die Online-Treffer, die in der Liste stehen — ihre Indizes in
  /// [online], **in der Reihenfolge, in der sie angezeigt werden**,
  /// höchstens [hoechstens] viele.
  ///
  /// [eigene] werden weder gefiltert noch zusammengefasst und tauchen im
  /// Ergebnis nicht auf; sie **vertreten** aber jeden Online-Treffer, der
  /// ihnen [gleich] ist. Sie zählen nicht zu [hoechstens]. Regel 2 gilt für
  /// sie nicht — ihr Record trägt weder Marke noch Makros.
  static List<int> zeilen({
    required String suchtext,
    required List<({String name, double? kcal})> eigene,
    required List<
      ({
        String name,
        String? marke,
        double? kcal,
        double? eiweissG,
        double? kohlenhydrateG,
        double? fettG,
      })
    >
    online,
    int hoechstens = 25,
  }) {
    // Eigene vertreten nur über die Namensregel. Sie sind Vertreter, bevor
    // der erste Online-Treffer gelesen ist, und gehören selbst nie ins
    // Ergebnis.
    final eigeneVertreter = <({String name, double kcal})>[
      for (final e in eigene)
        if (e.kcal case final kcal?) (name: vergleichsName(e.name), kcal: kcal),
    ];
    final gruppen = <_Gruppe>[];

    for (var i = 0; i < online.length; i++) {
      final treffer = online[i];
      final kcal = treffer.kcal;

      // 1. Verwerfen — vor dem Zusammenfassen, damit kein Datenfehler eine
      //    Gruppe anführt.
      if (kcal == null || kcal > _hoechstKcal) continue;

      // 2. Zusammenfassen — verglichen wird mit dem Vertreter, nicht mit
      //    irgendeinem Mitglied. Der erste in Reihenfolge der Antwort führt.
      final name = vergleichsName(treffer.name);
      if (eigeneVertreter.any((v) => _gleich(v.name, v.kcal, name, kcal))) {
        continue;
      }

      final marke = _marke(treffer.marke);
      final makros = _makrosAus(
        treffer.eiweissG,
        treffer.kohlenhydrateG,
        treffer.fettG,
      );
      _Gruppe? gruppe;
      for (final g in gruppen) {
        if (_gleich(g.name, g.kcal, name, kcal) ||
            (marke != null &&
                g.marken.contains(marke) &&
                _naehrwerteNah(g, kcal, makros))) {
          gruppe = g;
          break;
        }
      }

      if (gruppe != null) {
        // Wer zur Gruppe stößt, bringt seine Marke mit — auch per Name.
        if (marke != null) gruppe.marken.add(marke);
        continue;
      }
      gruppen.add(
        _Gruppe(
          index: i,
          name: name,
          kcal: kcal,
          makros: makros,
          marken: {?marke},
        ),
      );
    }

    // 3. Umsortieren — nach dem Vertreter, den Tim sieht. Stabil: Innerhalb
    //    beider Gruppen bleibt die Reihenfolge der Antwort.
    final suchwoerter = _woerter(suchtext);
    final vorn = <int>[];
    final hinten = <int>[];
    for (final g in gruppen) {
      final t = online[g.index];
      (_trifft(suchwoerter, name: t.name, marke: t.marke) ? vorn : hinten).add(
        g.index,
      );
    }

    // 4. Begrenzen — zuletzt, damit Zeilen gezählt werden und nicht
    //    Treffer.
    return [...vorn, ...hinten].take(max(hoechstens, 0)).toList();
  }

  static bool _gleich(String nameA, double? a, String nameB, double? b) {
    if (a == null || b == null) return false;
    if (nameA != nameB) return false;
    return (a - b).abs() <= _toleranz * max(a, b);
  }

  /// Regel 2, Teil (b): Kalorien innerhalb von 5 %, jedes Makro innerhalb
  /// von 5 % oder 0,5 g — je vom Vertreter aus. Fehlt eins der Makros auf
  /// einer Seite, nie nah.
  static bool _naehrwerteNah(_Gruppe vertreter, double kcal, _Makros? b) {
    final a = vertreter.makros;
    if (a == null || b == null) return false;
    if ((vertreter.kcal - kcal).abs() > _kcalNah * max(vertreter.kcal, kcal)) {
      return false;
    }
    bool nah(double x, double y) =>
        (x - y).abs() <= max(_makroNah * max(x, y), _makroNahG);
    return nah(a.eiweiss, b.eiweiss) &&
        nah(a.kohlenhydrate, b.kohlenhydrate) &&
        nah(a.fett, b.fett);
  }

  static _Makros? _makrosAus(double? e, double? kh, double? f) =>
      e == null || kh == null || f == null
      ? null
      : (eiweiss: e, kohlenhydrate: kh, fett: f);

  /// Die Marke über [normalerName] — `null`, wenn nichts übrig bleibt.
  /// Zwei leere Marken sind keine gleiche Marke.
  static String? _marke(String? marke) {
    if (marke == null) return null;
    final normal = normalerName(marke);
    return normal.isEmpty ? null : normal;
  }

  static bool _trifft(
    List<String> suchwoerter, {
    required String name,
    String? marke,
  }) {
    if (suchwoerter.isEmpty) return true;
    final woerter = [..._woerter(name), if (marke != null) ..._woerter(marke)];
    return suchwoerter.every(
      (such) => woerter.any((wort) => wort.startsWith(such)),
    );
  }

  static List<String> _woerter(String text) {
    final normal = normalerName(text);
    return normal.isEmpty ? const [] : normal.split(' ');
  }
}

typedef _Makros = ({double eiweiss, double kohlenhydrate, double fett});

/// Eine Zeile der Liste während des Zusammenfassens: der Vertreter (Index,
/// Vergleichsname, Kalorien, Makros) und die Marken aller bisherigen
/// Mitglieder — einschließlich des Vertreters.
final class _Gruppe {
  _Gruppe({
    required this.index,
    required this.name,
    required this.kcal,
    required this.makros,
    required this.marken,
  });

  final int index;
  final String name;
  final double kcal;
  final _Makros? makros;
  final Set<String> marken;
}

/// Jede Folge von Zeichen, die weder Buchstabe noch Ziffer ist. `\p{L}`
/// schließt Umlaute und ß ein, `\p{N}` die Ziffern.
final _trenner = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Größen- und Packungswörter, nach [LebensmittelDubletten.normalerName].
/// Sie beschreiben die Packung, nicht das Lebensmittel.
const _groessenWoerter = {
  'mini',
  'klein',
  'kleine',
  'kleines',
  'maxi',
  'gross',
  'groß',
  'große',
  'großes',
  'xl',
  'xxl',
  'familienpackung',
  'vorteilspackung',
  'glas',
  'becher',
  'dose',
  'packung',
  'pack',
  'portion',
  'portionen',
  'coppette',
};

/// Eine Zahl — nach der Normalisierung nur Ziffern, ein Komma ist schon
/// ein Leerzeichen.
final _zahl = RegExp(r'^\d+$');

/// Die Einheiten einer Mengenangabe.
final _einheit = RegExp(r'^(g|gr|kg|ml|cl|l)$');

/// „450g", „x6", „6x" — Menge oder Stückzahl in einem Wort.
final _mengeInEinemWort = RegExp(r'^(\d+(g|gr|kg|ml|cl|l)|x\d+|\d+x)$');

/// Reines Fett hat rund 900 kcal je 100 g — darüber ist es ein Datenfehler
/// in Open Food Facts. 900 genau bleibt.
const _hoechstKcal = 900.0;

/// Namensregel: 3 % vom größeren der beiden Werte.
const _toleranz = 0.03;

/// Regel 2, Kalorien: 5 % vom größeren der beiden Werte.
const _kcalNah = 0.05;

/// Regel 2, Makros: 5 % vom größeren der beiden Werte …
const _makroNah = 0.05;

/// … aber mindestens 0,5 g — 0,1 und 0,2 g Fett sind dasselbe.
const _makroNahG = 0.5;
