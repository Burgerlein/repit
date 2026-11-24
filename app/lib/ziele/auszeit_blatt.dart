// Das Blatt „Auszeit eintragen“ / „Auszeit ändern“ (#448 unter #404).
//
// Verhalten durch `app/test/ziele/ziele_view_test.dart` vorgegeben (siehe
// dessen Dateikopf) — diese Datei darf die Tests ausführen, aber nicht
// verändern (`CLAUDE.md`). Aufbau nach `docs/screens/screens/auszeit.js`
// (`FORM`, Zustände `op` und `urlaub`), Begründungen in der Auszeit-Spec
// in `docs/superpowers/specs/` (V4–V7, V19).
//
// **Die Formularlogik steht in [AuszeitFormular]**, nicht hier: Vorbelegung,
// Nachziehen des Endes und die Notiz sind dort ohne Widget geprüft. Dieses
// Blatt zeichnet nur, was das Formular sagt.
//
// **Ein Blatt, kein Schirm** (`showCupertinoModalPopup`): Es landet nicht
// im Navigationsstapel eines Tabs, und `AppRouter` ist nicht beteiligt.
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:trainings_core/trainings_core.dart';

import '../data/ereignisse.dart';
import '../design/palette.dart';
import '../live/live_provider.dart';
import 'auszeit_formular.dart';
import 'auszeit_texte.dart';
import 'ziele_bausteine.dart';

/// Öffnet das Blatt. Ohne [ereignis] „Auszeit eintragen“, vorbelegt mit
/// einer OP ab dem Esstag; mit [ereignis] „Auszeit ändern“, vorbelegt mit
/// ihm und mit „Auszeit löschen“ am Ende (V7).
Future<void> zeigeAuszeitBlatt(BuildContext context, {Ereignis? ereignis}) =>
    showCupertinoModalPopup<void>(
      context: context,
      builder: (_) =>
          _AuszeitBlatt(key: const Key('auszeit-blatt'), ereignis: ereignis),
    );

/// Welches Datumsrad offen ist — höchstens eins (V19).
enum _Rad { von, bis }

class _AuszeitBlatt extends ConsumerStatefulWidget {
  const _AuszeitBlatt({super.key, required this.ereignis});

  final Ereignis? ereignis;

  @override
  ConsumerState<_AuszeitBlatt> createState() => _AuszeitBlattZustand();
}

class _AuszeitBlattZustand extends ConsumerState<_AuszeitBlatt> {
  /// Der Esstag beim Öffnen — Vorbelegung und „mit Jahr oder ohne“.
  late final String _heute = ref.read(esstagProvider);

  late AuszeitFormular _formular = switch (widget.ereignis) {
    final e? => AuszeitFormular.fuer(e),
    null => AuszeitFormular.neu(heute: _heute),
  };

  late final TextEditingController _notiz = TextEditingController(
    text: widget.ereignis?.notiz ?? '',
  );

  _Rad? _offen;

  /// Läuft gerade ein Schreibzugriff — dann sind Sichern und Löschen aus,
  /// sonst legte ein zweiter Tipp eine zweite Zeile an.
  bool _laeuft = false;

  /// Das letzte Schreiben ist gescheitert. Das Blatt bleibt dann offen und
  /// sagt es, statt still zu verschwinden.
  bool _gescheitert = false;

  bool get _istAenderung => widget.ereignis != null;

  @override
  void dispose() {
    _notiz.dispose();
    super.dispose();
  }

  Future<void> _sichere() async {
    final alt = widget.ereignis;
    final ereignis = _formular
        .mitNotiz(_notiz.text)
        .alsEreignis(id: alt?.id, angelegt: alt?.angelegt);
    final notifier = ref.read(ereignisseProvider.notifier);
    setState(() {
      _laeuft = true;
      _gescheitert = false;
    });
    try {
      if (alt == null) {
        await notifier.legeAn(ereignis);
      } else {
        await notifier.aendere(ereignis);
      }
    } on Object {
      if (!mounted) return;
      setState(() {
        _laeuft = false;
        _gescheitert = true;
      });
      return;
    }
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _loesche() async {
    final id = widget.ereignis?.id;
    if (id == null) return;
    final notifier = ref.read(ereignisseProvider.notifier);
    final loeschen = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialog) => CupertinoAlertDialog(
        title: const Text('Auszeit löschen?'),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialog).pop(false),
            child: const Text('Abbrechen'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialog).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );
    if (loeschen != true || !mounted) return;
    setState(() {
      _laeuft = true;
      _gescheitert = false;
    });
    try {
      await notifier.loesche(id);
    } on Object {
      if (!mounted) return;
      setState(() {
        _laeuft = false;
        _gescheitert = true;
      });
      return;
    }
    // Ein offenes Ändern-Blatt für ein gelöschtes Ereignis gäbe es nicht
    // mehr zu sichern.
    if (mounted) Navigator.of(context).pop();
  }

  void _klappe(_Rad rad) =>
      setState(() => _offen = _offen == rad ? null : rad);

  @override
  Widget build(BuildContext context) {
    final medien = MediaQuery.of(context);
    final art = _formular.art;
    return Container(
      // Feste Höhe wie `sheet` im Entwurf: Ein Blatt, das mit seinem Inhalt
      // wächst, spränge beim Aufklappen des Rades.
      height: medien.size.height * 0.64,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(Palette.bg, context),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 15,
          color: CupertinoDynamicColor.resolve(Palette.ink, context),
        ),
        child: Column(
          children: [
            const _Griff(),
            _Leiste(
              titel: _istAenderung ? 'Auszeit ändern' : 'Auszeit eintragen',
              abbrechen: () => Navigator.of(context).pop(),
              sichern: _laeuft ? null : _sichere,
            ),
            Expanded(
              child: SingleChildScrollView(
                // Unten durchzeichnen statt abschneiden: Die
                // halbtransparente Tastatur legt sich darüber
                // (flutter#179482).
                padding: EdgeInsets.only(bottom: 18 + medien.viewInsets.bottom),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_gescheitert)
                      const ZieleNotiz(
                        ton: ZieleTon.warnung,
                        text: 'Das ließ sich gerade nicht speichern. Die '
                            'Eingaben stehen noch da — versuch es noch '
                            'einmal.',
                      ),
                    const ZieleFormKopf('Art'),
                    _Umschalter(
                      art: art,
                      aufWahl: (neu) => setState(
                        () => _formular = _formular.mitArt(neu),
                      ),
                    ),
                    ZieleFormFuss(auszeitWirkung(art)),
                    const ZieleFormKopf('Zeitraum'),
                    _zeitraum(),
                    ZieleFormFuss(
                      art == EreignisArt.op ? auszeitFussOp : auszeitFussSonst,
                    ),
                    const ZieleFormKopf('Notiz'),
                    _notizKarte(),
                    if (pausiertKoerperziel(art))
                      const ZieleNotiz(
                        key: Key('auszeit-freigabe'),
                        ton: ZieleTon.warnung,
                        text: auszeitFreigabe,
                        rand: EdgeInsets.fromLTRB(16, 14, 16, 0),
                      ),
                    if (_istAenderung) ...[
                      const SizedBox(height: 22),
                      ZieleFormKarte(
                        zeilen: [
                          CupertinoButton(
                            key: const Key('auszeit-loeschen'),
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            onPressed: _laeuft ? null : _loesche,
                            child: Text(
                              'Auszeit löschen',
                              style: TextStyle(
                                fontSize: 15,
                                color: CupertinoDynamicColor.resolve(
                                  Palette.warn,
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zeitraum() {
    final art = _formular.art;
    return ZieleFormKarte(
      zeilen: [
        _DatumsZeile(
          key: const Key('auszeit-von'),
          titel: auszeitVonTitel(art),
          wert: auszeitFormDatum(_formular.von, heute: _heute),
          offen: _offen == _Rad.von,
          onTap: () => _klappe(_Rad.von),
        ),
        if (_offen == _Rad.von)
          _DatumsRad(
            key: const ValueKey('rad-von'),
            tag: _formular.von,
            aufWahl: (tag) =>
                setState(() => _formular = _formular.mitVon(tag)),
          ),
        _DatumsZeile(
          key: const Key('auszeit-bis'),
          titel: auszeitBisTitel(art),
          wert: auszeitFormDatum(_formular.bis, heute: _heute),
          offen: _offen == _Rad.bis,
          onTap: () => _klappe(_Rad.bis),
        ),
        if (_offen == _Rad.bis)
          _DatumsRad(
            key: const ValueKey('rad-bis'),
            tag: _formular.bis,
            // Das Rad für das Ende beginnt beim Beginn (V5).
            frueheste: _formular.von,
            aufWahl: (tag) =>
                setState(() => _formular = _formular.mitBis(tag)),
          ),
      ],
    );
  }

  Widget _notizKarte() => ZieleFormKarte(
    zeilen: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 2, 8, 2),
        child: Row(
          children: [
            const Text('Notiz'),
            const SizedBox(width: 10),
            Expanded(
              // Einzeilig und frei (V6); getrimmt wird im Formular.
              child: CupertinoTextField.borderless(
                key: const Key('auszeit-notiz'),
                controller: _notiz,
                placeholder: '–',
                textAlign: TextAlign.end,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                style: TextStyle(
                  color: CupertinoDynamicColor.resolve(Palette.river, context),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _Griff extends StatelessWidget {
  const _Griff();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Container(
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.resolve(Palette.line, context),
        borderRadius: BorderRadius.circular(3),
      ),
    ),
  );
}

/// Die Leiste: „Abbrechen“ links, Titel, „Sichern“ rechts. „Sichern“ ist
/// immer möglich (V5) — außer während des Schreibens.
class _Leiste extends StatelessWidget {
  const _Leiste({
    required this.titel,
    required this.abbrechen,
    required this.sichern,
  });

  final String titel;
  final VoidCallback abbrechen;
  final VoidCallback? sichern;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
    child: Row(
      children: [
        SizedBox(
          width: 96,
          child: Align(
            alignment: Alignment.centerLeft,
            child: CupertinoButton(
              key: const Key('auszeit-abbrechen'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
              onPressed: abbrechen,
              child: const Text('Abbrechen', style: TextStyle(fontSize: 15)),
            ),
          ),
        ),
        Expanded(
          child: Text(
            titel,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        SizedBox(
          width: 96,
          child: Align(
            alignment: Alignment.centerRight,
            child: CupertinoButton(
              key: const Key('auszeit-sichern'),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(44, 36),
              onPressed: sichern,
              child: const Text(
                'Sichern',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

/// Der Umschalter OP · Krankheit · Verletzung · Urlaub.
class _Umschalter extends StatelessWidget {
  const _Umschalter({required this.art, required this.aufWahl});

  final EreignisArt art;
  final ValueChanged<EreignisArt> aufWahl;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: CupertinoSlidingSegmentedControl<EreignisArt>(
      groupValue: art,
      onValueChanged: (neu) {
        if (neu != null) aufWahl(neu);
      },
      children: {
        for (final a in EreignisArt.values)
          a: Padding(
            key: Key('auszeit-art-${a.name}'),
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(
              auszeitArtKurz(a),
              maxLines: 1,
              style: const TextStyle(fontSize: 13.5),
            ),
          ),
      },
    ),
  );
}

/// `formRow` — Beschriftung links, Datum rechts, Winkel. Ein Tipp klappt
/// das Rad darunter auf oder zu (V19).
class _DatumsZeile extends StatelessWidget {
  const _DatumsZeile({
    super.key,
    required this.titel,
    required this.wert,
    required this.offen,
    required this.onTap,
  });

  final String titel;
  final String wert;
  final bool offen;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = CupertinoDynamicColor.resolve(Palette.muted, context);
    return Semantics(
      button: true,
      expanded: offen,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(
            children: [
              Text(titel),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  wert,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: CupertinoDynamicColor.resolve(Palette.river, context),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                offen
                    ? CupertinoIcons.chevron_up
                    : CupertinoIcons.chevron_down,
                size: 11,
                color: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Das Datumsrad, Modus Datum (V19).
///
/// **Der ISO-Tag kommt aus den Kalenderfeldern des Rades** — wer den
/// Zeitpunkt nach UTC dreht, verschiebt den Tag um einen (`CLAUDE.md`, „Der
/// Datumsschlüssel ist der ISO-Tagesstring“). Hinein geht er als Ortszeit:
/// `CupertinoDatePicker` rechnet mit lokalen Kalendertagen.
class _DatumsRad extends StatelessWidget {
  const _DatumsRad({
    super.key,
    required this.tag,
    required this.aufWahl,
    this.frueheste,
  });

  final String tag;
  final String? frueheste;
  final ValueChanged<String> aufWahl;

  static DateTime _lokal(String tag) {
    final d = auszeitAlsDatum(tag);
    return DateTime(d.year, d.month, d.day);
  }

  static String _iso(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final frueheste = this.frueheste;
    return SizedBox(
      height: 180,
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        initialDateTime: _lokal(tag),
        minimumDate: frueheste == null ? null : _lokal(frueheste),
        onDateTimeChanged: (wert) => aufWahl(_iso(wert)),
      ),
    );
  }
}
