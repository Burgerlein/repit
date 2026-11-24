import 'package:trainings_core/trainings_core.dart';

/// Testhilfe der Tagesgrenze (#375) — **kein Test.**
///
/// Die Tests der Tagesgrenze formulieren Uhrzeiten als **Berliner
/// Wanduhr** im Jahr 2099 (Plan `2026-11-10-tagesgrenze.md`, „Global
/// Constraints“). Diese Funktion macht daraus den UTC-Zeitpunkt.
///
/// Die Berliner Wanduhrzeit [stunde]:[minute] am Kalendertag [tag]
/// (ISO-Tag), als UTC-Zeitpunkt. In der doppelten Stunde im Oktober ist der
/// erste (Sommerzeit) gemeint, mit [zweites] der zweite (Winterzeit). Eine
/// Uhrzeit, die es nicht gibt (02:30 am Umstellungstag im März), wirft.
///
/// Probiert beide möglichen Versätze und prüft das Ergebnis mit
/// `BerlinCalendar` gegen, statt den Versatz selbst zu rechnen. Die
/// Umstellungstage 2099 sind der 29.03. und der 25.10.
DateTime berlin(String tag, int stunde, int minute, {bool zweites = false}) {
  final teile = tag.split('-').map(int.parse).toList();
  final wand = DateTime.utc(teile[0], teile[1], teile[2], stunde, minute);
  final treffer = [
    for (final versatz in const [2, 1]) wand.subtract(Duration(hours: versatz)),
  ].where(
    (t) =>
        BerlinCalendar.dayKey(t) == tag &&
        BerlinCalendar.wallClock(t) == (stunde, minute),
  ).toList();
  if (treffer.isEmpty) {
    throw ArgumentError('$tag $stunde:$minute gibt es in Berlin nicht');
  }
  if (zweites && treffer.length < 2) {
    throw ArgumentError('$tag $stunde:$minute gibt es nur einmal');
  }
  return zweites ? treffer.last : treffer.first;
}
