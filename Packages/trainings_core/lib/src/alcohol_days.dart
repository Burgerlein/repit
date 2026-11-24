import 'berlin_calendar.dart';

/// Alkohol-Tage aus Tageswerten (#125).
///
/// **Die Regel ist eine Zeile:** Ein Tag mit mehr als 0 ist ein
/// Alkohol-Tag. Alles andere an dieser Datei sind die Fälle drumherum —
/// Tagesgrenzen, Reihenfolge, Doppel, und vor allem der Unterschied
/// zwischen „gemessen, nichts" und „kein Wert".
///
/// **`drinks` ist eine Zahl, keine Menge.** Apple Health hat keinen
/// Nährwert Alkohol; der einzige Tagebuch-Typ zählt Getränke
/// (`HKQuantityTypeIdentifierNumberOfAlcoholicBeverages`, Einheit `count`).
/// Für diese Rechnung spielt das keine Rolle — sie fragt nur „mehr als
/// nichts?" —, aber der Name soll nicht mehr behaupten, als ankommt.
///
/// **`null` ist keine Null.** Apple verrät den Lesestatus nicht: Ein Tag
/// ohne Alkoholwert kann ein Tag ohne Alkohol sein oder ein Tag ohne
/// Freigabe, und beides sieht gleich aus. Ein solcher Tag ist deshalb kein
/// Alkohol-Tag — aber er belegt auch nicht, dass keiner war. Was ein
/// Schirm aus einer leeren Liste macht, entscheidet der Schirm; hier steht
/// keine Behauptung darüber.
///
/// **Gezählt, nicht bewertet.** Es gibt keine zweite Schwelle, keinen
/// Richtwert und keine Empfehlung — das wäre eine Diagnose, und die gehört
/// nirgendwohin in dieser App.
abstract final class AlcoholDays {
  /// Die Alkohol-Tage aus Tageswerten: aufsteigend, ohne Doppel, jeder auf
  /// der Berliner Tagesgrenze.
  ///
  /// `drinks` ist nullbar, weil der Kanal ein fehlendes Feld als `null`
  /// durchreicht statt als 0 (`CLAUDE.md`). Mehrere Einträge desselben
  /// Kalendertags sind erlaubt und ergeben **einen** Tag: Gezählt werden
  /// Tage, nicht Messpunkte — und ein Eintrag ohne Wert nimmt demselben Tag
  /// seinen Wert nicht weg.
  ///
  /// Negative Werte fallen heraus. Die gibt es nicht; ein solcher Wert ist
  /// ein Datenfehler und keine Angabe über einen Abend.
  static List<DateTime> from(
    Iterable<({DateTime date, double? drinks})> entries,
  ) {
    final days = <DateTime>{};
    for (final entry in entries) {
      final drinks = entry.drinks;
      if (drinks == null || drinks <= 0) continue;
      days.add(BerlinCalendar.startOfDay(entry.date));
    }
    return days.toList()..sort((a, b) => a.compareTo(b));
  }

  /// Die Tage, an denen eine **Null gemessen** wurde: das belegte „nein".
  ///
  /// Das Gegenstück zu [from], aus denselben Einträgen gelesen. Ein Tag
  /// steht hier genau dann, wenn für ihn mindestens eine Null vorliegt und
  /// **kein** Eintrag desselben Tages mehr als nichts zeigt — eine
  /// einzelne Null widerlegt nicht, was am selben Tag sonst noch erfasst
  /// ist. Die beiden Listen überschneiden sich deshalb nie.
  ///
  /// `null` steht hier nicht: Ein fehlender Wert belegt nichts (siehe oben).
  /// Negative Werte ebenso wenig — die gibt es nicht, ein solcher Wert ist
  /// ein Datenfehler.
  ///
  /// **Dass diese Liste heute meist leer bleibt, ist kein Mangel.** Der
  /// Tagebuch-Typ legt nur dann eine Probe an, wenn etwas getrunken wurde;
  /// eine gemessene Null kommt nur von einem Tagebuch, das sie ausdrücklich
  /// schreibt. Sie ist trotzdem der einzige Fall, in dem „nein" mehr ist
  /// als eine Vermutung.
  static List<DateTime> measuredZero(
    Iterable<({DateTime date, double? drinks})> entries,
  ) {
    final zero = <DateTime>{};
    final positive = <DateTime>{};
    for (final entry in entries) {
      final drinks = entry.drinks;
      if (drinks == null) continue;
      final day = BerlinCalendar.startOfDay(entry.date);
      if (drinks > 0) {
        positive.add(day);
      } else if (drinks == 0) {
        zero.add(day);
      }
    }
    return (zero..removeAll(positive)).toList()..sort((a, b) => a.compareTo(b));
  }

  /// Der jüngste Alkohol-Tag, oder `null`, wenn es keinen gibt.
  ///
  /// Nimmt die Reihenfolge der Eingabe **nicht** als gegeben hin: [from]
  /// sortiert zwar, aber diese Funktion steht auch für Listen offen, die
  /// woanders herkommen — und ein erfundenes „zuletzt" wäre schlimmer als
  /// gar keines.
  static DateTime? last(Iterable<DateTime> days) {
    DateTime? latest;
    for (final day in days) {
      if (latest == null || day.isAfter(latest)) latest = day;
    }
    return latest;
  }
}

/// Was über Alkohol am **Vortag** eines Tages bekannt ist (#268).
///
/// Drei Fälle, weil „nein" und „nicht erfasst" zwei verschiedene Dinge
/// sind: Ein „nein", das in Wahrheit „keine Daten" heißt, wäre Fehler `01`
/// in klein. Sie entsprechen eins zu eins den drei Fällen, die
/// [AlcoholDays] ohnehin schon unterscheidet — mehr als nichts, gemessene
/// Null, kein Wert.
enum AlcoholEve {
  /// Für den Vortag ist mindestens ein Getränk erfasst.
  drinks,

  /// Für den Vortag liegt ein Alkoholwert vor, und er war null. **Nur
  /// hier ist „nein" belegt.**
  noDrinks,

  /// Für den Vortag liegt kein Alkoholwert vor. Das heißt **nicht**
  /// „nichts getrunken": Apple Health legt für alkoholische Getränke nur
  /// dann eine Probe an, wenn etwas getrunken wurde, und eine fehlende
  /// Freigabe sieht genauso aus. Der Normalfall — und die ehrliche
  /// Auskunft.
  unknown,
}
