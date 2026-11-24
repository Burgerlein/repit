import 'package:flutter/widgets.dart';

/// Zuordnung der rund 20 SF-Symbol-Namen aus
/// `Sources/Features/Shell/RootView.swift:29-40` und
/// `Sources/Features/Shell/MoreView.swift:51-67` auf einen freien Icon-Satz.
///
/// **Warum Phosphor statt Lucide** (Entwurf Abschnitt 6.5: „SF Symbols lassen
/// sich für Android nicht lizenzieren"): Das Phosphor-Projekt liefert für
/// jeden der 20 Namen unten eine unmittelbare Entsprechung, auch für
/// Nischenbegriffe wie „stethoscope" oder „waveform.path.ecg"
/// (→ `heartbeat`). Das naheliegende reine Lucide-Paket (`lucide_icons`,
/// 0.257.0) verlangt in seinem eigenen `pubspec.yaml` `sdk: >=2.12.0 <3.0.0`
/// und löst mit diesem Projekt (`sdk: ^3.13.5`) nicht auf; die einzige
/// auflösende Alternative (`lucide_icons_flutter`, ein Fork eines
/// Drittautors) ist kein offizielles Projektpaket.
///
/// **Woher die Schrift kommt — direkt gebündelt, nicht über das Paket
/// `phosphor_flutter`:** Das Paket übersetzt gegen diese Flutter-Fassung
/// nicht mehr (`IconData` ist inzwischen eine `final class`,
/// `phosphor_flutter` 2.1.0 erbt in `phosphor_icon_data.dart:5` trotzdem
/// davon — „The class 'IconData' can't be extended outside of its library
/// because it's a final class"). Es als Abhängigkeit nur wegen seiner
/// Schriftdatei zu behalten (ohne sie je zu importieren) wäre eine Falle:
/// Ein künftiger `pub get` könnte eine Fassung mit verschobenen Codepoints
/// ziehen, und weil die Codepoints unten hart im Code stehen, schlüge dabei
/// **nichts** fehl — die Symbole würden still falsch. Die beiden benötigten
/// Stile liegen deshalb direkt im Repository
/// (`app/assets/fonts/Phosphor/Phosphor-Regular.ttf`,
/// `Phosphor-Fill.ttf`, in `pubspec.yaml` als eigene Fontfamilien
/// `PhosphorRegular`/`PhosphorFill` eingetragen, **ohne** `fontPackage`, da
/// es jetzt eine App-eigene Schrift ist, keine aus einer Abhängigkeit). Sie
/// ändern sich nur noch, wenn hier jemand bewusst eine neue Datei einspielt.
///
/// **Herkunft und Prüfsumme der Codepoints unten**, damit sie nachprüfbar
/// sind statt geglaubt werden zu müssen: unverändert aus `phosphor_flutter`
/// 2.1.0 übernommen (`lib/fonts/Phosphor.ttf` → `Phosphor-Regular.ttf`,
/// `lib/fonts/Phosphor-Fill.ttf` → `Phosphor-Fill.ttf`), Codepoints
/// nachgezählt in `lib/src/phosphor_icons_regular.dart` und
/// `phosphor_icons_fill.dart` derselben Paketquelle. SHA-256 der
/// mitgelieferten Dateien, zum Abgleich bei einem künftigen Schrift-Update:
///
/// ```
/// 06b91e022b7ee899a63efced879392a74f0bacbda54e4467e9f663220d173a10  Phosphor-Regular.ttf
/// a53f5d2630cab5e3b7536ecb9d69d71519a2190298c22b1f8d770dd37bc2940a  Phosphor-Fill.ttf
/// ```
///
/// Ändert sich eine Prüfsumme (neue Schriftdatei eingespielt), sind die
/// Codepoints unten gegen die neue Fassung von
/// `lib/src/phosphor_icons_*.dart` im Paket-Quelltext neu abzugleichen —
/// ein stillschweigend falsches Symbol fällt sonst erst auf dem Schirm auf,
/// nicht im Test (siehe Prüfung unten).
///
/// Die Tabelle bildet **Namen auf `IconData`** ab, nicht Widgets — `IconRow`
/// bekommt weiterhin nur den String-Namen (parallel zu den Swift-Aufrufern,
/// die ebenfalls nur `"calendar"`, `"dumbbell"` usw. durchreichen) und löst
/// ihn selbst über diese Tabelle auf.
class Symbole {
  Symbole._();

  static const IconData _bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const IconData _calendar = IconData(
    0xe108,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _listBullets = IconData(
    0xe2f2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _barbell = IconData(
    0xe0b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _barbellFill = IconData(
    0xe0b6,
    fontFamily: 'PhosphorFill',
  );
  static const IconData _forkKnife = IconData(
    0xe262,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _dotsThree = IconData(
    0xe1fe,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _target = IconData(
    0xe47c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _personSimpleRun = IconData(
    0xe730,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _personArmsSpread = IconData(
    0xecfe,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _moonStars = IconData(
    0xe58e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _bed = IconData(0xe0cc, fontFamily: 'PhosphorRegular');
  static const IconData _sun = IconData(0xe472, fontFamily: 'PhosphorRegular');
  static const IconData _heartbeat = IconData(
    0xe2ac,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _chartLine = IconData(
    0xe154,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _heart = IconData(
    0xe2a8,
    fontFamily: 'PhosphorRegular',
  );
  // Der Tropfen des Zykluskalenders (#539). Codepoint wie die übrigen
  // aus `phosphor_flutter` 2.1.0 nachgezählt
  // (`phosphor_icons_regular.dart`, `drop`).
  static const IconData _drop = IconData(
    0xe210,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _sealCheck = IconData(
    0xe606,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _gearSix = IconData(
    0xe272,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _downloadSimple = IconData(
    0xe20c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _stethoscope = IconData(
    0xe7ea,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData _uploadSimple = IconData(
    0xe4c0,
    fontFamily: 'PhosphorRegular',
  );
  // task-navbar (26.10.2026) — Bogenmenü des (+), components.js:174-240
  // (`tabMenu()`-Einträge „Barcode"/„Foto"). `_arrowsOut` existiert schon
  // (oben, für "arrow.up.left.and.arrow.down.right"); die Vorlage für
  // "expand" im Bogen ist dasselbe Glyph (vier Pfeile in die Ecken), daher
  // Wiederverwendung statt eines zweiten Codepoints für dieselbe Form —
  // genau wie 'scale' weiter unten `_scales` wiederverwendet. "photo"
  // braucht dagegen eine eigene Glyphe: `image` aus `phosphor_flutter`
  // 2.1.0 (`lib/src/phosphor_icons_regular.dart:2388`), Codepoint gegen die
  // Paketquelle im lokalen `pub-cache` abgeglichen und per `fontTools`
  // gegen die gebündelte `Phosphor-Regular.ttf` geprüft (5 Konturen, keine
  // leere `.notdef`-Glyphe).
  static const IconData _image = IconData(0xe2ca, fontFamily: 'PhosphorRegular');
  // Derselbe Anlass: Der (+)/(×)-Knopf der Tableiste ([ErfassenKnopf])
  // braucht ein Pluszeichen, das sich um 45° drehen lässt, um wie ein Kreuz
  // auszusehen (`components.css`, `.tmclose`) — die Tabelle kannte bisher
  // kein einziges Plus-Symbol. `plus` aus `phosphor_flutter` 2.1.0
  // (`phosphor_icons_regular.dart:3296`), ebenso gegen Paketquelle und
  // Schriftdatei geprüft (1 Kontur, kein `.notdef`).
  static const IconData _plus = IconData(0xe3d4, fontFamily: 'PhosphorRegular');

  // #319 (05.11.2026) — Namen, die Board-Schirme zeichnen und die App nicht
  // kannte. Codepoints aus `phosphor_flutter` 2.1.0
  // (`lib/src/phosphor_icons_regular.dart`); dass jede Glyphe echte
  // Konturen hat, prüft seither `symbole_board_abgleich_test.dart` für die
  // ganze Tabelle.
  static const IconData _plusCircle = IconData(
    0xe3d6,
    fontFamily: 'PhosphorRegular',
  ); // plusCircle
  // #385 (10.11.2026): die Kachelreihe der Erfassungswege im Board.
  static const IconData _barcode = IconData(
    0xe0b8,
    fontFamily: 'PhosphorRegular',
  ); // barcode
  static const IconData _magnifyingGlass = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  ); // magnifyingGlass

  // Task 11: vollständiger Abgleich aller `systemName:`/`systemImage:`-
  // Vorkommen in `Sources/` gegen diese Tabelle (siehe `task-11-report.md`),
  // nachdem zweimal in Folge ein einzelner übersehener Name durchfiel
  // (`bell` in Task 10, `ruler` hier). Die Namen unten gehören zu Screens,
  // die es in dieser App noch nicht gibt (Gym, Körper, Erholung, Plan,
  // Heute, Einstellungen) — nachgetragen, damit beim Portieren dieser
  // Screens nicht wieder derselbe Fehler entsteht. Codepoints wie oben aus
  // `phosphor_flutter` 2.1.0 (`lib/src/phosphor_icons_regular.dart`,
  // `phosphor_icons_fill.dart`), Namen in den Kommentaren sind die
  // Phosphor-eigenen (camelCase), zum Nachschlagen in derselben Quelle.
  static const IconData _ruler = IconData(
    0xe6b8,
    fontFamily: 'PhosphorRegular',
  ); // ruler
  static const IconData _checkCircleFill = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  ); // checkCircle
  static const IconData _dotsThreeCircle = IconData(
    0xe200,
    fontFamily: 'PhosphorRegular',
  ); // dotsThreeCircle
  static const IconData _minusCircle = IconData(
    0xe32c,
    fontFamily: 'PhosphorRegular',
  ); // minusCircle
  static const IconData _wifiSlash = IconData(
    0xe4f2,
    fontFamily: 'PhosphorRegular',
  ); // wifiSlash
  static const IconData _x = IconData(
    0xe4f6,
    fontFamily: 'PhosphorRegular',
  ); // x
  static const IconData _arrowUp = IconData(
    0xe08e,
    fontFamily: 'PhosphorRegular',
  ); // arrowUp
  static const IconData _arrowDown = IconData(
    0xe03e,
    fontFamily: 'PhosphorRegular',
  ); // arrowDown
  static const IconData _minus = IconData(
    0xe32a,
    fontFamily: 'PhosphorRegular',
  ); // minus
  static const IconData _circle = IconData(
    0xe18a,
    fontFamily: 'PhosphorRegular',
  ); // circle
  static const IconData _stopCircleFill = IconData(
    0xe46e,
    fontFamily: 'PhosphorFill',
  ); // stopCircle
  static const IconData _clock = IconData(
    0xe19a,
    fontFamily: 'PhosphorRegular',
  ); // clock
  static const IconData _timer = IconData(
    0xe492,
    fontFamily: 'PhosphorRegular',
  ); // timer
  static const IconData _sparkle = IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
  ); // sparkle
  static const IconData _warningFill = IconData(
    0xe4e0,
    fontFamily: 'PhosphorFill',
  ); // warning
  static const IconData _equals = IconData(
    0xe21c,
    fontFamily: 'PhosphorRegular',
  ); // equals
  static const IconData _arrowUUpLeft = IconData(
    0xe08a,
    fontFamily: 'PhosphorRegular',
  ); // arrowUUpLeft
  static const IconData _lightningFill = IconData(
    0xe2de,
    fontFamily: 'PhosphorFill',
  ); // lightning
  static const IconData _chartLineUp = IconData(
    0xe156,
    fontFamily: 'PhosphorRegular',
  ); // chartLineUp
  static const IconData _check = IconData(
    0xe182,
    fontFamily: 'PhosphorRegular',
  ); // check
  static const IconData _firstAidKit = IconData(
    0xe570,
    fontFamily: 'PhosphorRegular',
  ); // firstAidKit
  static const IconData _info = IconData(
    0xe2ce,
    fontFamily: 'PhosphorRegular',
  ); // info
  static const IconData _caretLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
  ); // caretLeft
  static const IconData _personSimpleWalk = IconData(
    0xe73a,
    fontFamily: 'PhosphorRegular',
  ); // personSimpleWalk
  static const IconData _scales = IconData(
    0xe750,
    fontFamily: 'PhosphorRegular',
  ); // scales
  static const IconData _arrowsOut = IconData(
    0xe0a2,
    fontFamily: 'PhosphorRegular',
  ); // arrowsOut
  static const IconData _arrowCounterClockwise = IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
  ); // arrowCounterClockwise

  static const Map<String, IconData> tabelle = {
    // RootView.swift:116 — Hinweis-Glocke, hängt an jedem Tab-Stapel.
    // Fehlte ursprünglich in dieser Tabelle (Task 9 nannte nur die
    // Tab-Symbol-Zeilen 29-40 und übersah die Glocke weiter unten in
    // derselben Datei) und wurde in Task 10 nachgetragen.
    'bell': _bell,

    // RootView.swift:29-40 — Tab-Leiste
    'calendar': _calendar,
    'list.bullet': _listBullets,
    'dumbbell': _barbell,
    'dumbbell.fill': _barbellFill,
    'fork.knife': _forkKnife,
    'ellipsis': _dotsThree,

    // MoreView.swift:51-67 — Mehr-Menü
    'target': _target,
    'figure.run': _personSimpleRun,
    'figure.arms.open': _personArmsSpread,
    'moon.zzz': _moonStars,
    'bed.double': _bed,
    'sun.max': _sun,
    'waveform.path.ecg': _heartbeat,
    'chart.xyaxis.line': _chartLine,
    'heart': _heart,
    'drop': _drop,
    'checkmark.seal': _sealCheck,
    'gearshape': _gearSix,
    'square.and.arrow.down': _downloadSimple,
    'stethoscope': _stethoscope,
    'square.and.arrow.up': _uploadSimple,

    // MoreView.swift:120 / BodyOverviewView.swift:162 — Umfänge-Zeile,
    // sowohl im Mehr-Menü als auch in der Körper-Übersicht (dort noch kein
    // Flutter-Screen).
    'ruler': _ruler,

    // Rest des Abgleichs aus Task 11 (siehe Kommentar oben): Namen aus
    // Gym-, Körper-, Erholungs-, Plan-, Heute- und Einstellungen-Screens,
    // die es in Flutter noch nicht gibt — nachgetragen, damit sie beim
    // Portieren nicht erneut fehlen.
    // GymFocusPage.swift:112, GymLogExerciseCard.swift:156
    'minus.circle': _minusCircle,
    // GymFocusPage.swift:121, GymLogExerciseCard.swift:57/167, GymLogView.swift:122
    'checkmark.circle.fill': _checkCircleFill,
    // GymFocusPage.swift:121, GymLogExerciseCard.swift:57/167
    'circle': _circle,
    // GymFocusPage.swift:168
    'stop.circle.fill': _stopCircleFill,
    // GymFocusPage.swift:168
    'clock': _clock,
    'timer': _timer,
    // SuggestionText.swift:116 (increaseTime ohne Historie, firstTime)
    'sparkles': _sparkle,
    // SuggestionText.swift:116, CircumferenceHistory.swift:93,
    // CircumferenceRow.swift:82, TodayDigest.swift (Suggestion/Verlauf)
    'arrow.up': _arrowUp,
    'arrow.down': _arrowDown,
    // CircumferenceHistory.swift:93, CircumferenceRow.swift:82
    'minus': _minus,
    // SuggestionText.swift:116 (harderVariant)
    'exclamationmark.triangle.fill': _warningFill,
    // SuggestionText.swift:116 (hold)
    'equal': _equals,
    // TodayDigest.swift (NextUp bei überfälligem Training)
    'arrow.uturn.left': _arrowUUpLeft,
    // SwapDaysSheet.swift:69 (Tausch zurücknehmen) — bewusst eigenes Icon,
    // nicht dasselbe wie "arrow.uturn.left": andere Geste (Rückgängig statt
    // Richtungspfeil), siehe Bericht.
    'arrow.uturn.backward': _arrowCounterClockwise,
    // TodayDigest.swift (HM-Tempo)
    'bolt.fill': _lightningFill,
    // GymOverviewView.swift:39 (Fortschritt pro Übung)
    'chart.line.uptrend.xyaxis': _chartLineUp,
    // TodayDigest.swift (erledigter Hinweis)
    'checkmark': _check,
    // TodayDigest.swift (Gesundheitshinweis)
    'cross.case': _firstAidKit,
    // FocusFooter-Aufruf in GymOverviewView.swift:201
    'info.circle': _info,
    // SleepNightBar.swift:14, SleepCalendarSheet.swift:68 — Monat/Nacht
    // zurückblättern. "chevron.right" bleibt bewusst außen vor: `IconRow`
    // zeichnet seinen Chevron fest über `CupertinoIcons.chevron_right`,
    // nie über `Symbole.aufloesen` (siehe `icon_row.dart`) — ein Eintrag
    // hier hätte keinen Aufrufer.
    'chevron.left': _caretLeft,
    // BodyOverviewView.swift:157 (Schritte-Zeile)
    'figure.walk': _personSimpleWalk,
    // BodyOverviewView.swift:160 (Messungen-Zeile)
    'scalemass': _scales,
    // GymLogView.swift:53 ("Fokus" in den Vollbild-Modus)
    'arrow.up.left.and.arrow.down.right': _arrowsOut,
    // GymOverviewView.swift:362 (weitere Optionen)
    'ellipsis.circle': _dotsThreeCircle,
    // ExerciseAnimationView.swift:161 (kein Netz beim Laden der Animation)
    'wifi.slash': _wifiSlash,
    // GymFocusView.swift:46 (Vollbild verlassen)
    'xmark': _x,

    // heute-kombi.js (Entwurf, Baukasten „Heute, kombiniert", Task H1) —
    // Wasser-Zeile in „Heute noch offen". Bewusste Wiederverwendung der
    // bereits geprüften `_scales`-Glyphe (wie `scalemass`), kein stiller
    // Rückfall: Für eine eigene Wasser-/Mess-Glyphe läge kein geprüfter
    // Codepoint vor (siehe Prüfsummen-Pflicht oben), und beide Namen
    // meinen ohnehin eine Waage/Messung.
    'scale': _scales,

    // task-navbar (26.10.2026) — Bogenmenü des (+) über der Tableiste,
    // components.js:174-240 (`tabMenu()`-Aufrufe in `ernaehrung.js` u. a.).
    // Siehe Kommentar bei `_image` oben zur Herkunft der Codepoints.
    'expand': _arrowsOut,
    'photo': _image,
    'plus': _plus,

    // #319 — Namen der Board-Schirme (`docs/screens/components.js`, `I`).
    // Vier davon zeichnet das Board mit derselben Form, die die App unter
    // ihrem SF-Namen schon führt; sie bekommen dieselbe Glyphe als zweiten
    // Namen, statt das Board umzubenennen:
    // `seal` ist dort ein Siegel mit Haken (= `checkmark.seal`), `gear` ein
    // Zahnrad (= `gearshape`), `download` ein Pfeil in eine Schale
    // (= `square.and.arrow.down`), `figure.arms` eine Figur mit
    // ausgebreiteten Armen (= `figure.arms.open`). `undo` ist ein Pfeil,
    // der nach links umkehrt (= `arrow.uturn.left`).
    'plus.circle': _plusCircle, // mahlzeit.js, erfassen.js, aktivitaeten.js
    // #356 (05.11.2026): die Hinweis-Vorschläge im Board zeichnen `info`
    // und `exclam` (`components.js`).
    'info': _info, // hinweise-vorschlag.js
    'barcode': _barcode, // erfassen.js (Kachelreihe, #385)
    'magnifyingglass': _magnifyingGlass, // erfassen.js (Kachelreihe, #385)
    'exclam': _warningFill, // hinweise-vorschlag.js
    // 'clock' (heute-kombi.js) steht schon oben, seit #358.
    'undo': _arrowUUpLeft, // einstellungen.js, erststart-plan.js
    'seal': _sealCheck, // mehr.js, einstellungen.js, erfassen.js
    'gear': _gearSix, // mehr.js, einstellungen.js
    'download': _downloadSimple, // mehr.js, platzhalter.js
    'figure.arms': _personArmsSpread, // mehr.js, healthtest.js
  };

  /// Sichtbarer Nachfolger für einen unbekannten Namen — Phosphor
  /// „warning-circle“ (U+E4E2, vorhanden und mit echten Konturen in
  /// `Phosphor-Regular.ttf`, siehe Prüfung in `task-9-report.md`). Bewusst
  /// kein Icon, das wie ein plausibles Symbol aussieht: Ein Warnzeichen soll
  /// auffallen, nicht sich einfügen.
  static const IconData _unbekannt = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
  );

  /// Löst einen Namen auf — **nie still**.
  ///
  /// Ein direkter Zugriff auf [tabelle] (`tabelle[name]`) liefert für einen
  /// unbekannten Namen `null`, und `Icon(null, …)` zeichnet daraufhin
  /// kommentarlos nichts: kein Fehler, keine Meldung, das Symbol ist
  /// einfach weg. Formal ist die Regel „kein stiller Rückfall“ trotzdem
  /// erfüllt, solange nur die heute 20 getesteten Namen vorkommen — aber ab
  /// Task 11 tippt `MoreView` rund zehn weitere Namen frei
  /// (`"stethoscope"`, `"waveform.path.ecg"`, …), ohne dass ein Tippfehler
  /// dort geprüft wird. Genau das ist die Klasse stiller Fehler, gegen die
  /// dieser Umbau laut `CLAUDE.md` antritt.
  ///
  /// `IconRow` ruft deshalb diese Methode auf, nicht [tabelle] direkt:
  /// - **In der Entwicklung** bricht ein `assert` hart ab — lauter geht es
  ///   nicht, und Asserts sind in Debug-/Profile-Builds aktiv.
  /// - **Im Auslieferungsbau** ist `assert` abgeschaltet; die App stürzt
  ///   deshalb nicht ab, zeigt aber ein Warnzeichen ([_unbekannt]) statt des
  ///   gemeinten Symbols — sichtbar falsch statt unsichtbar falsch. Ein
  ///   Platzhalter, der wie ein plausibles Icon aussähe, wäre nur eine
  ///   mildere Form desselben stillen Fehlers und deshalb keine Option.
  static IconData aufloesen(String name) {
    final symbol = tabelle[name];
    assert(
      symbol != null,
      'Symbole.tabelle kennt "$name" nicht — Name prüfen oder Eintrag in '
      'symbole.dart ergänzen.',
    );
    return symbol ?? _unbekannt;
  }
}
