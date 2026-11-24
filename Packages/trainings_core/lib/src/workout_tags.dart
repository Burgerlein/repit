// Tags eines Trainings: normalisieren, hinzufügen, vorschlagen (#532,
// Spec 5.6).

/// Tags sind frei mit Vorschlägen (Tim, 18.11.2026). **Welche** es gibt, steht
/// nirgends im Quelltext: „Gym" kommt nur aus den Templates, „Home" nur, wo
/// jemand es getippt hat.
abstract final class WorkoutTags {
  /// Höchstzahl der Tags je Training. Die Zahl ist ein Vorschlag der Spec,
  /// keine Entscheidung des Nutzers.
  static const int maxCount = 5;

  /// Höchstlänge eines Tags in Zeichen — Vorschlag der Spec.
  static const int maxLength = 20;

  static final RegExp _whitespace = RegExp(r'\s+');

  /// Trimmen, innere Leerraum-Folgen auf ein Leerzeichen; leer oder länger
  /// als [maxLength] ergibt `null`.
  ///
  /// **Gekürzt wird nie:** Kürzen ist Raten, aus einem langen Tag würde einer,
  /// den niemand getippt hat. Gezählt wird nach dem Zusammenziehen.
  /// Groß-/Kleinschreibung bleibt, wie getippt.
  static String? normalize(String raw) {
    final tag = raw.trim().replaceAll(_whitespace, ' ');
    if (tag.isEmpty || tag.length > maxLength) return null;
    return tag;
  }

  /// Hängt [raw] normalisiert ans Ende einer **neuen** Liste.
  ///
  /// Es ändert sich nichts, wenn [raw] sich nicht normalisieren lässt, der
  /// Tag (ohne Beachtung der Schreibweise) schon dasteht — die zuerst
  /// geschriebene Schreibweise gewinnt — oder schon [maxCount] Tags da sind.
  /// [tags] selbst bleibt unverändert, auch eine unveränderliche Liste ist
  /// kein Hindernis.
  static List<String> add(List<String> tags, String raw) {
    final tag = normalize(raw);
    if (tag == null) return List.of(tags);
    if (tags.length >= maxCount) return List.of(tags);
    final key = tag.toLowerCase();
    if (tags.any((vorhanden) => vorhanden.toLowerCase() == key)) {
      return List.of(tags);
    }
    return [...tags, tag];
  }

  /// Die schon benutzten Tags, die noch nicht in [current] stehen:
  /// **absteigend nach Häufigkeit, bei Gleichstand alphabetisch** ohne
  /// Beachtung der Schreibweise.
  ///
  /// [used] zählt die Tags lebender Trainings — Entwürfe zählen, Tombstones
  /// nicht; das entscheidet, wer [used] baut. Die Vorschläge tragen die
  /// Schreibweise aus [used]. Die Sortierung ist ein Vorschlag der Spec.
  static List<String> suggestions({
    required Map<String, int> used,
    required List<String> current,
  }) {
    final schon = {for (final tag in current) tag.toLowerCase()};
    final kandidaten = used.entries
        .where((eintrag) => !schon.contains(eintrag.key.toLowerCase()))
        .toList();
    kandidaten.sort((a, b) {
      final haeufigkeit = b.value.compareTo(a.value);
      if (haeufigkeit != 0) return haeufigkeit;
      final alphabet = a.key.toLowerCase().compareTo(b.key.toLowerCase());
      if (alphabet != 0) return alphabet;
      // Nur Schreibweisen desselben Tags: eine feste Reihenfolge statt
      // einer, die von der Map abhängt.
      return a.key.compareTo(b.key);
    });
    return [for (final eintrag in kandidaten) eintrag.key];
  }
}
