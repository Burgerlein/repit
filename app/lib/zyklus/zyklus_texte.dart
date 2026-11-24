// Alle Nutzertexte des Zykluskalenders an einer Stelle (#539) — wie
// `auszeit_texte.dart` beim Ziele-Schirm.
//
// **Hier steht, was die Nutzerin liest**, nicht was die App rechnet.
// Die Wortlaute stammen aus dem Entwurfsboard
// (`docs/screens/screens/zyklus*.js`); wer sie ändert, zieht das Board
// im selben Zug nach (`CLAUDE.md`).
//
// Zwei Regeln tragen fast jeden Satz hier:
//
//   · **Keine Diagnosen.** Jede Angabe ist als Schätzung gekennzeichnet,
//     und bei einem positiven Test steht der Verweis auf ärztliche
//     Abklärung.
//   · **Kein Tag wird je als „sicher" dargestellt** — auch nicht durch
//     Weglassen. Schwanger werden ist trotz Pille möglich.
library;

/// Die Schirmtitel.
const zyklusTitel = 'Zyklus';
const zyklusTagTitel = 'Tag eintragen';
const zyklusEinrichtenTitel = 'Zyklus';
const zyklusErinnerungenTitel = 'Erinnerungen';

/// Die Zeile am Fuß des Kalenders — **immer heute**. Sie nahm bis zum
/// 24.11.2026 das Datum des zuletzt angetippten Tages entgegen; dafür
/// musste der Kalender sich einen Tag merken, und der trug einen Ring,
/// den nichts wieder aufhob (#603). Nachgetragen wird über die Zelle des
/// Tages, nicht über diese Zeile.
const zyklusEintragenTitel = 'Heute eintragen';

const zyklusEintragenUnterzeile = 'Blutung, Schmerzen, Symptome, Sex, Test';

const zyklusEinstellungenTitel = 'Zyklus-Einstellungen';
const zyklusEinstellungenUnterzeile = 'Verhütung, Erinnerungen, Daten';

/// Die Lage nach einem positiven Test. `tag` ist der Tag des Tests.
const zyklusPausiertLeitwort = 'Vorhersage pausiert';
String zyklusPausiertText(String tag) =>
    'seit dem positiven Test am $tag. Was er bedeutet, klärt eine '
    'ärztliche Praxis.';

/// Der Pflichtsatz — steht **einmal** oben im Hilfe-Blatt, nicht unter
/// jeder Zahl (Tim, 23.11.2026).
const zyklusPflichtsatz =
    'Alles hier sind Schätzungen aus deinen bisherigen Zyklen — keine '
    'Verhütungsmethode und keine ärztliche Auskunft.';

/// Die Blöcke des Hilfe-Blatts auf dem Kalender.
const zyklusHilfeVolleKreiseTitel = 'Volle Kreise: eingetragen';
const zyklusHilfeVolleKreiseText =
    'Tage, an denen du eine Blutung eingetragen hast. Die kleine Zahl '
    'links oben ist der Zyklustag — Tag 1 ist der erste Tag der letzten '
    'Periode.';

const zyklusHilfeHelleKreiseTitel = 'Helle Kreise: vorhergesagt';
const zyklusHilfeHelleKreiseText =
    'Wann die nächste Blutung wahrscheinlich kommt, gerechnet aus dem '
    'Mittel deiner letzten sechs Zyklen. Die Tage davor und danach sind '
    'der Spielraum — die Vorhersage nennt keinen Tag, sondern einen '
    'Bereich.';

const zyklusHilfeEisprungTitel = 'Türkis: geschätzter Eisprung';
const zyklusHilfeEisprungText =
    'Etwa 14 Tage vor der nächsten Blutung, mit den fruchtbaren Tagen '
    'davor. Aus dem Kalender geschätzt, nicht gemessen — gemessen wird '
    'hier nichts.';

const zyklusHilfeVerhuetungTitel = 'Unter hormoneller Verhütung';
const zyklusHilfeVerhuetungText =
    'Die Pille unterdrückt den Eisprung normalerweise, deshalb stehen '
    'die türkisen Zeichen dann nur blass. Schwanger werden ist trotzdem '
    'möglich — bei Einnahmefehlern, Erbrechen, Durchfall oder bestimmten '
    'Medikamenten. Kein Tag im Kalender ist ein sicherer Tag.';

const zyklusHilfeMarkenTitel = 'Was unter einem Tag hängt';
const zyklusHilfeMarkenText =
    'Ein Herz heißt, dass dort Sex eingetragen ist; ein Punkt steht für '
    'Schmerzen oder Symptome. Was im Tag liegt, ist gerechnet — was '
    'darunter hängt, hast du eingetragen.';

/// Die Keine-Daten-Ansicht: Was steht, solange nichts vorherzusagen ist.
const zyklusKeineVorhersage = 'Noch keine Vorhersage';
const zyklusKeineVorhersageGrund =
    'Dafür braucht es zwei vollständige Zyklen. Trag ein, was ist — '
    'geraten wird hier nichts.';

/// Abschnitte auf „Tag eintragen".
const zyklusAbschnittBlutung = 'Blutung';
const zyklusAbschnittSchmerzen = 'Schmerzen';
const zyklusAbschnittSymptome = 'Symptome';
const zyklusAbschnittSex = 'Sex';
const zyklusAbschnittTest = 'Schwangerschaftstest';
const zyklusAbschnittNotiz = 'Notiz';

const zyklusNichtsGewaehlt = 'nichts gewählt';
const zyklusZwischenblutung = 'Zwischenblutung';
const zyklusSexGehabt = 'Sex gehabt';
const zyklusVerhuetet = 'Verhütet';
const zyklusTestNichtGemacht = 'nicht gemacht';
const zyklusNichtsNotiert = 'nichts notiert';

/// Bleibt sichtbar: was der Eintrag auslöst. Eine Wirkung auf einen
/// anderen Schirm hinter einem Fragezeichen wäre eine verschwiegene
/// Wirkung.
const zyklusTestWirkung = 'Pausiert die Vorhersage im Kalender';

/// Die Stufen — dieselben wie bei Apple, damit der Wert dort ohne
/// Umrechnung ankommt.
const zyklusStufen = ['keine', 'leicht', 'mittel', 'stark'];

/// Abschnitte auf „Zyklus einrichten".
const zyklusSchalterTitel = 'Zykluskalender';
const zyklusSchalterName = 'Zyklus';
const zyklusSchalterAn = 'Kalender unter „Mehr", Blutung, Symptome, Vorhersage';
const zyklusSchalterAus = 'Kalender, Einträge und Vorhersage sind ausgeblendet';

/// Bleibt sichtbar: eine Folge, die man vor dem Umlegen wissen muss.
const zyklusAusblendenFolge =
    'Ausblenden löscht nichts — nach dem Einschalten ist alles wieder da';

const zyklusImportTitel = 'Aus Apple Health';
const zyklusImportZeile = 'Blutungshistorie übernehmen';
const zyklusImportWartet = 'Gefunden, noch nicht übernommen';
const zyklusImportNichts = 'nichts gefunden';

/// Solange niemand in Health nachgesehen hat. **Nicht „nichts gefunden"**:
/// Ob dort etwas liegt, weiß die App dann nicht, und „keine Daten" und
/// „nicht erlaubt" sind bei HealthKit ohnehin nicht unterscheidbar
/// (`CLAUDE.md`).
const zyklusImportOffen = 'noch nicht nachgesehen';

/// Nach dem Erstimport. **Ohne Datum** — abgelegt ist nur, *ob* er lief
/// (Spec 4.3, `import_gelaufen` als Bool); ein Datum wäre erfunden.
const zyklusImportUebernommen = 'übernommen';

/// Wie viel Health hergibt, in Monaten.
String zyklusImportMonate(int monate) =>
    monate == 1 ? '1 Monat' : '$monate Monate';

const zyklusWofuerTitel = 'Wofür';
const zyklusSichtUeberblick = 'Überblick';
const zyklusSichtKinderwunsch = 'Kinderwunsch';

const zyklusVerhuetungTitel = 'Hormonelle Verhütung';
const zyklusVerhuetungName = 'Pille, Spirale, Ring oder Ähnliches';
const zyklusVerhuetungSeit = 'Seit';

/// Solange kein Zeitpunkt gewählt ist. **Keine Vorbelegung auf heute:**
/// Wer seit Jahren verhütet, bekäme sonst ein erfundenes Datum
/// untergeschoben, und genau daran hängt die Rückschau (Spec 3.7).
const zyklusVerhuetungDatumWaehlen = 'Datum wählen';

/// Die Tür zu den Erinnerungen (#589) — sie steht beim Verhütungsmittel,
/// weil Art und Takt dieselbe Angabe sind.
const zyklusErinnerungenMitVerhuetung = 'Verhütung, Periode, Eintragen';
const zyklusErinnerungenOhneVerhuetung = 'Periode und Eintragen';

const zyklusDatenTitel = 'Daten';
const zyklusLoeschen = 'Alle Zyklusdaten löschen';
const zyklusLoeschenFolge = 'Was schon in Apple Health steht, bleibt dort';

/// Was an eine Zeile gehängt wird, die es im Entwurf schon gibt und im
/// Code noch nicht — derselbe Satz wie im Mehr-Menü. Eine Zeile, die
/// aussieht wie ein Knopf und beim Tippen schweigt, ist der Fehler, den
/// `docs/screens/pruefen.mjs` eigens sucht.
const zyklusFolgtHinweis = ' — folgt in einer späteren Aufgabe.';

/// Die beiden Zeilen unter *Mehr* (#573). Untertitel **ohne Zahlen**, wie
/// alle dort: Ein gerechneter Untertitel brächte Tims Werte in den
/// Quelltext der Zeile (`CLAUDE.md`).
const zyklusMehrZeile = 'Zyklus';
const zyklusMehrUnterzeile = 'Kalender, Blutung, Symptome, Vorhersage';
const zyklusEinrichtenZeile = 'Zyklus einrichten';
const zyklusEinrichtenUnterzeile = 'Kalender, Verhütung, Erinnerungen, Daten';

/// Die Blöcke des Hilfe-Blatts auf „Zyklus einrichten" (Entwurf, Variante
/// `hilfe`). Fassung C: Die Fußtexte unter den Abschnitten sind weg;
/// sichtbar bleibt nur, was eine Folge hat.
const zyklusEinrichtenHilfeTitel = 'Zykluskalender';
const zyklusEinrichtenHilfePflicht =
    'Alle Vorhersagen sind Schätzungen aus deinen Zyklen — keine '
    'Verhütungsmethode und keine ärztliche Auskunft.';

const zyklusEinrichtenHilfeDazuTitel = 'Was eingeschaltet dazukommt';
const zyklusEinrichtenHilfeDazuText =
    'Der Kalender erscheint unter „Mehr“. Du trägst Blutung, Schmerzen, '
    'Symptome, Sex und Tests ein; aus den Zyklen schätzt die App, wann '
    'die nächste Blutung kommt.';

const zyklusEinrichtenHilfeOrtTitel = 'Wo die Daten liegen';
const zyklusEinrichtenHilfeOrtText =
    'Auf diesem iPhone. Sie wandern im iCloud-Gerätebackup mit, wie alle '
    'Daten dieser App — in kein Konto und auf keinen Server von uns.';

const zyklusEinrichtenHilfeSichtTitel = 'Wofür: Überblick oder Kinderwunsch';
const zyklusEinrichtenHilfeSichtText =
    'Gerechnet wird in beiden Fassungen dasselbe, nur die Betonung ist '
    'eine andere: Überblick zeigt das geschätzte Fenster in voller '
    'Breite, Kinderwunsch hebt die geschätzt besten Tage hervor.';

const zyklusEinrichtenHilfeVerhuetungTitel = 'Hormonelle Verhütung';
const zyklusEinrichtenHilfeVerhuetungText =
    'Die Blutungsvorhersage wird dadurch genauer — eine Abbruchblutung '
    'folgt dem Einnahmeschema. Der Eisprung dagegen wird üblicherweise '
    'unterdrückt und ist kaum zu schätzen; er steht im Kalender deshalb '
    'nur blass. Schwanger werden ist trotzdem möglich, und kein Tag im '
    'Kalender ist ein sicherer Tag.';

const zyklusEinrichtenHilfeImportTitel = 'Aus Apple Health übernehmen';
const zyklusEinrichtenHilfeImportText =
    'Läuft einmal und nimmt nur die Blutungstage — die tragen die '
    'Vorhersage. Symptome, Sex und Tests fangen hier an. Übernommenes '
    'wird nicht nach Health zurückgeschrieben, sonst stünde dort alles '
    'doppelt.';

/// Die beiden Beschriftungen der aufklappenden Zeilen auf „Tag eintragen".
const zyklusTestErgebnis = 'Ergebnis';
const zyklusNotizFreitext = 'Freitext';

/// Die Blöcke des Hilfe-Blatts auf „Tag eintragen" (Entwurf, Variante
/// `hilfe`). Fassung C: Was erklärt, steht hier — sichtbar bleibt nur, was
/// zu einem Feld gehört.
const zyklusTagHilfeTitel = 'Was hier hineingehört';
const zyklusTagHilfePflicht =
    'Alles hier ist dein Eintrag, keine Messung und keine ärztliche '
    'Auskunft.';

const zyklusTagHilfeBlutungTitel = 'Blutung';
const zyklusTagHilfeBlutungText =
    'Die Stufen sind dieselben wie in Apple Health (leicht, mittel, '
    'stark), damit der Wert dort ohne Umrechnung ankommt. Eine '
    'Zwischenblutung zählt nicht als Periodenstart — sie verschiebt die '
    'Vorhersage nicht.';

const zyklusTagHilfeJederTagTitel = 'Für jeden Tag, nicht nur für heute';
const zyklusTagHilfeJederTagText =
    'Im Kalender lässt sich jeder Tag antippen — auch einer, der schon '
    'vorbei ist. Was du gestern vergessen hast, trägst du so nach; oben '
    'steht dann dessen Datum.';

const zyklusTagHilfeNichtsTitel = 'Nichts gewählt heißt nicht eingetragen';
const zyklusTagHilfeNichtsText =
    'Ein Tag ohne Eintrag ist ein Tag ohne Eintrag, nicht ein Tag ohne '
    'Beschwerden. Darum ist nichts vorbelegt.';

const zyklusTagHilfeSymptomeTitel = 'Schmerzen und Symptome';
const zyklusTagHilfeSymptomeText =
    'Nur für dich und deine Verläufe — die App leitet daraus keine '
    'Empfehlung ab. Die Liste bildet Apples Symptomtypen ab, damit die '
    'Einträge nach Health geschrieben werden können; was dort fehlt, '
    'passt in die Notiz.';

const zyklusTagHilfeSexTitel = 'Sex';
const zyklusTagHilfeSexText =
    'Zwei Schalter, mehr fragt die App nicht. „Verhütet" steht dabei, '
    'weil die Antwort später zählt, wenn du deine Einträge durchsiehst.';

const zyklusTagHilfeTestTitel = 'Schwangerschaftstest';
const zyklusTagHilfeTestText =
    'Ein positives Ergebnis pausiert die Vorhersage im Kalender — '
    '„Blutung in 3 Tagen" wäre dann selbst eine falsche Auskunft. Was das '
    'Ergebnis bedeutet, klärt eine Ärztin oder ein Arzt; die App rechnet '
    'dazu nichts aus.';

/// Dasselbe als eigenständige Zeile, nicht als Anhängsel.
const zyklusFolgtZeile = 'folgt in einer späteren Aufgabe';
