/// Die Nährwerte einer Portion, einer Mahlzeit oder eines ganzen Tages.
///
/// Acht benannte Felder und ein offener Rest ([extra]) für alles, was die
/// Spec unter „Vitamine und Mineralstoffe" führt (`docs/SPEC.md` 4.8). Die
/// benannten acht stehen hier, weil sie in der Datenbank eigene Spalten
/// haben und in jeder Summe vorkommen; die übrigen 21 wechseln je Quelle
/// und wären 21 fast immer leere Felder.
///
/// **Ein fehlender Wert ist `null`, nie `0`** (`CLAUDE.md`, Fehler `01`).
/// Ein Lebensmittel ohne Ballaststoffangabe hat keine 0 g Ballaststoffe —
/// es hat keine Angabe. Daran hängt die Rechenregel von [operator +]:
/// `null + null` bleibt `null`, `null + 6` ist `6`, und `0 + null` ist `0`,
/// weil eine gemessene Null eine Messung ist.
///
/// Werttyp mit [==] und [hashCode], **einschließlich [extra]**: Eine
/// Tagessumme ist Abhängigkeit eines Providers, und ohne Wertgleichheit
/// wäre jede neu gerechnete Summe ungleich der vorigen und jeder
/// abgeleitete Wert liefe neu (`CLAUDE.md`, Fehler `03`).
///
/// **Grenze:** Die übergebene [extra]-Map wird nicht kopiert. Wer eine
/// veränderliche Map hineingibt und sie später ändert, ändert damit auch
/// Gleichheit und [hashCode] dieses Werts. Erzwingen lässt sich das hier
/// nicht; die aus [operator +] und [fuerMenge] entstehenden Maps sind
/// frisch gebaut und werden von niemandem sonst gehalten.
class Naehrwerte {
  /// Absolute Werte — das, was tatsächlich auf dem Teller lag.
  const Naehrwerte({
    this.kcal,
    this.eiweissG,
    this.kohlenhydrateG,
    this.fettG,
    this.zuckerG,
    this.ballaststoffeG,
    this.gesaettigtG,
    this.wasserMl,
    this.extra = const {},
  });

  /// Dieselben Felder, aber als Angabe **je 100 Gramm** zu lesen — der Weg
  /// aus Open Food Facts und aus einer Nährwerttabelle.
  ///
  /// Der Unterschied steht im Namen und sonst nirgends: Der Typ trägt kein
  /// Merkmal, das ihn vom allgemeinen Fall unterscheidet, und [fuerMenge]
  /// rechnet auf jeder Instanz. Wer eine absolute Angabe durch [fuerMenge]
  /// schickt, bekommt deshalb Unsinn — das fängt hier niemand ab.
  const Naehrwerte.je100g({
    double? kcal,
    double? eiweissG,
    double? kohlenhydrateG,
    double? fettG,
    double? zuckerG,
    double? ballaststoffeG,
    double? gesaettigtG,
    double? wasserMl,
    Map<String, double?> extra = const {},
  }) : this(
         kcal: kcal,
         eiweissG: eiweissG,
         kohlenhydrateG: kohlenhydrateG,
         fettG: fettG,
         zuckerG: zuckerG,
         ballaststoffeG: ballaststoffeG,
         gesaettigtG: gesaettigtG,
         wasserMl: wasserMl,
         extra: extra,
       );

  final double? kcal;
  final double? eiweissG;
  final double? kohlenhydrateG;
  final double? fettG;
  final double? zuckerG;
  final double? ballaststoffeG;
  final double? gesaettigtG;
  final double? wasserMl;

  /// Die übrigen Werte, nach Schlüssel. Ein Schlüssel mit `null` heißt
  /// „dieser Wert ist bekannt als unbekannt" und verhält sich in jeder
  /// Rechnung wie ein fehlendes benanntes Feld.
  final Map<String, double?> extra;

  /// Skaliert eine Je-100-g-Angabe auf [gramm].
  ///
  /// Was nicht angegeben war, bleibt nach der Rechnung fehlend. `0` Gramm
  /// ergeben dagegen `0` — eine gewogene Null, kein fehlender Wert.
  Naehrwerte fuerMenge(double gramm) {
    final faktor = gramm / 100;
    return Naehrwerte(
      kcal: _skaliert(kcal, faktor),
      eiweissG: _skaliert(eiweissG, faktor),
      kohlenhydrateG: _skaliert(kohlenhydrateG, faktor),
      fettG: _skaliert(fettG, faktor),
      zuckerG: _skaliert(zuckerG, faktor),
      ballaststoffeG: _skaliert(ballaststoffeG, faktor),
      gesaettigtG: _skaliert(gesaettigtG, faktor),
      wasserMl: _skaliert(wasserMl, faktor),
      extra: {
        for (final eintrag in extra.entries)
          eintrag.key: _skaliert(eintrag.value, faktor),
      },
    );
  }

  /// Feldweise Summe nach der Regel oben. Die Schlüssel von [extra] werden
  /// vereinigt, nicht geschnitten: Was nur eine Seite kennt, steht danach
  /// mit ihrem Wert da.
  Naehrwerte operator +(Naehrwerte andere) => Naehrwerte(
    kcal: _summe(kcal, andere.kcal),
    eiweissG: _summe(eiweissG, andere.eiweissG),
    kohlenhydrateG: _summe(kohlenhydrateG, andere.kohlenhydrateG),
    fettG: _summe(fettG, andere.fettG),
    zuckerG: _summe(zuckerG, andere.zuckerG),
    ballaststoffeG: _summe(ballaststoffeG, andere.ballaststoffeG),
    gesaettigtG: _summe(gesaettigtG, andere.gesaettigtG),
    wasserMl: _summe(wasserMl, andere.wasserMl),
    extra: {
      for (final schluessel in <String>{...extra.keys, ...andere.extra.keys})
        schluessel: _summe(extra[schluessel], andere.extra[schluessel]),
    },
  );

  @override
  bool operator ==(Object other) =>
      other is Naehrwerte &&
      other.kcal == kcal &&
      other.eiweissG == eiweissG &&
      other.kohlenhydrateG == kohlenhydrateG &&
      other.fettG == fettG &&
      other.zuckerG == zuckerG &&
      other.ballaststoffeG == ballaststoffeG &&
      other.gesaettigtG == gesaettigtG &&
      other.wasserMl == wasserMl &&
      _gleicherInhalt(extra, other.extra);

  @override
  int get hashCode => Object.hash(
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    ballaststoffeG,
    gesaettigtG,
    wasserMl,
    _inhaltsHash(extra),
  );

  @override
  String toString() =>
      'Naehrwerte(kcal: $kcal, eiweissG: $eiweissG, '
      'kohlenhydrateG: $kohlenhydrateG, fettG: $fettG, zuckerG: $zuckerG, '
      'ballaststoffeG: $ballaststoffeG, gesaettigtG: $gesaettigtG, '
      'wasserMl: $wasserMl, extra: $extra)';
}

/// `null` heißt „keine Angabe", nicht „null Gramm": Zwei Lebensmittel ohne
/// Ballaststoffangabe ergeben keine 0 g Ballaststoffe.
double? _summe(double? links, double? rechts) {
  if (links == null) return rechts;
  if (rechts == null) return links;
  return links + rechts;
}

double? _skaliert(double? wert, double faktor) =>
    wert == null ? null : wert * faktor;

/// Inhaltsgleichheit zweier Maps. `package:collection` wäre der kurze Weg
/// und ist hier verboten — der Kern importiert nur `dart:core` und
/// `dart:math` (`CLAUDE.md`, `test/import_boundary_test.dart`).
bool _gleicherInhalt(Map<String, double?> links, Map<String, double?> rechts) {
  if (identical(links, rechts)) return true;
  if (links.length != rechts.length) return false;
  for (final eintrag in links.entries) {
    if (!rechts.containsKey(eintrag.key)) return false;
    if (rechts[eintrag.key] != eintrag.value) return false;
  }
  return true;
}

/// Hash über den Inhalt, **unabhängig von der Reihenfolge**: Die Summe
/// zweier Maps entsteht je nach Aufrufreihenfolge mit anderer
/// Einfügereihenfolge, und zwei inhaltsgleiche Maps müssen denselben Hash
/// haben. `^` ist dafür das passende Mittel, weil es vertauschbar ist.
int _inhaltsHash(Map<String, double?> werte) {
  var vermischt = 0;
  for (final eintrag in werte.entries) {
    vermischt ^= Object.hash(eintrag.key, eintrag.value);
  }
  return Object.hash(werte.length, vermischt);
}
