import 'package:trainings_core/trainings_core.dart';

// Die vorbelegten Gemini-Preise (#337). Spec
// „KI-Zugang und Foto-Schätzung" (`docs/superpowers/specs/`), „Verbrauch und
// Limit".
//
// **Stand dieser App-Fassung.** Google gibt Preise nicht über die
// Schnittstelle heraus, und sie ändern sich — für die Flash-Modelle ist
// bereits eine Erhöhung angekündigt. Darum sind sie hier nur vorbelegt;
// Tims Überschreibungen in den Einstellungen gehen vor ([preisFuer]).
// **Kein Datum im Quelltext** (`CLAUDE.md`, „Keine hartcodierten
// Ereignisse"); wann die Zahlen abgelesen wurden, steht in der
// Commit-Nachricht.
//
// Standard-Stufe (bezahlt), Eingabe bis 200k Token, Text/Bild/Video, in
// US-Dollar je 1.000.000 Token. Denk-Token kosten den Ausgabepreis
// (`kostenUsd` im Kern).
//
// Nicht aufgenommen: Vorschau-Modelle (nie Voreinstellung, Preise wechseln
// häufig) und abgekündigte Modelle, die Google auf andere umleitet und zu
// deren Preis berechnet — für sie stünde hier ein Betrag, den Google nicht
// mehr verlangt. Ein Modell ohne Preis zeigt den Betrag als `–/–`.

/// Das Modell, das gilt, solange Tim keines gewählt hat. Stabil, nimmt
/// Bilder; ein Vorschau-Modell ist nie Voreinstellung (Spec).
const String voreingestelltesModell = 'gemini-3.6-flash';

/// Die vorbelegten Preise je Modellname (ohne `models/`).
const Map<String, KiPreis> vorbelegtePreise = {
  'gemini-3.8-flash': KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75),
  'gemini-3.6-flash': KiPreis(eingabeJeMio: 0.75, ausgabeJeMio: 3.75),
  'gemini-3.5-flash-lite': KiPreis(eingabeJeMio: 0.30, ausgabeJeMio: 2.50),
  'gemini-3.1-flash-lite': KiPreis(eingabeJeMio: 0.25, ausgabeJeMio: 1.50),
  'gemini-2.5-flash-lite': KiPreis(eingabeJeMio: 0.10, ausgabeJeMio: 0.40),
};

/// Der Preis für [modell]: Tims eigener aus [eigene], sonst der vorbelegte,
/// sonst `null` — kein Preis heißt Betrag `–/–`, nicht `0 $`.
KiPreis? preisFuer(String modell, Map<String, KiPreis> eigene) =>
    eigene[modell] ?? vorbelegtePreise[modell];
