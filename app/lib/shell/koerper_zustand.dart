// Der Zustand der Körper-Schirme (#202, Teil C) — `koerper` (#82) und
// `messungen` (#85) zeigen dieselben Zahlen in zwei Anordnungen und
// bekommen sie deshalb aus **einem** Zustand. Die Oberflächen liegen in
// eigenen Dateien.
//
// API und Vertrag sind durch `app/test/shell/koerper_zustand_test.dart`
// verbindlich vorgegeben (siehe dessen Dateikopf für die vollständige
// Begründung des Schnitts) — diese Datei darf die Tests ausführen, aber
// nicht verändern (`CLAUDE.md`, „Wer Tests schreibt, schreibt nicht die
// Implementierung").
//
// **Es entsteht keine zweite Quelle für Tageswerte.**
// `dailyMetricsProvider` liest bereits Cache zuerst und dann den Kanal;
// Gewicht, Körperfett und fettfreie Masse stehen seit Teil B darin. Hier
// wird davon **abgeleitet** und nichts selbst gefragt — in Swift holten
// `BodyStore` und `EnduranceStore` beide dieselben Tageswerte, und genau
// das soll sich nicht wiederholen (Spec, Teil C).
//
// **Keine Schwelle und keine Formel steht hier als Zahl.** Trend, Grenzen
// und Eiweißkorridor rechnen [BodyTrend] und [ProteinTarget], der
// Sieben-Tage-Schnitt [StepStatistics] — der Kern trägt die Rechnungen.
//
// **Keine Nutzertexte.** Der Zustand liefert Zahlen, Tagesschlüssel und
// Enums; „zuletzt am 11.10." und die vier Trendsätze stehen in der View
// (`CLAUDE.md`).
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../core/messwert.dart';
import '../data/cache_repository.dart';
import '../health/health_provider.dart';
import '../health/health_types.dart';

/// Wie viele Messpunkte eine Sparkline trägt — die jüngsten sieben.
const int _sparklinePunkte = 7;

/// Was Körper und Messungen zu **einer** Messart zeigen.
///
/// Werttyp mit `==` und `hashCode`: Er steckt in [KoerperWerte] und damit
/// in einer Provider-Abhängigkeit. Ohne Wertgleichheit wäre jede neu
/// gerechnete Fassung ungleich der vorigen, und jeder abgeleitete Wert
/// liefe neu — das wäre Fehler `03`, wortgleich im neuen Code.
@immutable
class MessStand {
  const MessStand({
    required this.art,
    required this.wert,
    required this.tag,
    required this.veraenderung6Wochen,
    required this.reihe,
  });

  /// Zu welcher der vier Messarten dieser Stand gehört. Jede Kachel und
  /// jede Karte weiß damit selbst, was sie zeigt.
  final MessArt art;

  /// Der jüngste **gemessene** Wert, nicht der des jüngsten Tages: Stand
  /// die Waage gestern nicht im Bad, gilt die Wägung von vorgestern.
  ///
  /// `null`, wenn nie gemessen wurde — **nie `0`**. Eine 0,0 behauptet eine
  /// Messung, die es nie gab, und das ist Fehler `01` in neuer Verpackung
  /// (`CLAUDE.md`).
  final double? wert;

  /// Der Tagesschlüssel von [wert] — der Tag gehört zur Zahl, nicht zum
  /// Lauf. Daraus wird in der View „zuletzt gemessen am …". Ohne Wert kein
  /// Tag.
  final String? tag;

  /// Jüngster minus ältester Wert im 6-Wochen-Fenster; `null` unter zwei
  /// Werten darin. Nicht der größte Abstand und nicht die Steigung — die
  /// steht für das Gewicht eigens in [KoerperWerte.gewichtsTrendProWoche].
  final double? veraenderung6Wochen;

  /// Die jüngsten sieben Messpunkte, aufsteigend — die Kurve läuft nach
  /// rechts. Lücken bleiben Lücken: Ein Tag ohne Messung fehlt, er steht
  /// nicht mit `0` darin.
  final List<MeasurementPoint> reihe;

  @override
  bool operator ==(Object other) =>
      other is MessStand &&
      other.art == art &&
      other.wert == wert &&
      other.tag == tag &&
      other.veraenderung6Wochen == veraenderung6Wochen &&
      // Element für Element, nicht nach Identität: Zwei gleich gerechnete
      // Reihen sind dieselbe Kurve.
      listEquals(other.reihe, reihe);

  @override
  int get hashCode =>
      Object.hash(art, wert, tag, veraenderung6Wochen, Object.hashAll(reihe));
}

/// Alles, was Körper und Messungen an Zahlen zeigen, einmal gerechnet.
@immutable
class KoerperWerte {
  const KoerperWerte({
    required this.gewicht,
    required this.koerperfett,
    required this.fettfreieMasse,
    required this.ruhepuls,
    required this.gewichtsTrendProWoche,
    required this.trendEinordnung,
    required this.eiweissZiel,
    required this.schritteSchnitt7,
  });

  final MessStand gewicht;
  final MessStand koerperfett;
  final MessStand fettfreieMasse;
  final MessStand ruhepuls;

  /// Steigung der Gewichtsreihe in kg **pro Woche** über sechs Wochen, aus
  /// [BodyTrend.perWeek]. `null` unter zwei Wägungen im Fenster — eine
  /// Gerade durch einen Punkt hat keine Steigung, und „0,00 kg pro Woche"
  /// wäre eine Zahl, die niemand gerechnet hat.
  final double? gewichtsTrendProWoche;

  /// Die Einordnung dieser Steigung aus [BodyTrend.rating] — die Grenzen
  /// stehen im Kern, nicht hier. Die vier Sätze dazu stehen in der View.
  final TrendRating? trendEinordnung;

  /// Eiweißkorridor in Gramm pro Tag aus [ProteinTarget.grams] über das
  /// jüngste Gewicht, positionell als `(low, high)`. `null` ohne Wägung.
  final (int, int)? eiweissZiel;

  /// Das Mittel der Schritte über die sieben Tage **vor** heute
  /// ([StepStatistics.average7]). `null`, wenn in diesem Fenster kein Tag
  /// gemessen wurde — eine 0 behauptete eine Woche ohne einen Schritt.
  final int? schritteSchnitt7;

  /// Die **eine** Zuordnung Messart → Stand; vier Karten, eine Rechnung.
  ///
  /// Dasselbe Muster wie `verlaufArtZu` nebenan: Wer die Zuordnung an
  /// zweiter Stelle nachbaut, hat sie an zweiter Stelle falsch.
  MessStand stand(MessArt art) => switch (art) {
    MessArt.gewicht => gewicht,
    MessArt.koerperfett => koerperfett,
    MessArt.fettfreieMasse => fettfreieMasse,
    MessArt.ruhepuls => ruhepuls,
  };

  /// Ob **irgendeine** der vier Messarten einen Wert trägt.
  ///
  /// Die eine Stelle, an der „leer" für diesen Zustand definiert ist (Spec,
  /// Teil C). Schritte zählen hier nicht mit: Die Kachel „Schritte Ø 7
  /// Tage" hängt an ihnen, der Leerzustand des Schirms nicht. Und ein
  /// Schirm, der drei Werte hat und wegen des vierten „keine Daten" sagt,
  /// wäre Fehler `01`.
  bool get traegtWert => MessArt.values.any((art) => stand(art).wert != null);

  @override
  bool operator ==(Object other) =>
      other is KoerperWerte &&
      other.gewicht == gewicht &&
      other.koerperfett == koerperfett &&
      other.fettfreieMasse == fettfreieMasse &&
      other.ruhepuls == ruhepuls &&
      other.gewichtsTrendProWoche == gewichtsTrendProWoche &&
      other.trendEinordnung == trendEinordnung &&
      other.eiweissZiel == eiweissZiel &&
      other.schritteSchnitt7 == schritteSchnitt7;

  @override
  int get hashCode => Object.hash(
    gewicht,
    koerperfett,
    fettfreieMasse,
    ruhepuls,
    gewichtsTrendProWoche,
    trendEinordnung,
    eiweissZiel,
    schritteSchnitt7,
  );
}

/// Rechnet die Körperzahlen aus den Tageswerten.
///
/// Die vier Zustände werden durchgereicht; nur aus `Bekannt` kann ein
/// anderer werden, und zwar genau dann, wenn **keine** der vier Messarten
/// einen Wert trägt:
///
/// * läuft der Lauf noch, ist es [NochNie] — der graue Platzhalter.
///   „Während des Ladens steht nie ein ‚keine Daten'-Grund" ist Fehler
///   `01`, und [LeerNachLauf] ist der einzige Zustand, der einen Grund
///   anzeigen darf (`messwert.dart`).
/// * ist er fertig, ist es [LeerNachLauf].
Messwert<KoerperWerte> koerperWerteAus({
  required Messwert<List<DailyMetrics>> tageswerte,
  required DateTime jetzt,
}) => switch (tageswerte) {
  // Vollständig über den sealed-Typ: Käme ein fünfter Zustand, zeigte der
  // Analyzer genau hierhin.
  NochNie<List<DailyMetrics>>() => const NochNie<KoerperWerte>(),
  LeerNachLauf<List<DailyMetrics>>(:final gelaufen) =>
    LeerNachLauf<KoerperWerte>(gelaufen: gelaufen),
  Fehlgeschlagen<List<DailyMetrics>>(:final fehler, :final gelaufen) =>
    Fehlgeschlagen<KoerperWerte>(fehler: fehler, gelaufen: gelaufen),
  Bekannt<List<DailyMetrics>>(:final wert, :final stand, :final laeuft) =>
    _ausTagen(wert, stand: stand, laeuft: laeuft, jetzt: jetzt),
};

Messwert<KoerperWerte> _ausTagen(
  List<DailyMetrics> tage, {
  required DateTime stand,
  required bool laeuft,
  required DateTime jetzt,
}) {
  final reihen = {
    for (final art in MessArt.values) art: messreiheAus(art, tage),
  };
  final gewichtsReihe = reihen[MessArt.gewicht]!;

  // Das Fenster bestimmt `BodyTrend` selbst — die ganze Reihe geht hinein,
  // damit die Kante genau einmal gezogen wird.
  final trend = BodyTrend.perWeek(gewichtsReihe, now: jetzt);
  final juengstesGewicht = gewichtsReihe.isEmpty
      ? null
      : gewichtsReihe.last.value;

  final werte = KoerperWerte(
    gewicht: _stand(MessArt.gewicht, reihen[MessArt.gewicht]!, jetzt),
    koerperfett: _stand(
      MessArt.koerperfett,
      reihen[MessArt.koerperfett]!,
      jetzt,
    ),
    fettfreieMasse: _stand(
      MessArt.fettfreieMasse,
      reihen[MessArt.fettfreieMasse]!,
      jetzt,
    ),
    ruhepuls: _stand(MessArt.ruhepuls, reihen[MessArt.ruhepuls]!, jetzt),
    gewichtsTrendProWoche: trend,
    trendEinordnung: trend == null ? null : BodyTrend.rating(trend),
    eiweissZiel: juengstesGewicht == null
        ? null
        : ProteinTarget.grams(juengstesGewicht),
    // `?tag.steps`: Ein Tag ohne gemessene Schritte fällt aus der Karte
    // heraus, statt mit `0` darin zu stehen — der Unterschied, an dem
    // Fehler `01` hängt, und den [StepStatistics.average7] im Nenner
    // braucht.
    schritteSchnitt7: StepStatistics.average7({
      for (final tag in tage) tag.tag: ?tag.steps,
    }, now: jetzt),
  );

  if (werte.traegtWert) {
    return Bekannt<KoerperWerte>(werte, stand: stand, laeuft: laeuft);
  }
  if (laeuft) return const NochNie<KoerperWerte>();
  // Der Zeitpunkt ist der Stand der Daten, die nichts hergaben — nicht die
  // Uhr. Die Spec legt das nicht fest (beides ist vertretbar); gewählt ist
  // der Stand, weil er zu der Datenlage gehört, über die hier geurteilt
  // wird.
  return LeerNachLauf<KoerperWerte>(gelaufen: stand);
}

MessStand _stand(MessArt art, List<MeasurementPoint> reihe, DateTime jetzt) {
  final juengster = reihe.isEmpty ? null : reihe.last;
  return MessStand(
    art: art,
    wert: juengster?.value,
    // Zurück zum Tagesschlüssel: Ein Tag ist eine Kalenderangabe, kein
    // Zeitpunkt (`CLAUDE.md`).
    tag: juengster == null ? null : BerlinCalendar.dayKey(juengster.date),
    veraenderung6Wochen: veraenderungImFenster(reihe, jetzt: jetzt),
    reihe: juengstePunkte(reihe, _sparklinePunkte),
  );
}

/// Die Messreihe einer Art aus den Tageswerten, aufsteigend nach Tag.
///
/// **Ein fehlendes Feld lässt den Tag ausfallen**, es wird nie zu `0`: Eine
/// Lücke ist keine gemessene Null, und ein Punkt auf 0,0 zöge die Kurve
/// durch den Keller (Fehler `01`).
///
/// Sortiert wird hier und nicht beim Aufrufer: Aus dem Cache kommt die
/// Liste sortiert, aus dem Kanal nicht zwingend — und „die jüngsten sieben"
/// ist ohne Ordnung keine Aussage.
List<MeasurementPoint> messreiheAus(MessArt art, List<DailyMetrics> tage) {
  final punkte = <MeasurementPoint>[
    for (final tag in tage)
      if (_wertVon(art, tag) case final wert?)
        MeasurementPoint(date: datumAusTag(tag.tag), value: wert),
  ];
  punkte.sort((a, b) => a.date.compareTo(b.date));
  return punkte;
}

/// Die Zuordnung Messart → Feld von [DailyMetrics], an genau einer Stelle.
///
/// Der Ruhepuls kommt als `double` heraus: Die Spalte ist eine
/// Ganzzahlspalte, eine Messreihe ist es nicht.
double? _wertVon(MessArt art, DailyMetrics tag) => switch (art) {
  MessArt.gewicht => tag.weightKg,
  MessArt.koerperfett => tag.bodyFatPct,
  MessArt.fettfreieMasse => tag.leanKg,
  MessArt.ruhepuls => tag.restingHR?.toDouble(),
};

/// Jüngster minus ältester Wert im Fenster der letzten [wochen] Wochen;
/// `null` unter zwei Werten darin.
///
/// Dieselbe Kante wie [BodyTrend.perWeek]: `wochen * 7` Kalendertage vor
/// dem **Berliner Tagesbeginn** von [jetzt], über [BerlinCalendar.addDays]
/// statt über eine feste Dauer, und Punkte genau auf der Kante zählen mit.
/// Zwei Kanten, die auseinanderlaufen, wären zwei Wahrheiten über dasselbe
/// Fenster.
///
/// Erwartet [reihe] **aufsteigend** — so kommt sie aus [messreiheAus] und
/// aus `CacheRepository.messReihe`.
double? veraenderungImFenster(
  List<MeasurementPoint> reihe, {
  required DateTime jetzt,
  int wochen = BodyTrend.defaultWeeks,
}) {
  final kante = BerlinCalendar.addDays(
    BerlinCalendar.startOfDay(jetzt),
    -wochen * 7,
  );
  final imFenster = [
    for (final punkt in reihe)
      if (!punkt.date.isBefore(kante)) punkt,
  ];
  // Einer ist keine Veränderung — und „0,0" behauptete Stillstand.
  if (imFenster.length < 2) return null;
  return imFenster.last.value - imFenster.first.value;
}

/// Die jüngsten [anzahl] Punkte einer aufsteigenden Reihe, weiter
/// aufsteigend. Kürzere Reihen kommen vollständig durch.
List<MeasurementPoint> juengstePunkte(
  List<MeasurementPoint> reihe,
  int anzahl,
) => reihe.length <= anzahl ? reihe : reihe.sublist(reihe.length - anzahl);

/// Die Körperzahlen, **gehalten** statt bei jedem Zugriff gerechnet
/// (Hausregel 2, Fehler `03`).
///
/// Abgeleitet aus [dailyMetricsProvider] und aus sonst nichts. `AsyncValue`
/// endet hier und taucht in der Widget-Schicht nicht auf — dasselbe reine
/// Durchreichen wie bei `erholungProvider`, mit [NochNie] als Rückfall,
/// solange der Provider noch kein Ergebnis hat.
///
/// Der Schirm besorgt seine Daten damit selbst: Er ist aus jedem Tab
/// erreichbar, niemand darf sich darauf verlassen, dass eine Übersicht
/// vorher geladen hat.
final koerperWerteProvider = Provider<Messwert<KoerperWerte>>(
  (ref) => koerperWerteAus(
    tageswerte:
        ref.watch(dailyMetricsProvider).value ??
        const NochNie<List<DailyMetrics>>(),
    jetzt: ref.watch(clockProvider)(),
  ),
);
