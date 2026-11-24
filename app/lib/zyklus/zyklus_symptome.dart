// Der Symptomkatalog des Zykluskalenders (#572).
//
// **Fachinhalt, keine Oberflächenbeschriftung** — darum deutsche Namen
// im Code, wie beim Übungskatalog (`CLAUDE.md`, Abschnitt „Code"): Name
// und HealthKit-Zuordnung gehören zusammen, und wer das eine ohne das
// andere liest, kann den Eintrag nicht schreiben.
//
// Jeder Eintrag hat eine Entsprechung in Apples Symptomtypen, damit er
// nach Health geschrieben werden kann. Was dort keine hat, gehört in
// die Notiz — eine eigene Liste neben Apples wäre ein zweites
// Vokabular, das niemand pflegt.
//
// **Der Schlüssel ist Speicherformat.** Die Spalte `symptome` der
// Tabelle `zyklus_eintraege` speichert ihn kommagetrennt; wer einen
// Schlüssel umbenennt, macht jeden gespeicherten Tag unlesbar, der ihn
// trägt.
import 'package:flutter/foundation.dart';

@immutable
class ZyklusSymptom {
  const ZyklusSymptom({
    required this.schluessel,
    required this.name,
    required this.healthTyp,
  });

  /// Speicherformat — **nie ändern**, siehe Dateikopf.
  final String schluessel;

  /// Was die Nutzerin liest.
  final String name;

  /// Der `HKCategoryTypeIdentifier` ohne das Präfix
  /// `HKCategoryTypeIdentifier`.
  final String healthTyp;

  @override
  bool operator ==(Object other) =>
      other is ZyklusSymptom && other.schluessel == schluessel;

  @override
  int get hashCode => schluessel.hashCode;

  @override
  String toString() => 'ZyklusSymptom($schluessel)';
}

/// Die zwölf des Entwurfs, in der Reihenfolge des Boards
/// (`docs/screens/screens/zyklus-tag.js`).
///
/// Bewusst kurz gehalten: Apple kennt über vierzig Symptomtypen, und
/// eine Liste, durch die man scrollen muss, wird nicht benutzt. Welche
/// genau es sind, ist beim Gegenlesen noch zu entscheiden — die
/// Zuordnung unten ändert sich dann mit.
const List<ZyklusSymptom> zyklusSymptome = [
  ZyklusSymptom(
    schluessel: 'kraempfe',
    name: 'Krämpfe',
    healthTyp: 'AbdominalCramps',
  ),
  ZyklusSymptom(
    schluessel: 'kopfschmerzen',
    name: 'Kopfschmerzen',
    healthTyp: 'Headache',
  ),
  ZyklusSymptom(
    schluessel: 'rueckenschmerzen',
    name: 'Rückenschmerzen',
    healthTyp: 'LowerBackPain',
  ),
  ZyklusSymptom(
    schluessel: 'blaehbauch',
    name: 'Blähbauch',
    healthTyp: 'Bloating',
  ),
  ZyklusSymptom(
    schluessel: 'brustspannen',
    name: 'Brustspannen',
    healthTyp: 'BreastPain',
  ),
  ZyklusSymptom(
    schluessel: 'uebelkeit',
    name: 'Übelkeit',
    healthTyp: 'Nausea',
  ),
  ZyklusSymptom(
    schluessel: 'muedigkeit',
    name: 'Müdigkeit',
    healthTyp: 'Fatigue',
  ),
  ZyklusSymptom(
    schluessel: 'heisshunger',
    name: 'Heißhunger',
    healthTyp: 'AppetiteChanges',
  ),
  ZyklusSymptom(
    schluessel: 'stimmung',
    name: 'Stimmungsschwankungen',
    healthTyp: 'MoodChanges',
  ),
  ZyklusSymptom(
    schluessel: 'schlafstoerungen',
    name: 'Schlafstörungen',
    healthTyp: 'SleepChanges',
  ),
  ZyklusSymptom(schluessel: 'akne', name: 'Akne', healthTyp: 'Acne'),
  ZyklusSymptom(
    schluessel: 'schwindel',
    name: 'Schwindel',
    healthTyp: 'Dizziness',
  ),
];

/// Das Symptom zu einem gespeicherten Schlüssel, oder `null`.
///
/// **Unbekannte Schlüssel werden übergangen, nicht geworfen** — eine
/// ältere Fassung der App könnte einen Schlüssel geschrieben haben, den
/// es nicht mehr gibt, und ein Tag mit einem unbekannten Symptom ist
/// immer noch ein lesbarer Tag.
ZyklusSymptom? symptomZu(String schluessel) {
  for (final symptom in zyklusSymptome) {
    if (symptom.schluessel == schluessel) return symptom;
  }
  return null;
}

/// Die Schlüssel als Speicherform: kommagetrennt, in Katalogreihenfolge.
String symptomeAlsText(Iterable<String> schluessel) {
  final gewaehlt = schluessel.toSet();
  return zyklusSymptome
      .where((s) => gewaehlt.contains(s.schluessel))
      .map((s) => s.schluessel)
      .join(',');
}

/// Zurück aus der Speicherform. Leere und unbekannte Schlüssel fallen
/// heraus.
List<String> symptomeAusText(String? text) {
  if (text == null || text.isEmpty) return const [];
  return text
      .split(',')
      .where((s) => s.isNotEmpty && symptomZu(s) != null)
      .toList();
}
