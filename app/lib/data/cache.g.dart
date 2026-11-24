// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cache.dart';

// ignore_for_file: type=lint
class $TagesWerteTable extends TagesWerte
    with TableInfo<$TagesWerteTable, TagesWerteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TagesWerteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schritteMeta = const VerificationMeta(
    'schritte',
  );
  @override
  late final GeneratedColumn<int> schritte = GeneratedColumn<int>(
    'schritte',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruhepulsBpmMeta = const VerificationMeta(
    'ruhepulsBpm',
  );
  @override
  late final GeneratedColumn<int> ruhepulsBpm = GeneratedColumn<int>(
    'ruhepuls_bpm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gelesenAmMeta = const VerificationMeta(
    'gelesenAm',
  );
  @override
  late final GeneratedColumn<DateTime> gelesenAm = GeneratedColumn<DateTime>(
    'gelesen_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrvMsMeta = const VerificationMeta('hrvMs');
  @override
  late final GeneratedColumn<double> hrvMs = GeneratedColumn<double>(
    'hrv_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _respRateMeta = const VerificationMeta(
    'respRate',
  );
  @override
  late final GeneratedColumn<double> respRate = GeneratedColumn<double>(
    'resp_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recoveryHrDropMeta = const VerificationMeta(
    'recoveryHrDrop',
  );
  @override
  late final GeneratedColumn<int> recoveryHrDrop = GeneratedColumn<int>(
    'recovery_hr_drop',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gewichtKgMeta = const VerificationMeta(
    'gewichtKg',
  );
  @override
  late final GeneratedColumn<double> gewichtKg = GeneratedColumn<double>(
    'gewicht_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _trainingsMinutenMeta = const VerificationMeta(
    'trainingsMinuten',
  );
  @override
  late final GeneratedColumn<double> trainingsMinuten = GeneratedColumn<double>(
    'trainings_minuten',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _koerperfettPctMeta = const VerificationMeta(
    'koerperfettPct',
  );
  @override
  late final GeneratedColumn<double> koerperfettPct = GeneratedColumn<double>(
    'koerperfett_pct',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fettfreiKgMeta = const VerificationMeta(
    'fettfreiKg',
  );
  @override
  late final GeneratedColumn<double> fettfreiKg = GeneratedColumn<double>(
    'fettfrei_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _vo2maxMeta = const VerificationMeta('vo2max');
  @override
  late final GeneratedColumn<double> vo2max = GeneratedColumn<double>(
    'vo2max',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    schritte,
    ruhepulsBpm,
    gelesenAm,
    hrvMs,
    respRate,
    recoveryHrDrop,
    gewichtKg,
    trainingsMinuten,
    koerperfettPct,
    fettfreiKg,
    vo2max,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tages_werte';
  @override
  VerificationContext validateIntegrity(
    Insertable<TagesWerteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('schritte')) {
      context.handle(
        _schritteMeta,
        schritte.isAcceptableOrUnknown(data['schritte']!, _schritteMeta),
      );
    }
    if (data.containsKey('ruhepuls_bpm')) {
      context.handle(
        _ruhepulsBpmMeta,
        ruhepulsBpm.isAcceptableOrUnknown(
          data['ruhepuls_bpm']!,
          _ruhepulsBpmMeta,
        ),
      );
    }
    if (data.containsKey('gelesen_am')) {
      context.handle(
        _gelesenAmMeta,
        gelesenAm.isAcceptableOrUnknown(data['gelesen_am']!, _gelesenAmMeta),
      );
    }
    if (data.containsKey('hrv_ms')) {
      context.handle(
        _hrvMsMeta,
        hrvMs.isAcceptableOrUnknown(data['hrv_ms']!, _hrvMsMeta),
      );
    }
    if (data.containsKey('resp_rate')) {
      context.handle(
        _respRateMeta,
        respRate.isAcceptableOrUnknown(data['resp_rate']!, _respRateMeta),
      );
    }
    if (data.containsKey('recovery_hr_drop')) {
      context.handle(
        _recoveryHrDropMeta,
        recoveryHrDrop.isAcceptableOrUnknown(
          data['recovery_hr_drop']!,
          _recoveryHrDropMeta,
        ),
      );
    }
    if (data.containsKey('gewicht_kg')) {
      context.handle(
        _gewichtKgMeta,
        gewichtKg.isAcceptableOrUnknown(data['gewicht_kg']!, _gewichtKgMeta),
      );
    }
    if (data.containsKey('trainings_minuten')) {
      context.handle(
        _trainingsMinutenMeta,
        trainingsMinuten.isAcceptableOrUnknown(
          data['trainings_minuten']!,
          _trainingsMinutenMeta,
        ),
      );
    }
    if (data.containsKey('koerperfett_pct')) {
      context.handle(
        _koerperfettPctMeta,
        koerperfettPct.isAcceptableOrUnknown(
          data['koerperfett_pct']!,
          _koerperfettPctMeta,
        ),
      );
    }
    if (data.containsKey('fettfrei_kg')) {
      context.handle(
        _fettfreiKgMeta,
        fettfreiKg.isAcceptableOrUnknown(data['fettfrei_kg']!, _fettfreiKgMeta),
      );
    }
    if (data.containsKey('vo2max')) {
      context.handle(
        _vo2maxMeta,
        vo2max.isAcceptableOrUnknown(data['vo2max']!, _vo2maxMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag};
  @override
  TagesWerteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TagesWerteRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      schritte: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schritte'],
      ),
      ruhepulsBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ruhepuls_bpm'],
      ),
      gelesenAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gelesen_am'],
      ),
      hrvMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hrv_ms'],
      ),
      respRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resp_rate'],
      ),
      recoveryHrDrop: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}recovery_hr_drop'],
      ),
      gewichtKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gewicht_kg'],
      ),
      trainingsMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}trainings_minuten'],
      ),
      koerperfettPct: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}koerperfett_pct'],
      ),
      fettfreiKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fettfrei_kg'],
      ),
      vo2max: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vo2max'],
      ),
    );
  }

  @override
  $TagesWerteTable createAlias(String alias) {
    return $TagesWerteTable(attachedDatabase, alias);
  }
}

class TagesWerteRow extends DataClass implements Insertable<TagesWerteRow> {
  final String tag;
  final int? schritte;
  final int? ruhepulsBpm;

  /// Wann diese Zeile aus Apple Health geholt wurde — `null`, solange
  /// unbekannt (etwa nach einer Migration aus Schema v1, das diese Spalte
  /// noch nicht kannte). Der Stand je Zeile aus Spec 5.3b, nicht ein
  /// globaler Zeitstempel für den ganzen Cache: Task 13 braucht ihn je
  /// Zeile für `Bekannt(…, stand: …)`.
  final DateTime? gelesenAm;

  /// Herzfrequenzvariabilität in Millisekunden (Schema v3, #113) —
  /// `DailyMetrics.hrvMs`. Nullbar wie jede Metrikspalte: An einem Tag ohne
  /// Uhr am Handgelenk gibt es diesen Wert schlicht nicht, und „0 ms HRV"
  /// wäre ein Alarmwert, kein fehlender Wert.
  final double? hrvMs;

  /// Atemfrequenz je Minute (Schema v3, #113) — `DailyMetrics.respRate`.
  final double? respRate;

  /// Puls-Erholung in Schlägen (Schema v3, #113) —
  /// `DailyMetrics.recoveryHRDrop`. Der Spaltenname schreibt sich mit
  /// kleinem `r` (`recovery_hr_drop`), damit drifts Standard-Snake-Case und
  /// der `.named(...)`-Wert dieselbe Form haben.
  final int? recoveryHrDrop;

  /// Körpergewicht in Kilogramm (Schema v7, #194) — `DailyMetrics.weightKg`.
  /// Bis dahin hatte dieses Feld keine Spalte und kam aus dem Cache **immer**
  /// `null` zurück; die Gewichtskachel stand nach jedem Kaltstart deshalb
  /// erst leer da. Nullbar wie jede Metrikspalte: An einem Tag ohne Waage
  /// gibt es diesen Wert nicht, und „0 kg" wäre keine fehlende Messung,
  /// sondern eine absurde.
  final double? gewichtKg;

  /// Trainingsminuten (Schema v7, #194) — `DailyMetrics.exerciseMinutes`.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.exerciseMinutes` ist
  /// `double?`. Eine Ganzzahlspalte zwänge die Brücke zu runden, und das
  /// wäre eine stille Veränderung von Tims Daten auf dem Weg in den Cache.
  /// Nullbar: Kein Wert heißt „nicht gemessen", nicht „0 Minuten
  /// trainiert" — ein Ring auf 0 behauptet „nichts getan" (Fehler `01`).
  final double? trainingsMinuten;

  /// Körperfettanteil in Prozent (Schema v7, #202) —
  /// `DailyMetrics.bodyFatPct`. Wie bei `gewichtKg` fehlte bis dahin die
  /// Spalte, der Wert kam aus dem Cache also **immer** `null` zurück, und
  /// die Körperfett-Kachel stand nach jedem Kaltstart erst leer da.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.bodyFatPct` ist
  /// `double?`, und ein gerundeter Prozentwert wäre eine stille Veränderung
  /// von Tims Daten auf dem Weg in den Cache. Nullbar: An einem Tag ohne
  /// Waage gibt es diesen Wert nicht, und „0,0 % Körperfett" wäre keine
  /// fehlende Messung, sondern eine absurde (Fehler `01`).
  final double? koerperfettPct;

  /// Fettfreie Masse in Kilogramm (Schema v7, #202) —
  /// `DailyMetrics.leanKg`. Dieselbe Begründung wie bei [koerperfettPct]:
  /// `double?` im Kanal, also `RealColumn`, und nullbar, weil „0 kg
  /// Muskelmasse" keine Messung ist.
  final double? fettfreiKg;

  /// VO₂max in ml/kg/min (Schema v26, #95) — `DailyMetrics.vo2max`. Bis
  /// dahin hatte dieses Feld keine Spalte und kam aus dem Cache **immer**
  /// `null` zurück (geerbte Schemagrenze aus Task 6); die VO₂max-Anzeige
  /// des Ausdauer-Schirms stünde nach jedem Kaltstart erst leer da.
  ///
  /// **Kein `.named(…)`:** drifts Standard-Snake-Case von `vo2max` ist
  /// `vo2max` selbst — anders als bei [recoveryHrDrop] haben Standard und
  /// Wunschname dieselbe Form.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** `DailyMetrics.vo2max` ist
  /// `double?`; eine Ganzzahlspalte zwänge die Brücke zu runden, und
  /// gerundete ml/kg/min wären eine stille Veränderung von Tims Daten auf
  /// dem Weg in den Cache. Nullbar wie jede Metrikspalte: An einem Tag
  /// ohne Ausdauereinheit mit der Uhr gibt es diesen Wert schlicht nicht,
  /// und „VO₂max 0" wäre keine fehlende Messung, sondern eine absurde
  /// (Fehler `01`). Kein Vorgabewert — eine Vorgabe erfände eine Messung,
  /// die niemand gemacht hat.
  final double? vo2max;
  const TagesWerteRow({
    required this.tag,
    this.schritte,
    this.ruhepulsBpm,
    this.gelesenAm,
    this.hrvMs,
    this.respRate,
    this.recoveryHrDrop,
    this.gewichtKg,
    this.trainingsMinuten,
    this.koerperfettPct,
    this.fettfreiKg,
    this.vo2max,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || schritte != null) {
      map['schritte'] = Variable<int>(schritte);
    }
    if (!nullToAbsent || ruhepulsBpm != null) {
      map['ruhepuls_bpm'] = Variable<int>(ruhepulsBpm);
    }
    if (!nullToAbsent || gelesenAm != null) {
      map['gelesen_am'] = Variable<DateTime>(gelesenAm);
    }
    if (!nullToAbsent || hrvMs != null) {
      map['hrv_ms'] = Variable<double>(hrvMs);
    }
    if (!nullToAbsent || respRate != null) {
      map['resp_rate'] = Variable<double>(respRate);
    }
    if (!nullToAbsent || recoveryHrDrop != null) {
      map['recovery_hr_drop'] = Variable<int>(recoveryHrDrop);
    }
    if (!nullToAbsent || gewichtKg != null) {
      map['gewicht_kg'] = Variable<double>(gewichtKg);
    }
    if (!nullToAbsent || trainingsMinuten != null) {
      map['trainings_minuten'] = Variable<double>(trainingsMinuten);
    }
    if (!nullToAbsent || koerperfettPct != null) {
      map['koerperfett_pct'] = Variable<double>(koerperfettPct);
    }
    if (!nullToAbsent || fettfreiKg != null) {
      map['fettfrei_kg'] = Variable<double>(fettfreiKg);
    }
    if (!nullToAbsent || vo2max != null) {
      map['vo2max'] = Variable<double>(vo2max);
    }
    return map;
  }

  TagesWerteCompanion toCompanion(bool nullToAbsent) {
    return TagesWerteCompanion(
      tag: Value(tag),
      schritte: schritte == null && nullToAbsent
          ? const Value.absent()
          : Value(schritte),
      ruhepulsBpm: ruhepulsBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(ruhepulsBpm),
      gelesenAm: gelesenAm == null && nullToAbsent
          ? const Value.absent()
          : Value(gelesenAm),
      hrvMs: hrvMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hrvMs),
      respRate: respRate == null && nullToAbsent
          ? const Value.absent()
          : Value(respRate),
      recoveryHrDrop: recoveryHrDrop == null && nullToAbsent
          ? const Value.absent()
          : Value(recoveryHrDrop),
      gewichtKg: gewichtKg == null && nullToAbsent
          ? const Value.absent()
          : Value(gewichtKg),
      trainingsMinuten: trainingsMinuten == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingsMinuten),
      koerperfettPct: koerperfettPct == null && nullToAbsent
          ? const Value.absent()
          : Value(koerperfettPct),
      fettfreiKg: fettfreiKg == null && nullToAbsent
          ? const Value.absent()
          : Value(fettfreiKg),
      vo2max: vo2max == null && nullToAbsent
          ? const Value.absent()
          : Value(vo2max),
    );
  }

  factory TagesWerteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TagesWerteRow(
      tag: serializer.fromJson<String>(json['tag']),
      schritte: serializer.fromJson<int?>(json['schritte']),
      ruhepulsBpm: serializer.fromJson<int?>(json['ruhepulsBpm']),
      gelesenAm: serializer.fromJson<DateTime?>(json['gelesenAm']),
      hrvMs: serializer.fromJson<double?>(json['hrvMs']),
      respRate: serializer.fromJson<double?>(json['respRate']),
      recoveryHrDrop: serializer.fromJson<int?>(json['recoveryHrDrop']),
      gewichtKg: serializer.fromJson<double?>(json['gewichtKg']),
      trainingsMinuten: serializer.fromJson<double?>(json['trainingsMinuten']),
      koerperfettPct: serializer.fromJson<double?>(json['koerperfettPct']),
      fettfreiKg: serializer.fromJson<double?>(json['fettfreiKg']),
      vo2max: serializer.fromJson<double?>(json['vo2max']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'schritte': serializer.toJson<int?>(schritte),
      'ruhepulsBpm': serializer.toJson<int?>(ruhepulsBpm),
      'gelesenAm': serializer.toJson<DateTime?>(gelesenAm),
      'hrvMs': serializer.toJson<double?>(hrvMs),
      'respRate': serializer.toJson<double?>(respRate),
      'recoveryHrDrop': serializer.toJson<int?>(recoveryHrDrop),
      'gewichtKg': serializer.toJson<double?>(gewichtKg),
      'trainingsMinuten': serializer.toJson<double?>(trainingsMinuten),
      'koerperfettPct': serializer.toJson<double?>(koerperfettPct),
      'fettfreiKg': serializer.toJson<double?>(fettfreiKg),
      'vo2max': serializer.toJson<double?>(vo2max),
    };
  }

  TagesWerteRow copyWith({
    String? tag,
    Value<int?> schritte = const Value.absent(),
    Value<int?> ruhepulsBpm = const Value.absent(),
    Value<DateTime?> gelesenAm = const Value.absent(),
    Value<double?> hrvMs = const Value.absent(),
    Value<double?> respRate = const Value.absent(),
    Value<int?> recoveryHrDrop = const Value.absent(),
    Value<double?> gewichtKg = const Value.absent(),
    Value<double?> trainingsMinuten = const Value.absent(),
    Value<double?> koerperfettPct = const Value.absent(),
    Value<double?> fettfreiKg = const Value.absent(),
    Value<double?> vo2max = const Value.absent(),
  }) => TagesWerteRow(
    tag: tag ?? this.tag,
    schritte: schritte.present ? schritte.value : this.schritte,
    ruhepulsBpm: ruhepulsBpm.present ? ruhepulsBpm.value : this.ruhepulsBpm,
    gelesenAm: gelesenAm.present ? gelesenAm.value : this.gelesenAm,
    hrvMs: hrvMs.present ? hrvMs.value : this.hrvMs,
    respRate: respRate.present ? respRate.value : this.respRate,
    recoveryHrDrop: recoveryHrDrop.present
        ? recoveryHrDrop.value
        : this.recoveryHrDrop,
    gewichtKg: gewichtKg.present ? gewichtKg.value : this.gewichtKg,
    trainingsMinuten: trainingsMinuten.present
        ? trainingsMinuten.value
        : this.trainingsMinuten,
    koerperfettPct: koerperfettPct.present
        ? koerperfettPct.value
        : this.koerperfettPct,
    fettfreiKg: fettfreiKg.present ? fettfreiKg.value : this.fettfreiKg,
    vo2max: vo2max.present ? vo2max.value : this.vo2max,
  );
  TagesWerteRow copyWithCompanion(TagesWerteCompanion data) {
    return TagesWerteRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      schritte: data.schritte.present ? data.schritte.value : this.schritte,
      ruhepulsBpm: data.ruhepulsBpm.present
          ? data.ruhepulsBpm.value
          : this.ruhepulsBpm,
      gelesenAm: data.gelesenAm.present ? data.gelesenAm.value : this.gelesenAm,
      hrvMs: data.hrvMs.present ? data.hrvMs.value : this.hrvMs,
      respRate: data.respRate.present ? data.respRate.value : this.respRate,
      recoveryHrDrop: data.recoveryHrDrop.present
          ? data.recoveryHrDrop.value
          : this.recoveryHrDrop,
      gewichtKg: data.gewichtKg.present ? data.gewichtKg.value : this.gewichtKg,
      trainingsMinuten: data.trainingsMinuten.present
          ? data.trainingsMinuten.value
          : this.trainingsMinuten,
      koerperfettPct: data.koerperfettPct.present
          ? data.koerperfettPct.value
          : this.koerperfettPct,
      fettfreiKg: data.fettfreiKg.present
          ? data.fettfreiKg.value
          : this.fettfreiKg,
      vo2max: data.vo2max.present ? data.vo2max.value : this.vo2max,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TagesWerteRow(')
          ..write('tag: $tag, ')
          ..write('schritte: $schritte, ')
          ..write('ruhepulsBpm: $ruhepulsBpm, ')
          ..write('gelesenAm: $gelesenAm, ')
          ..write('hrvMs: $hrvMs, ')
          ..write('respRate: $respRate, ')
          ..write('recoveryHrDrop: $recoveryHrDrop, ')
          ..write('gewichtKg: $gewichtKg, ')
          ..write('trainingsMinuten: $trainingsMinuten, ')
          ..write('koerperfettPct: $koerperfettPct, ')
          ..write('fettfreiKg: $fettfreiKg, ')
          ..write('vo2max: $vo2max')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tag,
    schritte,
    ruhepulsBpm,
    gelesenAm,
    hrvMs,
    respRate,
    recoveryHrDrop,
    gewichtKg,
    trainingsMinuten,
    koerperfettPct,
    fettfreiKg,
    vo2max,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TagesWerteRow &&
          other.tag == this.tag &&
          other.schritte == this.schritte &&
          other.ruhepulsBpm == this.ruhepulsBpm &&
          other.gelesenAm == this.gelesenAm &&
          other.hrvMs == this.hrvMs &&
          other.respRate == this.respRate &&
          other.recoveryHrDrop == this.recoveryHrDrop &&
          other.gewichtKg == this.gewichtKg &&
          other.trainingsMinuten == this.trainingsMinuten &&
          other.koerperfettPct == this.koerperfettPct &&
          other.fettfreiKg == this.fettfreiKg &&
          other.vo2max == this.vo2max);
}

class TagesWerteCompanion extends UpdateCompanion<TagesWerteRow> {
  final Value<String> tag;
  final Value<int?> schritte;
  final Value<int?> ruhepulsBpm;
  final Value<DateTime?> gelesenAm;
  final Value<double?> hrvMs;
  final Value<double?> respRate;
  final Value<int?> recoveryHrDrop;
  final Value<double?> gewichtKg;
  final Value<double?> trainingsMinuten;
  final Value<double?> koerperfettPct;
  final Value<double?> fettfreiKg;
  final Value<double?> vo2max;
  final Value<int> rowid;
  const TagesWerteCompanion({
    this.tag = const Value.absent(),
    this.schritte = const Value.absent(),
    this.ruhepulsBpm = const Value.absent(),
    this.gelesenAm = const Value.absent(),
    this.hrvMs = const Value.absent(),
    this.respRate = const Value.absent(),
    this.recoveryHrDrop = const Value.absent(),
    this.gewichtKg = const Value.absent(),
    this.trainingsMinuten = const Value.absent(),
    this.koerperfettPct = const Value.absent(),
    this.fettfreiKg = const Value.absent(),
    this.vo2max = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TagesWerteCompanion.insert({
    required String tag,
    this.schritte = const Value.absent(),
    this.ruhepulsBpm = const Value.absent(),
    this.gelesenAm = const Value.absent(),
    this.hrvMs = const Value.absent(),
    this.respRate = const Value.absent(),
    this.recoveryHrDrop = const Value.absent(),
    this.gewichtKg = const Value.absent(),
    this.trainingsMinuten = const Value.absent(),
    this.koerperfettPct = const Value.absent(),
    this.fettfreiKg = const Value.absent(),
    this.vo2max = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tag = Value(tag);
  static Insertable<TagesWerteRow> custom({
    Expression<String>? tag,
    Expression<int>? schritte,
    Expression<int>? ruhepulsBpm,
    Expression<DateTime>? gelesenAm,
    Expression<double>? hrvMs,
    Expression<double>? respRate,
    Expression<int>? recoveryHrDrop,
    Expression<double>? gewichtKg,
    Expression<double>? trainingsMinuten,
    Expression<double>? koerperfettPct,
    Expression<double>? fettfreiKg,
    Expression<double>? vo2max,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (schritte != null) 'schritte': schritte,
      if (ruhepulsBpm != null) 'ruhepuls_bpm': ruhepulsBpm,
      if (gelesenAm != null) 'gelesen_am': gelesenAm,
      if (hrvMs != null) 'hrv_ms': hrvMs,
      if (respRate != null) 'resp_rate': respRate,
      if (recoveryHrDrop != null) 'recovery_hr_drop': recoveryHrDrop,
      if (gewichtKg != null) 'gewicht_kg': gewichtKg,
      if (trainingsMinuten != null) 'trainings_minuten': trainingsMinuten,
      if (koerperfettPct != null) 'koerperfett_pct': koerperfettPct,
      if (fettfreiKg != null) 'fettfrei_kg': fettfreiKg,
      if (vo2max != null) 'vo2max': vo2max,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TagesWerteCompanion copyWith({
    Value<String>? tag,
    Value<int?>? schritte,
    Value<int?>? ruhepulsBpm,
    Value<DateTime?>? gelesenAm,
    Value<double?>? hrvMs,
    Value<double?>? respRate,
    Value<int?>? recoveryHrDrop,
    Value<double?>? gewichtKg,
    Value<double?>? trainingsMinuten,
    Value<double?>? koerperfettPct,
    Value<double?>? fettfreiKg,
    Value<double?>? vo2max,
    Value<int>? rowid,
  }) {
    return TagesWerteCompanion(
      tag: tag ?? this.tag,
      schritte: schritte ?? this.schritte,
      ruhepulsBpm: ruhepulsBpm ?? this.ruhepulsBpm,
      gelesenAm: gelesenAm ?? this.gelesenAm,
      hrvMs: hrvMs ?? this.hrvMs,
      respRate: respRate ?? this.respRate,
      recoveryHrDrop: recoveryHrDrop ?? this.recoveryHrDrop,
      gewichtKg: gewichtKg ?? this.gewichtKg,
      trainingsMinuten: trainingsMinuten ?? this.trainingsMinuten,
      koerperfettPct: koerperfettPct ?? this.koerperfettPct,
      fettfreiKg: fettfreiKg ?? this.fettfreiKg,
      vo2max: vo2max ?? this.vo2max,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (schritte.present) {
      map['schritte'] = Variable<int>(schritte.value);
    }
    if (ruhepulsBpm.present) {
      map['ruhepuls_bpm'] = Variable<int>(ruhepulsBpm.value);
    }
    if (gelesenAm.present) {
      map['gelesen_am'] = Variable<DateTime>(gelesenAm.value);
    }
    if (hrvMs.present) {
      map['hrv_ms'] = Variable<double>(hrvMs.value);
    }
    if (respRate.present) {
      map['resp_rate'] = Variable<double>(respRate.value);
    }
    if (recoveryHrDrop.present) {
      map['recovery_hr_drop'] = Variable<int>(recoveryHrDrop.value);
    }
    if (gewichtKg.present) {
      map['gewicht_kg'] = Variable<double>(gewichtKg.value);
    }
    if (trainingsMinuten.present) {
      map['trainings_minuten'] = Variable<double>(trainingsMinuten.value);
    }
    if (koerperfettPct.present) {
      map['koerperfett_pct'] = Variable<double>(koerperfettPct.value);
    }
    if (fettfreiKg.present) {
      map['fettfrei_kg'] = Variable<double>(fettfreiKg.value);
    }
    if (vo2max.present) {
      map['vo2max'] = Variable<double>(vo2max.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TagesWerteCompanion(')
          ..write('tag: $tag, ')
          ..write('schritte: $schritte, ')
          ..write('ruhepulsBpm: $ruhepulsBpm, ')
          ..write('gelesenAm: $gelesenAm, ')
          ..write('hrvMs: $hrvMs, ')
          ..write('respRate: $respRate, ')
          ..write('recoveryHrDrop: $recoveryHrDrop, ')
          ..write('gewichtKg: $gewichtKg, ')
          ..write('trainingsMinuten: $trainingsMinuten, ')
          ..write('koerperfettPct: $koerperfettPct, ')
          ..write('fettfreiKg: $fettfreiKg, ')
          ..write('vo2max: $vo2max, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StundenSchritteTable extends StundenSchritte
    with TableInfo<$StundenSchritteTable, StundenSchritteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StundenSchritteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stundeMeta = const VerificationMeta('stunde');
  @override
  late final GeneratedColumn<int> stunde = GeneratedColumn<int>(
    'stunde',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schritteMeta = const VerificationMeta(
    'schritte',
  );
  @override
  late final GeneratedColumn<int> schritte = GeneratedColumn<int>(
    'schritte',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [tag, stunde, schritte];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stunden_schritte';
  @override
  VerificationContext validateIntegrity(
    Insertable<StundenSchritteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('stunde')) {
      context.handle(
        _stundeMeta,
        stunde.isAcceptableOrUnknown(data['stunde']!, _stundeMeta),
      );
    } else if (isInserting) {
      context.missing(_stundeMeta);
    }
    if (data.containsKey('schritte')) {
      context.handle(
        _schritteMeta,
        schritte.isAcceptableOrUnknown(data['schritte']!, _schritteMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag, stunde};
  @override
  StundenSchritteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StundenSchritteRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      stunde: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stunde'],
      )!,
      schritte: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schritte'],
      ),
    );
  }

  @override
  $StundenSchritteTable createAlias(String alias) {
    return $StundenSchritteTable(attachedDatabase, alias);
  }
}

class StundenSchritteRow extends DataClass
    implements Insertable<StundenSchritteRow> {
  final String tag;
  final int stunde;
  final int? schritte;
  const StundenSchritteRow({
    required this.tag,
    required this.stunde,
    this.schritte,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    map['stunde'] = Variable<int>(stunde);
    if (!nullToAbsent || schritte != null) {
      map['schritte'] = Variable<int>(schritte);
    }
    return map;
  }

  StundenSchritteCompanion toCompanion(bool nullToAbsent) {
    return StundenSchritteCompanion(
      tag: Value(tag),
      stunde: Value(stunde),
      schritte: schritte == null && nullToAbsent
          ? const Value.absent()
          : Value(schritte),
    );
  }

  factory StundenSchritteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StundenSchritteRow(
      tag: serializer.fromJson<String>(json['tag']),
      stunde: serializer.fromJson<int>(json['stunde']),
      schritte: serializer.fromJson<int?>(json['schritte']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'stunde': serializer.toJson<int>(stunde),
      'schritte': serializer.toJson<int?>(schritte),
    };
  }

  StundenSchritteRow copyWith({
    String? tag,
    int? stunde,
    Value<int?> schritte = const Value.absent(),
  }) => StundenSchritteRow(
    tag: tag ?? this.tag,
    stunde: stunde ?? this.stunde,
    schritte: schritte.present ? schritte.value : this.schritte,
  );
  StundenSchritteRow copyWithCompanion(StundenSchritteCompanion data) {
    return StundenSchritteRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      stunde: data.stunde.present ? data.stunde.value : this.stunde,
      schritte: data.schritte.present ? data.schritte.value : this.schritte,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StundenSchritteRow(')
          ..write('tag: $tag, ')
          ..write('stunde: $stunde, ')
          ..write('schritte: $schritte')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tag, stunde, schritte);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StundenSchritteRow &&
          other.tag == this.tag &&
          other.stunde == this.stunde &&
          other.schritte == this.schritte);
}

class StundenSchritteCompanion extends UpdateCompanion<StundenSchritteRow> {
  final Value<String> tag;
  final Value<int> stunde;
  final Value<int?> schritte;
  final Value<int> rowid;
  const StundenSchritteCompanion({
    this.tag = const Value.absent(),
    this.stunde = const Value.absent(),
    this.schritte = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StundenSchritteCompanion.insert({
    required String tag,
    required int stunde,
    this.schritte = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tag = Value(tag),
       stunde = Value(stunde);
  static Insertable<StundenSchritteRow> custom({
    Expression<String>? tag,
    Expression<int>? stunde,
    Expression<int>? schritte,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (stunde != null) 'stunde': stunde,
      if (schritte != null) 'schritte': schritte,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StundenSchritteCompanion copyWith({
    Value<String>? tag,
    Value<int>? stunde,
    Value<int?>? schritte,
    Value<int>? rowid,
  }) {
    return StundenSchritteCompanion(
      tag: tag ?? this.tag,
      stunde: stunde ?? this.stunde,
      schritte: schritte ?? this.schritte,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (stunde.present) {
      map['stunde'] = Variable<int>(stunde.value);
    }
    if (schritte.present) {
      map['schritte'] = Variable<int>(schritte.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StundenSchritteCompanion(')
          ..write('tag: $tag, ')
          ..write('stunde: $stunde, ')
          ..write('schritte: $schritte, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EigeneDatenTable extends EigeneDaten
    with TableInfo<$EigeneDatenTable, EigeneDatenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EigeneDatenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _inhaltMeta = const VerificationMeta('inhalt');
  @override
  late final GeneratedColumn<String> inhalt = GeneratedColumn<String>(
    'inhalt',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, tag, inhalt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eigene_daten';
  @override
  VerificationContext validateIntegrity(
    Insertable<EigeneDatenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('inhalt')) {
      context.handle(
        _inhaltMeta,
        inhalt.isAcceptableOrUnknown(data['inhalt']!, _inhaltMeta),
      );
    } else if (isInserting) {
      context.missing(_inhaltMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EigeneDatenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EigeneDatenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      inhalt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}inhalt'],
      )!,
    );
  }

  @override
  $EigeneDatenTable createAlias(String alias) {
    return $EigeneDatenTable(attachedDatabase, alias);
  }
}

class EigeneDatenRow extends DataClass implements Insertable<EigeneDatenRow> {
  final int id;
  final String tag;
  final String inhalt;
  const EigeneDatenRow({
    required this.id,
    required this.tag,
    required this.inhalt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tag'] = Variable<String>(tag);
    map['inhalt'] = Variable<String>(inhalt);
    return map;
  }

  EigeneDatenCompanion toCompanion(bool nullToAbsent) {
    return EigeneDatenCompanion(
      id: Value(id),
      tag: Value(tag),
      inhalt: Value(inhalt),
    );
  }

  factory EigeneDatenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EigeneDatenRow(
      id: serializer.fromJson<int>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
      inhalt: serializer.fromJson<String>(json['inhalt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tag': serializer.toJson<String>(tag),
      'inhalt': serializer.toJson<String>(inhalt),
    };
  }

  EigeneDatenRow copyWith({int? id, String? tag, String? inhalt}) =>
      EigeneDatenRow(
        id: id ?? this.id,
        tag: tag ?? this.tag,
        inhalt: inhalt ?? this.inhalt,
      );
  EigeneDatenRow copyWithCompanion(EigeneDatenCompanion data) {
    return EigeneDatenRow(
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
      inhalt: data.inhalt.present ? data.inhalt.value : this.inhalt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EigeneDatenRow(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('inhalt: $inhalt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, tag, inhalt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EigeneDatenRow &&
          other.id == this.id &&
          other.tag == this.tag &&
          other.inhalt == this.inhalt);
}

class EigeneDatenCompanion extends UpdateCompanion<EigeneDatenRow> {
  final Value<int> id;
  final Value<String> tag;
  final Value<String> inhalt;
  const EigeneDatenCompanion({
    this.id = const Value.absent(),
    this.tag = const Value.absent(),
    this.inhalt = const Value.absent(),
  });
  EigeneDatenCompanion.insert({
    this.id = const Value.absent(),
    required String tag,
    required String inhalt,
  }) : tag = Value(tag),
       inhalt = Value(inhalt);
  static Insertable<EigeneDatenRow> custom({
    Expression<int>? id,
    Expression<String>? tag,
    Expression<String>? inhalt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
      if (inhalt != null) 'inhalt': inhalt,
    });
  }

  EigeneDatenCompanion copyWith({
    Value<int>? id,
    Value<String>? tag,
    Value<String>? inhalt,
  }) {
    return EigeneDatenCompanion(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      inhalt: inhalt ?? this.inhalt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (inhalt.present) {
      map['inhalt'] = Variable<String>(inhalt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EigeneDatenCompanion(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('inhalt: $inhalt')
          ..write(')'))
        .toString();
  }
}

class $NaechteTable extends Naechte with TableInfo<$NaechteTable, NachtRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NaechteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gelesenAmMeta = const VerificationMeta(
    'gelesenAm',
  );
  @override
  late final GeneratedColumn<DateTime> gelesenAm = GeneratedColumn<DateTime>(
    'gelesen_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ruhepulsBpmMeta = const VerificationMeta(
    'ruhepulsBpm',
  );
  @override
  late final GeneratedColumn<double> ruhepulsBpm = GeneratedColumn<double>(
    'ruhepuls_bpm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hrvMsMeta = const VerificationMeta('hrvMs');
  @override
  late final GeneratedColumn<double> hrvMs = GeneratedColumn<double>(
    'hrv_ms',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _respRateMeta = const VerificationMeta(
    'respRate',
  );
  @override
  late final GeneratedColumn<double> respRate = GeneratedColumn<double>(
    'resp_rate',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    gelesenAm,
    ruhepulsBpm,
    hrvMs,
    respRate,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'naechte';
  @override
  VerificationContext validateIntegrity(
    Insertable<NachtRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('gelesen_am')) {
      context.handle(
        _gelesenAmMeta,
        gelesenAm.isAcceptableOrUnknown(data['gelesen_am']!, _gelesenAmMeta),
      );
    }
    if (data.containsKey('ruhepuls_bpm')) {
      context.handle(
        _ruhepulsBpmMeta,
        ruhepulsBpm.isAcceptableOrUnknown(
          data['ruhepuls_bpm']!,
          _ruhepulsBpmMeta,
        ),
      );
    }
    if (data.containsKey('hrv_ms')) {
      context.handle(
        _hrvMsMeta,
        hrvMs.isAcceptableOrUnknown(data['hrv_ms']!, _hrvMsMeta),
      );
    }
    if (data.containsKey('resp_rate')) {
      context.handle(
        _respRateMeta,
        respRate.isAcceptableOrUnknown(data['resp_rate']!, _respRateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag};
  @override
  NachtRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NachtRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      gelesenAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gelesen_am'],
      ),
      ruhepulsBpm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ruhepuls_bpm'],
      ),
      hrvMs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hrv_ms'],
      ),
      respRate: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}resp_rate'],
      ),
    );
  }

  @override
  $NaechteTable createAlias(String alias) {
    return $NaechteTable(attachedDatabase, alias);
  }
}

class NachtRow extends DataClass implements Insertable<NachtRow> {
  /// ISO-Tagesschlüssel des **Aufwachtags** (`BerlinCalendar.dayKey`),
  /// derselbe Schlüsseltyp wie in [TagesWerte] — damit wird aus
  /// `DataWindow.clip(...)` auch hier ein `WHERE tag >= ?` (Spec 5.6).
  final String tag;

  /// Wann diese Nacht aus Apple Health geholt wurde. Der Stand liegt auf der
  /// **Nacht**, nicht auf dem einzelnen Abschnitt: Ein Lauf hat einen
  /// Zeitpunkt (Spec 5.3b), und ein Abschnitt ohne seine Nacht gibt es
  /// nicht. Nullbar, weil eine künftige Migration Zeilen ohne bekannten
  /// Stand hinterlassen könnte — die gelten dann als „kein Cache", nicht
  /// als Cache mit einem erfundenen Zeitstempel.
  final DateTime? gelesenAm;

  /// Der Ruhepuls **dieser Nacht** in bpm (Schema v8, #193) — das
  /// 5. Perzentil der Pulsproben im Schlaffenster, gerechnet von
  /// `NightVitals` im Kern.
  ///
  /// Die drei Spalten stehen hier und nicht in [TagesWerte], obwohl es sie
  /// dort gleichnamig schon gibt: Dort ist es der Wert des **Kalendertags**,
  /// und genau dessen Verwechslung mit der Nacht behebt #193. Zwei Spalten
  /// gleichen Namens in zwei Tabellen sind hier kein Versehen, sondern der
  /// Unterschied selbst.
  ///
  /// **`RealColumn`, anders als [TagesWerte.ruhepulsBpm]:** Apples
  /// `RestingHeartRate` kam als ganze Zahl; dieser Wert ist ein linear
  /// interpoliertes Perzentil (`NightVitals.restingHeartRate` ist
  /// `double?`). Eine Ganzzahlspalte zwänge die Brücke zu runden, und das
  /// wäre eine stille Veränderung des gerechneten Werts auf dem Weg in den
  /// Cache — derselbe Grund, aus dem [TagesWerte.trainingsMinuten] in #194
  /// eine `RealColumn` wurde.
  ///
  /// Nullbar wie jede Metrikspalte: Unter fünf Pulsproben gibt es keinen
  /// Ruhepuls, und „0 bpm" wäre kein fehlender Wert, sondern ein Alarmwert.
  ///
  /// **Gespeichert wird das Ergebnis, nicht die Eingabe.** Die Rohproben
  /// liegen nicht im Cache und sollen es nicht — für dreißig Tage wären das
  /// rund 24.000 Pulsproben.
  final double? ruhepulsBpm;

  /// Die Herzfrequenzvariabilität dieser Nacht in Millisekunden (Schema v8,
  /// #193) — der Median der Proben im Schlaffenster. Für sie gibt es keine
  /// Mindestzahl an Proben: Die Uhr misst HRV nur zwei- bis sechsmal je
  /// Nacht.
  final double? hrvMs;

  /// Die Atemfrequenz dieser Nacht je Minute (Schema v8, #193), ebenfalls
  /// der Median. Nacht und Tag unterscheiden sich hier kaum; sie kommt
  /// trotzdem aus dem Nachtfenster, weil ein Ampelsignal, das an einer
  /// anderen Zeitspanne hängt als die beiden anderen, sich nicht erklären
  /// ließe (von Tim am 02.11.2026 so entschieden).
  final double? respRate;
  const NachtRow({
    required this.tag,
    this.gelesenAm,
    this.ruhepulsBpm,
    this.hrvMs,
    this.respRate,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || gelesenAm != null) {
      map['gelesen_am'] = Variable<DateTime>(gelesenAm);
    }
    if (!nullToAbsent || ruhepulsBpm != null) {
      map['ruhepuls_bpm'] = Variable<double>(ruhepulsBpm);
    }
    if (!nullToAbsent || hrvMs != null) {
      map['hrv_ms'] = Variable<double>(hrvMs);
    }
    if (!nullToAbsent || respRate != null) {
      map['resp_rate'] = Variable<double>(respRate);
    }
    return map;
  }

  NaechteCompanion toCompanion(bool nullToAbsent) {
    return NaechteCompanion(
      tag: Value(tag),
      gelesenAm: gelesenAm == null && nullToAbsent
          ? const Value.absent()
          : Value(gelesenAm),
      ruhepulsBpm: ruhepulsBpm == null && nullToAbsent
          ? const Value.absent()
          : Value(ruhepulsBpm),
      hrvMs: hrvMs == null && nullToAbsent
          ? const Value.absent()
          : Value(hrvMs),
      respRate: respRate == null && nullToAbsent
          ? const Value.absent()
          : Value(respRate),
    );
  }

  factory NachtRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NachtRow(
      tag: serializer.fromJson<String>(json['tag']),
      gelesenAm: serializer.fromJson<DateTime?>(json['gelesenAm']),
      ruhepulsBpm: serializer.fromJson<double?>(json['ruhepulsBpm']),
      hrvMs: serializer.fromJson<double?>(json['hrvMs']),
      respRate: serializer.fromJson<double?>(json['respRate']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'gelesenAm': serializer.toJson<DateTime?>(gelesenAm),
      'ruhepulsBpm': serializer.toJson<double?>(ruhepulsBpm),
      'hrvMs': serializer.toJson<double?>(hrvMs),
      'respRate': serializer.toJson<double?>(respRate),
    };
  }

  NachtRow copyWith({
    String? tag,
    Value<DateTime?> gelesenAm = const Value.absent(),
    Value<double?> ruhepulsBpm = const Value.absent(),
    Value<double?> hrvMs = const Value.absent(),
    Value<double?> respRate = const Value.absent(),
  }) => NachtRow(
    tag: tag ?? this.tag,
    gelesenAm: gelesenAm.present ? gelesenAm.value : this.gelesenAm,
    ruhepulsBpm: ruhepulsBpm.present ? ruhepulsBpm.value : this.ruhepulsBpm,
    hrvMs: hrvMs.present ? hrvMs.value : this.hrvMs,
    respRate: respRate.present ? respRate.value : this.respRate,
  );
  NachtRow copyWithCompanion(NaechteCompanion data) {
    return NachtRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      gelesenAm: data.gelesenAm.present ? data.gelesenAm.value : this.gelesenAm,
      ruhepulsBpm: data.ruhepulsBpm.present
          ? data.ruhepulsBpm.value
          : this.ruhepulsBpm,
      hrvMs: data.hrvMs.present ? data.hrvMs.value : this.hrvMs,
      respRate: data.respRate.present ? data.respRate.value : this.respRate,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NachtRow(')
          ..write('tag: $tag, ')
          ..write('gelesenAm: $gelesenAm, ')
          ..write('ruhepulsBpm: $ruhepulsBpm, ')
          ..write('hrvMs: $hrvMs, ')
          ..write('respRate: $respRate')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tag, gelesenAm, ruhepulsBpm, hrvMs, respRate);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NachtRow &&
          other.tag == this.tag &&
          other.gelesenAm == this.gelesenAm &&
          other.ruhepulsBpm == this.ruhepulsBpm &&
          other.hrvMs == this.hrvMs &&
          other.respRate == this.respRate);
}

class NaechteCompanion extends UpdateCompanion<NachtRow> {
  final Value<String> tag;
  final Value<DateTime?> gelesenAm;
  final Value<double?> ruhepulsBpm;
  final Value<double?> hrvMs;
  final Value<double?> respRate;
  final Value<int> rowid;
  const NaechteCompanion({
    this.tag = const Value.absent(),
    this.gelesenAm = const Value.absent(),
    this.ruhepulsBpm = const Value.absent(),
    this.hrvMs = const Value.absent(),
    this.respRate = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NaechteCompanion.insert({
    required String tag,
    this.gelesenAm = const Value.absent(),
    this.ruhepulsBpm = const Value.absent(),
    this.hrvMs = const Value.absent(),
    this.respRate = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tag = Value(tag);
  static Insertable<NachtRow> custom({
    Expression<String>? tag,
    Expression<DateTime>? gelesenAm,
    Expression<double>? ruhepulsBpm,
    Expression<double>? hrvMs,
    Expression<double>? respRate,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (gelesenAm != null) 'gelesen_am': gelesenAm,
      if (ruhepulsBpm != null) 'ruhepuls_bpm': ruhepulsBpm,
      if (hrvMs != null) 'hrv_ms': hrvMs,
      if (respRate != null) 'resp_rate': respRate,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NaechteCompanion copyWith({
    Value<String>? tag,
    Value<DateTime?>? gelesenAm,
    Value<double?>? ruhepulsBpm,
    Value<double?>? hrvMs,
    Value<double?>? respRate,
    Value<int>? rowid,
  }) {
    return NaechteCompanion(
      tag: tag ?? this.tag,
      gelesenAm: gelesenAm ?? this.gelesenAm,
      ruhepulsBpm: ruhepulsBpm ?? this.ruhepulsBpm,
      hrvMs: hrvMs ?? this.hrvMs,
      respRate: respRate ?? this.respRate,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (gelesenAm.present) {
      map['gelesen_am'] = Variable<DateTime>(gelesenAm.value);
    }
    if (ruhepulsBpm.present) {
      map['ruhepuls_bpm'] = Variable<double>(ruhepulsBpm.value);
    }
    if (hrvMs.present) {
      map['hrv_ms'] = Variable<double>(hrvMs.value);
    }
    if (respRate.present) {
      map['resp_rate'] = Variable<double>(respRate.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NaechteCompanion(')
          ..write('tag: $tag, ')
          ..write('gelesenAm: $gelesenAm, ')
          ..write('ruhepulsBpm: $ruhepulsBpm, ')
          ..write('hrvMs: $hrvMs, ')
          ..write('respRate: $respRate, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SchlafAbschnitteTable extends SchlafAbschnitte
    with TableInfo<$SchlafAbschnitteTable, SchlafAbschnittRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchlafAbschnitteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quelleMeta = const VerificationMeta('quelle');
  @override
  late final GeneratedColumn<int> quelle = GeneratedColumn<int>(
    'quelle',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lfdNrMeta = const VerificationMeta('lfdNr');
  @override
  late final GeneratedColumn<int> lfdNr = GeneratedColumn<int>(
    'lfd_nr',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phaseMeta = const VerificationMeta('phase');
  @override
  late final GeneratedColumn<String> phase = GeneratedColumn<String>(
    'phase',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beginnMeta = const VerificationMeta('beginn');
  @override
  late final GeneratedColumn<DateTime> beginn = GeneratedColumn<DateTime>(
    'beginn',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endeMeta = const VerificationMeta('ende');
  @override
  late final GeneratedColumn<DateTime> ende = GeneratedColumn<DateTime>(
    'ende',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    quelle,
    lfdNr,
    phase,
    beginn,
    ende,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schlaf_abschnitte';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchlafAbschnittRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('quelle')) {
      context.handle(
        _quelleMeta,
        quelle.isAcceptableOrUnknown(data['quelle']!, _quelleMeta),
      );
    } else if (isInserting) {
      context.missing(_quelleMeta);
    }
    if (data.containsKey('lfd_nr')) {
      context.handle(
        _lfdNrMeta,
        lfdNr.isAcceptableOrUnknown(data['lfd_nr']!, _lfdNrMeta),
      );
    } else if (isInserting) {
      context.missing(_lfdNrMeta);
    }
    if (data.containsKey('phase')) {
      context.handle(
        _phaseMeta,
        phase.isAcceptableOrUnknown(data['phase']!, _phaseMeta),
      );
    } else if (isInserting) {
      context.missing(_phaseMeta);
    }
    if (data.containsKey('beginn')) {
      context.handle(
        _beginnMeta,
        beginn.isAcceptableOrUnknown(data['beginn']!, _beginnMeta),
      );
    } else if (isInserting) {
      context.missing(_beginnMeta);
    }
    if (data.containsKey('ende')) {
      context.handle(
        _endeMeta,
        ende.isAcceptableOrUnknown(data['ende']!, _endeMeta),
      );
    } else if (isInserting) {
      context.missing(_endeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag, quelle, lfdNr};
  @override
  SchlafAbschnittRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchlafAbschnittRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      quelle: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}quelle'],
      )!,
      lfdNr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lfd_nr'],
      )!,
      phase: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phase'],
      )!,
      beginn: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}beginn'],
      )!,
      ende: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ende'],
      )!,
    );
  }

  @override
  $SchlafAbschnitteTable createAlias(String alias) {
    return $SchlafAbschnitteTable(attachedDatabase, alias);
  }
}

class SchlafAbschnittRow extends DataClass
    implements Insertable<SchlafAbschnittRow> {
  /// Aufwachtag, wie in [Naechte].
  final String tag;

  /// 0 = Hauptnacht, 1..n = n-tes Nickerchen desselben Tages. SPEC 4.6
  /// zählt Tagschlaf nicht zur Nacht, deshalb trägt der Schlüssel die
  /// Herkunft mit.
  ///
  /// **Kein nullbarer Schlüsselteil:** SQLite lässt NULL in einem
  /// Primärschlüssel zu und behandelt zwei NULLs als verschieden — ein
  /// `INSERT OR REPLACE` würde Abschnitte dann verdoppeln statt zu
  /// ersetzen.
  final int quelle;

  /// Laufende Nummer innerhalb der Quelle, bei 0 beginnend. Hält die
  /// Reihenfolge der Abschnitte fest, ohne sie aus den Zeiten
  /// zurückrechnen zu müssen.
  final int lfdNr;

  /// `SleepStage.name` — der Name der Phase, nicht ihr Index: Eine später
  /// eingefügte Phase verschöbe sonst stillschweigend die Bedeutung aller
  /// abgelegten Zeilen.
  final String phase;
  final DateTime beginn;
  final DateTime ende;
  const SchlafAbschnittRow({
    required this.tag,
    required this.quelle,
    required this.lfdNr,
    required this.phase,
    required this.beginn,
    required this.ende,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    map['quelle'] = Variable<int>(quelle);
    map['lfd_nr'] = Variable<int>(lfdNr);
    map['phase'] = Variable<String>(phase);
    map['beginn'] = Variable<DateTime>(beginn);
    map['ende'] = Variable<DateTime>(ende);
    return map;
  }

  SchlafAbschnitteCompanion toCompanion(bool nullToAbsent) {
    return SchlafAbschnitteCompanion(
      tag: Value(tag),
      quelle: Value(quelle),
      lfdNr: Value(lfdNr),
      phase: Value(phase),
      beginn: Value(beginn),
      ende: Value(ende),
    );
  }

  factory SchlafAbschnittRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchlafAbschnittRow(
      tag: serializer.fromJson<String>(json['tag']),
      quelle: serializer.fromJson<int>(json['quelle']),
      lfdNr: serializer.fromJson<int>(json['lfdNr']),
      phase: serializer.fromJson<String>(json['phase']),
      beginn: serializer.fromJson<DateTime>(json['beginn']),
      ende: serializer.fromJson<DateTime>(json['ende']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'quelle': serializer.toJson<int>(quelle),
      'lfdNr': serializer.toJson<int>(lfdNr),
      'phase': serializer.toJson<String>(phase),
      'beginn': serializer.toJson<DateTime>(beginn),
      'ende': serializer.toJson<DateTime>(ende),
    };
  }

  SchlafAbschnittRow copyWith({
    String? tag,
    int? quelle,
    int? lfdNr,
    String? phase,
    DateTime? beginn,
    DateTime? ende,
  }) => SchlafAbschnittRow(
    tag: tag ?? this.tag,
    quelle: quelle ?? this.quelle,
    lfdNr: lfdNr ?? this.lfdNr,
    phase: phase ?? this.phase,
    beginn: beginn ?? this.beginn,
    ende: ende ?? this.ende,
  );
  SchlafAbschnittRow copyWithCompanion(SchlafAbschnitteCompanion data) {
    return SchlafAbschnittRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      quelle: data.quelle.present ? data.quelle.value : this.quelle,
      lfdNr: data.lfdNr.present ? data.lfdNr.value : this.lfdNr,
      phase: data.phase.present ? data.phase.value : this.phase,
      beginn: data.beginn.present ? data.beginn.value : this.beginn,
      ende: data.ende.present ? data.ende.value : this.ende,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchlafAbschnittRow(')
          ..write('tag: $tag, ')
          ..write('quelle: $quelle, ')
          ..write('lfdNr: $lfdNr, ')
          ..write('phase: $phase, ')
          ..write('beginn: $beginn, ')
          ..write('ende: $ende')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tag, quelle, lfdNr, phase, beginn, ende);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchlafAbschnittRow &&
          other.tag == this.tag &&
          other.quelle == this.quelle &&
          other.lfdNr == this.lfdNr &&
          other.phase == this.phase &&
          other.beginn == this.beginn &&
          other.ende == this.ende);
}

class SchlafAbschnitteCompanion extends UpdateCompanion<SchlafAbschnittRow> {
  final Value<String> tag;
  final Value<int> quelle;
  final Value<int> lfdNr;
  final Value<String> phase;
  final Value<DateTime> beginn;
  final Value<DateTime> ende;
  final Value<int> rowid;
  const SchlafAbschnitteCompanion({
    this.tag = const Value.absent(),
    this.quelle = const Value.absent(),
    this.lfdNr = const Value.absent(),
    this.phase = const Value.absent(),
    this.beginn = const Value.absent(),
    this.ende = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchlafAbschnitteCompanion.insert({
    required String tag,
    required int quelle,
    required int lfdNr,
    required String phase,
    required DateTime beginn,
    required DateTime ende,
    this.rowid = const Value.absent(),
  }) : tag = Value(tag),
       quelle = Value(quelle),
       lfdNr = Value(lfdNr),
       phase = Value(phase),
       beginn = Value(beginn),
       ende = Value(ende);
  static Insertable<SchlafAbschnittRow> custom({
    Expression<String>? tag,
    Expression<int>? quelle,
    Expression<int>? lfdNr,
    Expression<String>? phase,
    Expression<DateTime>? beginn,
    Expression<DateTime>? ende,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (quelle != null) 'quelle': quelle,
      if (lfdNr != null) 'lfd_nr': lfdNr,
      if (phase != null) 'phase': phase,
      if (beginn != null) 'beginn': beginn,
      if (ende != null) 'ende': ende,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchlafAbschnitteCompanion copyWith({
    Value<String>? tag,
    Value<int>? quelle,
    Value<int>? lfdNr,
    Value<String>? phase,
    Value<DateTime>? beginn,
    Value<DateTime>? ende,
    Value<int>? rowid,
  }) {
    return SchlafAbschnitteCompanion(
      tag: tag ?? this.tag,
      quelle: quelle ?? this.quelle,
      lfdNr: lfdNr ?? this.lfdNr,
      phase: phase ?? this.phase,
      beginn: beginn ?? this.beginn,
      ende: ende ?? this.ende,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (quelle.present) {
      map['quelle'] = Variable<int>(quelle.value);
    }
    if (lfdNr.present) {
      map['lfd_nr'] = Variable<int>(lfdNr.value);
    }
    if (phase.present) {
      map['phase'] = Variable<String>(phase.value);
    }
    if (beginn.present) {
      map['beginn'] = Variable<DateTime>(beginn.value);
    }
    if (ende.present) {
      map['ende'] = Variable<DateTime>(ende.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchlafAbschnitteCompanion(')
          ..write('tag: $tag, ')
          ..write('quelle: $quelle, ')
          ..write('lfdNr: $lfdNr, ')
          ..write('phase: $phase, ')
          ..write('beginn: $beginn, ')
          ..write('ende: $ende, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZielWerteTable extends ZielWerte
    with TableInfo<$ZielWerteTable, ZielWerteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZielWerteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _schlafzielMinutenMeta = const VerificationMeta(
    'schlafzielMinuten',
  );
  @override
  late final GeneratedColumn<int> schlafzielMinuten = GeneratedColumn<int>(
    'schlafziel_minuten',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schlafenszeitMinutenMeta =
      const VerificationMeta('schlafenszeitMinuten');
  @override
  late final GeneratedColumn<int> schlafenszeitMinuten = GeneratedColumn<int>(
    'schlafenszeit_minuten',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wochenzielTrainingsminutenMeta =
      const VerificationMeta('wochenzielTrainingsminuten');
  @override
  late final GeneratedColumn<int> wochenzielTrainingsminuten =
      GeneratedColumn<int>(
        'wochenziel_trainingsminuten',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    schlafzielMinuten,
    schlafenszeitMinuten,
    wochenzielTrainingsminuten,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ziel_werte';
  @override
  VerificationContext validateIntegrity(
    Insertable<ZielWerteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('schlafziel_minuten')) {
      context.handle(
        _schlafzielMinutenMeta,
        schlafzielMinuten.isAcceptableOrUnknown(
          data['schlafziel_minuten']!,
          _schlafzielMinutenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schlafzielMinutenMeta);
    }
    if (data.containsKey('schlafenszeit_minuten')) {
      context.handle(
        _schlafenszeitMinutenMeta,
        schlafenszeitMinuten.isAcceptableOrUnknown(
          data['schlafenszeit_minuten']!,
          _schlafenszeitMinutenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schlafenszeitMinutenMeta);
    }
    if (data.containsKey('wochenziel_trainingsminuten')) {
      context.handle(
        _wochenzielTrainingsminutenMeta,
        wochenzielTrainingsminuten.isAcceptableOrUnknown(
          data['wochenziel_trainingsminuten']!,
          _wochenzielTrainingsminutenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wochenzielTrainingsminutenMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ZielWerteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZielWerteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      schlafzielMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schlafziel_minuten'],
      )!,
      schlafenszeitMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schlafenszeit_minuten'],
      )!,
      wochenzielTrainingsminuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wochenziel_trainingsminuten'],
      )!,
    );
  }

  @override
  $ZielWerteTable createAlias(String alias) {
    return $ZielWerteTable(attachedDatabase, alias);
  }
}

class ZielWerteRow extends DataClass implements Insertable<ZielWerteRow> {
  final int id;

  /// Schlafziel in ganzen Minuten — Minuten statt Stunden, damit „7:30 h"
  /// ohne Gleitkommarundung ausdrückbar bleibt.
  final int schlafzielMinuten;

  /// Schlafenszeitziel als **Minuten nach Mitternacht**. Kein `DateTime`:
  /// 22:30 ist eine Tageszeit, kein Ereignis (`CLAUDE.md`, „Keine
  /// hartcodierten Ereignisse"). Und nicht auf der 18-Uhr-Skala der
  /// Zubettgehzeit-Formel (#110): Die Ablage soll lesbar sein, ohne die
  /// Formel zu kennen.
  final int schlafenszeitMinuten;

  /// Wochenziel Trainingsminuten (Spec 10a Punkt 4).
  final int wochenzielTrainingsminuten;
  const ZielWerteRow({
    required this.id,
    required this.schlafzielMinuten,
    required this.schlafenszeitMinuten,
    required this.wochenzielTrainingsminuten,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['schlafziel_minuten'] = Variable<int>(schlafzielMinuten);
    map['schlafenszeit_minuten'] = Variable<int>(schlafenszeitMinuten);
    map['wochenziel_trainingsminuten'] = Variable<int>(
      wochenzielTrainingsminuten,
    );
    return map;
  }

  ZielWerteCompanion toCompanion(bool nullToAbsent) {
    return ZielWerteCompanion(
      id: Value(id),
      schlafzielMinuten: Value(schlafzielMinuten),
      schlafenszeitMinuten: Value(schlafenszeitMinuten),
      wochenzielTrainingsminuten: Value(wochenzielTrainingsminuten),
    );
  }

  factory ZielWerteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZielWerteRow(
      id: serializer.fromJson<int>(json['id']),
      schlafzielMinuten: serializer.fromJson<int>(json['schlafzielMinuten']),
      schlafenszeitMinuten: serializer.fromJson<int>(
        json['schlafenszeitMinuten'],
      ),
      wochenzielTrainingsminuten: serializer.fromJson<int>(
        json['wochenzielTrainingsminuten'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'schlafzielMinuten': serializer.toJson<int>(schlafzielMinuten),
      'schlafenszeitMinuten': serializer.toJson<int>(schlafenszeitMinuten),
      'wochenzielTrainingsminuten': serializer.toJson<int>(
        wochenzielTrainingsminuten,
      ),
    };
  }

  ZielWerteRow copyWith({
    int? id,
    int? schlafzielMinuten,
    int? schlafenszeitMinuten,
    int? wochenzielTrainingsminuten,
  }) => ZielWerteRow(
    id: id ?? this.id,
    schlafzielMinuten: schlafzielMinuten ?? this.schlafzielMinuten,
    schlafenszeitMinuten: schlafenszeitMinuten ?? this.schlafenszeitMinuten,
    wochenzielTrainingsminuten:
        wochenzielTrainingsminuten ?? this.wochenzielTrainingsminuten,
  );
  ZielWerteRow copyWithCompanion(ZielWerteCompanion data) {
    return ZielWerteRow(
      id: data.id.present ? data.id.value : this.id,
      schlafzielMinuten: data.schlafzielMinuten.present
          ? data.schlafzielMinuten.value
          : this.schlafzielMinuten,
      schlafenszeitMinuten: data.schlafenszeitMinuten.present
          ? data.schlafenszeitMinuten.value
          : this.schlafenszeitMinuten,
      wochenzielTrainingsminuten: data.wochenzielTrainingsminuten.present
          ? data.wochenzielTrainingsminuten.value
          : this.wochenzielTrainingsminuten,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZielWerteRow(')
          ..write('id: $id, ')
          ..write('schlafzielMinuten: $schlafzielMinuten, ')
          ..write('schlafenszeitMinuten: $schlafenszeitMinuten, ')
          ..write('wochenzielTrainingsminuten: $wochenzielTrainingsminuten')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    schlafzielMinuten,
    schlafenszeitMinuten,
    wochenzielTrainingsminuten,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZielWerteRow &&
          other.id == this.id &&
          other.schlafzielMinuten == this.schlafzielMinuten &&
          other.schlafenszeitMinuten == this.schlafenszeitMinuten &&
          other.wochenzielTrainingsminuten == this.wochenzielTrainingsminuten);
}

class ZielWerteCompanion extends UpdateCompanion<ZielWerteRow> {
  final Value<int> id;
  final Value<int> schlafzielMinuten;
  final Value<int> schlafenszeitMinuten;
  final Value<int> wochenzielTrainingsminuten;
  const ZielWerteCompanion({
    this.id = const Value.absent(),
    this.schlafzielMinuten = const Value.absent(),
    this.schlafenszeitMinuten = const Value.absent(),
    this.wochenzielTrainingsminuten = const Value.absent(),
  });
  ZielWerteCompanion.insert({
    this.id = const Value.absent(),
    required int schlafzielMinuten,
    required int schlafenszeitMinuten,
    required int wochenzielTrainingsminuten,
  }) : schlafzielMinuten = Value(schlafzielMinuten),
       schlafenszeitMinuten = Value(schlafenszeitMinuten),
       wochenzielTrainingsminuten = Value(wochenzielTrainingsminuten);
  static Insertable<ZielWerteRow> custom({
    Expression<int>? id,
    Expression<int>? schlafzielMinuten,
    Expression<int>? schlafenszeitMinuten,
    Expression<int>? wochenzielTrainingsminuten,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (schlafzielMinuten != null) 'schlafziel_minuten': schlafzielMinuten,
      if (schlafenszeitMinuten != null)
        'schlafenszeit_minuten': schlafenszeitMinuten,
      if (wochenzielTrainingsminuten != null)
        'wochenziel_trainingsminuten': wochenzielTrainingsminuten,
    });
  }

  ZielWerteCompanion copyWith({
    Value<int>? id,
    Value<int>? schlafzielMinuten,
    Value<int>? schlafenszeitMinuten,
    Value<int>? wochenzielTrainingsminuten,
  }) {
    return ZielWerteCompanion(
      id: id ?? this.id,
      schlafzielMinuten: schlafzielMinuten ?? this.schlafzielMinuten,
      schlafenszeitMinuten: schlafenszeitMinuten ?? this.schlafenszeitMinuten,
      wochenzielTrainingsminuten:
          wochenzielTrainingsminuten ?? this.wochenzielTrainingsminuten,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (schlafzielMinuten.present) {
      map['schlafziel_minuten'] = Variable<int>(schlafzielMinuten.value);
    }
    if (schlafenszeitMinuten.present) {
      map['schlafenszeit_minuten'] = Variable<int>(schlafenszeitMinuten.value);
    }
    if (wochenzielTrainingsminuten.present) {
      map['wochenziel_trainingsminuten'] = Variable<int>(
        wochenzielTrainingsminuten.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZielWerteCompanion(')
          ..write('id: $id, ')
          ..write('schlafzielMinuten: $schlafzielMinuten, ')
          ..write('schlafenszeitMinuten: $schlafenszeitMinuten, ')
          ..write('wochenzielTrainingsminuten: $wochenzielTrainingsminuten')
          ..write(')'))
        .toString();
  }
}

class $SchlafEintraegeTable extends SchlafEintraege
    with TableInfo<$SchlafEintraegeTable, SchlafEintragRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SchlafEintraegeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artMeta = const VerificationMeta('art');
  @override
  late final GeneratedColumn<String> art = GeneratedColumn<String>(
    'art',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lfdNrMeta = const VerificationMeta('lfdNr');
  @override
  late final GeneratedColumn<int> lfdNr = GeneratedColumn<int>(
    'lfd_nr',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _schlafMinutenMeta = const VerificationMeta(
    'schlafMinuten',
  );
  @override
  late final GeneratedColumn<int> schlafMinuten = GeneratedColumn<int>(
    'schlaf_minuten',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _beginnMinutenMeta = const VerificationMeta(
    'beginnMinuten',
  );
  @override
  late final GeneratedColumn<int> beginnMinuten = GeneratedColumn<int>(
    'beginn_minuten',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endeMinutenMeta = const VerificationMeta(
    'endeMinuten',
  );
  @override
  late final GeneratedColumn<int> endeMinuten = GeneratedColumn<int>(
    'ende_minuten',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    art,
    lfdNr,
    schlafMinuten,
    beginnMinuten,
    endeMinuten,
    notiz,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'schlaf_eintraege';
  @override
  VerificationContext validateIntegrity(
    Insertable<SchlafEintragRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('art')) {
      context.handle(
        _artMeta,
        art.isAcceptableOrUnknown(data['art']!, _artMeta),
      );
    } else if (isInserting) {
      context.missing(_artMeta);
    }
    if (data.containsKey('lfd_nr')) {
      context.handle(
        _lfdNrMeta,
        lfdNr.isAcceptableOrUnknown(data['lfd_nr']!, _lfdNrMeta),
      );
    } else if (isInserting) {
      context.missing(_lfdNrMeta);
    }
    if (data.containsKey('schlaf_minuten')) {
      context.handle(
        _schlafMinutenMeta,
        schlafMinuten.isAcceptableOrUnknown(
          data['schlaf_minuten']!,
          _schlafMinutenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_schlafMinutenMeta);
    }
    if (data.containsKey('beginn_minuten')) {
      context.handle(
        _beginnMinutenMeta,
        beginnMinuten.isAcceptableOrUnknown(
          data['beginn_minuten']!,
          _beginnMinutenMeta,
        ),
      );
    }
    if (data.containsKey('ende_minuten')) {
      context.handle(
        _endeMinutenMeta,
        endeMinuten.isAcceptableOrUnknown(
          data['ende_minuten']!,
          _endeMinutenMeta,
        ),
      );
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag, art, lfdNr};
  @override
  SchlafEintragRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SchlafEintragRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      art: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art'],
      )!,
      lfdNr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lfd_nr'],
      )!,
      schlafMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schlaf_minuten'],
      )!,
      beginnMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}beginn_minuten'],
      ),
      endeMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ende_minuten'],
      ),
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
    );
  }

  @override
  $SchlafEintraegeTable createAlias(String alias) {
    return $SchlafEintraegeTable(attachedDatabase, alias);
  }
}

class SchlafEintragRow extends DataClass
    implements Insertable<SchlafEintragRow> {
  /// ISO-Tagesschlüssel aus `BerlinCalendar.dayKey(...)`, wie in
  /// [TagesWerte] — bei der Nacht der **Aufwachtag**, beim Tagschlaf der
  /// Tag des Nickerchens.
  final String tag;

  /// `SchlafEintragArt.name`, nicht der Index: Ein später eingefügter Wert
  /// verschöbe sonst die Bedeutung jeder abgelegten Zeile — dieselbe
  /// Regel, nach der [SchlafAbschnitte.phase] den `SleepStage.name` trägt.
  final String art;

  /// Laufende Nummer innerhalb von Tag und Art, bei 0 beginnend. Bei einer
  /// Nacht immer 0 — eine zweite eingetragene Nacht für denselben
  /// Aufwachtag wäre eine zweite Antwort auf dieselbe Frage. Beim
  /// Tagschlaf zählt sie hoch; `tagschlaf.js` kennt den Zustand „Zwei
  /// Phasen" ausdrücklich.
  final int lfdNr;

  /// Die geschlafene Zeit in ganzen Minuten. **Nicht nullbar und nicht aus
  /// den Zeiten zurückgerechnet:** Der Entwurf lässt die aus den Zeiten
  /// gerechnete Dauer überschreiben („falls du wach dazwischen lagst"), und
  /// eine abgeleitete Dauer könnte das nicht abbilden.
  final int schlafMinuten;

  /// Zubettgehen bzw. Einschlafen als **Minuten nach Mitternacht**
  /// (0..1439); `null` in der Formularfassung „nur Dauer".
  ///
  /// Kein `DateTime`: „23:10" ist eine Tageszeit, kein Ereignis — dieselbe
  /// Entscheidung wie bei [ZielWerte.schlafenszeitMinuten]. Sie erspart
  /// zugleich die Zeitzonenfrage: Als Zeitpunkt abgelegt bezeichnete
  /// „02:30 am 25.10.2026" in Berlin zwei verschiedene Momente.
  final int? beginnMinuten;

  /// Aufstehen bzw. Aufwachen, ebenfalls Minuten nach Mitternacht.
  /// Entweder stehen beide Uhrzeiten da oder keine — eine halbe Angabe
  /// ergäbe kein Fenster.
  final int? endeMinuten;

  /// Tims Notiz („Uhr vergessen"). Leer heißt leer: Eine leere Zeichenkette
  /// wird beim Schreiben zu `null`, sonst gäbe es zwei Schreibweisen für
  /// „keine Notiz".
  final String? notiz;
  const SchlafEintragRow({
    required this.tag,
    required this.art,
    required this.lfdNr,
    required this.schlafMinuten,
    this.beginnMinuten,
    this.endeMinuten,
    this.notiz,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    map['art'] = Variable<String>(art);
    map['lfd_nr'] = Variable<int>(lfdNr);
    map['schlaf_minuten'] = Variable<int>(schlafMinuten);
    if (!nullToAbsent || beginnMinuten != null) {
      map['beginn_minuten'] = Variable<int>(beginnMinuten);
    }
    if (!nullToAbsent || endeMinuten != null) {
      map['ende_minuten'] = Variable<int>(endeMinuten);
    }
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    return map;
  }

  SchlafEintraegeCompanion toCompanion(bool nullToAbsent) {
    return SchlafEintraegeCompanion(
      tag: Value(tag),
      art: Value(art),
      lfdNr: Value(lfdNr),
      schlafMinuten: Value(schlafMinuten),
      beginnMinuten: beginnMinuten == null && nullToAbsent
          ? const Value.absent()
          : Value(beginnMinuten),
      endeMinuten: endeMinuten == null && nullToAbsent
          ? const Value.absent()
          : Value(endeMinuten),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
    );
  }

  factory SchlafEintragRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SchlafEintragRow(
      tag: serializer.fromJson<String>(json['tag']),
      art: serializer.fromJson<String>(json['art']),
      lfdNr: serializer.fromJson<int>(json['lfdNr']),
      schlafMinuten: serializer.fromJson<int>(json['schlafMinuten']),
      beginnMinuten: serializer.fromJson<int?>(json['beginnMinuten']),
      endeMinuten: serializer.fromJson<int?>(json['endeMinuten']),
      notiz: serializer.fromJson<String?>(json['notiz']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'art': serializer.toJson<String>(art),
      'lfdNr': serializer.toJson<int>(lfdNr),
      'schlafMinuten': serializer.toJson<int>(schlafMinuten),
      'beginnMinuten': serializer.toJson<int?>(beginnMinuten),
      'endeMinuten': serializer.toJson<int?>(endeMinuten),
      'notiz': serializer.toJson<String?>(notiz),
    };
  }

  SchlafEintragRow copyWith({
    String? tag,
    String? art,
    int? lfdNr,
    int? schlafMinuten,
    Value<int?> beginnMinuten = const Value.absent(),
    Value<int?> endeMinuten = const Value.absent(),
    Value<String?> notiz = const Value.absent(),
  }) => SchlafEintragRow(
    tag: tag ?? this.tag,
    art: art ?? this.art,
    lfdNr: lfdNr ?? this.lfdNr,
    schlafMinuten: schlafMinuten ?? this.schlafMinuten,
    beginnMinuten: beginnMinuten.present
        ? beginnMinuten.value
        : this.beginnMinuten,
    endeMinuten: endeMinuten.present ? endeMinuten.value : this.endeMinuten,
    notiz: notiz.present ? notiz.value : this.notiz,
  );
  SchlafEintragRow copyWithCompanion(SchlafEintraegeCompanion data) {
    return SchlafEintragRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      art: data.art.present ? data.art.value : this.art,
      lfdNr: data.lfdNr.present ? data.lfdNr.value : this.lfdNr,
      schlafMinuten: data.schlafMinuten.present
          ? data.schlafMinuten.value
          : this.schlafMinuten,
      beginnMinuten: data.beginnMinuten.present
          ? data.beginnMinuten.value
          : this.beginnMinuten,
      endeMinuten: data.endeMinuten.present
          ? data.endeMinuten.value
          : this.endeMinuten,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SchlafEintragRow(')
          ..write('tag: $tag, ')
          ..write('art: $art, ')
          ..write('lfdNr: $lfdNr, ')
          ..write('schlafMinuten: $schlafMinuten, ')
          ..write('beginnMinuten: $beginnMinuten, ')
          ..write('endeMinuten: $endeMinuten, ')
          ..write('notiz: $notiz')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tag,
    art,
    lfdNr,
    schlafMinuten,
    beginnMinuten,
    endeMinuten,
    notiz,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SchlafEintragRow &&
          other.tag == this.tag &&
          other.art == this.art &&
          other.lfdNr == this.lfdNr &&
          other.schlafMinuten == this.schlafMinuten &&
          other.beginnMinuten == this.beginnMinuten &&
          other.endeMinuten == this.endeMinuten &&
          other.notiz == this.notiz);
}

class SchlafEintraegeCompanion extends UpdateCompanion<SchlafEintragRow> {
  final Value<String> tag;
  final Value<String> art;
  final Value<int> lfdNr;
  final Value<int> schlafMinuten;
  final Value<int?> beginnMinuten;
  final Value<int?> endeMinuten;
  final Value<String?> notiz;
  final Value<int> rowid;
  const SchlafEintraegeCompanion({
    this.tag = const Value.absent(),
    this.art = const Value.absent(),
    this.lfdNr = const Value.absent(),
    this.schlafMinuten = const Value.absent(),
    this.beginnMinuten = const Value.absent(),
    this.endeMinuten = const Value.absent(),
    this.notiz = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SchlafEintraegeCompanion.insert({
    required String tag,
    required String art,
    required int lfdNr,
    required int schlafMinuten,
    this.beginnMinuten = const Value.absent(),
    this.endeMinuten = const Value.absent(),
    this.notiz = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : tag = Value(tag),
       art = Value(art),
       lfdNr = Value(lfdNr),
       schlafMinuten = Value(schlafMinuten);
  static Insertable<SchlafEintragRow> custom({
    Expression<String>? tag,
    Expression<String>? art,
    Expression<int>? lfdNr,
    Expression<int>? schlafMinuten,
    Expression<int>? beginnMinuten,
    Expression<int>? endeMinuten,
    Expression<String>? notiz,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (art != null) 'art': art,
      if (lfdNr != null) 'lfd_nr': lfdNr,
      if (schlafMinuten != null) 'schlaf_minuten': schlafMinuten,
      if (beginnMinuten != null) 'beginn_minuten': beginnMinuten,
      if (endeMinuten != null) 'ende_minuten': endeMinuten,
      if (notiz != null) 'notiz': notiz,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SchlafEintraegeCompanion copyWith({
    Value<String>? tag,
    Value<String>? art,
    Value<int>? lfdNr,
    Value<int>? schlafMinuten,
    Value<int?>? beginnMinuten,
    Value<int?>? endeMinuten,
    Value<String?>? notiz,
    Value<int>? rowid,
  }) {
    return SchlafEintraegeCompanion(
      tag: tag ?? this.tag,
      art: art ?? this.art,
      lfdNr: lfdNr ?? this.lfdNr,
      schlafMinuten: schlafMinuten ?? this.schlafMinuten,
      beginnMinuten: beginnMinuten ?? this.beginnMinuten,
      endeMinuten: endeMinuten ?? this.endeMinuten,
      notiz: notiz ?? this.notiz,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (art.present) {
      map['art'] = Variable<String>(art.value);
    }
    if (lfdNr.present) {
      map['lfd_nr'] = Variable<int>(lfdNr.value);
    }
    if (schlafMinuten.present) {
      map['schlaf_minuten'] = Variable<int>(schlafMinuten.value);
    }
    if (beginnMinuten.present) {
      map['beginn_minuten'] = Variable<int>(beginnMinuten.value);
    }
    if (endeMinuten.present) {
      map['ende_minuten'] = Variable<int>(endeMinuten.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SchlafEintraegeCompanion(')
          ..write('tag: $tag, ')
          ..write('art: $art, ')
          ..write('lfdNr: $lfdNr, ')
          ..write('schlafMinuten: $schlafMinuten, ')
          ..write('beginnMinuten: $beginnMinuten, ')
          ..write('endeMinuten: $endeMinuten, ')
          ..write('notiz: $notiz, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StammdatenTable extends Stammdaten
    with TableInfo<$StammdatenTable, StammdatenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StammdatenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _groesseCmMeta = const VerificationMeta(
    'groesseCm',
  );
  @override
  late final GeneratedColumn<int> groesseCm = GeneratedColumn<int>(
    'groesse_cm',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geburtsjahrMeta = const VerificationMeta(
    'geburtsjahr',
  );
  @override
  late final GeneratedColumn<int> geburtsjahr = GeneratedColumn<int>(
    'geburtsjahr',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zielgewichtKgMeta = const VerificationMeta(
    'zielgewichtKg',
  );
  @override
  late final GeneratedColumn<double> zielgewichtKg = GeneratedColumn<double>(
    'zielgewicht_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zieldatumMeta = const VerificationMeta(
    'zieldatum',
  );
  @override
  late final GeneratedColumn<String> zieldatum = GeneratedColumn<String>(
    'zieldatum',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groesseCm,
    geburtsjahr,
    zielgewichtKg,
    zieldatum,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stammdaten';
  @override
  VerificationContext validateIntegrity(
    Insertable<StammdatenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('groesse_cm')) {
      context.handle(
        _groesseCmMeta,
        groesseCm.isAcceptableOrUnknown(data['groesse_cm']!, _groesseCmMeta),
      );
    }
    if (data.containsKey('geburtsjahr')) {
      context.handle(
        _geburtsjahrMeta,
        geburtsjahr.isAcceptableOrUnknown(
          data['geburtsjahr']!,
          _geburtsjahrMeta,
        ),
      );
    }
    if (data.containsKey('zielgewicht_kg')) {
      context.handle(
        _zielgewichtKgMeta,
        zielgewichtKg.isAcceptableOrUnknown(
          data['zielgewicht_kg']!,
          _zielgewichtKgMeta,
        ),
      );
    }
    if (data.containsKey('zieldatum')) {
      context.handle(
        _zieldatumMeta,
        zieldatum.isAcceptableOrUnknown(data['zieldatum']!, _zieldatumMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StammdatenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StammdatenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      groesseCm: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}groesse_cm'],
      ),
      geburtsjahr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}geburtsjahr'],
      ),
      zielgewichtKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}zielgewicht_kg'],
      ),
      zieldatum: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zieldatum'],
      ),
    );
  }

  @override
  $StammdatenTable createAlias(String alias) {
    return $StammdatenTable(attachedDatabase, alias);
  }
}

class StammdatenRow extends DataClass implements Insertable<StammdatenRow> {
  final int id;

  /// Körpergröße in ganzen Zentimetern.
  final int? groesseCm;

  /// Geburtsjahr als vierstellige Jahreszahl — kein Geburtsdatum und kein
  /// `DateTime`. Mifflin-St Jeor braucht das Alter in Jahren; ein volles
  /// Datum wäre eine Angabe mehr, als die Formel trägt.
  final int? geburtsjahr;

  /// Zielgewicht in Kilogramm.
  ///
  /// **`RealColumn`, nicht `IntColumn`:** Eine Ganzzahlspalte zwänge zum
  /// Runden, und das wäre eine stille Veränderung von Tims Wert auf dem
  /// Weg in den Cache — derselbe Grund, aus dem
  /// [TagesWerte.trainingsMinuten] in #194 eine `RealColumn` wurde.
  final double? zielgewichtKg;

  /// Das Datum, zu dem das Zielgewicht erreicht sein soll, als
  /// **ISO-Tagesstring** (`YYYY-MM-DD`) — derselbe Schlüsseltyp wie
  /// [TagesWerte.tag]. Kein Zeitpunkt und keine Epoch-Zahl: Ein Zieldatum
  /// ist eine Kalenderangabe; als Zeitstempel abgelegt hinge es an einer
  /// Zeitzone und wäre nach der nächsten Umstellung der Vortag.
  final String? zieldatum;
  const StammdatenRow({
    required this.id,
    this.groesseCm,
    this.geburtsjahr,
    this.zielgewichtKg,
    this.zieldatum,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || groesseCm != null) {
      map['groesse_cm'] = Variable<int>(groesseCm);
    }
    if (!nullToAbsent || geburtsjahr != null) {
      map['geburtsjahr'] = Variable<int>(geburtsjahr);
    }
    if (!nullToAbsent || zielgewichtKg != null) {
      map['zielgewicht_kg'] = Variable<double>(zielgewichtKg);
    }
    if (!nullToAbsent || zieldatum != null) {
      map['zieldatum'] = Variable<String>(zieldatum);
    }
    return map;
  }

  StammdatenCompanion toCompanion(bool nullToAbsent) {
    return StammdatenCompanion(
      id: Value(id),
      groesseCm: groesseCm == null && nullToAbsent
          ? const Value.absent()
          : Value(groesseCm),
      geburtsjahr: geburtsjahr == null && nullToAbsent
          ? const Value.absent()
          : Value(geburtsjahr),
      zielgewichtKg: zielgewichtKg == null && nullToAbsent
          ? const Value.absent()
          : Value(zielgewichtKg),
      zieldatum: zieldatum == null && nullToAbsent
          ? const Value.absent()
          : Value(zieldatum),
    );
  }

  factory StammdatenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StammdatenRow(
      id: serializer.fromJson<int>(json['id']),
      groesseCm: serializer.fromJson<int?>(json['groesseCm']),
      geburtsjahr: serializer.fromJson<int?>(json['geburtsjahr']),
      zielgewichtKg: serializer.fromJson<double?>(json['zielgewichtKg']),
      zieldatum: serializer.fromJson<String?>(json['zieldatum']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'groesseCm': serializer.toJson<int?>(groesseCm),
      'geburtsjahr': serializer.toJson<int?>(geburtsjahr),
      'zielgewichtKg': serializer.toJson<double?>(zielgewichtKg),
      'zieldatum': serializer.toJson<String?>(zieldatum),
    };
  }

  StammdatenRow copyWith({
    int? id,
    Value<int?> groesseCm = const Value.absent(),
    Value<int?> geburtsjahr = const Value.absent(),
    Value<double?> zielgewichtKg = const Value.absent(),
    Value<String?> zieldatum = const Value.absent(),
  }) => StammdatenRow(
    id: id ?? this.id,
    groesseCm: groesseCm.present ? groesseCm.value : this.groesseCm,
    geburtsjahr: geburtsjahr.present ? geburtsjahr.value : this.geburtsjahr,
    zielgewichtKg: zielgewichtKg.present
        ? zielgewichtKg.value
        : this.zielgewichtKg,
    zieldatum: zieldatum.present ? zieldatum.value : this.zieldatum,
  );
  StammdatenRow copyWithCompanion(StammdatenCompanion data) {
    return StammdatenRow(
      id: data.id.present ? data.id.value : this.id,
      groesseCm: data.groesseCm.present ? data.groesseCm.value : this.groesseCm,
      geburtsjahr: data.geburtsjahr.present
          ? data.geburtsjahr.value
          : this.geburtsjahr,
      zielgewichtKg: data.zielgewichtKg.present
          ? data.zielgewichtKg.value
          : this.zielgewichtKg,
      zieldatum: data.zieldatum.present ? data.zieldatum.value : this.zieldatum,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StammdatenRow(')
          ..write('id: $id, ')
          ..write('groesseCm: $groesseCm, ')
          ..write('geburtsjahr: $geburtsjahr, ')
          ..write('zielgewichtKg: $zielgewichtKg, ')
          ..write('zieldatum: $zieldatum')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, groesseCm, geburtsjahr, zielgewichtKg, zieldatum);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StammdatenRow &&
          other.id == this.id &&
          other.groesseCm == this.groesseCm &&
          other.geburtsjahr == this.geburtsjahr &&
          other.zielgewichtKg == this.zielgewichtKg &&
          other.zieldatum == this.zieldatum);
}

class StammdatenCompanion extends UpdateCompanion<StammdatenRow> {
  final Value<int> id;
  final Value<int?> groesseCm;
  final Value<int?> geburtsjahr;
  final Value<double?> zielgewichtKg;
  final Value<String?> zieldatum;
  const StammdatenCompanion({
    this.id = const Value.absent(),
    this.groesseCm = const Value.absent(),
    this.geburtsjahr = const Value.absent(),
    this.zielgewichtKg = const Value.absent(),
    this.zieldatum = const Value.absent(),
  });
  StammdatenCompanion.insert({
    this.id = const Value.absent(),
    this.groesseCm = const Value.absent(),
    this.geburtsjahr = const Value.absent(),
    this.zielgewichtKg = const Value.absent(),
    this.zieldatum = const Value.absent(),
  });
  static Insertable<StammdatenRow> custom({
    Expression<int>? id,
    Expression<int>? groesseCm,
    Expression<int>? geburtsjahr,
    Expression<double>? zielgewichtKg,
    Expression<String>? zieldatum,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groesseCm != null) 'groesse_cm': groesseCm,
      if (geburtsjahr != null) 'geburtsjahr': geburtsjahr,
      if (zielgewichtKg != null) 'zielgewicht_kg': zielgewichtKg,
      if (zieldatum != null) 'zieldatum': zieldatum,
    });
  }

  StammdatenCompanion copyWith({
    Value<int>? id,
    Value<int?>? groesseCm,
    Value<int?>? geburtsjahr,
    Value<double?>? zielgewichtKg,
    Value<String?>? zieldatum,
  }) {
    return StammdatenCompanion(
      id: id ?? this.id,
      groesseCm: groesseCm ?? this.groesseCm,
      geburtsjahr: geburtsjahr ?? this.geburtsjahr,
      zielgewichtKg: zielgewichtKg ?? this.zielgewichtKg,
      zieldatum: zieldatum ?? this.zieldatum,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (groesseCm.present) {
      map['groesse_cm'] = Variable<int>(groesseCm.value);
    }
    if (geburtsjahr.present) {
      map['geburtsjahr'] = Variable<int>(geburtsjahr.value);
    }
    if (zielgewichtKg.present) {
      map['zielgewicht_kg'] = Variable<double>(zielgewichtKg.value);
    }
    if (zieldatum.present) {
      map['zieldatum'] = Variable<String>(zieldatum.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StammdatenCompanion(')
          ..write('id: $id, ')
          ..write('groesseCm: $groesseCm, ')
          ..write('geburtsjahr: $geburtsjahr, ')
          ..write('zielgewichtKg: $zielgewichtKg, ')
          ..write('zieldatum: $zieldatum')
          ..write(')'))
        .toString();
  }
}

class $LebensmittelTable extends Lebensmittel
    with TableInfo<$LebensmittelTable, LebensmittelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LebensmittelTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eiweissGMeta = const VerificationMeta(
    'eiweissG',
  );
  @override
  late final GeneratedColumn<double> eiweissG = GeneratedColumn<double>(
    'eiweiss_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kohlenhydrateGMeta = const VerificationMeta(
    'kohlenhydrateG',
  );
  @override
  late final GeneratedColumn<double> kohlenhydrateG = GeneratedColumn<double>(
    'kohlenhydrate_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fettGMeta = const VerificationMeta('fettG');
  @override
  late final GeneratedColumn<double> fettG = GeneratedColumn<double>(
    'fett_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zuckerGMeta = const VerificationMeta(
    'zuckerG',
  );
  @override
  late final GeneratedColumn<double> zuckerG = GeneratedColumn<double>(
    'zucker_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ballaststoffeGMeta = const VerificationMeta(
    'ballaststoffeG',
  );
  @override
  late final GeneratedColumn<double> ballaststoffeG = GeneratedColumn<double>(
    'ballaststoffe_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gesaettigtGMeta = const VerificationMeta(
    'gesaettigtG',
  );
  @override
  late final GeneratedColumn<double> gesaettigtG = GeneratedColumn<double>(
    'gesaettigt_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wasserMlMeta = const VerificationMeta(
    'wasserMl',
  );
  @override
  late final GeneratedColumn<double> wasserMl = GeneratedColumn<double>(
    'wasser_ml',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _fluessigMeta = const VerificationMeta(
    'fluessig',
  );
  @override
  late final GeneratedColumn<bool> fluessig = GeneratedColumn<bool>(
    'fluessig',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fluessig" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _zuletztBenutztMeta = const VerificationMeta(
    'zuletztBenutzt',
  );
  @override
  late final GeneratedColumn<DateTime> zuletztBenutzt =
      GeneratedColumn<DateTime>(
        'zuletzt_benutzt',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _herkunftMeta = const VerificationMeta(
    'herkunft',
  );
  @override
  late final GeneratedColumn<String> herkunft = GeneratedColumn<String>(
    'herkunft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('eigen'),
  );
  static const VerificationMeta _portionenAbgefragtAmMeta =
      const VerificationMeta('portionenAbgefragtAm');
  @override
  late final GeneratedColumn<DateTime> portionenAbgefragtAm =
      GeneratedColumn<DateTime>(
        'portionen_abgefragt_am',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geaendertAmMeta = const VerificationMeta(
    'geaendertAm',
  );
  @override
  late final GeneratedColumn<DateTime> geaendertAm = GeneratedColumn<DateTime>(
    'geaendert_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geloeschtAmMeta = const VerificationMeta(
    'geloeschtAm',
  );
  @override
  late final GeneratedColumn<DateTime> geloeschtAm = GeneratedColumn<DateTime>(
    'geloescht_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autorMeta = const VerificationMeta('autor');
  @override
  late final GeneratedColumn<String> autor = GeneratedColumn<String>(
    'autor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quelleSchluesselMeta = const VerificationMeta(
    'quelleSchluessel',
  );
  @override
  late final GeneratedColumn<String> quelleSchluessel = GeneratedColumn<String>(
    'quelle_schluessel',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    ballaststoffeG,
    gesaettigtG,
    wasserMl,
    extra,
    fluessig,
    zuletztBenutzt,
    barcode,
    herkunft,
    portionenAbgefragtAm,
    uuid,
    geaendertAm,
    geloeschtAm,
    autor,
    quelleSchluessel,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'lebensmittel';
  @override
  VerificationContext validateIntegrity(
    Insertable<LebensmittelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('eiweiss_g')) {
      context.handle(
        _eiweissGMeta,
        eiweissG.isAcceptableOrUnknown(data['eiweiss_g']!, _eiweissGMeta),
      );
    }
    if (data.containsKey('kohlenhydrate_g')) {
      context.handle(
        _kohlenhydrateGMeta,
        kohlenhydrateG.isAcceptableOrUnknown(
          data['kohlenhydrate_g']!,
          _kohlenhydrateGMeta,
        ),
      );
    }
    if (data.containsKey('fett_g')) {
      context.handle(
        _fettGMeta,
        fettG.isAcceptableOrUnknown(data['fett_g']!, _fettGMeta),
      );
    }
    if (data.containsKey('zucker_g')) {
      context.handle(
        _zuckerGMeta,
        zuckerG.isAcceptableOrUnknown(data['zucker_g']!, _zuckerGMeta),
      );
    }
    if (data.containsKey('ballaststoffe_g')) {
      context.handle(
        _ballaststoffeGMeta,
        ballaststoffeG.isAcceptableOrUnknown(
          data['ballaststoffe_g']!,
          _ballaststoffeGMeta,
        ),
      );
    }
    if (data.containsKey('gesaettigt_g')) {
      context.handle(
        _gesaettigtGMeta,
        gesaettigtG.isAcceptableOrUnknown(
          data['gesaettigt_g']!,
          _gesaettigtGMeta,
        ),
      );
    }
    if (data.containsKey('wasser_ml')) {
      context.handle(
        _wasserMlMeta,
        wasserMl.isAcceptableOrUnknown(data['wasser_ml']!, _wasserMlMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    if (data.containsKey('fluessig')) {
      context.handle(
        _fluessigMeta,
        fluessig.isAcceptableOrUnknown(data['fluessig']!, _fluessigMeta),
      );
    }
    if (data.containsKey('zuletzt_benutzt')) {
      context.handle(
        _zuletztBenutztMeta,
        zuletztBenutzt.isAcceptableOrUnknown(
          data['zuletzt_benutzt']!,
          _zuletztBenutztMeta,
        ),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('herkunft')) {
      context.handle(
        _herkunftMeta,
        herkunft.isAcceptableOrUnknown(data['herkunft']!, _herkunftMeta),
      );
    }
    if (data.containsKey('portionen_abgefragt_am')) {
      context.handle(
        _portionenAbgefragtAmMeta,
        portionenAbgefragtAm.isAcceptableOrUnknown(
          data['portionen_abgefragt_am']!,
          _portionenAbgefragtAmMeta,
        ),
      );
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('geaendert_am')) {
      context.handle(
        _geaendertAmMeta,
        geaendertAm.isAcceptableOrUnknown(
          data['geaendert_am']!,
          _geaendertAmMeta,
        ),
      );
    }
    if (data.containsKey('geloescht_am')) {
      context.handle(
        _geloeschtAmMeta,
        geloeschtAm.isAcceptableOrUnknown(
          data['geloescht_am']!,
          _geloeschtAmMeta,
        ),
      );
    }
    if (data.containsKey('autor')) {
      context.handle(
        _autorMeta,
        autor.isAcceptableOrUnknown(data['autor']!, _autorMeta),
      );
    }
    if (data.containsKey('quelle_schluessel')) {
      context.handle(
        _quelleSchluesselMeta,
        quelleSchluessel.isAcceptableOrUnknown(
          data['quelle_schluessel']!,
          _quelleSchluesselMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LebensmittelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LebensmittelRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      ),
      eiweissG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}eiweiss_g'],
      ),
      kohlenhydrateG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kohlenhydrate_g'],
      ),
      fettG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fett_g'],
      ),
      zuckerG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}zucker_g'],
      ),
      ballaststoffeG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ballaststoffe_g'],
      ),
      gesaettigtG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gesaettigt_g'],
      ),
      wasserMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wasser_ml'],
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
      fluessig: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fluessig'],
      )!,
      zuletztBenutzt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zuletzt_benutzt'],
      ),
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      herkunft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}herkunft'],
      )!,
      portionenAbgefragtAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}portionen_abgefragt_am'],
      ),
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      ),
      geaendertAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geaendert_am'],
      ),
      geloeschtAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geloescht_am'],
      ),
      autor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}autor'],
      ),
      quelleSchluessel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quelle_schluessel'],
      ),
    );
  }

  @override
  $LebensmittelTable createAlias(String alias) {
    return $LebensmittelTable(attachedDatabase, alias);
  }
}

class LebensmittelRow extends DataClass implements Insertable<LebensmittelRow> {
  /// Der Schlüssel, **mit `AUTOINCREMENT`** — aus demselben Grund wie bei
  /// [Eintraege.id]: `Eintraege.lebensmittelId` zeigt hierher, und eine
  /// nach einer Löschung erneut vergebene Zeilennummer hinge einen
  /// gebuchten Eintrag lautlos an eine fremde Vorlage.
  final int id;

  /// Wie die Vorlage heißt — das, wonach die Suche sucht.
  ///
  /// **`NOT NULL` mit Vorgabewert `''`.** `LebensmittelVorlage.name` ist
  /// ein nicht-nullbarer `String`, die treue Abbildung davon ist
  /// `NOT NULL`. Dann braucht die Spalte aber einen Vorgabewert, denn
  /// SQLite lehnt `ALTER TABLE … ADD COLUMN … NOT NULL` ohne ihn ab — und
  /// genau diesen Weg nimmt die Stufe 13 (siehe Dateikopf). Der leere Name
  /// ist dabei kein erfundener Name, sondern das Eingeständnis, dass
  /// keiner dasteht: Auf einem v12-Gerät gab es die Spalte nicht, also
  /// weiß niemand mehr, wie die Vorlage hieß.
  final String name;

  /// Die acht Nährwerte **je 100 g** — benannt wie in [Eintraege], weil
  /// beide dasselbe halten: einen `Naehrwerte`-Satz. Zwei Schreibweisen
  /// für dasselbe Feld wären zwei Umwandlungen, die auseinanderlaufen
  /// können, und die Zahlen wandern beim Buchen von hier nach dort.
  ///
  /// Alle nullbar: Ein Lebensmittel ohne Ballaststoffangabe hat nicht 0 g
  /// davon, sondern keine Angabe (#232). Eine **gewogene** Null bleibt
  /// dagegen `0` — Mineralwasser hat 0 kcal, und das ist eine Messung.
  final double? kcal;
  final double? eiweissG;
  final double? kohlenhydrateG;
  final double? fettG;
  final double? zuckerG;
  final double? ballaststoffeG;
  final double? gesaettigtG;
  final double? wasserMl;

  /// Die übrigen Nährwerte als JSON-Objekt — dieselbe Spalte und derselbe
  /// Name wie bei [Eintraege.extra], und aus denselben Gründen:
  /// `Naehrwerte.extra` ist eine nicht-nullbare Map, das leere Objekt ist
  /// ihr genaues Abbild, und der Vorgabewert macht die Spalte nachtragbar.
  final String extra;

  /// Ob in Millilitern gerechnet wird statt in Gramm — **das ist alles,
  /// was dieses Feld entscheidet.** Ein Getränk wiegt man nicht, man
  /// schenkt es ein (`docs/screens/screens/erfassen.js`, Zustand
  /// `anlegen`).
  ///
  /// Vorgabe `false`: Ein Lebensmittel ohne Angabe ist fest, nicht
  /// unbekannt. `drift`s `boolean()` legt dafür eine `INTEGER`-Spalte mit
  /// `CHECK (… IN (0, 1))` an — SQLite kennt keinen Wahrheitstyp.
  final bool fluessig;

  /// Wann die Vorlage zuletzt gebucht wurde — **nullbar**: Angelegt ist
  /// nicht benutzt.
  ///
  /// Ein Vorgabewert wäre hier ein erfundener Zeitpunkt, und „nie benutzt"
  /// ist in der Reihenfolge der Suche ein eigener Fall: zuletzt Benutztes
  /// zuerst, nie Benutztes danach alphabetisch.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT (`CLAUDE.md`).
  final DateTime? zuletztBenutzt;

  /// Der Strichcode (EAN) — **nullbar**: Ein selbst angelegtes
  /// Lebensmittel hat keinen (Schema v14, #284).
  ///
  /// Er ist das, woran die Tabelle ein übernommenes Produkt aus Open Food
  /// Facts wiedererkennt. Ohne ihn legte jedes Buchen desselben Produkts
  /// ein neues an, und die Suche könnte einen Online-Treffer nicht gegen
  /// die eigene Kopie abgleichen.
  ///
  /// **Kein `UNIQUE`-Index.** Dass ein Strichcode nur einmal übernommen
  /// wird, sichert `LebensmittelRepository.uebernimm` in einer Transaktion
  /// ab. Ein Index ließe sich über `_reconcileSchema` nicht nachziehen —
  /// der kennt Tabellen und Spalten, keine Indizes — und stünde damit auf
  /// manchen Geräten und auf anderen nicht.
  final String? barcode;

  /// Woher die Vorlage stammt: `'eigen'` oder `'off'` (Open Food Facts) —
  /// als Text, damit lesbar bleibt, was dasteht, wer die Datei mit einem
  /// SQLite-Werkzeug öffnet (dieselbe Haltung wie `eintraege.mahlzeit`).
  ///
  /// **`NOT NULL` mit Vorgabewert `'eigen'`.** Der Vorgabewert ist hier
  /// keine erfundene Angabe: Vor v14 gab es keinen Weg aus Open Food Facts
  /// in die Tabelle, jede ältere Zeile ist von Hand angelegt. Und SQLite
  /// lehnt `ADD COLUMN … NOT NULL` ohne ihn ab (Dateikopf).
  final String herkunft;

  /// Wann Open Food Facts zu diesem Produkt nach Portionen gefragt wurde
  /// und geantwortet hat (Schema v17, #393) — **nullbar und ohne
  /// Vorgabewert**.
  ///
  /// Ein Vorgabewert behauptete eine Anfrage, die es nie gab. Alte Zeilen
  /// bleiben `null`, und genau das löst die einmalige Nachfrage aus. Die
  /// Stufe 17 setzt die Spalte nirgends.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT und kommt als UTC zurück (`CLAUDE.md`).
  ///
  /// **Kein Index**, aus demselben Grund wie bei [barcode].
  final DateTime? portionenAbgefragtAm;

  /// Die Sync-Identität neben der Autoincrement-ID (Schema v25, #542).
  ///
  /// Später sollen eigene Vorlagen und Rezepte zwischen den Nutzer*innen
  /// geteilt werden; ein Autoincrement-Schlüssel taugt dafür nicht, weil
  /// zwei Geräte unabhängig dieselbe 7 vergeben. Die Spalte steht jetzt
  /// da, damit der Sync ein Anbau wird und kein Umbau.
  ///
  /// **Nullbar und ohne Vorgabewert** — wie alle vier Nachbarn unten.
  /// Vor v25 gab es keinen Sync, also hat niemand eine UUID vergeben;
  /// eine nachträglich erfundene behauptete das Gegenteil.
  ///
  /// **Kein `UNIQUE`**, aus demselben Grund wie bei [barcode]: Der
  /// Abgleich beim Öffnen kennt Tabellen und Spalten, keine Indizes, und
  /// eine Eindeutigkeit, die auf manchen Geräten gilt und auf anderen
  /// nicht, ist keine.
  final String? uuid;

  /// Wann die Zeile zuletzt geändert wurde (Schema v25, #542) — die
  /// Grundlage jedes späteren Abgleichs zweier Stände.
  ///
  /// Nullbar und ohne Vorgabewert: Ein Vorgabewert behauptete, jede alte
  /// Zeile sei eben erst geändert worden. TEXT und UTC wie überall
  /// (`storeDateTimeAsText`, `CLAUDE.md`).
  final DateTime? geaendertAm;

  /// Der Löschmarker (Schema v25, #542): Ein gelöschtes Lebensmittel wird
  /// später markiert statt entfernt, sonst kehrt es beim nächsten Abgleich
  /// vom anderen Gerät zurück.
  ///
  /// **Gelöscht wird bis auf Weiteres gar nicht** — das Repository kennt
  /// keinen Weg dorthin. Die Spalte hält den Platz frei; sie ist leer,
  /// und das ist die Wahrheit.
  final DateTime? geloeschtAm;

  /// Wer die Vorlage angelegt hat (Schema v25, #542) — gefüllt erst, wenn
  /// es mehr als ein Gerät gibt.
  ///
  /// Nullbar und ohne Vorgabewert: Ein Vorgabe-Autor behauptete, jede
  /// alte Vorlage stamme von ihm.
  final String? autor;

  /// Der Schlüssel in der Quelle, aus der die Vorlage übernommen wurde
  /// (Schema v25, #542): der BLS-Code bei Grundnahrung aus dem
  /// Bundeslebensmittelschlüssel, die EAN bei einem Produkt aus Open Food
  /// Facts.
  ///
  /// Warum nicht [barcode]: Ein BLS-Code ist kein Strichcode, und
  /// `zuBarcode` sucht Produkte, die man scannen kann. Ein BLS-Eintrag im
  /// Barcode-Feld träfe bei jedem Scan daneben.
  ///
  /// Nullbar und ohne Vorgabewert: Vor dem Seed gab es keine Herkunft,
  /// die einen Schlüssel hätte.
  final String? quelleSchluessel;
  const LebensmittelRow({
    required this.id,
    required this.name,
    this.kcal,
    this.eiweissG,
    this.kohlenhydrateG,
    this.fettG,
    this.zuckerG,
    this.ballaststoffeG,
    this.gesaettigtG,
    this.wasserMl,
    required this.extra,
    required this.fluessig,
    this.zuletztBenutzt,
    this.barcode,
    required this.herkunft,
    this.portionenAbgefragtAm,
    this.uuid,
    this.geaendertAm,
    this.geloeschtAm,
    this.autor,
    this.quelleSchluessel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<double>(kcal);
    }
    if (!nullToAbsent || eiweissG != null) {
      map['eiweiss_g'] = Variable<double>(eiweissG);
    }
    if (!nullToAbsent || kohlenhydrateG != null) {
      map['kohlenhydrate_g'] = Variable<double>(kohlenhydrateG);
    }
    if (!nullToAbsent || fettG != null) {
      map['fett_g'] = Variable<double>(fettG);
    }
    if (!nullToAbsent || zuckerG != null) {
      map['zucker_g'] = Variable<double>(zuckerG);
    }
    if (!nullToAbsent || ballaststoffeG != null) {
      map['ballaststoffe_g'] = Variable<double>(ballaststoffeG);
    }
    if (!nullToAbsent || gesaettigtG != null) {
      map['gesaettigt_g'] = Variable<double>(gesaettigtG);
    }
    if (!nullToAbsent || wasserMl != null) {
      map['wasser_ml'] = Variable<double>(wasserMl);
    }
    map['extra'] = Variable<String>(extra);
    map['fluessig'] = Variable<bool>(fluessig);
    if (!nullToAbsent || zuletztBenutzt != null) {
      map['zuletzt_benutzt'] = Variable<DateTime>(zuletztBenutzt);
    }
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['herkunft'] = Variable<String>(herkunft);
    if (!nullToAbsent || portionenAbgefragtAm != null) {
      map['portionen_abgefragt_am'] = Variable<DateTime>(portionenAbgefragtAm);
    }
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    if (!nullToAbsent || geaendertAm != null) {
      map['geaendert_am'] = Variable<DateTime>(geaendertAm);
    }
    if (!nullToAbsent || geloeschtAm != null) {
      map['geloescht_am'] = Variable<DateTime>(geloeschtAm);
    }
    if (!nullToAbsent || autor != null) {
      map['autor'] = Variable<String>(autor);
    }
    if (!nullToAbsent || quelleSchluessel != null) {
      map['quelle_schluessel'] = Variable<String>(quelleSchluessel);
    }
    return map;
  }

  LebensmittelCompanion toCompanion(bool nullToAbsent) {
    return LebensmittelCompanion(
      id: Value(id),
      name: Value(name),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      eiweissG: eiweissG == null && nullToAbsent
          ? const Value.absent()
          : Value(eiweissG),
      kohlenhydrateG: kohlenhydrateG == null && nullToAbsent
          ? const Value.absent()
          : Value(kohlenhydrateG),
      fettG: fettG == null && nullToAbsent
          ? const Value.absent()
          : Value(fettG),
      zuckerG: zuckerG == null && nullToAbsent
          ? const Value.absent()
          : Value(zuckerG),
      ballaststoffeG: ballaststoffeG == null && nullToAbsent
          ? const Value.absent()
          : Value(ballaststoffeG),
      gesaettigtG: gesaettigtG == null && nullToAbsent
          ? const Value.absent()
          : Value(gesaettigtG),
      wasserMl: wasserMl == null && nullToAbsent
          ? const Value.absent()
          : Value(wasserMl),
      extra: Value(extra),
      fluessig: Value(fluessig),
      zuletztBenutzt: zuletztBenutzt == null && nullToAbsent
          ? const Value.absent()
          : Value(zuletztBenutzt),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      herkunft: Value(herkunft),
      portionenAbgefragtAm: portionenAbgefragtAm == null && nullToAbsent
          ? const Value.absent()
          : Value(portionenAbgefragtAm),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      geaendertAm: geaendertAm == null && nullToAbsent
          ? const Value.absent()
          : Value(geaendertAm),
      geloeschtAm: geloeschtAm == null && nullToAbsent
          ? const Value.absent()
          : Value(geloeschtAm),
      autor: autor == null && nullToAbsent
          ? const Value.absent()
          : Value(autor),
      quelleSchluessel: quelleSchluessel == null && nullToAbsent
          ? const Value.absent()
          : Value(quelleSchluessel),
    );
  }

  factory LebensmittelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LebensmittelRow(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kcal: serializer.fromJson<double?>(json['kcal']),
      eiweissG: serializer.fromJson<double?>(json['eiweissG']),
      kohlenhydrateG: serializer.fromJson<double?>(json['kohlenhydrateG']),
      fettG: serializer.fromJson<double?>(json['fettG']),
      zuckerG: serializer.fromJson<double?>(json['zuckerG']),
      ballaststoffeG: serializer.fromJson<double?>(json['ballaststoffeG']),
      gesaettigtG: serializer.fromJson<double?>(json['gesaettigtG']),
      wasserMl: serializer.fromJson<double?>(json['wasserMl']),
      extra: serializer.fromJson<String>(json['extra']),
      fluessig: serializer.fromJson<bool>(json['fluessig']),
      zuletztBenutzt: serializer.fromJson<DateTime?>(json['zuletztBenutzt']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      herkunft: serializer.fromJson<String>(json['herkunft']),
      portionenAbgefragtAm: serializer.fromJson<DateTime?>(
        json['portionenAbgefragtAm'],
      ),
      uuid: serializer.fromJson<String?>(json['uuid']),
      geaendertAm: serializer.fromJson<DateTime?>(json['geaendertAm']),
      geloeschtAm: serializer.fromJson<DateTime?>(json['geloeschtAm']),
      autor: serializer.fromJson<String?>(json['autor']),
      quelleSchluessel: serializer.fromJson<String?>(json['quelleSchluessel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'kcal': serializer.toJson<double?>(kcal),
      'eiweissG': serializer.toJson<double?>(eiweissG),
      'kohlenhydrateG': serializer.toJson<double?>(kohlenhydrateG),
      'fettG': serializer.toJson<double?>(fettG),
      'zuckerG': serializer.toJson<double?>(zuckerG),
      'ballaststoffeG': serializer.toJson<double?>(ballaststoffeG),
      'gesaettigtG': serializer.toJson<double?>(gesaettigtG),
      'wasserMl': serializer.toJson<double?>(wasserMl),
      'extra': serializer.toJson<String>(extra),
      'fluessig': serializer.toJson<bool>(fluessig),
      'zuletztBenutzt': serializer.toJson<DateTime?>(zuletztBenutzt),
      'barcode': serializer.toJson<String?>(barcode),
      'herkunft': serializer.toJson<String>(herkunft),
      'portionenAbgefragtAm': serializer.toJson<DateTime?>(
        portionenAbgefragtAm,
      ),
      'uuid': serializer.toJson<String?>(uuid),
      'geaendertAm': serializer.toJson<DateTime?>(geaendertAm),
      'geloeschtAm': serializer.toJson<DateTime?>(geloeschtAm),
      'autor': serializer.toJson<String?>(autor),
      'quelleSchluessel': serializer.toJson<String?>(quelleSchluessel),
    };
  }

  LebensmittelRow copyWith({
    int? id,
    String? name,
    Value<double?> kcal = const Value.absent(),
    Value<double?> eiweissG = const Value.absent(),
    Value<double?> kohlenhydrateG = const Value.absent(),
    Value<double?> fettG = const Value.absent(),
    Value<double?> zuckerG = const Value.absent(),
    Value<double?> ballaststoffeG = const Value.absent(),
    Value<double?> gesaettigtG = const Value.absent(),
    Value<double?> wasserMl = const Value.absent(),
    String? extra,
    bool? fluessig,
    Value<DateTime?> zuletztBenutzt = const Value.absent(),
    Value<String?> barcode = const Value.absent(),
    String? herkunft,
    Value<DateTime?> portionenAbgefragtAm = const Value.absent(),
    Value<String?> uuid = const Value.absent(),
    Value<DateTime?> geaendertAm = const Value.absent(),
    Value<DateTime?> geloeschtAm = const Value.absent(),
    Value<String?> autor = const Value.absent(),
    Value<String?> quelleSchluessel = const Value.absent(),
  }) => LebensmittelRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kcal: kcal.present ? kcal.value : this.kcal,
    eiweissG: eiweissG.present ? eiweissG.value : this.eiweissG,
    kohlenhydrateG: kohlenhydrateG.present
        ? kohlenhydrateG.value
        : this.kohlenhydrateG,
    fettG: fettG.present ? fettG.value : this.fettG,
    zuckerG: zuckerG.present ? zuckerG.value : this.zuckerG,
    ballaststoffeG: ballaststoffeG.present
        ? ballaststoffeG.value
        : this.ballaststoffeG,
    gesaettigtG: gesaettigtG.present ? gesaettigtG.value : this.gesaettigtG,
    wasserMl: wasserMl.present ? wasserMl.value : this.wasserMl,
    extra: extra ?? this.extra,
    fluessig: fluessig ?? this.fluessig,
    zuletztBenutzt: zuletztBenutzt.present
        ? zuletztBenutzt.value
        : this.zuletztBenutzt,
    barcode: barcode.present ? barcode.value : this.barcode,
    herkunft: herkunft ?? this.herkunft,
    portionenAbgefragtAm: portionenAbgefragtAm.present
        ? portionenAbgefragtAm.value
        : this.portionenAbgefragtAm,
    uuid: uuid.present ? uuid.value : this.uuid,
    geaendertAm: geaendertAm.present ? geaendertAm.value : this.geaendertAm,
    geloeschtAm: geloeschtAm.present ? geloeschtAm.value : this.geloeschtAm,
    autor: autor.present ? autor.value : this.autor,
    quelleSchluessel: quelleSchluessel.present
        ? quelleSchluessel.value
        : this.quelleSchluessel,
  );
  LebensmittelRow copyWithCompanion(LebensmittelCompanion data) {
    return LebensmittelRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      eiweissG: data.eiweissG.present ? data.eiweissG.value : this.eiweissG,
      kohlenhydrateG: data.kohlenhydrateG.present
          ? data.kohlenhydrateG.value
          : this.kohlenhydrateG,
      fettG: data.fettG.present ? data.fettG.value : this.fettG,
      zuckerG: data.zuckerG.present ? data.zuckerG.value : this.zuckerG,
      ballaststoffeG: data.ballaststoffeG.present
          ? data.ballaststoffeG.value
          : this.ballaststoffeG,
      gesaettigtG: data.gesaettigtG.present
          ? data.gesaettigtG.value
          : this.gesaettigtG,
      wasserMl: data.wasserMl.present ? data.wasserMl.value : this.wasserMl,
      extra: data.extra.present ? data.extra.value : this.extra,
      fluessig: data.fluessig.present ? data.fluessig.value : this.fluessig,
      zuletztBenutzt: data.zuletztBenutzt.present
          ? data.zuletztBenutzt.value
          : this.zuletztBenutzt,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      herkunft: data.herkunft.present ? data.herkunft.value : this.herkunft,
      portionenAbgefragtAm: data.portionenAbgefragtAm.present
          ? data.portionenAbgefragtAm.value
          : this.portionenAbgefragtAm,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      geaendertAm: data.geaendertAm.present
          ? data.geaendertAm.value
          : this.geaendertAm,
      geloeschtAm: data.geloeschtAm.present
          ? data.geloeschtAm.value
          : this.geloeschtAm,
      autor: data.autor.present ? data.autor.value : this.autor,
      quelleSchluessel: data.quelleSchluessel.present
          ? data.quelleSchluessel.value
          : this.quelleSchluessel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LebensmittelRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kcal: $kcal, ')
          ..write('eiweissG: $eiweissG, ')
          ..write('kohlenhydrateG: $kohlenhydrateG, ')
          ..write('fettG: $fettG, ')
          ..write('zuckerG: $zuckerG, ')
          ..write('ballaststoffeG: $ballaststoffeG, ')
          ..write('gesaettigtG: $gesaettigtG, ')
          ..write('wasserMl: $wasserMl, ')
          ..write('extra: $extra, ')
          ..write('fluessig: $fluessig, ')
          ..write('zuletztBenutzt: $zuletztBenutzt, ')
          ..write('barcode: $barcode, ')
          ..write('herkunft: $herkunft, ')
          ..write('portionenAbgefragtAm: $portionenAbgefragtAm, ')
          ..write('uuid: $uuid, ')
          ..write('geaendertAm: $geaendertAm, ')
          ..write('geloeschtAm: $geloeschtAm, ')
          ..write('autor: $autor, ')
          ..write('quelleSchluessel: $quelleSchluessel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    ballaststoffeG,
    gesaettigtG,
    wasserMl,
    extra,
    fluessig,
    zuletztBenutzt,
    barcode,
    herkunft,
    portionenAbgefragtAm,
    uuid,
    geaendertAm,
    geloeschtAm,
    autor,
    quelleSchluessel,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LebensmittelRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kcal == this.kcal &&
          other.eiweissG == this.eiweissG &&
          other.kohlenhydrateG == this.kohlenhydrateG &&
          other.fettG == this.fettG &&
          other.zuckerG == this.zuckerG &&
          other.ballaststoffeG == this.ballaststoffeG &&
          other.gesaettigtG == this.gesaettigtG &&
          other.wasserMl == this.wasserMl &&
          other.extra == this.extra &&
          other.fluessig == this.fluessig &&
          other.zuletztBenutzt == this.zuletztBenutzt &&
          other.barcode == this.barcode &&
          other.herkunft == this.herkunft &&
          other.portionenAbgefragtAm == this.portionenAbgefragtAm &&
          other.uuid == this.uuid &&
          other.geaendertAm == this.geaendertAm &&
          other.geloeschtAm == this.geloeschtAm &&
          other.autor == this.autor &&
          other.quelleSchluessel == this.quelleSchluessel);
}

class LebensmittelCompanion extends UpdateCompanion<LebensmittelRow> {
  final Value<int> id;
  final Value<String> name;
  final Value<double?> kcal;
  final Value<double?> eiweissG;
  final Value<double?> kohlenhydrateG;
  final Value<double?> fettG;
  final Value<double?> zuckerG;
  final Value<double?> ballaststoffeG;
  final Value<double?> gesaettigtG;
  final Value<double?> wasserMl;
  final Value<String> extra;
  final Value<bool> fluessig;
  final Value<DateTime?> zuletztBenutzt;
  final Value<String?> barcode;
  final Value<String> herkunft;
  final Value<DateTime?> portionenAbgefragtAm;
  final Value<String?> uuid;
  final Value<DateTime?> geaendertAm;
  final Value<DateTime?> geloeschtAm;
  final Value<String?> autor;
  final Value<String?> quelleSchluessel;
  const LebensmittelCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kcal = const Value.absent(),
    this.eiweissG = const Value.absent(),
    this.kohlenhydrateG = const Value.absent(),
    this.fettG = const Value.absent(),
    this.zuckerG = const Value.absent(),
    this.ballaststoffeG = const Value.absent(),
    this.gesaettigtG = const Value.absent(),
    this.wasserMl = const Value.absent(),
    this.extra = const Value.absent(),
    this.fluessig = const Value.absent(),
    this.zuletztBenutzt = const Value.absent(),
    this.barcode = const Value.absent(),
    this.herkunft = const Value.absent(),
    this.portionenAbgefragtAm = const Value.absent(),
    this.uuid = const Value.absent(),
    this.geaendertAm = const Value.absent(),
    this.geloeschtAm = const Value.absent(),
    this.autor = const Value.absent(),
    this.quelleSchluessel = const Value.absent(),
  });
  LebensmittelCompanion.insert({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kcal = const Value.absent(),
    this.eiweissG = const Value.absent(),
    this.kohlenhydrateG = const Value.absent(),
    this.fettG = const Value.absent(),
    this.zuckerG = const Value.absent(),
    this.ballaststoffeG = const Value.absent(),
    this.gesaettigtG = const Value.absent(),
    this.wasserMl = const Value.absent(),
    this.extra = const Value.absent(),
    this.fluessig = const Value.absent(),
    this.zuletztBenutzt = const Value.absent(),
    this.barcode = const Value.absent(),
    this.herkunft = const Value.absent(),
    this.portionenAbgefragtAm = const Value.absent(),
    this.uuid = const Value.absent(),
    this.geaendertAm = const Value.absent(),
    this.geloeschtAm = const Value.absent(),
    this.autor = const Value.absent(),
    this.quelleSchluessel = const Value.absent(),
  });
  static Insertable<LebensmittelRow> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<double>? kcal,
    Expression<double>? eiweissG,
    Expression<double>? kohlenhydrateG,
    Expression<double>? fettG,
    Expression<double>? zuckerG,
    Expression<double>? ballaststoffeG,
    Expression<double>? gesaettigtG,
    Expression<double>? wasserMl,
    Expression<String>? extra,
    Expression<bool>? fluessig,
    Expression<DateTime>? zuletztBenutzt,
    Expression<String>? barcode,
    Expression<String>? herkunft,
    Expression<DateTime>? portionenAbgefragtAm,
    Expression<String>? uuid,
    Expression<DateTime>? geaendertAm,
    Expression<DateTime>? geloeschtAm,
    Expression<String>? autor,
    Expression<String>? quelleSchluessel,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kcal != null) 'kcal': kcal,
      if (eiweissG != null) 'eiweiss_g': eiweissG,
      if (kohlenhydrateG != null) 'kohlenhydrate_g': kohlenhydrateG,
      if (fettG != null) 'fett_g': fettG,
      if (zuckerG != null) 'zucker_g': zuckerG,
      if (ballaststoffeG != null) 'ballaststoffe_g': ballaststoffeG,
      if (gesaettigtG != null) 'gesaettigt_g': gesaettigtG,
      if (wasserMl != null) 'wasser_ml': wasserMl,
      if (extra != null) 'extra': extra,
      if (fluessig != null) 'fluessig': fluessig,
      if (zuletztBenutzt != null) 'zuletzt_benutzt': zuletztBenutzt,
      if (barcode != null) 'barcode': barcode,
      if (herkunft != null) 'herkunft': herkunft,
      if (portionenAbgefragtAm != null)
        'portionen_abgefragt_am': portionenAbgefragtAm,
      if (uuid != null) 'uuid': uuid,
      if (geaendertAm != null) 'geaendert_am': geaendertAm,
      if (geloeschtAm != null) 'geloescht_am': geloeschtAm,
      if (autor != null) 'autor': autor,
      if (quelleSchluessel != null) 'quelle_schluessel': quelleSchluessel,
    });
  }

  LebensmittelCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<double?>? kcal,
    Value<double?>? eiweissG,
    Value<double?>? kohlenhydrateG,
    Value<double?>? fettG,
    Value<double?>? zuckerG,
    Value<double?>? ballaststoffeG,
    Value<double?>? gesaettigtG,
    Value<double?>? wasserMl,
    Value<String>? extra,
    Value<bool>? fluessig,
    Value<DateTime?>? zuletztBenutzt,
    Value<String?>? barcode,
    Value<String>? herkunft,
    Value<DateTime?>? portionenAbgefragtAm,
    Value<String?>? uuid,
    Value<DateTime?>? geaendertAm,
    Value<DateTime?>? geloeschtAm,
    Value<String?>? autor,
    Value<String?>? quelleSchluessel,
  }) {
    return LebensmittelCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kcal: kcal ?? this.kcal,
      eiweissG: eiweissG ?? this.eiweissG,
      kohlenhydrateG: kohlenhydrateG ?? this.kohlenhydrateG,
      fettG: fettG ?? this.fettG,
      zuckerG: zuckerG ?? this.zuckerG,
      ballaststoffeG: ballaststoffeG ?? this.ballaststoffeG,
      gesaettigtG: gesaettigtG ?? this.gesaettigtG,
      wasserMl: wasserMl ?? this.wasserMl,
      extra: extra ?? this.extra,
      fluessig: fluessig ?? this.fluessig,
      zuletztBenutzt: zuletztBenutzt ?? this.zuletztBenutzt,
      barcode: barcode ?? this.barcode,
      herkunft: herkunft ?? this.herkunft,
      portionenAbgefragtAm: portionenAbgefragtAm ?? this.portionenAbgefragtAm,
      uuid: uuid ?? this.uuid,
      geaendertAm: geaendertAm ?? this.geaendertAm,
      geloeschtAm: geloeschtAm ?? this.geloeschtAm,
      autor: autor ?? this.autor,
      quelleSchluessel: quelleSchluessel ?? this.quelleSchluessel,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (eiweissG.present) {
      map['eiweiss_g'] = Variable<double>(eiweissG.value);
    }
    if (kohlenhydrateG.present) {
      map['kohlenhydrate_g'] = Variable<double>(kohlenhydrateG.value);
    }
    if (fettG.present) {
      map['fett_g'] = Variable<double>(fettG.value);
    }
    if (zuckerG.present) {
      map['zucker_g'] = Variable<double>(zuckerG.value);
    }
    if (ballaststoffeG.present) {
      map['ballaststoffe_g'] = Variable<double>(ballaststoffeG.value);
    }
    if (gesaettigtG.present) {
      map['gesaettigt_g'] = Variable<double>(gesaettigtG.value);
    }
    if (wasserMl.present) {
      map['wasser_ml'] = Variable<double>(wasserMl.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (fluessig.present) {
      map['fluessig'] = Variable<bool>(fluessig.value);
    }
    if (zuletztBenutzt.present) {
      map['zuletzt_benutzt'] = Variable<DateTime>(zuletztBenutzt.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (herkunft.present) {
      map['herkunft'] = Variable<String>(herkunft.value);
    }
    if (portionenAbgefragtAm.present) {
      map['portionen_abgefragt_am'] = Variable<DateTime>(
        portionenAbgefragtAm.value,
      );
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (geaendertAm.present) {
      map['geaendert_am'] = Variable<DateTime>(geaendertAm.value);
    }
    if (geloeschtAm.present) {
      map['geloescht_am'] = Variable<DateTime>(geloeschtAm.value);
    }
    if (autor.present) {
      map['autor'] = Variable<String>(autor.value);
    }
    if (quelleSchluessel.present) {
      map['quelle_schluessel'] = Variable<String>(quelleSchluessel.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LebensmittelCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kcal: $kcal, ')
          ..write('eiweissG: $eiweissG, ')
          ..write('kohlenhydrateG: $kohlenhydrateG, ')
          ..write('fettG: $fettG, ')
          ..write('zuckerG: $zuckerG, ')
          ..write('ballaststoffeG: $ballaststoffeG, ')
          ..write('gesaettigtG: $gesaettigtG, ')
          ..write('wasserMl: $wasserMl, ')
          ..write('extra: $extra, ')
          ..write('fluessig: $fluessig, ')
          ..write('zuletztBenutzt: $zuletztBenutzt, ')
          ..write('barcode: $barcode, ')
          ..write('herkunft: $herkunft, ')
          ..write('portionenAbgefragtAm: $portionenAbgefragtAm, ')
          ..write('uuid: $uuid, ')
          ..write('geaendertAm: $geaendertAm, ')
          ..write('geloeschtAm: $geloeschtAm, ')
          ..write('autor: $autor, ')
          ..write('quelleSchluessel: $quelleSchluessel')
          ..write(')'))
        .toString();
  }
}

class $PortionenTable extends Portionen
    with TableInfo<$PortionenTable, PortionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PortionenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lebensmittelIdMeta = const VerificationMeta(
    'lebensmittelId',
  );
  @override
  late final GeneratedColumn<int> lebensmittelId = GeneratedColumn<int>(
    'lebensmittel_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _mengeGMeta = const VerificationMeta('mengeG');
  @override
  late final GeneratedColumn<double> mengeG = GeneratedColumn<double>(
    'menge_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _herkunftMeta = const VerificationMeta(
    'herkunft',
  );
  @override
  late final GeneratedColumn<String> herkunft = GeneratedColumn<String>(
    'herkunft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('eigen'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lebensmittelId,
    name,
    mengeG,
    herkunft,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'portionen';
  @override
  VerificationContext validateIntegrity(
    Insertable<PortionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lebensmittel_id')) {
      context.handle(
        _lebensmittelIdMeta,
        lebensmittelId.isAcceptableOrUnknown(
          data['lebensmittel_id']!,
          _lebensmittelIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('menge_g')) {
      context.handle(
        _mengeGMeta,
        mengeG.isAcceptableOrUnknown(data['menge_g']!, _mengeGMeta),
      );
    }
    if (data.containsKey('herkunft')) {
      context.handle(
        _herkunftMeta,
        herkunft.isAcceptableOrUnknown(data['herkunft']!, _herkunftMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PortionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PortionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lebensmittelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lebensmittel_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mengeG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}menge_g'],
      ),
      herkunft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}herkunft'],
      )!,
    );
  }

  @override
  $PortionenTable createAlias(String alias) {
    return $PortionenTable(attachedDatabase, alias);
  }
}

class PortionRow extends DataClass implements Insertable<PortionRow> {
  final int id;

  /// Das Lebensmittel, zu dem die Portion gehört — **ohne
  /// Fremdschlüssel**, wie [Eintraege.lebensmittelId].
  ///
  /// Nullbar ist sie nur, weil sie nachgetragen wird: SQLite lehnt
  /// `ADD COLUMN … NOT NULL` ohne Vorgabewert ab, und für eine
  /// Lebensmittel-ID gibt es keinen ehrlichen. Das Repository schreibt
  /// immer eine ID und liest nur Zeilen mit ID.
  final int? lebensmittelId;

  /// Wie die Portion heißt, etwa „Portion", „Packung", „Bon" oder
  /// „Schale".
  ///
  /// **`NOT NULL` mit Vorgabewert `''`**, wie `lebensmittel.name`: Der
  /// leere Name ist das Eingeständnis, dass keiner dasteht, und der
  /// Vorgabewert macht die Spalte nachtragbar (Dateikopf).
  final String name;

  /// Die Menge je Portion **in der Einheit des Lebensmittels**
  /// (`fluessig`), nach derselben Konvention wie [Eintraege.mengeG] —
  /// nullbar und ohne Vorgabewert.
  ///
  /// Eine Vorgabe `0` wäre eine Portion von 0 g. Gelesen werden nur Zeilen
  /// mit `menge_g > 0`, denn eine Portion ohne Gramm ist keine.
  final double? mengeG;

  /// Woher die Portion stammt: `'eigen'` oder `'off'`, als Wort wie bei
  /// [Lebensmittel.herkunft].
  ///
  /// **`NOT NULL` mit Vorgabewert `'eigen'`.** Vor v17 gab es keinen Weg
  /// aus Open Food Facts in diese Tabelle.
  final String herkunft;
  const PortionRow({
    required this.id,
    this.lebensmittelId,
    required this.name,
    this.mengeG,
    required this.herkunft,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || lebensmittelId != null) {
      map['lebensmittel_id'] = Variable<int>(lebensmittelId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || mengeG != null) {
      map['menge_g'] = Variable<double>(mengeG);
    }
    map['herkunft'] = Variable<String>(herkunft);
    return map;
  }

  PortionenCompanion toCompanion(bool nullToAbsent) {
    return PortionenCompanion(
      id: Value(id),
      lebensmittelId: lebensmittelId == null && nullToAbsent
          ? const Value.absent()
          : Value(lebensmittelId),
      name: Value(name),
      mengeG: mengeG == null && nullToAbsent
          ? const Value.absent()
          : Value(mengeG),
      herkunft: Value(herkunft),
    );
  }

  factory PortionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PortionRow(
      id: serializer.fromJson<int>(json['id']),
      lebensmittelId: serializer.fromJson<int?>(json['lebensmittelId']),
      name: serializer.fromJson<String>(json['name']),
      mengeG: serializer.fromJson<double?>(json['mengeG']),
      herkunft: serializer.fromJson<String>(json['herkunft']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lebensmittelId': serializer.toJson<int?>(lebensmittelId),
      'name': serializer.toJson<String>(name),
      'mengeG': serializer.toJson<double?>(mengeG),
      'herkunft': serializer.toJson<String>(herkunft),
    };
  }

  PortionRow copyWith({
    int? id,
    Value<int?> lebensmittelId = const Value.absent(),
    String? name,
    Value<double?> mengeG = const Value.absent(),
    String? herkunft,
  }) => PortionRow(
    id: id ?? this.id,
    lebensmittelId: lebensmittelId.present
        ? lebensmittelId.value
        : this.lebensmittelId,
    name: name ?? this.name,
    mengeG: mengeG.present ? mengeG.value : this.mengeG,
    herkunft: herkunft ?? this.herkunft,
  );
  PortionRow copyWithCompanion(PortionenCompanion data) {
    return PortionRow(
      id: data.id.present ? data.id.value : this.id,
      lebensmittelId: data.lebensmittelId.present
          ? data.lebensmittelId.value
          : this.lebensmittelId,
      name: data.name.present ? data.name.value : this.name,
      mengeG: data.mengeG.present ? data.mengeG.value : this.mengeG,
      herkunft: data.herkunft.present ? data.herkunft.value : this.herkunft,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PortionRow(')
          ..write('id: $id, ')
          ..write('lebensmittelId: $lebensmittelId, ')
          ..write('name: $name, ')
          ..write('mengeG: $mengeG, ')
          ..write('herkunft: $herkunft')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, lebensmittelId, name, mengeG, herkunft);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PortionRow &&
          other.id == this.id &&
          other.lebensmittelId == this.lebensmittelId &&
          other.name == this.name &&
          other.mengeG == this.mengeG &&
          other.herkunft == this.herkunft);
}

class PortionenCompanion extends UpdateCompanion<PortionRow> {
  final Value<int> id;
  final Value<int?> lebensmittelId;
  final Value<String> name;
  final Value<double?> mengeG;
  final Value<String> herkunft;
  const PortionenCompanion({
    this.id = const Value.absent(),
    this.lebensmittelId = const Value.absent(),
    this.name = const Value.absent(),
    this.mengeG = const Value.absent(),
    this.herkunft = const Value.absent(),
  });
  PortionenCompanion.insert({
    this.id = const Value.absent(),
    this.lebensmittelId = const Value.absent(),
    this.name = const Value.absent(),
    this.mengeG = const Value.absent(),
    this.herkunft = const Value.absent(),
  });
  static Insertable<PortionRow> custom({
    Expression<int>? id,
    Expression<int>? lebensmittelId,
    Expression<String>? name,
    Expression<double>? mengeG,
    Expression<String>? herkunft,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lebensmittelId != null) 'lebensmittel_id': lebensmittelId,
      if (name != null) 'name': name,
      if (mengeG != null) 'menge_g': mengeG,
      if (herkunft != null) 'herkunft': herkunft,
    });
  }

  PortionenCompanion copyWith({
    Value<int>? id,
    Value<int?>? lebensmittelId,
    Value<String>? name,
    Value<double?>? mengeG,
    Value<String>? herkunft,
  }) {
    return PortionenCompanion(
      id: id ?? this.id,
      lebensmittelId: lebensmittelId ?? this.lebensmittelId,
      name: name ?? this.name,
      mengeG: mengeG ?? this.mengeG,
      herkunft: herkunft ?? this.herkunft,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lebensmittelId.present) {
      map['lebensmittel_id'] = Variable<int>(lebensmittelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mengeG.present) {
      map['menge_g'] = Variable<double>(mengeG.value);
    }
    if (herkunft.present) {
      map['herkunft'] = Variable<String>(herkunft.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PortionenCompanion(')
          ..write('id: $id, ')
          ..write('lebensmittelId: $lebensmittelId, ')
          ..write('name: $name, ')
          ..write('mengeG: $mengeG, ')
          ..write('herkunft: $herkunft')
          ..write(')'))
        .toString();
  }
}

class $EintraegeTable extends Eintraege
    with TableInfo<$EintraegeTable, EintragRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EintraegeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tagesSchluesselMeta = const VerificationMeta(
    'tagesSchluessel',
  );
  @override
  late final GeneratedColumn<String> tagesSchluessel = GeneratedColumn<String>(
    'tages_schluessel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mahlzeitMeta = const VerificationMeta(
    'mahlzeit',
  );
  @override
  late final GeneratedColumn<String> mahlzeit = GeneratedColumn<String>(
    'mahlzeit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lebensmittelIdMeta = const VerificationMeta(
    'lebensmittelId',
  );
  @override
  late final GeneratedColumn<int> lebensmittelId = GeneratedColumn<int>(
    'lebensmittel_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mengeGMeta = const VerificationMeta('mengeG');
  @override
  late final GeneratedColumn<double> mengeG = GeneratedColumn<double>(
    'menge_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _eiweissGMeta = const VerificationMeta(
    'eiweissG',
  );
  @override
  late final GeneratedColumn<double> eiweissG = GeneratedColumn<double>(
    'eiweiss_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _kohlenhydrateGMeta = const VerificationMeta(
    'kohlenhydrateG',
  );
  @override
  late final GeneratedColumn<double> kohlenhydrateG = GeneratedColumn<double>(
    'kohlenhydrate_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fettGMeta = const VerificationMeta('fettG');
  @override
  late final GeneratedColumn<double> fettG = GeneratedColumn<double>(
    'fett_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zuckerGMeta = const VerificationMeta(
    'zuckerG',
  );
  @override
  late final GeneratedColumn<double> zuckerG = GeneratedColumn<double>(
    'zucker_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ballaststoffeGMeta = const VerificationMeta(
    'ballaststoffeG',
  );
  @override
  late final GeneratedColumn<double> ballaststoffeG = GeneratedColumn<double>(
    'ballaststoffe_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gesaettigtGMeta = const VerificationMeta(
    'gesaettigtG',
  );
  @override
  late final GeneratedColumn<double> gesaettigtG = GeneratedColumn<double>(
    'gesaettigt_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wasserMlMeta = const VerificationMeta(
    'wasserMl',
  );
  @override
  late final GeneratedColumn<double> wasserMl = GeneratedColumn<double>(
    'wasser_ml',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extraMeta = const VerificationMeta('extra');
  @override
  late final GeneratedColumn<String> extra = GeneratedColumn<String>(
    'extra',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _healthUuidMeta = const VerificationMeta(
    'healthUuid',
  );
  @override
  late final GeneratedColumn<String> healthUuid = GeneratedColumn<String>(
    'health_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthStandMeta = const VerificationMeta(
    'healthStand',
  );
  @override
  late final GeneratedColumn<String> healthStand = GeneratedColumn<String>(
    'health_stand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('offen'),
  );
  static const VerificationMeta _vorschlagMeta = const VerificationMeta(
    'vorschlag',
  );
  @override
  late final GeneratedColumn<String> vorschlag = GeneratedColumn<String>(
    'vorschlag',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portionIdMeta = const VerificationMeta(
    'portionId',
  );
  @override
  late final GeneratedColumn<int> portionId = GeneratedColumn<int>(
    'portion_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portionNameMeta = const VerificationMeta(
    'portionName',
  );
  @override
  late final GeneratedColumn<String> portionName = GeneratedColumn<String>(
    'portion_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _portionGMeta = const VerificationMeta(
    'portionG',
  );
  @override
  late final GeneratedColumn<double> portionG = GeneratedColumn<double>(
    'portion_g',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fluessigMeta = const VerificationMeta(
    'fluessig',
  );
  @override
  late final GeneratedColumn<bool> fluessig = GeneratedColumn<bool>(
    'fluessig',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("fluessig" IN (0, 1))',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tagesSchluessel,
    mahlzeit,
    zeitpunkt,
    lebensmittelId,
    name,
    mengeG,
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    ballaststoffeG,
    gesaettigtG,
    wasserMl,
    extra,
    healthUuid,
    healthStand,
    vorschlag,
    portionId,
    portionName,
    portionG,
    fluessig,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'eintraege';
  @override
  VerificationContext validateIntegrity(
    Insertable<EintragRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tages_schluessel')) {
      context.handle(
        _tagesSchluesselMeta,
        tagesSchluessel.isAcceptableOrUnknown(
          data['tages_schluessel']!,
          _tagesSchluesselMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tagesSchluesselMeta);
    }
    if (data.containsKey('mahlzeit')) {
      context.handle(
        _mahlzeitMeta,
        mahlzeit.isAcceptableOrUnknown(data['mahlzeit']!, _mahlzeitMeta),
      );
    } else if (isInserting) {
      context.missing(_mahlzeitMeta);
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('lebensmittel_id')) {
      context.handle(
        _lebensmittelIdMeta,
        lebensmittelId.isAcceptableOrUnknown(
          data['lebensmittel_id']!,
          _lebensmittelIdMeta,
        ),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('menge_g')) {
      context.handle(
        _mengeGMeta,
        mengeG.isAcceptableOrUnknown(data['menge_g']!, _mengeGMeta),
      );
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    }
    if (data.containsKey('eiweiss_g')) {
      context.handle(
        _eiweissGMeta,
        eiweissG.isAcceptableOrUnknown(data['eiweiss_g']!, _eiweissGMeta),
      );
    }
    if (data.containsKey('kohlenhydrate_g')) {
      context.handle(
        _kohlenhydrateGMeta,
        kohlenhydrateG.isAcceptableOrUnknown(
          data['kohlenhydrate_g']!,
          _kohlenhydrateGMeta,
        ),
      );
    }
    if (data.containsKey('fett_g')) {
      context.handle(
        _fettGMeta,
        fettG.isAcceptableOrUnknown(data['fett_g']!, _fettGMeta),
      );
    }
    if (data.containsKey('zucker_g')) {
      context.handle(
        _zuckerGMeta,
        zuckerG.isAcceptableOrUnknown(data['zucker_g']!, _zuckerGMeta),
      );
    }
    if (data.containsKey('ballaststoffe_g')) {
      context.handle(
        _ballaststoffeGMeta,
        ballaststoffeG.isAcceptableOrUnknown(
          data['ballaststoffe_g']!,
          _ballaststoffeGMeta,
        ),
      );
    }
    if (data.containsKey('gesaettigt_g')) {
      context.handle(
        _gesaettigtGMeta,
        gesaettigtG.isAcceptableOrUnknown(
          data['gesaettigt_g']!,
          _gesaettigtGMeta,
        ),
      );
    }
    if (data.containsKey('wasser_ml')) {
      context.handle(
        _wasserMlMeta,
        wasserMl.isAcceptableOrUnknown(data['wasser_ml']!, _wasserMlMeta),
      );
    }
    if (data.containsKey('extra')) {
      context.handle(
        _extraMeta,
        extra.isAcceptableOrUnknown(data['extra']!, _extraMeta),
      );
    }
    if (data.containsKey('health_uuid')) {
      context.handle(
        _healthUuidMeta,
        healthUuid.isAcceptableOrUnknown(data['health_uuid']!, _healthUuidMeta),
      );
    }
    if (data.containsKey('health_stand')) {
      context.handle(
        _healthStandMeta,
        healthStand.isAcceptableOrUnknown(
          data['health_stand']!,
          _healthStandMeta,
        ),
      );
    }
    if (data.containsKey('vorschlag')) {
      context.handle(
        _vorschlagMeta,
        vorschlag.isAcceptableOrUnknown(data['vorschlag']!, _vorschlagMeta),
      );
    }
    if (data.containsKey('portion_id')) {
      context.handle(
        _portionIdMeta,
        portionId.isAcceptableOrUnknown(data['portion_id']!, _portionIdMeta),
      );
    }
    if (data.containsKey('portion_name')) {
      context.handle(
        _portionNameMeta,
        portionName.isAcceptableOrUnknown(
          data['portion_name']!,
          _portionNameMeta,
        ),
      );
    }
    if (data.containsKey('portion_g')) {
      context.handle(
        _portionGMeta,
        portionG.isAcceptableOrUnknown(data['portion_g']!, _portionGMeta),
      );
    }
    if (data.containsKey('fluessig')) {
      context.handle(
        _fluessigMeta,
        fluessig.isAcceptableOrUnknown(data['fluessig']!, _fluessigMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EintragRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EintragRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tagesSchluessel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tages_schluessel'],
      )!,
      mahlzeit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mahlzeit'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      lebensmittelId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lebensmittel_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      mengeG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}menge_g'],
      ),
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      ),
      eiweissG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}eiweiss_g'],
      ),
      kohlenhydrateG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kohlenhydrate_g'],
      ),
      fettG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fett_g'],
      ),
      zuckerG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}zucker_g'],
      ),
      ballaststoffeG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}ballaststoffe_g'],
      ),
      gesaettigtG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gesaettigt_g'],
      ),
      wasserMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}wasser_ml'],
      ),
      extra: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extra'],
      )!,
      healthUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_uuid'],
      ),
      healthStand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_stand'],
      )!,
      vorschlag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}vorschlag'],
      ),
      portionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}portion_id'],
      ),
      portionName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}portion_name'],
      ),
      portionG: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}portion_g'],
      ),
      fluessig: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}fluessig'],
      ),
    );
  }

  @override
  $EintraegeTable createAlias(String alias) {
    return $EintraegeTable(attachedDatabase, alias);
  }
}

class EintragRow extends DataClass implements Insertable<EintragRow> {
  /// Der Schlüssel, **mit `AUTOINCREMENT`** und nicht bloß
  /// `INTEGER PRIMARY KEY`.
  ///
  /// Ohne `AUTOINCREMENT` vergibt SQLite nach einer Löschung dieselbe
  /// Zeilennummer erneut. Der Health-Nachlauf merkt sich die IDs offener
  /// Einträge und ruft später `setzeHealthStand(id, …)` — eine
  /// wiederverwendete ID setzte den Stand eines **fremden** Eintrags, und
  /// zwar lautlos. `drift`s `autoIncrement()` schreibt genau diese Form.
  final int id;

  /// Der **Esstag** als ISO-Tagesschlüssel (`YYYY-MM-DD`), wie
  /// `TagesWerte.tag` — nicht der Kalendertag von [zeitpunkt].
  ///
  /// Der Abend läuft bis 03:59 und umschließt Mitternacht
  /// (`Mahlzeitfenster`): Ein Eintrag um 01:30 gehört zum Abend davor.
  /// Die beiden Felder weichen dann um einen Tag voneinander ab, und
  /// genau deshalb gibt es beide. Gefiltert wird über **diese** Spalte,
  /// lexikografisch und damit über jede Zeitumstellung hinweg
  /// (`CLAUDE.md`, „Der Datumsschlüssel ist der ISO-Tagesstring").
  final String tagesSchluessel;

  /// `Mahlzeit.name` — `fruehstueck`, `mittag`, `snack` oder `abend`.
  ///
  /// Der **Name**, nicht der Index: Eine abgelegte Ordnungszahl
  /// verschiebt sich lautlos, sobald jemand die Reihenfolge der
  /// Enum-Fälle ändert — dieselbe Regel, nach der
  /// `SchlafAbschnitte.phase` den `SleepStage.name` trägt. Und auf dem
  /// iPhone liegt Tims einzige Kopie.
  final String mahlzeit;

  /// Wann gegessen wurde, als UTC-Zeitpunkt.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT. Drifts Standard (Unix-Sekunden) gäbe den Zeitpunkt als
  /// **lokale** Zeit zurück, und ein als UTC abgelegter Wert wäre danach
  /// ungleich sich selbst (`CLAUDE.md`).
  final DateTime zeitpunkt;

  /// Die Vorlage, aus der der Eintrag entstand — **nullbar**.
  ///
  /// Der Schnelleintrag „nur Kalorien" hat keine (Entwurf, „Schnelleintrag
  /// und Favoriten"), und jede Abfrage muss das aushalten. Bewusst **ohne
  /// Fremdschlüssel**: Ein Eintrag bleibt gültig, wenn seine Vorlage
  /// gelöscht wird; er ist Tims Tatsache, nicht ihr Anhängsel.
  final int? lebensmittelId;

  /// Was auf dem Teller lag, als Text — auch der Schnelleintrag trägt
  /// einen Namen. Eingefroren wie die Nährwerte: Eine spätere Korrektur
  /// der Vorlage benennt den gebuchten Eintrag nicht um.
  final String name;

  /// Die gegessene Menge in Gramm — **nullbar**.
  ///
  /// Der Schnelleintrag trägt „einen Namen und seine eingefrorenen
  /// Nährwerte und sonst nichts"; er wiegt nichts. Eine
  /// `NOT NULL`-Spalte zwänge dort zu einer `0`, und „0 g gegessen" ist
  /// eine Behauptung, kein fehlender Wert (`CLAUDE.md`, „`0` ist keine
  /// Antwort auf ‚kein Wert'").
  ///
  /// `RealColumn`, nicht `IntColumn`: 33,5 g sind eine Menge, und Runden
  /// wäre eine stille Veränderung von Tims Wert.
  final double? mengeG;

  /// Die acht eingefrorenen Nährwerte — `Naehrwerte` im Kern, acht
  /// `double?`, also acht nullbare `RealColumn`.
  final double? kcal;
  final double? eiweissG;
  final double? kohlenhydrateG;
  final double? fettG;
  final double? zuckerG;
  final double? ballaststoffeG;
  final double? gesaettigtG;
  final double? wasserMl;

  /// Die übrigen Nährwerte als JSON-Objekt — die 26 Mikronährstoffe des
  /// Austauschformats. So ist der spätere Vitamin-Schirm eine Ansicht und
  /// keine Migration.
  ///
  /// **`NOT NULL` mit Vorgabewert `{}`, nicht nullbar.** `Naehrwerte.extra`
  /// ist eine nicht-nullbare Map; das leere Objekt ist ihr genaues Abbild.
  /// Wäre die Spalte nullbar, gäbe es zwei Schreibweisen für „keine
  /// weiteren Werte" — dieselbe Überlegung, aus der `SchlafEintraege.notiz`
  /// genau eine hat. Der Vorgabewert erlaubt außerdem, die Spalte auf
  /// einer Datei nachzutragen, in der die Tabelle von einem anderen Zweig
  /// schon steht (#233).
  ///
  /// **Ein Schlüssel mit Wert `null` bleibt drin.** „Bekannt als
  /// unbekannt" ist eine andere Auskunft als „nie gefragt"; das
  /// Austauschformat 4.11 schreibt in der Exportdatei `0` für nicht
  /// erfasste Werte, und das ist die Regel für die **Datei**, nicht für
  /// die Datenbank.
  final String extra;

  /// Die UUID der Probe in Apple Health — **nullbar**: Die kennt erst, wer
  /// geschrieben hat. Gebucht wird aber immer, auch ohne Freigabe.
  final String? healthUuid;

  /// Was aus der Kopie nach Apple Health geworden ist: `offen`,
  /// `geschrieben` oder `nicht_moeglich` (Entwurf, „Wenn die
  /// Schreibfreigabe fehlt").
  ///
  /// `NOT NULL` — jeder Eintrag hat einen der drei Stände, ein leeres Feld
  /// wäre ein vierter, unbenannter. Als **Wort**, nicht als Ordnungszahl,
  /// aus demselben Grund wie bei [mahlzeit].
  ///
  /// **Der Vorgabewert `offen` ist keine Erfindung, sondern die Wahrheit
  /// über eine Zeile, deren Stand niemand festgehalten hat:** Sie ist
  /// nicht nach Health geschrieben worden. Er macht die Spalte zugleich
  /// nachtragbar (#233) — anders als [name] oder [tagesSchluessel], für
  /// die es keinen ehrlichen Vorgabewert gibt.
  final String healthStand;

  /// Die Herkunft eines gebuchten KI-Vorschlags als JSON (Schema v15,
  /// #332) — `{"anbieter":"gemini","modell":…,"zeitpunkt":…,
  /// "zweck":"foto"}`.
  ///
  /// **Nullbar und ohne Vorgabewert.** Ein von Hand gebuchter Eintrag hat
  /// keine KI-Herkunft, und eine Vorgabe wäre eine Herkunft, die jeder
  /// Eintrag erbte. Alte Zeilen bleiben `null` — eine Migration erfindet
  /// keine Herkunft.
  final String? vorschlag;

  /// Die Portion, mit der gebucht wurde (Schema v17, #393) — **ohne
  /// Fremdschlüssel**. Über sie findet die Vorwahl die Portion wieder,
  /// auch nachdem sie umbenannt wurde.
  ///
  /// Darf `null` sein, während [portionName] und [portionG] gesetzt sind:
  /// Die Portion hatte beim Buchen keine Zeile in [Portionen]. Die Vorwahl
  /// fällt dann auf „g" zurück.
  final int? portionId;

  /// Name und Gramm der Portion als **Schnappschuss beim Buchen**,
  /// eingefroren wie die Nährwerte (Schema v17, #393). Ändern-Blatt und
  /// Mahlzeitenzeile lesen sie von hier, nie aus [Portionen].
  ///
  /// Beide stehen nur gemeinsam da. **Ohne Portion gebucht heißt: alle drei
  /// `null`** — das gilt auch für jeden alten Eintrag, und es stimmt, denn
  /// alle alten Einträge sind in Gramm gebucht. Kein Vorgabewert: Ein
  /// `portion_g` von `0` wäre eine Portion von 0 g statt „ohne Portion".
  ///
  /// **Keine Spalte für die Anzahl.** Sie ist `menge_g / portion_g`, und
  /// eine zweite Spalte könnte der ersten widersprechen. Kein Index.
  final String? portionName;
  final double? portionG;

  /// Ob in Millilitern gebucht wurde — ein **Schnappschuss** von
  /// [Lebensmittel.fluessig] beim Buchen (Schema v19, #403), eingefroren
  /// wie die Nährwerte. Wird die Vorlage später fest oder flüssig gestellt
  /// oder gelöscht, bleibt die Einheit des Eintrags.
  ///
  /// **Nullbar und ohne Vorgabewert.** `NULL` heißt „unbekannt" — so steht
  /// es in jedem Eintrag von vor der Stufe 20, und die Anzeige fällt dann
  /// auf die Vorlage zurück. Eine Vorgabe `0` behauptete für jedes alte
  /// Getränk „in Gramm gebucht". Kein Index.
  final bool? fluessig;
  const EintragRow({
    required this.id,
    required this.tagesSchluessel,
    required this.mahlzeit,
    required this.zeitpunkt,
    this.lebensmittelId,
    required this.name,
    this.mengeG,
    this.kcal,
    this.eiweissG,
    this.kohlenhydrateG,
    this.fettG,
    this.zuckerG,
    this.ballaststoffeG,
    this.gesaettigtG,
    this.wasserMl,
    required this.extra,
    this.healthUuid,
    required this.healthStand,
    this.vorschlag,
    this.portionId,
    this.portionName,
    this.portionG,
    this.fluessig,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tages_schluessel'] = Variable<String>(tagesSchluessel);
    map['mahlzeit'] = Variable<String>(mahlzeit);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    if (!nullToAbsent || lebensmittelId != null) {
      map['lebensmittel_id'] = Variable<int>(lebensmittelId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || mengeG != null) {
      map['menge_g'] = Variable<double>(mengeG);
    }
    if (!nullToAbsent || kcal != null) {
      map['kcal'] = Variable<double>(kcal);
    }
    if (!nullToAbsent || eiweissG != null) {
      map['eiweiss_g'] = Variable<double>(eiweissG);
    }
    if (!nullToAbsent || kohlenhydrateG != null) {
      map['kohlenhydrate_g'] = Variable<double>(kohlenhydrateG);
    }
    if (!nullToAbsent || fettG != null) {
      map['fett_g'] = Variable<double>(fettG);
    }
    if (!nullToAbsent || zuckerG != null) {
      map['zucker_g'] = Variable<double>(zuckerG);
    }
    if (!nullToAbsent || ballaststoffeG != null) {
      map['ballaststoffe_g'] = Variable<double>(ballaststoffeG);
    }
    if (!nullToAbsent || gesaettigtG != null) {
      map['gesaettigt_g'] = Variable<double>(gesaettigtG);
    }
    if (!nullToAbsent || wasserMl != null) {
      map['wasser_ml'] = Variable<double>(wasserMl);
    }
    map['extra'] = Variable<String>(extra);
    if (!nullToAbsent || healthUuid != null) {
      map['health_uuid'] = Variable<String>(healthUuid);
    }
    map['health_stand'] = Variable<String>(healthStand);
    if (!nullToAbsent || vorschlag != null) {
      map['vorschlag'] = Variable<String>(vorschlag);
    }
    if (!nullToAbsent || portionId != null) {
      map['portion_id'] = Variable<int>(portionId);
    }
    if (!nullToAbsent || portionName != null) {
      map['portion_name'] = Variable<String>(portionName);
    }
    if (!nullToAbsent || portionG != null) {
      map['portion_g'] = Variable<double>(portionG);
    }
    if (!nullToAbsent || fluessig != null) {
      map['fluessig'] = Variable<bool>(fluessig);
    }
    return map;
  }

  EintraegeCompanion toCompanion(bool nullToAbsent) {
    return EintraegeCompanion(
      id: Value(id),
      tagesSchluessel: Value(tagesSchluessel),
      mahlzeit: Value(mahlzeit),
      zeitpunkt: Value(zeitpunkt),
      lebensmittelId: lebensmittelId == null && nullToAbsent
          ? const Value.absent()
          : Value(lebensmittelId),
      name: Value(name),
      mengeG: mengeG == null && nullToAbsent
          ? const Value.absent()
          : Value(mengeG),
      kcal: kcal == null && nullToAbsent ? const Value.absent() : Value(kcal),
      eiweissG: eiweissG == null && nullToAbsent
          ? const Value.absent()
          : Value(eiweissG),
      kohlenhydrateG: kohlenhydrateG == null && nullToAbsent
          ? const Value.absent()
          : Value(kohlenhydrateG),
      fettG: fettG == null && nullToAbsent
          ? const Value.absent()
          : Value(fettG),
      zuckerG: zuckerG == null && nullToAbsent
          ? const Value.absent()
          : Value(zuckerG),
      ballaststoffeG: ballaststoffeG == null && nullToAbsent
          ? const Value.absent()
          : Value(ballaststoffeG),
      gesaettigtG: gesaettigtG == null && nullToAbsent
          ? const Value.absent()
          : Value(gesaettigtG),
      wasserMl: wasserMl == null && nullToAbsent
          ? const Value.absent()
          : Value(wasserMl),
      extra: Value(extra),
      healthUuid: healthUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(healthUuid),
      healthStand: Value(healthStand),
      vorschlag: vorschlag == null && nullToAbsent
          ? const Value.absent()
          : Value(vorschlag),
      portionId: portionId == null && nullToAbsent
          ? const Value.absent()
          : Value(portionId),
      portionName: portionName == null && nullToAbsent
          ? const Value.absent()
          : Value(portionName),
      portionG: portionG == null && nullToAbsent
          ? const Value.absent()
          : Value(portionG),
      fluessig: fluessig == null && nullToAbsent
          ? const Value.absent()
          : Value(fluessig),
    );
  }

  factory EintragRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EintragRow(
      id: serializer.fromJson<int>(json['id']),
      tagesSchluessel: serializer.fromJson<String>(json['tagesSchluessel']),
      mahlzeit: serializer.fromJson<String>(json['mahlzeit']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      lebensmittelId: serializer.fromJson<int?>(json['lebensmittelId']),
      name: serializer.fromJson<String>(json['name']),
      mengeG: serializer.fromJson<double?>(json['mengeG']),
      kcal: serializer.fromJson<double?>(json['kcal']),
      eiweissG: serializer.fromJson<double?>(json['eiweissG']),
      kohlenhydrateG: serializer.fromJson<double?>(json['kohlenhydrateG']),
      fettG: serializer.fromJson<double?>(json['fettG']),
      zuckerG: serializer.fromJson<double?>(json['zuckerG']),
      ballaststoffeG: serializer.fromJson<double?>(json['ballaststoffeG']),
      gesaettigtG: serializer.fromJson<double?>(json['gesaettigtG']),
      wasserMl: serializer.fromJson<double?>(json['wasserMl']),
      extra: serializer.fromJson<String>(json['extra']),
      healthUuid: serializer.fromJson<String?>(json['healthUuid']),
      healthStand: serializer.fromJson<String>(json['healthStand']),
      vorschlag: serializer.fromJson<String?>(json['vorschlag']),
      portionId: serializer.fromJson<int?>(json['portionId']),
      portionName: serializer.fromJson<String?>(json['portionName']),
      portionG: serializer.fromJson<double?>(json['portionG']),
      fluessig: serializer.fromJson<bool?>(json['fluessig']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tagesSchluessel': serializer.toJson<String>(tagesSchluessel),
      'mahlzeit': serializer.toJson<String>(mahlzeit),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'lebensmittelId': serializer.toJson<int?>(lebensmittelId),
      'name': serializer.toJson<String>(name),
      'mengeG': serializer.toJson<double?>(mengeG),
      'kcal': serializer.toJson<double?>(kcal),
      'eiweissG': serializer.toJson<double?>(eiweissG),
      'kohlenhydrateG': serializer.toJson<double?>(kohlenhydrateG),
      'fettG': serializer.toJson<double?>(fettG),
      'zuckerG': serializer.toJson<double?>(zuckerG),
      'ballaststoffeG': serializer.toJson<double?>(ballaststoffeG),
      'gesaettigtG': serializer.toJson<double?>(gesaettigtG),
      'wasserMl': serializer.toJson<double?>(wasserMl),
      'extra': serializer.toJson<String>(extra),
      'healthUuid': serializer.toJson<String?>(healthUuid),
      'healthStand': serializer.toJson<String>(healthStand),
      'vorschlag': serializer.toJson<String?>(vorschlag),
      'portionId': serializer.toJson<int?>(portionId),
      'portionName': serializer.toJson<String?>(portionName),
      'portionG': serializer.toJson<double?>(portionG),
      'fluessig': serializer.toJson<bool?>(fluessig),
    };
  }

  EintragRow copyWith({
    int? id,
    String? tagesSchluessel,
    String? mahlzeit,
    DateTime? zeitpunkt,
    Value<int?> lebensmittelId = const Value.absent(),
    String? name,
    Value<double?> mengeG = const Value.absent(),
    Value<double?> kcal = const Value.absent(),
    Value<double?> eiweissG = const Value.absent(),
    Value<double?> kohlenhydrateG = const Value.absent(),
    Value<double?> fettG = const Value.absent(),
    Value<double?> zuckerG = const Value.absent(),
    Value<double?> ballaststoffeG = const Value.absent(),
    Value<double?> gesaettigtG = const Value.absent(),
    Value<double?> wasserMl = const Value.absent(),
    String? extra,
    Value<String?> healthUuid = const Value.absent(),
    String? healthStand,
    Value<String?> vorschlag = const Value.absent(),
    Value<int?> portionId = const Value.absent(),
    Value<String?> portionName = const Value.absent(),
    Value<double?> portionG = const Value.absent(),
    Value<bool?> fluessig = const Value.absent(),
  }) => EintragRow(
    id: id ?? this.id,
    tagesSchluessel: tagesSchluessel ?? this.tagesSchluessel,
    mahlzeit: mahlzeit ?? this.mahlzeit,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    lebensmittelId: lebensmittelId.present
        ? lebensmittelId.value
        : this.lebensmittelId,
    name: name ?? this.name,
    mengeG: mengeG.present ? mengeG.value : this.mengeG,
    kcal: kcal.present ? kcal.value : this.kcal,
    eiweissG: eiweissG.present ? eiweissG.value : this.eiweissG,
    kohlenhydrateG: kohlenhydrateG.present
        ? kohlenhydrateG.value
        : this.kohlenhydrateG,
    fettG: fettG.present ? fettG.value : this.fettG,
    zuckerG: zuckerG.present ? zuckerG.value : this.zuckerG,
    ballaststoffeG: ballaststoffeG.present
        ? ballaststoffeG.value
        : this.ballaststoffeG,
    gesaettigtG: gesaettigtG.present ? gesaettigtG.value : this.gesaettigtG,
    wasserMl: wasserMl.present ? wasserMl.value : this.wasserMl,
    extra: extra ?? this.extra,
    healthUuid: healthUuid.present ? healthUuid.value : this.healthUuid,
    healthStand: healthStand ?? this.healthStand,
    vorschlag: vorschlag.present ? vorschlag.value : this.vorschlag,
    portionId: portionId.present ? portionId.value : this.portionId,
    portionName: portionName.present ? portionName.value : this.portionName,
    portionG: portionG.present ? portionG.value : this.portionG,
    fluessig: fluessig.present ? fluessig.value : this.fluessig,
  );
  EintragRow copyWithCompanion(EintraegeCompanion data) {
    return EintragRow(
      id: data.id.present ? data.id.value : this.id,
      tagesSchluessel: data.tagesSchluessel.present
          ? data.tagesSchluessel.value
          : this.tagesSchluessel,
      mahlzeit: data.mahlzeit.present ? data.mahlzeit.value : this.mahlzeit,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      lebensmittelId: data.lebensmittelId.present
          ? data.lebensmittelId.value
          : this.lebensmittelId,
      name: data.name.present ? data.name.value : this.name,
      mengeG: data.mengeG.present ? data.mengeG.value : this.mengeG,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      eiweissG: data.eiweissG.present ? data.eiweissG.value : this.eiweissG,
      kohlenhydrateG: data.kohlenhydrateG.present
          ? data.kohlenhydrateG.value
          : this.kohlenhydrateG,
      fettG: data.fettG.present ? data.fettG.value : this.fettG,
      zuckerG: data.zuckerG.present ? data.zuckerG.value : this.zuckerG,
      ballaststoffeG: data.ballaststoffeG.present
          ? data.ballaststoffeG.value
          : this.ballaststoffeG,
      gesaettigtG: data.gesaettigtG.present
          ? data.gesaettigtG.value
          : this.gesaettigtG,
      wasserMl: data.wasserMl.present ? data.wasserMl.value : this.wasserMl,
      extra: data.extra.present ? data.extra.value : this.extra,
      healthUuid: data.healthUuid.present
          ? data.healthUuid.value
          : this.healthUuid,
      healthStand: data.healthStand.present
          ? data.healthStand.value
          : this.healthStand,
      vorschlag: data.vorschlag.present ? data.vorschlag.value : this.vorschlag,
      portionId: data.portionId.present ? data.portionId.value : this.portionId,
      portionName: data.portionName.present
          ? data.portionName.value
          : this.portionName,
      portionG: data.portionG.present ? data.portionG.value : this.portionG,
      fluessig: data.fluessig.present ? data.fluessig.value : this.fluessig,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EintragRow(')
          ..write('id: $id, ')
          ..write('tagesSchluessel: $tagesSchluessel, ')
          ..write('mahlzeit: $mahlzeit, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('lebensmittelId: $lebensmittelId, ')
          ..write('name: $name, ')
          ..write('mengeG: $mengeG, ')
          ..write('kcal: $kcal, ')
          ..write('eiweissG: $eiweissG, ')
          ..write('kohlenhydrateG: $kohlenhydrateG, ')
          ..write('fettG: $fettG, ')
          ..write('zuckerG: $zuckerG, ')
          ..write('ballaststoffeG: $ballaststoffeG, ')
          ..write('gesaettigtG: $gesaettigtG, ')
          ..write('wasserMl: $wasserMl, ')
          ..write('extra: $extra, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('healthStand: $healthStand, ')
          ..write('vorschlag: $vorschlag, ')
          ..write('portionId: $portionId, ')
          ..write('portionName: $portionName, ')
          ..write('portionG: $portionG, ')
          ..write('fluessig: $fluessig')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    tagesSchluessel,
    mahlzeit,
    zeitpunkt,
    lebensmittelId,
    name,
    mengeG,
    kcal,
    eiweissG,
    kohlenhydrateG,
    fettG,
    zuckerG,
    ballaststoffeG,
    gesaettigtG,
    wasserMl,
    extra,
    healthUuid,
    healthStand,
    vorschlag,
    portionId,
    portionName,
    portionG,
    fluessig,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EintragRow &&
          other.id == this.id &&
          other.tagesSchluessel == this.tagesSchluessel &&
          other.mahlzeit == this.mahlzeit &&
          other.zeitpunkt == this.zeitpunkt &&
          other.lebensmittelId == this.lebensmittelId &&
          other.name == this.name &&
          other.mengeG == this.mengeG &&
          other.kcal == this.kcal &&
          other.eiweissG == this.eiweissG &&
          other.kohlenhydrateG == this.kohlenhydrateG &&
          other.fettG == this.fettG &&
          other.zuckerG == this.zuckerG &&
          other.ballaststoffeG == this.ballaststoffeG &&
          other.gesaettigtG == this.gesaettigtG &&
          other.wasserMl == this.wasserMl &&
          other.extra == this.extra &&
          other.healthUuid == this.healthUuid &&
          other.healthStand == this.healthStand &&
          other.vorschlag == this.vorschlag &&
          other.portionId == this.portionId &&
          other.portionName == this.portionName &&
          other.portionG == this.portionG &&
          other.fluessig == this.fluessig);
}

class EintraegeCompanion extends UpdateCompanion<EintragRow> {
  final Value<int> id;
  final Value<String> tagesSchluessel;
  final Value<String> mahlzeit;
  final Value<DateTime> zeitpunkt;
  final Value<int?> lebensmittelId;
  final Value<String> name;
  final Value<double?> mengeG;
  final Value<double?> kcal;
  final Value<double?> eiweissG;
  final Value<double?> kohlenhydrateG;
  final Value<double?> fettG;
  final Value<double?> zuckerG;
  final Value<double?> ballaststoffeG;
  final Value<double?> gesaettigtG;
  final Value<double?> wasserMl;
  final Value<String> extra;
  final Value<String?> healthUuid;
  final Value<String> healthStand;
  final Value<String?> vorschlag;
  final Value<int?> portionId;
  final Value<String?> portionName;
  final Value<double?> portionG;
  final Value<bool?> fluessig;
  const EintraegeCompanion({
    this.id = const Value.absent(),
    this.tagesSchluessel = const Value.absent(),
    this.mahlzeit = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.lebensmittelId = const Value.absent(),
    this.name = const Value.absent(),
    this.mengeG = const Value.absent(),
    this.kcal = const Value.absent(),
    this.eiweissG = const Value.absent(),
    this.kohlenhydrateG = const Value.absent(),
    this.fettG = const Value.absent(),
    this.zuckerG = const Value.absent(),
    this.ballaststoffeG = const Value.absent(),
    this.gesaettigtG = const Value.absent(),
    this.wasserMl = const Value.absent(),
    this.extra = const Value.absent(),
    this.healthUuid = const Value.absent(),
    this.healthStand = const Value.absent(),
    this.vorschlag = const Value.absent(),
    this.portionId = const Value.absent(),
    this.portionName = const Value.absent(),
    this.portionG = const Value.absent(),
    this.fluessig = const Value.absent(),
  });
  EintraegeCompanion.insert({
    this.id = const Value.absent(),
    required String tagesSchluessel,
    required String mahlzeit,
    required DateTime zeitpunkt,
    this.lebensmittelId = const Value.absent(),
    required String name,
    this.mengeG = const Value.absent(),
    this.kcal = const Value.absent(),
    this.eiweissG = const Value.absent(),
    this.kohlenhydrateG = const Value.absent(),
    this.fettG = const Value.absent(),
    this.zuckerG = const Value.absent(),
    this.ballaststoffeG = const Value.absent(),
    this.gesaettigtG = const Value.absent(),
    this.wasserMl = const Value.absent(),
    this.extra = const Value.absent(),
    this.healthUuid = const Value.absent(),
    this.healthStand = const Value.absent(),
    this.vorschlag = const Value.absent(),
    this.portionId = const Value.absent(),
    this.portionName = const Value.absent(),
    this.portionG = const Value.absent(),
    this.fluessig = const Value.absent(),
  }) : tagesSchluessel = Value(tagesSchluessel),
       mahlzeit = Value(mahlzeit),
       zeitpunkt = Value(zeitpunkt),
       name = Value(name);
  static Insertable<EintragRow> custom({
    Expression<int>? id,
    Expression<String>? tagesSchluessel,
    Expression<String>? mahlzeit,
    Expression<DateTime>? zeitpunkt,
    Expression<int>? lebensmittelId,
    Expression<String>? name,
    Expression<double>? mengeG,
    Expression<double>? kcal,
    Expression<double>? eiweissG,
    Expression<double>? kohlenhydrateG,
    Expression<double>? fettG,
    Expression<double>? zuckerG,
    Expression<double>? ballaststoffeG,
    Expression<double>? gesaettigtG,
    Expression<double>? wasserMl,
    Expression<String>? extra,
    Expression<String>? healthUuid,
    Expression<String>? healthStand,
    Expression<String>? vorschlag,
    Expression<int>? portionId,
    Expression<String>? portionName,
    Expression<double>? portionG,
    Expression<bool>? fluessig,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tagesSchluessel != null) 'tages_schluessel': tagesSchluessel,
      if (mahlzeit != null) 'mahlzeit': mahlzeit,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (lebensmittelId != null) 'lebensmittel_id': lebensmittelId,
      if (name != null) 'name': name,
      if (mengeG != null) 'menge_g': mengeG,
      if (kcal != null) 'kcal': kcal,
      if (eiweissG != null) 'eiweiss_g': eiweissG,
      if (kohlenhydrateG != null) 'kohlenhydrate_g': kohlenhydrateG,
      if (fettG != null) 'fett_g': fettG,
      if (zuckerG != null) 'zucker_g': zuckerG,
      if (ballaststoffeG != null) 'ballaststoffe_g': ballaststoffeG,
      if (gesaettigtG != null) 'gesaettigt_g': gesaettigtG,
      if (wasserMl != null) 'wasser_ml': wasserMl,
      if (extra != null) 'extra': extra,
      if (healthUuid != null) 'health_uuid': healthUuid,
      if (healthStand != null) 'health_stand': healthStand,
      if (vorschlag != null) 'vorschlag': vorschlag,
      if (portionId != null) 'portion_id': portionId,
      if (portionName != null) 'portion_name': portionName,
      if (portionG != null) 'portion_g': portionG,
      if (fluessig != null) 'fluessig': fluessig,
    });
  }

  EintraegeCompanion copyWith({
    Value<int>? id,
    Value<String>? tagesSchluessel,
    Value<String>? mahlzeit,
    Value<DateTime>? zeitpunkt,
    Value<int?>? lebensmittelId,
    Value<String>? name,
    Value<double?>? mengeG,
    Value<double?>? kcal,
    Value<double?>? eiweissG,
    Value<double?>? kohlenhydrateG,
    Value<double?>? fettG,
    Value<double?>? zuckerG,
    Value<double?>? ballaststoffeG,
    Value<double?>? gesaettigtG,
    Value<double?>? wasserMl,
    Value<String>? extra,
    Value<String?>? healthUuid,
    Value<String>? healthStand,
    Value<String?>? vorschlag,
    Value<int?>? portionId,
    Value<String?>? portionName,
    Value<double?>? portionG,
    Value<bool?>? fluessig,
  }) {
    return EintraegeCompanion(
      id: id ?? this.id,
      tagesSchluessel: tagesSchluessel ?? this.tagesSchluessel,
      mahlzeit: mahlzeit ?? this.mahlzeit,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      lebensmittelId: lebensmittelId ?? this.lebensmittelId,
      name: name ?? this.name,
      mengeG: mengeG ?? this.mengeG,
      kcal: kcal ?? this.kcal,
      eiweissG: eiweissG ?? this.eiweissG,
      kohlenhydrateG: kohlenhydrateG ?? this.kohlenhydrateG,
      fettG: fettG ?? this.fettG,
      zuckerG: zuckerG ?? this.zuckerG,
      ballaststoffeG: ballaststoffeG ?? this.ballaststoffeG,
      gesaettigtG: gesaettigtG ?? this.gesaettigtG,
      wasserMl: wasserMl ?? this.wasserMl,
      extra: extra ?? this.extra,
      healthUuid: healthUuid ?? this.healthUuid,
      healthStand: healthStand ?? this.healthStand,
      vorschlag: vorschlag ?? this.vorschlag,
      portionId: portionId ?? this.portionId,
      portionName: portionName ?? this.portionName,
      portionG: portionG ?? this.portionG,
      fluessig: fluessig ?? this.fluessig,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tagesSchluessel.present) {
      map['tages_schluessel'] = Variable<String>(tagesSchluessel.value);
    }
    if (mahlzeit.present) {
      map['mahlzeit'] = Variable<String>(mahlzeit.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (lebensmittelId.present) {
      map['lebensmittel_id'] = Variable<int>(lebensmittelId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mengeG.present) {
      map['menge_g'] = Variable<double>(mengeG.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (eiweissG.present) {
      map['eiweiss_g'] = Variable<double>(eiweissG.value);
    }
    if (kohlenhydrateG.present) {
      map['kohlenhydrate_g'] = Variable<double>(kohlenhydrateG.value);
    }
    if (fettG.present) {
      map['fett_g'] = Variable<double>(fettG.value);
    }
    if (zuckerG.present) {
      map['zucker_g'] = Variable<double>(zuckerG.value);
    }
    if (ballaststoffeG.present) {
      map['ballaststoffe_g'] = Variable<double>(ballaststoffeG.value);
    }
    if (gesaettigtG.present) {
      map['gesaettigt_g'] = Variable<double>(gesaettigtG.value);
    }
    if (wasserMl.present) {
      map['wasser_ml'] = Variable<double>(wasserMl.value);
    }
    if (extra.present) {
      map['extra'] = Variable<String>(extra.value);
    }
    if (healthUuid.present) {
      map['health_uuid'] = Variable<String>(healthUuid.value);
    }
    if (healthStand.present) {
      map['health_stand'] = Variable<String>(healthStand.value);
    }
    if (vorschlag.present) {
      map['vorschlag'] = Variable<String>(vorschlag.value);
    }
    if (portionId.present) {
      map['portion_id'] = Variable<int>(portionId.value);
    }
    if (portionName.present) {
      map['portion_name'] = Variable<String>(portionName.value);
    }
    if (portionG.present) {
      map['portion_g'] = Variable<double>(portionG.value);
    }
    if (fluessig.present) {
      map['fluessig'] = Variable<bool>(fluessig.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EintraegeCompanion(')
          ..write('id: $id, ')
          ..write('tagesSchluessel: $tagesSchluessel, ')
          ..write('mahlzeit: $mahlzeit, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('lebensmittelId: $lebensmittelId, ')
          ..write('name: $name, ')
          ..write('mengeG: $mengeG, ')
          ..write('kcal: $kcal, ')
          ..write('eiweissG: $eiweissG, ')
          ..write('kohlenhydrateG: $kohlenhydrateG, ')
          ..write('fettG: $fettG, ')
          ..write('zuckerG: $zuckerG, ')
          ..write('ballaststoffeG: $ballaststoffeG, ')
          ..write('gesaettigtG: $gesaettigtG, ')
          ..write('wasserMl: $wasserMl, ')
          ..write('extra: $extra, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('healthStand: $healthStand, ')
          ..write('vorschlag: $vorschlag, ')
          ..write('portionId: $portionId, ')
          ..write('portionName: $portionName, ')
          ..write('portionG: $portionG, ')
          ..write('fluessig: $fluessig')
          ..write(')'))
        .toString();
  }
}

class $RezepteTable extends Rezepte with TableInfo<$RezepteTable, RezeptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RezepteTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geaendertAmMeta = const VerificationMeta(
    'geaendertAm',
  );
  @override
  late final GeneratedColumn<DateTime> geaendertAm = GeneratedColumn<DateTime>(
    'geaendert_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _geloeschtAmMeta = const VerificationMeta(
    'geloeschtAm',
  );
  @override
  late final GeneratedColumn<DateTime> geloeschtAm = GeneratedColumn<DateTime>(
    'geloescht_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _autorMeta = const VerificationMeta('autor');
  @override
  late final GeneratedColumn<String> autor = GeneratedColumn<String>(
    'autor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    geaendertAm,
    geloeschtAm,
    autor,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rezepte';
  @override
  VerificationContext validateIntegrity(
    Insertable<RezeptRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('geaendert_am')) {
      context.handle(
        _geaendertAmMeta,
        geaendertAm.isAcceptableOrUnknown(
          data['geaendert_am']!,
          _geaendertAmMeta,
        ),
      );
    }
    if (data.containsKey('geloescht_am')) {
      context.handle(
        _geloeschtAmMeta,
        geloeschtAm.isAcceptableOrUnknown(
          data['geloescht_am']!,
          _geloeschtAmMeta,
        ),
      );
    }
    if (data.containsKey('autor')) {
      context.handle(
        _autorMeta,
        autor.isAcceptableOrUnknown(data['autor']!, _autorMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RezeptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RezeptRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      ),
      geaendertAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geaendert_am'],
      ),
      geloeschtAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geloescht_am'],
      ),
      autor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}autor'],
      ),
    );
  }

  @override
  $RezepteTable createAlias(String alias) {
    return $RezepteTable(attachedDatabase, alias);
  }
}

class RezeptRow extends DataClass implements Insertable<RezeptRow> {
  final int id;

  /// Die Sync-Identität neben der Autoincrement-ID (Schema v25, #542).
  /// Begründung und Form wie bei [Lebensmittel.uuid]; geteilt werden
  /// später beide, Vorlagen wie Rezepte.
  final String? uuid;

  /// Wann das Rezept zuletzt geändert wurde (Schema v25, #542) — wie
  /// [Lebensmittel.geaendertAm].
  final DateTime? geaendertAm;

  /// Der Löschmarker (Schema v25, #542) — wie [Lebensmittel.geloeschtAm].
  final DateTime? geloeschtAm;

  /// Wer das Rezept angelegt hat (Schema v25, #542) — wie
  /// [Lebensmittel.autor].
  final String? autor;
  const RezeptRow({
    required this.id,
    this.uuid,
    this.geaendertAm,
    this.geloeschtAm,
    this.autor,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || uuid != null) {
      map['uuid'] = Variable<String>(uuid);
    }
    if (!nullToAbsent || geaendertAm != null) {
      map['geaendert_am'] = Variable<DateTime>(geaendertAm);
    }
    if (!nullToAbsent || geloeschtAm != null) {
      map['geloescht_am'] = Variable<DateTime>(geloeschtAm);
    }
    if (!nullToAbsent || autor != null) {
      map['autor'] = Variable<String>(autor);
    }
    return map;
  }

  RezepteCompanion toCompanion(bool nullToAbsent) {
    return RezepteCompanion(
      id: Value(id),
      uuid: uuid == null && nullToAbsent ? const Value.absent() : Value(uuid),
      geaendertAm: geaendertAm == null && nullToAbsent
          ? const Value.absent()
          : Value(geaendertAm),
      geloeschtAm: geloeschtAm == null && nullToAbsent
          ? const Value.absent()
          : Value(geloeschtAm),
      autor: autor == null && nullToAbsent
          ? const Value.absent()
          : Value(autor),
    );
  }

  factory RezeptRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RezeptRow(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String?>(json['uuid']),
      geaendertAm: serializer.fromJson<DateTime?>(json['geaendertAm']),
      geloeschtAm: serializer.fromJson<DateTime?>(json['geloeschtAm']),
      autor: serializer.fromJson<String?>(json['autor']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String?>(uuid),
      'geaendertAm': serializer.toJson<DateTime?>(geaendertAm),
      'geloeschtAm': serializer.toJson<DateTime?>(geloeschtAm),
      'autor': serializer.toJson<String?>(autor),
    };
  }

  RezeptRow copyWith({
    int? id,
    Value<String?> uuid = const Value.absent(),
    Value<DateTime?> geaendertAm = const Value.absent(),
    Value<DateTime?> geloeschtAm = const Value.absent(),
    Value<String?> autor = const Value.absent(),
  }) => RezeptRow(
    id: id ?? this.id,
    uuid: uuid.present ? uuid.value : this.uuid,
    geaendertAm: geaendertAm.present ? geaendertAm.value : this.geaendertAm,
    geloeschtAm: geloeschtAm.present ? geloeschtAm.value : this.geloeschtAm,
    autor: autor.present ? autor.value : this.autor,
  );
  RezeptRow copyWithCompanion(RezepteCompanion data) {
    return RezeptRow(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      geaendertAm: data.geaendertAm.present
          ? data.geaendertAm.value
          : this.geaendertAm,
      geloeschtAm: data.geloeschtAm.present
          ? data.geloeschtAm.value
          : this.geloeschtAm,
      autor: data.autor.present ? data.autor.value : this.autor,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RezeptRow(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('geaendertAm: $geaendertAm, ')
          ..write('geloeschtAm: $geloeschtAm, ')
          ..write('autor: $autor')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uuid, geaendertAm, geloeschtAm, autor);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RezeptRow &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.geaendertAm == this.geaendertAm &&
          other.geloeschtAm == this.geloeschtAm &&
          other.autor == this.autor);
}

class RezepteCompanion extends UpdateCompanion<RezeptRow> {
  final Value<int> id;
  final Value<String?> uuid;
  final Value<DateTime?> geaendertAm;
  final Value<DateTime?> geloeschtAm;
  final Value<String?> autor;
  const RezepteCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.geaendertAm = const Value.absent(),
    this.geloeschtAm = const Value.absent(),
    this.autor = const Value.absent(),
  });
  RezepteCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.geaendertAm = const Value.absent(),
    this.geloeschtAm = const Value.absent(),
    this.autor = const Value.absent(),
  });
  static Insertable<RezeptRow> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? geaendertAm,
    Expression<DateTime>? geloeschtAm,
    Expression<String>? autor,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (geaendertAm != null) 'geaendert_am': geaendertAm,
      if (geloeschtAm != null) 'geloescht_am': geloeschtAm,
      if (autor != null) 'autor': autor,
    });
  }

  RezepteCompanion copyWith({
    Value<int>? id,
    Value<String?>? uuid,
    Value<DateTime?>? geaendertAm,
    Value<DateTime?>? geloeschtAm,
    Value<String?>? autor,
  }) {
    return RezepteCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      geaendertAm: geaendertAm ?? this.geaendertAm,
      geloeschtAm: geloeschtAm ?? this.geloeschtAm,
      autor: autor ?? this.autor,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (geaendertAm.present) {
      map['geaendert_am'] = Variable<DateTime>(geaendertAm.value);
    }
    if (geloeschtAm.present) {
      map['geloescht_am'] = Variable<DateTime>(geloeschtAm.value);
    }
    if (autor.present) {
      map['autor'] = Variable<String>(autor.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RezepteCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('geaendertAm: $geaendertAm, ')
          ..write('geloeschtAm: $geloeschtAm, ')
          ..write('autor: $autor')
          ..write(')'))
        .toString();
  }
}

class $RezeptZutatenTable extends RezeptZutaten
    with TableInfo<$RezeptZutatenTable, RezeptZutatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RezeptZutatenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  List<GeneratedColumn> get $columns => [id];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rezept_zutaten';
  @override
  VerificationContext validateIntegrity(
    Insertable<RezeptZutatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RezeptZutatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RezeptZutatRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
    );
  }

  @override
  $RezeptZutatenTable createAlias(String alias) {
    return $RezeptZutatenTable(attachedDatabase, alias);
  }
}

class RezeptZutatRow extends DataClass implements Insertable<RezeptZutatRow> {
  final int id;
  const RezeptZutatRow({required this.id});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    return map;
  }

  RezeptZutatenCompanion toCompanion(bool nullToAbsent) {
    return RezeptZutatenCompanion(id: Value(id));
  }

  factory RezeptZutatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RezeptZutatRow(id: serializer.fromJson<int>(json['id']));
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{'id': serializer.toJson<int>(id)};
  }

  RezeptZutatRow copyWith({int? id}) => RezeptZutatRow(id: id ?? this.id);
  RezeptZutatRow copyWithCompanion(RezeptZutatenCompanion data) {
    return RezeptZutatRow(id: data.id.present ? data.id.value : this.id);
  }

  @override
  String toString() {
    return (StringBuffer('RezeptZutatRow(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => id.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RezeptZutatRow && other.id == this.id);
}

class RezeptZutatenCompanion extends UpdateCompanion<RezeptZutatRow> {
  final Value<int> id;
  const RezeptZutatenCompanion({this.id = const Value.absent()});
  RezeptZutatenCompanion.insert({this.id = const Value.absent()});
  static Insertable<RezeptZutatRow> custom({Expression<int>? id}) {
    return RawValuesInsertable({if (id != null) 'id': id});
  }

  RezeptZutatenCompanion copyWith({Value<int>? id}) {
    return RezeptZutatenCompanion(id: id ?? this.id);
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RezeptZutatenCompanion(')
          ..write('id: $id')
          ..write(')'))
        .toString();
  }
}

class $KiEinstellungenTable extends KiEinstellungen
    with TableInfo<$KiEinstellungenTable, KiEinstellungenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KiEinstellungenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modellMeta = const VerificationMeta('modell');
  @override
  late final GeneratedColumn<String> modell = GeneratedColumn<String>(
    'modell',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _limitUsdMeta = const VerificationMeta(
    'limitUsd',
  );
  @override
  late final GeneratedColumn<double> limitUsd = GeneratedColumn<double>(
    'limit_usd',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preiseMeta = const VerificationMeta('preise');
  @override
  late final GeneratedColumn<String> preise = GeneratedColumn<String>(
    'preise',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _geprueftAmMeta = const VerificationMeta(
    'geprueftAm',
  );
  @override
  late final GeneratedColumn<DateTime> geprueftAm = GeneratedColumn<DateTime>(
    'geprueft_am',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pruefErgebnisMeta = const VerificationMeta(
    'pruefErgebnis',
  );
  @override
  late final GeneratedColumn<String> pruefErgebnis = GeneratedColumn<String>(
    'pruef_ergebnis',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    modell,
    limitUsd,
    preise,
    geprueftAm,
    pruefErgebnis,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ki_einstellungen';
  @override
  VerificationContext validateIntegrity(
    Insertable<KiEinstellungenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('modell')) {
      context.handle(
        _modellMeta,
        modell.isAcceptableOrUnknown(data['modell']!, _modellMeta),
      );
    }
    if (data.containsKey('limit_usd')) {
      context.handle(
        _limitUsdMeta,
        limitUsd.isAcceptableOrUnknown(data['limit_usd']!, _limitUsdMeta),
      );
    }
    if (data.containsKey('preise')) {
      context.handle(
        _preiseMeta,
        preise.isAcceptableOrUnknown(data['preise']!, _preiseMeta),
      );
    }
    if (data.containsKey('geprueft_am')) {
      context.handle(
        _geprueftAmMeta,
        geprueftAm.isAcceptableOrUnknown(data['geprueft_am']!, _geprueftAmMeta),
      );
    }
    if (data.containsKey('pruef_ergebnis')) {
      context.handle(
        _pruefErgebnisMeta,
        pruefErgebnis.isAcceptableOrUnknown(
          data['pruef_ergebnis']!,
          _pruefErgebnisMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KiEinstellungenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KiEinstellungenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      modell: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modell'],
      ),
      limitUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}limit_usd'],
      ),
      preise: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preise'],
      )!,
      geprueftAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geprueft_am'],
      ),
      pruefErgebnis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pruef_ergebnis'],
      ),
    );
  }

  @override
  $KiEinstellungenTable createAlias(String alias) {
    return $KiEinstellungenTable(attachedDatabase, alias);
  }
}

class KiEinstellungenRow extends DataClass
    implements Insertable<KiEinstellungenRow> {
  final int id;

  /// Das gewählte Modell — **nullbar**: Nichts gewählt heißt, die
  /// Voreinstellung der App gilt.
  final String? modell;

  /// Das Monatslimit in US-Dollar — **nullbar**: `null` heißt „Vorgabe",
  /// nicht `0` und keine Zahl, die niemand eingegeben hat.
  final double? limitUsd;

  /// Eigene Preise je Modell als JSON-Objekt, Überschreibungen der
  /// vorbelegten. **`NOT NULL` mit Vorgabewert `{}`**: Das leere Objekt
  /// heißt „keine Überschreibungen", und der Vorgabewert macht die Spalte
  /// nachtragbar (#233).
  final String preise;

  /// Wann der Schlüssel zuletzt geprüft wurde, als UTC-Zeitpunkt —
  /// **nullbar**: Nie geprüft ist ein eigener Zustand, kein erfundener
  /// Zeitpunkt.
  ///
  /// `AppCache` arbeitet mit `storeDateTimeAsText: true`, die Spalte ist
  /// also TEXT (`CLAUDE.md`).
  final DateTime? geprueftAm;

  /// Ergebnis der letzten Prüfung als Wort — `gueltig`, `abgelehnt` oder
  /// `kontingent` (Spec). Nullbar aus demselben Grund wie [geprueftAm].
  final String? pruefErgebnis;
  const KiEinstellungenRow({
    required this.id,
    this.modell,
    this.limitUsd,
    required this.preise,
    this.geprueftAm,
    this.pruefErgebnis,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || modell != null) {
      map['modell'] = Variable<String>(modell);
    }
    if (!nullToAbsent || limitUsd != null) {
      map['limit_usd'] = Variable<double>(limitUsd);
    }
    map['preise'] = Variable<String>(preise);
    if (!nullToAbsent || geprueftAm != null) {
      map['geprueft_am'] = Variable<DateTime>(geprueftAm);
    }
    if (!nullToAbsent || pruefErgebnis != null) {
      map['pruef_ergebnis'] = Variable<String>(pruefErgebnis);
    }
    return map;
  }

  KiEinstellungenCompanion toCompanion(bool nullToAbsent) {
    return KiEinstellungenCompanion(
      id: Value(id),
      modell: modell == null && nullToAbsent
          ? const Value.absent()
          : Value(modell),
      limitUsd: limitUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(limitUsd),
      preise: Value(preise),
      geprueftAm: geprueftAm == null && nullToAbsent
          ? const Value.absent()
          : Value(geprueftAm),
      pruefErgebnis: pruefErgebnis == null && nullToAbsent
          ? const Value.absent()
          : Value(pruefErgebnis),
    );
  }

  factory KiEinstellungenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KiEinstellungenRow(
      id: serializer.fromJson<int>(json['id']),
      modell: serializer.fromJson<String?>(json['modell']),
      limitUsd: serializer.fromJson<double?>(json['limitUsd']),
      preise: serializer.fromJson<String>(json['preise']),
      geprueftAm: serializer.fromJson<DateTime?>(json['geprueftAm']),
      pruefErgebnis: serializer.fromJson<String?>(json['pruefErgebnis']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'modell': serializer.toJson<String?>(modell),
      'limitUsd': serializer.toJson<double?>(limitUsd),
      'preise': serializer.toJson<String>(preise),
      'geprueftAm': serializer.toJson<DateTime?>(geprueftAm),
      'pruefErgebnis': serializer.toJson<String?>(pruefErgebnis),
    };
  }

  KiEinstellungenRow copyWith({
    int? id,
    Value<String?> modell = const Value.absent(),
    Value<double?> limitUsd = const Value.absent(),
    String? preise,
    Value<DateTime?> geprueftAm = const Value.absent(),
    Value<String?> pruefErgebnis = const Value.absent(),
  }) => KiEinstellungenRow(
    id: id ?? this.id,
    modell: modell.present ? modell.value : this.modell,
    limitUsd: limitUsd.present ? limitUsd.value : this.limitUsd,
    preise: preise ?? this.preise,
    geprueftAm: geprueftAm.present ? geprueftAm.value : this.geprueftAm,
    pruefErgebnis: pruefErgebnis.present
        ? pruefErgebnis.value
        : this.pruefErgebnis,
  );
  KiEinstellungenRow copyWithCompanion(KiEinstellungenCompanion data) {
    return KiEinstellungenRow(
      id: data.id.present ? data.id.value : this.id,
      modell: data.modell.present ? data.modell.value : this.modell,
      limitUsd: data.limitUsd.present ? data.limitUsd.value : this.limitUsd,
      preise: data.preise.present ? data.preise.value : this.preise,
      geprueftAm: data.geprueftAm.present
          ? data.geprueftAm.value
          : this.geprueftAm,
      pruefErgebnis: data.pruefErgebnis.present
          ? data.pruefErgebnis.value
          : this.pruefErgebnis,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KiEinstellungenRow(')
          ..write('id: $id, ')
          ..write('modell: $modell, ')
          ..write('limitUsd: $limitUsd, ')
          ..write('preise: $preise, ')
          ..write('geprueftAm: $geprueftAm, ')
          ..write('pruefErgebnis: $pruefErgebnis')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, modell, limitUsd, preise, geprueftAm, pruefErgebnis);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KiEinstellungenRow &&
          other.id == this.id &&
          other.modell == this.modell &&
          other.limitUsd == this.limitUsd &&
          other.preise == this.preise &&
          other.geprueftAm == this.geprueftAm &&
          other.pruefErgebnis == this.pruefErgebnis);
}

class KiEinstellungenCompanion extends UpdateCompanion<KiEinstellungenRow> {
  final Value<int> id;
  final Value<String?> modell;
  final Value<double?> limitUsd;
  final Value<String> preise;
  final Value<DateTime?> geprueftAm;
  final Value<String?> pruefErgebnis;
  const KiEinstellungenCompanion({
    this.id = const Value.absent(),
    this.modell = const Value.absent(),
    this.limitUsd = const Value.absent(),
    this.preise = const Value.absent(),
    this.geprueftAm = const Value.absent(),
    this.pruefErgebnis = const Value.absent(),
  });
  KiEinstellungenCompanion.insert({
    this.id = const Value.absent(),
    this.modell = const Value.absent(),
    this.limitUsd = const Value.absent(),
    this.preise = const Value.absent(),
    this.geprueftAm = const Value.absent(),
    this.pruefErgebnis = const Value.absent(),
  });
  static Insertable<KiEinstellungenRow> custom({
    Expression<int>? id,
    Expression<String>? modell,
    Expression<double>? limitUsd,
    Expression<String>? preise,
    Expression<DateTime>? geprueftAm,
    Expression<String>? pruefErgebnis,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (modell != null) 'modell': modell,
      if (limitUsd != null) 'limit_usd': limitUsd,
      if (preise != null) 'preise': preise,
      if (geprueftAm != null) 'geprueft_am': geprueftAm,
      if (pruefErgebnis != null) 'pruef_ergebnis': pruefErgebnis,
    });
  }

  KiEinstellungenCompanion copyWith({
    Value<int>? id,
    Value<String?>? modell,
    Value<double?>? limitUsd,
    Value<String>? preise,
    Value<DateTime?>? geprueftAm,
    Value<String?>? pruefErgebnis,
  }) {
    return KiEinstellungenCompanion(
      id: id ?? this.id,
      modell: modell ?? this.modell,
      limitUsd: limitUsd ?? this.limitUsd,
      preise: preise ?? this.preise,
      geprueftAm: geprueftAm ?? this.geprueftAm,
      pruefErgebnis: pruefErgebnis ?? this.pruefErgebnis,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (modell.present) {
      map['modell'] = Variable<String>(modell.value);
    }
    if (limitUsd.present) {
      map['limit_usd'] = Variable<double>(limitUsd.value);
    }
    if (preise.present) {
      map['preise'] = Variable<String>(preise.value);
    }
    if (geprueftAm.present) {
      map['geprueft_am'] = Variable<DateTime>(geprueftAm.value);
    }
    if (pruefErgebnis.present) {
      map['pruef_ergebnis'] = Variable<String>(pruefErgebnis.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KiEinstellungenCompanion(')
          ..write('id: $id, ')
          ..write('modell: $modell, ')
          ..write('limitUsd: $limitUsd, ')
          ..write('preise: $preise, ')
          ..write('geprueftAm: $geprueftAm, ')
          ..write('pruefErgebnis: $pruefErgebnis')
          ..write(')'))
        .toString();
  }
}

class $KiAnfragenTable extends KiAnfragen
    with TableInfo<$KiAnfragenTable, KiAnfrageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KiAnfragenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _monatMeta = const VerificationMeta('monat');
  @override
  late final GeneratedColumn<String> monat = GeneratedColumn<String>(
    'monat',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modellMeta = const VerificationMeta('modell');
  @override
  late final GeneratedColumn<String> modell = GeneratedColumn<String>(
    'modell',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zweckMeta = const VerificationMeta('zweck');
  @override
  late final GeneratedColumn<String> zweck = GeneratedColumn<String>(
    'zweck',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eingabeTokenMeta = const VerificationMeta(
    'eingabeToken',
  );
  @override
  late final GeneratedColumn<int> eingabeToken = GeneratedColumn<int>(
    'eingabe_token',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ausgabeTokenMeta = const VerificationMeta(
    'ausgabeToken',
  );
  @override
  late final GeneratedColumn<int> ausgabeToken = GeneratedColumn<int>(
    'ausgabe_token',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _denkTokenMeta = const VerificationMeta(
    'denkToken',
  );
  @override
  late final GeneratedColumn<int> denkToken = GeneratedColumn<int>(
    'denk_token',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kostenUsdMeta = const VerificationMeta(
    'kostenUsd',
  );
  @override
  late final GeneratedColumn<double> kostenUsd = GeneratedColumn<double>(
    'kosten_usd',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    zeitpunkt,
    monat,
    modell,
    zweck,
    eingabeToken,
    ausgabeToken,
    denkToken,
    kostenUsd,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ki_anfragen';
  @override
  VerificationContext validateIntegrity(
    Insertable<KiAnfrageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('monat')) {
      context.handle(
        _monatMeta,
        monat.isAcceptableOrUnknown(data['monat']!, _monatMeta),
      );
    } else if (isInserting) {
      context.missing(_monatMeta);
    }
    if (data.containsKey('modell')) {
      context.handle(
        _modellMeta,
        modell.isAcceptableOrUnknown(data['modell']!, _modellMeta),
      );
    } else if (isInserting) {
      context.missing(_modellMeta);
    }
    if (data.containsKey('zweck')) {
      context.handle(
        _zweckMeta,
        zweck.isAcceptableOrUnknown(data['zweck']!, _zweckMeta),
      );
    } else if (isInserting) {
      context.missing(_zweckMeta);
    }
    if (data.containsKey('eingabe_token')) {
      context.handle(
        _eingabeTokenMeta,
        eingabeToken.isAcceptableOrUnknown(
          data['eingabe_token']!,
          _eingabeTokenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eingabeTokenMeta);
    }
    if (data.containsKey('ausgabe_token')) {
      context.handle(
        _ausgabeTokenMeta,
        ausgabeToken.isAcceptableOrUnknown(
          data['ausgabe_token']!,
          _ausgabeTokenMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_ausgabeTokenMeta);
    }
    if (data.containsKey('denk_token')) {
      context.handle(
        _denkTokenMeta,
        denkToken.isAcceptableOrUnknown(data['denk_token']!, _denkTokenMeta),
      );
    } else if (isInserting) {
      context.missing(_denkTokenMeta);
    }
    if (data.containsKey('kosten_usd')) {
      context.handle(
        _kostenUsdMeta,
        kostenUsd.isAcceptableOrUnknown(data['kosten_usd']!, _kostenUsdMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KiAnfrageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KiAnfrageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      monat: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}monat'],
      )!,
      modell: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}modell'],
      )!,
      zweck: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}zweck'],
      )!,
      eingabeToken: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}eingabe_token'],
      )!,
      ausgabeToken: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ausgabe_token'],
      )!,
      denkToken: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}denk_token'],
      )!,
      kostenUsd: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kosten_usd'],
      ),
    );
  }

  @override
  $KiAnfragenTable createAlias(String alias) {
    return $KiAnfragenTable(attachedDatabase, alias);
  }
}

class KiAnfrageRow extends DataClass implements Insertable<KiAnfrageRow> {
  /// Der Schlüssel, mit `AUTOINCREMENT` wie bei `Eintraege.id`: Eine nach
  /// einer Löschung erneut vergebene Nummer wäre eine andere Anfrage unter
  /// demselben Namen.
  final int id;

  /// Wann die Anfrage abgeschickt wurde, als UTC-Zeitpunkt. TEXT in der
  /// Datei (`storeDateTimeAsText`).
  final DateTime zeitpunkt;

  /// Der Monatsschlüssel in Berliner Zeit (`JJJJ-MM`), beim Schreiben aus
  /// [zeitpunkt] gerechnet. Abgelegt statt bei jeder Abfrage gerechnet,
  /// damit die Monatssumme in SQL filtern kann.
  final String monat;

  /// Das Modell, an das die Anfrage ging.
  final String modell;

  /// Wofür die Anfrage war, etwa `foto` oder `pruefung`.
  final String zweck;

  /// Die gezählten Token. **`NOT NULL`**: Es sind Zählungen, keine
  /// Messwerte — fehlt ein Feld in der Antwort, zählt es `0` (Plan,
  /// „Review Focus" 2).
  final int eingabeToken;
  final int ausgabeToken;
  final int denkToken;

  /// Die Kosten in US-Dollar — **nullbar**: Ohne bekannten Preis sind die
  /// Kosten unbekannt, nicht `0`. Eine `0` senkte die Monatssumme still.
  final double? kostenUsd;
  const KiAnfrageRow({
    required this.id,
    required this.zeitpunkt,
    required this.monat,
    required this.modell,
    required this.zweck,
    required this.eingabeToken,
    required this.ausgabeToken,
    required this.denkToken,
    this.kostenUsd,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    map['monat'] = Variable<String>(monat);
    map['modell'] = Variable<String>(modell);
    map['zweck'] = Variable<String>(zweck);
    map['eingabe_token'] = Variable<int>(eingabeToken);
    map['ausgabe_token'] = Variable<int>(ausgabeToken);
    map['denk_token'] = Variable<int>(denkToken);
    if (!nullToAbsent || kostenUsd != null) {
      map['kosten_usd'] = Variable<double>(kostenUsd);
    }
    return map;
  }

  KiAnfragenCompanion toCompanion(bool nullToAbsent) {
    return KiAnfragenCompanion(
      id: Value(id),
      zeitpunkt: Value(zeitpunkt),
      monat: Value(monat),
      modell: Value(modell),
      zweck: Value(zweck),
      eingabeToken: Value(eingabeToken),
      ausgabeToken: Value(ausgabeToken),
      denkToken: Value(denkToken),
      kostenUsd: kostenUsd == null && nullToAbsent
          ? const Value.absent()
          : Value(kostenUsd),
    );
  }

  factory KiAnfrageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KiAnfrageRow(
      id: serializer.fromJson<int>(json['id']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      monat: serializer.fromJson<String>(json['monat']),
      modell: serializer.fromJson<String>(json['modell']),
      zweck: serializer.fromJson<String>(json['zweck']),
      eingabeToken: serializer.fromJson<int>(json['eingabeToken']),
      ausgabeToken: serializer.fromJson<int>(json['ausgabeToken']),
      denkToken: serializer.fromJson<int>(json['denkToken']),
      kostenUsd: serializer.fromJson<double?>(json['kostenUsd']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'monat': serializer.toJson<String>(monat),
      'modell': serializer.toJson<String>(modell),
      'zweck': serializer.toJson<String>(zweck),
      'eingabeToken': serializer.toJson<int>(eingabeToken),
      'ausgabeToken': serializer.toJson<int>(ausgabeToken),
      'denkToken': serializer.toJson<int>(denkToken),
      'kostenUsd': serializer.toJson<double?>(kostenUsd),
    };
  }

  KiAnfrageRow copyWith({
    int? id,
    DateTime? zeitpunkt,
    String? monat,
    String? modell,
    String? zweck,
    int? eingabeToken,
    int? ausgabeToken,
    int? denkToken,
    Value<double?> kostenUsd = const Value.absent(),
  }) => KiAnfrageRow(
    id: id ?? this.id,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    monat: monat ?? this.monat,
    modell: modell ?? this.modell,
    zweck: zweck ?? this.zweck,
    eingabeToken: eingabeToken ?? this.eingabeToken,
    ausgabeToken: ausgabeToken ?? this.ausgabeToken,
    denkToken: denkToken ?? this.denkToken,
    kostenUsd: kostenUsd.present ? kostenUsd.value : this.kostenUsd,
  );
  KiAnfrageRow copyWithCompanion(KiAnfragenCompanion data) {
    return KiAnfrageRow(
      id: data.id.present ? data.id.value : this.id,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      monat: data.monat.present ? data.monat.value : this.monat,
      modell: data.modell.present ? data.modell.value : this.modell,
      zweck: data.zweck.present ? data.zweck.value : this.zweck,
      eingabeToken: data.eingabeToken.present
          ? data.eingabeToken.value
          : this.eingabeToken,
      ausgabeToken: data.ausgabeToken.present
          ? data.ausgabeToken.value
          : this.ausgabeToken,
      denkToken: data.denkToken.present ? data.denkToken.value : this.denkToken,
      kostenUsd: data.kostenUsd.present ? data.kostenUsd.value : this.kostenUsd,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KiAnfrageRow(')
          ..write('id: $id, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('monat: $monat, ')
          ..write('modell: $modell, ')
          ..write('zweck: $zweck, ')
          ..write('eingabeToken: $eingabeToken, ')
          ..write('ausgabeToken: $ausgabeToken, ')
          ..write('denkToken: $denkToken, ')
          ..write('kostenUsd: $kostenUsd')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    zeitpunkt,
    monat,
    modell,
    zweck,
    eingabeToken,
    ausgabeToken,
    denkToken,
    kostenUsd,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KiAnfrageRow &&
          other.id == this.id &&
          other.zeitpunkt == this.zeitpunkt &&
          other.monat == this.monat &&
          other.modell == this.modell &&
          other.zweck == this.zweck &&
          other.eingabeToken == this.eingabeToken &&
          other.ausgabeToken == this.ausgabeToken &&
          other.denkToken == this.denkToken &&
          other.kostenUsd == this.kostenUsd);
}

class KiAnfragenCompanion extends UpdateCompanion<KiAnfrageRow> {
  final Value<int> id;
  final Value<DateTime> zeitpunkt;
  final Value<String> monat;
  final Value<String> modell;
  final Value<String> zweck;
  final Value<int> eingabeToken;
  final Value<int> ausgabeToken;
  final Value<int> denkToken;
  final Value<double?> kostenUsd;
  const KiAnfragenCompanion({
    this.id = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.monat = const Value.absent(),
    this.modell = const Value.absent(),
    this.zweck = const Value.absent(),
    this.eingabeToken = const Value.absent(),
    this.ausgabeToken = const Value.absent(),
    this.denkToken = const Value.absent(),
    this.kostenUsd = const Value.absent(),
  });
  KiAnfragenCompanion.insert({
    this.id = const Value.absent(),
    required DateTime zeitpunkt,
    required String monat,
    required String modell,
    required String zweck,
    required int eingabeToken,
    required int ausgabeToken,
    required int denkToken,
    this.kostenUsd = const Value.absent(),
  }) : zeitpunkt = Value(zeitpunkt),
       monat = Value(monat),
       modell = Value(modell),
       zweck = Value(zweck),
       eingabeToken = Value(eingabeToken),
       ausgabeToken = Value(ausgabeToken),
       denkToken = Value(denkToken);
  static Insertable<KiAnfrageRow> custom({
    Expression<int>? id,
    Expression<DateTime>? zeitpunkt,
    Expression<String>? monat,
    Expression<String>? modell,
    Expression<String>? zweck,
    Expression<int>? eingabeToken,
    Expression<int>? ausgabeToken,
    Expression<int>? denkToken,
    Expression<double>? kostenUsd,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (monat != null) 'monat': monat,
      if (modell != null) 'modell': modell,
      if (zweck != null) 'zweck': zweck,
      if (eingabeToken != null) 'eingabe_token': eingabeToken,
      if (ausgabeToken != null) 'ausgabe_token': ausgabeToken,
      if (denkToken != null) 'denk_token': denkToken,
      if (kostenUsd != null) 'kosten_usd': kostenUsd,
    });
  }

  KiAnfragenCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? zeitpunkt,
    Value<String>? monat,
    Value<String>? modell,
    Value<String>? zweck,
    Value<int>? eingabeToken,
    Value<int>? ausgabeToken,
    Value<int>? denkToken,
    Value<double?>? kostenUsd,
  }) {
    return KiAnfragenCompanion(
      id: id ?? this.id,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      monat: monat ?? this.monat,
      modell: modell ?? this.modell,
      zweck: zweck ?? this.zweck,
      eingabeToken: eingabeToken ?? this.eingabeToken,
      ausgabeToken: ausgabeToken ?? this.ausgabeToken,
      denkToken: denkToken ?? this.denkToken,
      kostenUsd: kostenUsd ?? this.kostenUsd,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (monat.present) {
      map['monat'] = Variable<String>(monat.value);
    }
    if (modell.present) {
      map['modell'] = Variable<String>(modell.value);
    }
    if (zweck.present) {
      map['zweck'] = Variable<String>(zweck.value);
    }
    if (eingabeToken.present) {
      map['eingabe_token'] = Variable<int>(eingabeToken.value);
    }
    if (ausgabeToken.present) {
      map['ausgabe_token'] = Variable<int>(ausgabeToken.value);
    }
    if (denkToken.present) {
      map['denk_token'] = Variable<int>(denkToken.value);
    }
    if (kostenUsd.present) {
      map['kosten_usd'] = Variable<double>(kostenUsd.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KiAnfragenCompanion(')
          ..write('id: $id, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('monat: $monat, ')
          ..write('modell: $modell, ')
          ..write('zweck: $zweck, ')
          ..write('eingabeToken: $eingabeToken, ')
          ..write('ausgabeToken: $ausgabeToken, ')
          ..write('denkToken: $denkToken, ')
          ..write('kostenUsd: $kostenUsd')
          ..write(')'))
        .toString();
  }
}

class $WasserEintraegeTable extends WasserEintraege
    with TableInfo<$WasserEintraegeTable, WasserEintragRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WasserEintraegeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _tagesSchluesselMeta = const VerificationMeta(
    'tagesSchluessel',
  );
  @override
  late final GeneratedColumn<String> tagesSchluessel = GeneratedColumn<String>(
    'tages_schluessel',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mengeMlMeta = const VerificationMeta(
    'mengeMl',
  );
  @override
  late final GeneratedColumn<double> mengeMl = GeneratedColumn<double>(
    'menge_ml',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _healthUuidMeta = const VerificationMeta(
    'healthUuid',
  );
  @override
  late final GeneratedColumn<String> healthUuid = GeneratedColumn<String>(
    'health_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthStandMeta = const VerificationMeta(
    'healthStand',
  );
  @override
  late final GeneratedColumn<String> healthStand = GeneratedColumn<String>(
    'health_stand',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('offen'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tagesSchluessel,
    zeitpunkt,
    mengeMl,
    healthUuid,
    healthStand,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wasser_eintraege';
  @override
  VerificationContext validateIntegrity(
    Insertable<WasserEintragRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('tages_schluessel')) {
      context.handle(
        _tagesSchluesselMeta,
        tagesSchluessel.isAcceptableOrUnknown(
          data['tages_schluessel']!,
          _tagesSchluesselMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_tagesSchluesselMeta);
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('menge_ml')) {
      context.handle(
        _mengeMlMeta,
        mengeMl.isAcceptableOrUnknown(data['menge_ml']!, _mengeMlMeta),
      );
    } else if (isInserting) {
      context.missing(_mengeMlMeta);
    }
    if (data.containsKey('health_uuid')) {
      context.handle(
        _healthUuidMeta,
        healthUuid.isAcceptableOrUnknown(data['health_uuid']!, _healthUuidMeta),
      );
    }
    if (data.containsKey('health_stand')) {
      context.handle(
        _healthStandMeta,
        healthStand.isAcceptableOrUnknown(
          data['health_stand']!,
          _healthStandMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WasserEintragRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WasserEintragRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      tagesSchluessel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tages_schluessel'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      mengeMl: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}menge_ml'],
      )!,
      healthUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_uuid'],
      ),
      healthStand: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_stand'],
      )!,
    );
  }

  @override
  $WasserEintraegeTable createAlias(String alias) {
    return $WasserEintraegeTable(attachedDatabase, alias);
  }
}

class WasserEintragRow extends DataClass
    implements Insertable<WasserEintragRow> {
  /// Mit `AUTOINCREMENT`, aus demselben Grund wie `Eintraege.id`: Der
  /// Health-Nachlauf merkt sich IDs, und eine nach einer Löschung neu
  /// vergebene Nummer setzte den Stand eines fremden Eintrags.
  final int id;

  /// Der Tag, auf den eingetragen wurde, als ISO-Tagesschlüssel — der
  /// **offene** Tag des Schirms, nicht der Kalendertag von [zeitpunkt]:
  /// Wer über ‹ gestern offen hat und ein Glas einträgt, meint gestern.
  final String tagesSchluessel;

  /// Wann eingetragen wurde, als UTC-Zeitpunkt. TEXT in der Datei
  /// (`storeDateTimeAsText`, `CLAUDE.md`).
  final DateTime zeitpunkt;

  /// Die Menge in Millilitern. `NOT NULL` — ein Glas ohne Menge ist kein
  /// Eintrag. `REAL`, denn 333,5 ml sind eine Menge, und Runden wäre eine
  /// stille Änderung von Tims Wert.
  final double mengeMl;

  /// Die UUID der Probe in Apple Health — nullbar, die kennt erst, wer
  /// geschrieben hat.
  final String? healthUuid;

  /// `offen`, `geschrieben` oder `nicht_moeglich` — dieselben drei Wörter
  /// wie `eintraege.health_stand`. Der Vorgabewert `offen` ist die
  /// Wahrheit über eine Zeile, deren Stand niemand festgehalten hat.
  final String healthStand;
  const WasserEintragRow({
    required this.id,
    required this.tagesSchluessel,
    required this.zeitpunkt,
    required this.mengeMl,
    this.healthUuid,
    required this.healthStand,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['tages_schluessel'] = Variable<String>(tagesSchluessel);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    map['menge_ml'] = Variable<double>(mengeMl);
    if (!nullToAbsent || healthUuid != null) {
      map['health_uuid'] = Variable<String>(healthUuid);
    }
    map['health_stand'] = Variable<String>(healthStand);
    return map;
  }

  WasserEintraegeCompanion toCompanion(bool nullToAbsent) {
    return WasserEintraegeCompanion(
      id: Value(id),
      tagesSchluessel: Value(tagesSchluessel),
      zeitpunkt: Value(zeitpunkt),
      mengeMl: Value(mengeMl),
      healthUuid: healthUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(healthUuid),
      healthStand: Value(healthStand),
    );
  }

  factory WasserEintragRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WasserEintragRow(
      id: serializer.fromJson<int>(json['id']),
      tagesSchluessel: serializer.fromJson<String>(json['tagesSchluessel']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      mengeMl: serializer.fromJson<double>(json['mengeMl']),
      healthUuid: serializer.fromJson<String?>(json['healthUuid']),
      healthStand: serializer.fromJson<String>(json['healthStand']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'tagesSchluessel': serializer.toJson<String>(tagesSchluessel),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'mengeMl': serializer.toJson<double>(mengeMl),
      'healthUuid': serializer.toJson<String?>(healthUuid),
      'healthStand': serializer.toJson<String>(healthStand),
    };
  }

  WasserEintragRow copyWith({
    int? id,
    String? tagesSchluessel,
    DateTime? zeitpunkt,
    double? mengeMl,
    Value<String?> healthUuid = const Value.absent(),
    String? healthStand,
  }) => WasserEintragRow(
    id: id ?? this.id,
    tagesSchluessel: tagesSchluessel ?? this.tagesSchluessel,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    mengeMl: mengeMl ?? this.mengeMl,
    healthUuid: healthUuid.present ? healthUuid.value : this.healthUuid,
    healthStand: healthStand ?? this.healthStand,
  );
  WasserEintragRow copyWithCompanion(WasserEintraegeCompanion data) {
    return WasserEintragRow(
      id: data.id.present ? data.id.value : this.id,
      tagesSchluessel: data.tagesSchluessel.present
          ? data.tagesSchluessel.value
          : this.tagesSchluessel,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      mengeMl: data.mengeMl.present ? data.mengeMl.value : this.mengeMl,
      healthUuid: data.healthUuid.present
          ? data.healthUuid.value
          : this.healthUuid,
      healthStand: data.healthStand.present
          ? data.healthStand.value
          : this.healthStand,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WasserEintragRow(')
          ..write('id: $id, ')
          ..write('tagesSchluessel: $tagesSchluessel, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('mengeMl: $mengeMl, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('healthStand: $healthStand')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tagesSchluessel,
    zeitpunkt,
    mengeMl,
    healthUuid,
    healthStand,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WasserEintragRow &&
          other.id == this.id &&
          other.tagesSchluessel == this.tagesSchluessel &&
          other.zeitpunkt == this.zeitpunkt &&
          other.mengeMl == this.mengeMl &&
          other.healthUuid == this.healthUuid &&
          other.healthStand == this.healthStand);
}

class WasserEintraegeCompanion extends UpdateCompanion<WasserEintragRow> {
  final Value<int> id;
  final Value<String> tagesSchluessel;
  final Value<DateTime> zeitpunkt;
  final Value<double> mengeMl;
  final Value<String?> healthUuid;
  final Value<String> healthStand;
  const WasserEintraegeCompanion({
    this.id = const Value.absent(),
    this.tagesSchluessel = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.mengeMl = const Value.absent(),
    this.healthUuid = const Value.absent(),
    this.healthStand = const Value.absent(),
  });
  WasserEintraegeCompanion.insert({
    this.id = const Value.absent(),
    required String tagesSchluessel,
    required DateTime zeitpunkt,
    required double mengeMl,
    this.healthUuid = const Value.absent(),
    this.healthStand = const Value.absent(),
  }) : tagesSchluessel = Value(tagesSchluessel),
       zeitpunkt = Value(zeitpunkt),
       mengeMl = Value(mengeMl);
  static Insertable<WasserEintragRow> custom({
    Expression<int>? id,
    Expression<String>? tagesSchluessel,
    Expression<DateTime>? zeitpunkt,
    Expression<double>? mengeMl,
    Expression<String>? healthUuid,
    Expression<String>? healthStand,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tagesSchluessel != null) 'tages_schluessel': tagesSchluessel,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (mengeMl != null) 'menge_ml': mengeMl,
      if (healthUuid != null) 'health_uuid': healthUuid,
      if (healthStand != null) 'health_stand': healthStand,
    });
  }

  WasserEintraegeCompanion copyWith({
    Value<int>? id,
    Value<String>? tagesSchluessel,
    Value<DateTime>? zeitpunkt,
    Value<double>? mengeMl,
    Value<String?>? healthUuid,
    Value<String>? healthStand,
  }) {
    return WasserEintraegeCompanion(
      id: id ?? this.id,
      tagesSchluessel: tagesSchluessel ?? this.tagesSchluessel,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      mengeMl: mengeMl ?? this.mengeMl,
      healthUuid: healthUuid ?? this.healthUuid,
      healthStand: healthStand ?? this.healthStand,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (tagesSchluessel.present) {
      map['tages_schluessel'] = Variable<String>(tagesSchluessel.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (mengeMl.present) {
      map['menge_ml'] = Variable<double>(mengeMl.value);
    }
    if (healthUuid.present) {
      map['health_uuid'] = Variable<String>(healthUuid.value);
    }
    if (healthStand.present) {
      map['health_stand'] = Variable<String>(healthStand.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WasserEintraegeCompanion(')
          ..write('id: $id, ')
          ..write('tagesSchluessel: $tagesSchluessel, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('mengeMl: $mengeMl, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('healthStand: $healthStand')
          ..write(')'))
        .toString();
  }
}

class $GymSitzungenTable extends GymSitzungen
    with TableInfo<$GymSitzungenTable, GymSitzungRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymSitzungenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workoutMeta = const VerificationMeta(
    'workout',
  );
  @override
  late final GeneratedColumn<String> workout = GeneratedColumn<String>(
    'workout',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minutenMeta = const VerificationMeta(
    'minuten',
  );
  @override
  late final GeneratedColumn<int> minuten = GeneratedColumn<int>(
    'minuten',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _healthUuidMeta = const VerificationMeta(
    'healthUuid',
  );
  @override
  late final GeneratedColumn<String> healthUuid = GeneratedColumn<String>(
    'health_uuid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aufwaermenArtMeta = const VerificationMeta(
    'aufwaermenArt',
  );
  @override
  late final GeneratedColumn<String> aufwaermenArt = GeneratedColumn<String>(
    'aufwaermen_art',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (aufwaermen_art IS NULL OR aufwaermen_art IN (\'bike\', \'treadmill\', \'rowing\', \'cross_trainer\', \'jump_rope\', \'mobility\'))',
  );
  static const VerificationMeta _aufwaermenMinutenMeta = const VerificationMeta(
    'aufwaermenMinuten',
  );
  @override
  late final GeneratedColumn<int> aufwaermenMinuten = GeneratedColumn<int>(
    'aufwaermen_minuten',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aufwaermenKmMeta = const VerificationMeta(
    'aufwaermenKm',
  );
  @override
  late final GeneratedColumn<double> aufwaermenKm = GeneratedColumn<double>(
    'aufwaermen_km',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aufwaermenUebersprungenMeta =
      const VerificationMeta('aufwaermenUebersprungen');
  @override
  late final GeneratedColumn<bool> aufwaermenUebersprungen =
      GeneratedColumn<bool>(
        'aufwaermen_uebersprungen',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("aufwaermen_uebersprungen" IN (0, 1))',
        ),
        defaultValue: const Constant(false),
      );
  static const VerificationMeta _aufwaermenHealthUuidMeta =
      const VerificationMeta('aufwaermenHealthUuid');
  @override
  late final GeneratedColumn<String> aufwaermenHealthUuid =
      GeneratedColumn<String>(
        'aufwaermen_health_uuid',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _trainingsNameMeta = const VerificationMeta(
    'trainingsName',
  );
  @override
  late final GeneratedColumn<String> trainingsName = GeneratedColumn<String>(
    'trainings_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    tag,
    zeitpunkt,
    workout,
    minuten,
    notiz,
    healthUuid,
    aufwaermenArt,
    aufwaermenMinuten,
    aufwaermenKm,
    aufwaermenUebersprungen,
    aufwaermenHealthUuid,
    trainingsName,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_sitzungen';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymSitzungRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('workout')) {
      context.handle(
        _workoutMeta,
        workout.isAcceptableOrUnknown(data['workout']!, _workoutMeta),
      );
    }
    if (data.containsKey('minuten')) {
      context.handle(
        _minutenMeta,
        minuten.isAcceptableOrUnknown(data['minuten']!, _minutenMeta),
      );
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    if (data.containsKey('health_uuid')) {
      context.handle(
        _healthUuidMeta,
        healthUuid.isAcceptableOrUnknown(data['health_uuid']!, _healthUuidMeta),
      );
    }
    if (data.containsKey('aufwaermen_art')) {
      context.handle(
        _aufwaermenArtMeta,
        aufwaermenArt.isAcceptableOrUnknown(
          data['aufwaermen_art']!,
          _aufwaermenArtMeta,
        ),
      );
    }
    if (data.containsKey('aufwaermen_minuten')) {
      context.handle(
        _aufwaermenMinutenMeta,
        aufwaermenMinuten.isAcceptableOrUnknown(
          data['aufwaermen_minuten']!,
          _aufwaermenMinutenMeta,
        ),
      );
    }
    if (data.containsKey('aufwaermen_km')) {
      context.handle(
        _aufwaermenKmMeta,
        aufwaermenKm.isAcceptableOrUnknown(
          data['aufwaermen_km']!,
          _aufwaermenKmMeta,
        ),
      );
    }
    if (data.containsKey('aufwaermen_uebersprungen')) {
      context.handle(
        _aufwaermenUebersprungenMeta,
        aufwaermenUebersprungen.isAcceptableOrUnknown(
          data['aufwaermen_uebersprungen']!,
          _aufwaermenUebersprungenMeta,
        ),
      );
    }
    if (data.containsKey('aufwaermen_health_uuid')) {
      context.handle(
        _aufwaermenHealthUuidMeta,
        aufwaermenHealthUuid.isAcceptableOrUnknown(
          data['aufwaermen_health_uuid']!,
          _aufwaermenHealthUuidMeta,
        ),
      );
    }
    if (data.containsKey('trainings_name')) {
      context.handle(
        _trainingsNameMeta,
        trainingsName.isAcceptableOrUnknown(
          data['trainings_name']!,
          _trainingsNameMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {tag, workout},
  ];
  @override
  GymSitzungRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymSitzungRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      workout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout'],
      ),
      minuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minuten'],
      ),
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
      healthUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}health_uuid'],
      ),
      aufwaermenArt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aufwaermen_art'],
      ),
      aufwaermenMinuten: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aufwaermen_minuten'],
      ),
      aufwaermenKm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aufwaermen_km'],
      ),
      aufwaermenUebersprungen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}aufwaermen_uebersprungen'],
      )!,
      aufwaermenHealthUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aufwaermen_health_uuid'],
      ),
      trainingsName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trainings_name'],
      ),
    );
  }

  @override
  $GymSitzungenTable createAlias(String alias) {
    return $GymSitzungenTable(attachedDatabase, alias);
  }
}

class GymSitzungRow extends DataClass implements Insertable<GymSitzungRow> {
  /// Die UUID der Einheit, vergeben beim Anlegen (#418 Punkt 1) — der
  /// Schlüssel, unter dem die Uhr später über denselben Trainingstag
  /// spricht.
  final String id;

  /// Der Berliner Kalendertag als ISO-Tagesschlüssel, aus
  /// `BerlinCalendar.dayKey(ImportedSession.date)` gerechnet. **Nicht der
  /// UTC-Kalendertag** — ein Training um 00:30 Berliner Zeit liegt auf dem
  /// UTC-Tag davor. Gefiltert wird über diese Spalte, lexikografisch
  /// (`CLAUDE.md`).
  final String tag;

  /// Der Zeitpunkt des Abschlusses, **mit Uhrzeit**, als UTC. TEXT in der
  /// Datei (`storeDateTimeAsText`).
  final DateTime zeitpunkt;

  /// Die **Kennung des Trainings**: für ein Training mit Enum-Fall sein
  /// `Workout.code` (`'A'`, `'Push'`, …), für jedes andere die UUID eines
  /// eigenen Trainings (ab Schema v25, Spec 4.6). **Der Name der Spalte ist
  /// damit ungenau und bleibt:** `UNIQUE (tag, workout)` steht in
  /// `CREATE TABLE`, SQLite kann das nicht ändern, ohne die Tabelle neu zu
  /// bauen und umzukopieren — und ein Neubau dieser Tabelle ist das Risiko,
  /// das Tims einzige Kopie seiner Trainings nicht eingehen darf. Weil die
  /// Spalte keine `CHECK`-Bedingung auf ihre Werte hat, nimmt sie die UUID
  /// ohne Eingriff.
  ///
  /// **Nullbar**: Die Übernahme aus dem Dashboard (#59) kennt Trainings ohne
  /// geführtes Workout, und einem zuzuschlagen hieße raten.
  final String? workout;

  /// Dauer in Minuten, `null` heißt „nicht erfasst" und nicht „null
  /// Minuten" (Fehler `01`).
  final int? minuten;

  /// Freitext, `null` statt der leeren Zeichenkette — die zeichnete eine
  /// leere Notizzeile.
  final String? notiz;

  /// Die UUID des von der App geschriebenen `HKWorkout` (#418 Punkt 2).
  /// Geschrieben wird sie erst vom Lückenfüller; hier entsteht nur die
  /// Spalte.
  final String? healthUuid;

  /// Womit aufgewärmt wurde, als `WarmUpKind.code`.
  ///
  /// **Der Wertebereich steht in der Datei, nicht nur im Dart-Enum** (#40:
  /// „Freitext lässt sich später nicht vergleichen, und vergleichen ist der
  /// Zweck"). Eine fremde Zeichenkette fiele sonst erst Monate später auf —
  /// beim Vergleichen.
  ///
  /// `customConstraint` und nicht `check(…)`: Die Bedingung muss als
  /// Literal in `CREATE TABLE` landen, damit sie auch dort steht, wo der
  /// Abgleich (#233) die Spalte nachträgt.
  ///
  /// **Die Bedingung steht hier ausgeschrieben und nicht als Konstante.**
  /// drifts Generator liest `customConstraint` zur Kompilierzeit und löst
  /// dabei keine Konstante auf — er übernimmt sie stillschweigend nicht,
  /// und im `CREATE TABLE` fehlt dann die Prüfung, während der Dart-Code
  /// unverändert übersetzt. Dasselbe Muster wie beim `@Test`-Makro in
  /// Swift Testing, das ebenfalls ein echtes Literal verlangt. Aufgefallen
  /// ist es nur, weil `schema_v18_test.dart` die Form der Datei prüft und
  /// nicht das Dart-Enum.
  ///
  /// `NULL` gehört mit in die Zeichenkette: `customConstraint` ersetzt
  /// **alle** erzeugten Bedingungen der Spalte, auch die Nullbarkeit.
  final String? aufwaermenArt;

  /// Die Dauer des Aufwärmens. Sie steht **neben** [minuten] und nicht
  /// darin — sonst wüchse die Trainingsdauer, ohne dass mehr trainiert
  /// wurde (#40, „Zu klären").
  final int? aufwaermenMinuten;

  /// Die Strecke in Kilometern — **auch im ausgefüllten Fall nullbar**:
  /// Bei Mobility gibt es keine, und wer aufs Rad steigt, ohne die Anzeige
  /// abzulesen, ist trotzdem gefahren. Eine `0` behauptete „null Kilometer
  /// gelaufen", und daraus rechnete die Steigerungskarte einen Rückschritt.
  final double? aufwaermenKm;

  /// Ob das Aufwärmen bewusst übersprungen wurde.
  ///
  /// **`NOT NULL` mit Vorgabe `0`**, und das ist die Wahrheit über eine
  /// Zeile, bei der niemand etwas eingetragen hat: nicht übersprungen,
  /// sondern nichts gesagt. „Übersprungen" ist eine Antwort und wird nur
  /// gesetzt, wenn jemand sie gegeben hat (#40).
  final bool aufwaermenUebersprungen;

  /// Die UUID des Health-Workouts, das zu diesem Aufwärmen gehört — ein
  /// Ablageschlüssel, kein Kernwert. Zugeordnet wird erst mit #414.
  final String? aufwaermenHealthUuid;

  /// Der Name des Trainings **zum Zeitpunkt der Sitzung** (Schema v25, #532,
  /// Spec 4.6) — der Verlauf friert ein: Umbenennen und Löschen eines
  /// Trainings schreiben ihn nicht um.
  ///
  /// **Nullbar und ohne Vorgabewert.** Eine alte Zeile bekommt keinen
  /// erfundenen Namen, `NULL` bleibt `NULL` — „Gym A" aus dem Enum
  /// hineinzuschreiben hieße zu behaupten, die Sitzung habe ihn zu ihrer
  /// Zeit getragen. Die Auflösung beim Lesen (`WorkoutNaming.title`) braucht
  /// keinen Eintrag.
  final String? trainingsName;
  const GymSitzungRow({
    required this.id,
    required this.tag,
    required this.zeitpunkt,
    this.workout,
    this.minuten,
    this.notiz,
    this.healthUuid,
    this.aufwaermenArt,
    this.aufwaermenMinuten,
    this.aufwaermenKm,
    required this.aufwaermenUebersprungen,
    this.aufwaermenHealthUuid,
    this.trainingsName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['tag'] = Variable<String>(tag);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    if (!nullToAbsent || workout != null) {
      map['workout'] = Variable<String>(workout);
    }
    if (!nullToAbsent || minuten != null) {
      map['minuten'] = Variable<int>(minuten);
    }
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    if (!nullToAbsent || healthUuid != null) {
      map['health_uuid'] = Variable<String>(healthUuid);
    }
    if (!nullToAbsent || aufwaermenArt != null) {
      map['aufwaermen_art'] = Variable<String>(aufwaermenArt);
    }
    if (!nullToAbsent || aufwaermenMinuten != null) {
      map['aufwaermen_minuten'] = Variable<int>(aufwaermenMinuten);
    }
    if (!nullToAbsent || aufwaermenKm != null) {
      map['aufwaermen_km'] = Variable<double>(aufwaermenKm);
    }
    map['aufwaermen_uebersprungen'] = Variable<bool>(aufwaermenUebersprungen);
    if (!nullToAbsent || aufwaermenHealthUuid != null) {
      map['aufwaermen_health_uuid'] = Variable<String>(aufwaermenHealthUuid);
    }
    if (!nullToAbsent || trainingsName != null) {
      map['trainings_name'] = Variable<String>(trainingsName);
    }
    return map;
  }

  GymSitzungenCompanion toCompanion(bool nullToAbsent) {
    return GymSitzungenCompanion(
      id: Value(id),
      tag: Value(tag),
      zeitpunkt: Value(zeitpunkt),
      workout: workout == null && nullToAbsent
          ? const Value.absent()
          : Value(workout),
      minuten: minuten == null && nullToAbsent
          ? const Value.absent()
          : Value(minuten),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
      healthUuid: healthUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(healthUuid),
      aufwaermenArt: aufwaermenArt == null && nullToAbsent
          ? const Value.absent()
          : Value(aufwaermenArt),
      aufwaermenMinuten: aufwaermenMinuten == null && nullToAbsent
          ? const Value.absent()
          : Value(aufwaermenMinuten),
      aufwaermenKm: aufwaermenKm == null && nullToAbsent
          ? const Value.absent()
          : Value(aufwaermenKm),
      aufwaermenUebersprungen: Value(aufwaermenUebersprungen),
      aufwaermenHealthUuid: aufwaermenHealthUuid == null && nullToAbsent
          ? const Value.absent()
          : Value(aufwaermenHealthUuid),
      trainingsName: trainingsName == null && nullToAbsent
          ? const Value.absent()
          : Value(trainingsName),
    );
  }

  factory GymSitzungRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymSitzungRow(
      id: serializer.fromJson<String>(json['id']),
      tag: serializer.fromJson<String>(json['tag']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      workout: serializer.fromJson<String?>(json['workout']),
      minuten: serializer.fromJson<int?>(json['minuten']),
      notiz: serializer.fromJson<String?>(json['notiz']),
      healthUuid: serializer.fromJson<String?>(json['healthUuid']),
      aufwaermenArt: serializer.fromJson<String?>(json['aufwaermenArt']),
      aufwaermenMinuten: serializer.fromJson<int?>(json['aufwaermenMinuten']),
      aufwaermenKm: serializer.fromJson<double?>(json['aufwaermenKm']),
      aufwaermenUebersprungen: serializer.fromJson<bool>(
        json['aufwaermenUebersprungen'],
      ),
      aufwaermenHealthUuid: serializer.fromJson<String?>(
        json['aufwaermenHealthUuid'],
      ),
      trainingsName: serializer.fromJson<String?>(json['trainingsName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'tag': serializer.toJson<String>(tag),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'workout': serializer.toJson<String?>(workout),
      'minuten': serializer.toJson<int?>(minuten),
      'notiz': serializer.toJson<String?>(notiz),
      'healthUuid': serializer.toJson<String?>(healthUuid),
      'aufwaermenArt': serializer.toJson<String?>(aufwaermenArt),
      'aufwaermenMinuten': serializer.toJson<int?>(aufwaermenMinuten),
      'aufwaermenKm': serializer.toJson<double?>(aufwaermenKm),
      'aufwaermenUebersprungen': serializer.toJson<bool>(
        aufwaermenUebersprungen,
      ),
      'aufwaermenHealthUuid': serializer.toJson<String?>(aufwaermenHealthUuid),
      'trainingsName': serializer.toJson<String?>(trainingsName),
    };
  }

  GymSitzungRow copyWith({
    String? id,
    String? tag,
    DateTime? zeitpunkt,
    Value<String?> workout = const Value.absent(),
    Value<int?> minuten = const Value.absent(),
    Value<String?> notiz = const Value.absent(),
    Value<String?> healthUuid = const Value.absent(),
    Value<String?> aufwaermenArt = const Value.absent(),
    Value<int?> aufwaermenMinuten = const Value.absent(),
    Value<double?> aufwaermenKm = const Value.absent(),
    bool? aufwaermenUebersprungen,
    Value<String?> aufwaermenHealthUuid = const Value.absent(),
    Value<String?> trainingsName = const Value.absent(),
  }) => GymSitzungRow(
    id: id ?? this.id,
    tag: tag ?? this.tag,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    workout: workout.present ? workout.value : this.workout,
    minuten: minuten.present ? minuten.value : this.minuten,
    notiz: notiz.present ? notiz.value : this.notiz,
    healthUuid: healthUuid.present ? healthUuid.value : this.healthUuid,
    aufwaermenArt: aufwaermenArt.present
        ? aufwaermenArt.value
        : this.aufwaermenArt,
    aufwaermenMinuten: aufwaermenMinuten.present
        ? aufwaermenMinuten.value
        : this.aufwaermenMinuten,
    aufwaermenKm: aufwaermenKm.present ? aufwaermenKm.value : this.aufwaermenKm,
    aufwaermenUebersprungen:
        aufwaermenUebersprungen ?? this.aufwaermenUebersprungen,
    aufwaermenHealthUuid: aufwaermenHealthUuid.present
        ? aufwaermenHealthUuid.value
        : this.aufwaermenHealthUuid,
    trainingsName: trainingsName.present
        ? trainingsName.value
        : this.trainingsName,
  );
  GymSitzungRow copyWithCompanion(GymSitzungenCompanion data) {
    return GymSitzungRow(
      id: data.id.present ? data.id.value : this.id,
      tag: data.tag.present ? data.tag.value : this.tag,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      workout: data.workout.present ? data.workout.value : this.workout,
      minuten: data.minuten.present ? data.minuten.value : this.minuten,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
      healthUuid: data.healthUuid.present
          ? data.healthUuid.value
          : this.healthUuid,
      aufwaermenArt: data.aufwaermenArt.present
          ? data.aufwaermenArt.value
          : this.aufwaermenArt,
      aufwaermenMinuten: data.aufwaermenMinuten.present
          ? data.aufwaermenMinuten.value
          : this.aufwaermenMinuten,
      aufwaermenKm: data.aufwaermenKm.present
          ? data.aufwaermenKm.value
          : this.aufwaermenKm,
      aufwaermenUebersprungen: data.aufwaermenUebersprungen.present
          ? data.aufwaermenUebersprungen.value
          : this.aufwaermenUebersprungen,
      aufwaermenHealthUuid: data.aufwaermenHealthUuid.present
          ? data.aufwaermenHealthUuid.value
          : this.aufwaermenHealthUuid,
      trainingsName: data.trainingsName.present
          ? data.trainingsName.value
          : this.trainingsName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymSitzungRow(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('workout: $workout, ')
          ..write('minuten: $minuten, ')
          ..write('notiz: $notiz, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('aufwaermenArt: $aufwaermenArt, ')
          ..write('aufwaermenMinuten: $aufwaermenMinuten, ')
          ..write('aufwaermenKm: $aufwaermenKm, ')
          ..write('aufwaermenUebersprungen: $aufwaermenUebersprungen, ')
          ..write('aufwaermenHealthUuid: $aufwaermenHealthUuid, ')
          ..write('trainingsName: $trainingsName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    tag,
    zeitpunkt,
    workout,
    minuten,
    notiz,
    healthUuid,
    aufwaermenArt,
    aufwaermenMinuten,
    aufwaermenKm,
    aufwaermenUebersprungen,
    aufwaermenHealthUuid,
    trainingsName,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymSitzungRow &&
          other.id == this.id &&
          other.tag == this.tag &&
          other.zeitpunkt == this.zeitpunkt &&
          other.workout == this.workout &&
          other.minuten == this.minuten &&
          other.notiz == this.notiz &&
          other.healthUuid == this.healthUuid &&
          other.aufwaermenArt == this.aufwaermenArt &&
          other.aufwaermenMinuten == this.aufwaermenMinuten &&
          other.aufwaermenKm == this.aufwaermenKm &&
          other.aufwaermenUebersprungen == this.aufwaermenUebersprungen &&
          other.aufwaermenHealthUuid == this.aufwaermenHealthUuid &&
          other.trainingsName == this.trainingsName);
}

class GymSitzungenCompanion extends UpdateCompanion<GymSitzungRow> {
  final Value<String> id;
  final Value<String> tag;
  final Value<DateTime> zeitpunkt;
  final Value<String?> workout;
  final Value<int?> minuten;
  final Value<String?> notiz;
  final Value<String?> healthUuid;
  final Value<String?> aufwaermenArt;
  final Value<int?> aufwaermenMinuten;
  final Value<double?> aufwaermenKm;
  final Value<bool> aufwaermenUebersprungen;
  final Value<String?> aufwaermenHealthUuid;
  final Value<String?> trainingsName;
  final Value<int> rowid;
  const GymSitzungenCompanion({
    this.id = const Value.absent(),
    this.tag = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.workout = const Value.absent(),
    this.minuten = const Value.absent(),
    this.notiz = const Value.absent(),
    this.healthUuid = const Value.absent(),
    this.aufwaermenArt = const Value.absent(),
    this.aufwaermenMinuten = const Value.absent(),
    this.aufwaermenKm = const Value.absent(),
    this.aufwaermenUebersprungen = const Value.absent(),
    this.aufwaermenHealthUuid = const Value.absent(),
    this.trainingsName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymSitzungenCompanion.insert({
    required String id,
    required String tag,
    required DateTime zeitpunkt,
    this.workout = const Value.absent(),
    this.minuten = const Value.absent(),
    this.notiz = const Value.absent(),
    this.healthUuid = const Value.absent(),
    this.aufwaermenArt = const Value.absent(),
    this.aufwaermenMinuten = const Value.absent(),
    this.aufwaermenKm = const Value.absent(),
    this.aufwaermenUebersprungen = const Value.absent(),
    this.aufwaermenHealthUuid = const Value.absent(),
    this.trainingsName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       tag = Value(tag),
       zeitpunkt = Value(zeitpunkt);
  static Insertable<GymSitzungRow> custom({
    Expression<String>? id,
    Expression<String>? tag,
    Expression<DateTime>? zeitpunkt,
    Expression<String>? workout,
    Expression<int>? minuten,
    Expression<String>? notiz,
    Expression<String>? healthUuid,
    Expression<String>? aufwaermenArt,
    Expression<int>? aufwaermenMinuten,
    Expression<double>? aufwaermenKm,
    Expression<bool>? aufwaermenUebersprungen,
    Expression<String>? aufwaermenHealthUuid,
    Expression<String>? trainingsName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (tag != null) 'tag': tag,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (workout != null) 'workout': workout,
      if (minuten != null) 'minuten': minuten,
      if (notiz != null) 'notiz': notiz,
      if (healthUuid != null) 'health_uuid': healthUuid,
      if (aufwaermenArt != null) 'aufwaermen_art': aufwaermenArt,
      if (aufwaermenMinuten != null) 'aufwaermen_minuten': aufwaermenMinuten,
      if (aufwaermenKm != null) 'aufwaermen_km': aufwaermenKm,
      if (aufwaermenUebersprungen != null)
        'aufwaermen_uebersprungen': aufwaermenUebersprungen,
      if (aufwaermenHealthUuid != null)
        'aufwaermen_health_uuid': aufwaermenHealthUuid,
      if (trainingsName != null) 'trainings_name': trainingsName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymSitzungenCompanion copyWith({
    Value<String>? id,
    Value<String>? tag,
    Value<DateTime>? zeitpunkt,
    Value<String?>? workout,
    Value<int?>? minuten,
    Value<String?>? notiz,
    Value<String?>? healthUuid,
    Value<String?>? aufwaermenArt,
    Value<int?>? aufwaermenMinuten,
    Value<double?>? aufwaermenKm,
    Value<bool>? aufwaermenUebersprungen,
    Value<String?>? aufwaermenHealthUuid,
    Value<String?>? trainingsName,
    Value<int>? rowid,
  }) {
    return GymSitzungenCompanion(
      id: id ?? this.id,
      tag: tag ?? this.tag,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      workout: workout ?? this.workout,
      minuten: minuten ?? this.minuten,
      notiz: notiz ?? this.notiz,
      healthUuid: healthUuid ?? this.healthUuid,
      aufwaermenArt: aufwaermenArt ?? this.aufwaermenArt,
      aufwaermenMinuten: aufwaermenMinuten ?? this.aufwaermenMinuten,
      aufwaermenKm: aufwaermenKm ?? this.aufwaermenKm,
      aufwaermenUebersprungen:
          aufwaermenUebersprungen ?? this.aufwaermenUebersprungen,
      aufwaermenHealthUuid: aufwaermenHealthUuid ?? this.aufwaermenHealthUuid,
      trainingsName: trainingsName ?? this.trainingsName,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (workout.present) {
      map['workout'] = Variable<String>(workout.value);
    }
    if (minuten.present) {
      map['minuten'] = Variable<int>(minuten.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (healthUuid.present) {
      map['health_uuid'] = Variable<String>(healthUuid.value);
    }
    if (aufwaermenArt.present) {
      map['aufwaermen_art'] = Variable<String>(aufwaermenArt.value);
    }
    if (aufwaermenMinuten.present) {
      map['aufwaermen_minuten'] = Variable<int>(aufwaermenMinuten.value);
    }
    if (aufwaermenKm.present) {
      map['aufwaermen_km'] = Variable<double>(aufwaermenKm.value);
    }
    if (aufwaermenUebersprungen.present) {
      map['aufwaermen_uebersprungen'] = Variable<bool>(
        aufwaermenUebersprungen.value,
      );
    }
    if (aufwaermenHealthUuid.present) {
      map['aufwaermen_health_uuid'] = Variable<String>(
        aufwaermenHealthUuid.value,
      );
    }
    if (trainingsName.present) {
      map['trainings_name'] = Variable<String>(trainingsName.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymSitzungenCompanion(')
          ..write('id: $id, ')
          ..write('tag: $tag, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('workout: $workout, ')
          ..write('minuten: $minuten, ')
          ..write('notiz: $notiz, ')
          ..write('healthUuid: $healthUuid, ')
          ..write('aufwaermenArt: $aufwaermenArt, ')
          ..write('aufwaermenMinuten: $aufwaermenMinuten, ')
          ..write('aufwaermenKm: $aufwaermenKm, ')
          ..write('aufwaermenUebersprungen: $aufwaermenUebersprungen, ')
          ..write('aufwaermenHealthUuid: $aufwaermenHealthUuid, ')
          ..write('trainingsName: $trainingsName, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymSaetzeTable extends GymSaetze
    with TableInfo<$GymSaetzeTable, GymSatzRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymSaetzeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sitzungIdMeta = const VerificationMeta(
    'sitzungId',
  );
  @override
  late final GeneratedColumn<String> sitzungId = GeneratedColumn<String>(
    'sitzung_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uebungIdMeta = const VerificationMeta(
    'uebungId',
  );
  @override
  late final GeneratedColumn<String> uebungId = GeneratedColumn<String>(
    'uebung_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uebungPosMeta = const VerificationMeta(
    'uebungPos',
  );
  @override
  late final GeneratedColumn<int> uebungPos = GeneratedColumn<int>(
    'uebung_pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _satzNrMeta = const VerificationMeta('satzNr');
  @override
  late final GeneratedColumn<int> satzNr = GeneratedColumn<int>(
    'satz_nr',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gewichtKgMeta = const VerificationMeta(
    'gewichtKg',
  );
  @override
  late final GeneratedColumn<double> gewichtKg = GeneratedColumn<double>(
    'gewicht_kg',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _wdhMeta = const VerificationMeta('wdh');
  @override
  late final GeneratedColumn<int> wdh = GeneratedColumn<int>(
    'wdh',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sitzungId,
    uebungId,
    uebungPos,
    satzNr,
    gewichtKg,
    wdh,
    zeitpunkt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_saetze';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymSatzRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sitzung_id')) {
      context.handle(
        _sitzungIdMeta,
        sitzungId.isAcceptableOrUnknown(data['sitzung_id']!, _sitzungIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sitzungIdMeta);
    }
    if (data.containsKey('uebung_id')) {
      context.handle(
        _uebungIdMeta,
        uebungId.isAcceptableOrUnknown(data['uebung_id']!, _uebungIdMeta),
      );
    } else if (isInserting) {
      context.missing(_uebungIdMeta);
    }
    if (data.containsKey('uebung_pos')) {
      context.handle(
        _uebungPosMeta,
        uebungPos.isAcceptableOrUnknown(data['uebung_pos']!, _uebungPosMeta),
      );
    } else if (isInserting) {
      context.missing(_uebungPosMeta);
    }
    if (data.containsKey('satz_nr')) {
      context.handle(
        _satzNrMeta,
        satzNr.isAcceptableOrUnknown(data['satz_nr']!, _satzNrMeta),
      );
    } else if (isInserting) {
      context.missing(_satzNrMeta);
    }
    if (data.containsKey('gewicht_kg')) {
      context.handle(
        _gewichtKgMeta,
        gewichtKg.isAcceptableOrUnknown(data['gewicht_kg']!, _gewichtKgMeta),
      );
    } else if (isInserting) {
      context.missing(_gewichtKgMeta);
    }
    if (data.containsKey('wdh')) {
      context.handle(
        _wdhMeta,
        wdh.isAcceptableOrUnknown(data['wdh']!, _wdhMeta),
      );
    } else if (isInserting) {
      context.missing(_wdhMeta);
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sitzungId, uebungId, satzNr};
  @override
  GymSatzRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymSatzRow(
      sitzungId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sitzung_id'],
      )!,
      uebungId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uebung_id'],
      )!,
      uebungPos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uebung_pos'],
      )!,
      satzNr: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}satz_nr'],
      )!,
      gewichtKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gewicht_kg'],
      )!,
      wdh: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wdh'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      ),
    );
  }

  @override
  $GymSaetzeTable createAlias(String alias) {
    return $GymSaetzeTable(attachedDatabase, alias);
  }
}

class GymSatzRow extends DataClass implements Insertable<GymSatzRow> {
  final String sitzungId;

  /// Die `Exercise.id` aus dem Katalog.
  final String uebungId;

  /// Die Position der Übung in der Sitzung, **ab 1**.
  ///
  /// Abgelegt und nicht aus `GymSessionOrder.ordered` gerechnet: Die
  /// Reihenfolge geht in `ImportedSession.==` ein, gehört also zur Sitzung.
  /// Rechnete man sie beim Laden neu, änderte eine Umsortierung des
  /// Katalogs rückwirkend, in welcher Reihenfolge Tim vor einem Jahr
  /// trainiert hat.
  final int uebungPos;

  /// Die Nummer des Satzes innerhalb der Übung, **ab 1** — damit „Satz 1"
  /// in der Datei auch Satz 1 ist.
  final int satzNr;

  /// Kilogramm. **Negativ heißt Unterstützung** (−27 sind 27 kg Hilfe der
  /// Maschine), `0.0` heißt eigenes Körpergewicht. Beides sind Werte, keine
  /// Lücken.
  final double gewichtKg;

  /// Wiederholungen — bei Zeitübungen Sekunden.
  final int wdh;

  /// Wann der Satz **eingetragen** wurde, als UTC — **nullbar und ohne
  /// Vorgabewert.**
  ///
  /// `null` heißt „nicht erfasst", und das ist der **Normalfall**: Die
  /// Übernahme aus der alten App (#59) bringt Tims gesamten bisherigen
  /// Verlauf, und dort gibt es keine Satz-Uhrzeiten. Ein Vorgabewert — ob
  /// `now`, ob `0`, ob Epoch-Null — behauptete, der Satz sei zu dieser
  /// Minute entstanden (Spec 11, Tim 10.11.2026).
  final DateTime? zeitpunkt;
  const GymSatzRow({
    required this.sitzungId,
    required this.uebungId,
    required this.uebungPos,
    required this.satzNr,
    required this.gewichtKg,
    required this.wdh,
    this.zeitpunkt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sitzung_id'] = Variable<String>(sitzungId);
    map['uebung_id'] = Variable<String>(uebungId);
    map['uebung_pos'] = Variable<int>(uebungPos);
    map['satz_nr'] = Variable<int>(satzNr);
    map['gewicht_kg'] = Variable<double>(gewichtKg);
    map['wdh'] = Variable<int>(wdh);
    if (!nullToAbsent || zeitpunkt != null) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    }
    return map;
  }

  GymSaetzeCompanion toCompanion(bool nullToAbsent) {
    return GymSaetzeCompanion(
      sitzungId: Value(sitzungId),
      uebungId: Value(uebungId),
      uebungPos: Value(uebungPos),
      satzNr: Value(satzNr),
      gewichtKg: Value(gewichtKg),
      wdh: Value(wdh),
      zeitpunkt: zeitpunkt == null && nullToAbsent
          ? const Value.absent()
          : Value(zeitpunkt),
    );
  }

  factory GymSatzRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymSatzRow(
      sitzungId: serializer.fromJson<String>(json['sitzungId']),
      uebungId: serializer.fromJson<String>(json['uebungId']),
      uebungPos: serializer.fromJson<int>(json['uebungPos']),
      satzNr: serializer.fromJson<int>(json['satzNr']),
      gewichtKg: serializer.fromJson<double>(json['gewichtKg']),
      wdh: serializer.fromJson<int>(json['wdh']),
      zeitpunkt: serializer.fromJson<DateTime?>(json['zeitpunkt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sitzungId': serializer.toJson<String>(sitzungId),
      'uebungId': serializer.toJson<String>(uebungId),
      'uebungPos': serializer.toJson<int>(uebungPos),
      'satzNr': serializer.toJson<int>(satzNr),
      'gewichtKg': serializer.toJson<double>(gewichtKg),
      'wdh': serializer.toJson<int>(wdh),
      'zeitpunkt': serializer.toJson<DateTime?>(zeitpunkt),
    };
  }

  GymSatzRow copyWith({
    String? sitzungId,
    String? uebungId,
    int? uebungPos,
    int? satzNr,
    double? gewichtKg,
    int? wdh,
    Value<DateTime?> zeitpunkt = const Value.absent(),
  }) => GymSatzRow(
    sitzungId: sitzungId ?? this.sitzungId,
    uebungId: uebungId ?? this.uebungId,
    uebungPos: uebungPos ?? this.uebungPos,
    satzNr: satzNr ?? this.satzNr,
    gewichtKg: gewichtKg ?? this.gewichtKg,
    wdh: wdh ?? this.wdh,
    zeitpunkt: zeitpunkt.present ? zeitpunkt.value : this.zeitpunkt,
  );
  GymSatzRow copyWithCompanion(GymSaetzeCompanion data) {
    return GymSatzRow(
      sitzungId: data.sitzungId.present ? data.sitzungId.value : this.sitzungId,
      uebungId: data.uebungId.present ? data.uebungId.value : this.uebungId,
      uebungPos: data.uebungPos.present ? data.uebungPos.value : this.uebungPos,
      satzNr: data.satzNr.present ? data.satzNr.value : this.satzNr,
      gewichtKg: data.gewichtKg.present ? data.gewichtKg.value : this.gewichtKg,
      wdh: data.wdh.present ? data.wdh.value : this.wdh,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymSatzRow(')
          ..write('sitzungId: $sitzungId, ')
          ..write('uebungId: $uebungId, ')
          ..write('uebungPos: $uebungPos, ')
          ..write('satzNr: $satzNr, ')
          ..write('gewichtKg: $gewichtKg, ')
          ..write('wdh: $wdh, ')
          ..write('zeitpunkt: $zeitpunkt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sitzungId,
    uebungId,
    uebungPos,
    satzNr,
    gewichtKg,
    wdh,
    zeitpunkt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymSatzRow &&
          other.sitzungId == this.sitzungId &&
          other.uebungId == this.uebungId &&
          other.uebungPos == this.uebungPos &&
          other.satzNr == this.satzNr &&
          other.gewichtKg == this.gewichtKg &&
          other.wdh == this.wdh &&
          other.zeitpunkt == this.zeitpunkt);
}

class GymSaetzeCompanion extends UpdateCompanion<GymSatzRow> {
  final Value<String> sitzungId;
  final Value<String> uebungId;
  final Value<int> uebungPos;
  final Value<int> satzNr;
  final Value<double> gewichtKg;
  final Value<int> wdh;
  final Value<DateTime?> zeitpunkt;
  final Value<int> rowid;
  const GymSaetzeCompanion({
    this.sitzungId = const Value.absent(),
    this.uebungId = const Value.absent(),
    this.uebungPos = const Value.absent(),
    this.satzNr = const Value.absent(),
    this.gewichtKg = const Value.absent(),
    this.wdh = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymSaetzeCompanion.insert({
    required String sitzungId,
    required String uebungId,
    required int uebungPos,
    required int satzNr,
    required double gewichtKg,
    required int wdh,
    this.zeitpunkt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sitzungId = Value(sitzungId),
       uebungId = Value(uebungId),
       uebungPos = Value(uebungPos),
       satzNr = Value(satzNr),
       gewichtKg = Value(gewichtKg),
       wdh = Value(wdh);
  static Insertable<GymSatzRow> custom({
    Expression<String>? sitzungId,
    Expression<String>? uebungId,
    Expression<int>? uebungPos,
    Expression<int>? satzNr,
    Expression<double>? gewichtKg,
    Expression<int>? wdh,
    Expression<DateTime>? zeitpunkt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sitzungId != null) 'sitzung_id': sitzungId,
      if (uebungId != null) 'uebung_id': uebungId,
      if (uebungPos != null) 'uebung_pos': uebungPos,
      if (satzNr != null) 'satz_nr': satzNr,
      if (gewichtKg != null) 'gewicht_kg': gewichtKg,
      if (wdh != null) 'wdh': wdh,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymSaetzeCompanion copyWith({
    Value<String>? sitzungId,
    Value<String>? uebungId,
    Value<int>? uebungPos,
    Value<int>? satzNr,
    Value<double>? gewichtKg,
    Value<int>? wdh,
    Value<DateTime?>? zeitpunkt,
    Value<int>? rowid,
  }) {
    return GymSaetzeCompanion(
      sitzungId: sitzungId ?? this.sitzungId,
      uebungId: uebungId ?? this.uebungId,
      uebungPos: uebungPos ?? this.uebungPos,
      satzNr: satzNr ?? this.satzNr,
      gewichtKg: gewichtKg ?? this.gewichtKg,
      wdh: wdh ?? this.wdh,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sitzungId.present) {
      map['sitzung_id'] = Variable<String>(sitzungId.value);
    }
    if (uebungId.present) {
      map['uebung_id'] = Variable<String>(uebungId.value);
    }
    if (uebungPos.present) {
      map['uebung_pos'] = Variable<int>(uebungPos.value);
    }
    if (satzNr.present) {
      map['satz_nr'] = Variable<int>(satzNr.value);
    }
    if (gewichtKg.present) {
      map['gewicht_kg'] = Variable<double>(gewichtKg.value);
    }
    if (wdh.present) {
      map['wdh'] = Variable<int>(wdh.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymSaetzeCompanion(')
          ..write('sitzungId: $sitzungId, ')
          ..write('uebungId: $uebungId, ')
          ..write('uebungPos: $uebungPos, ')
          ..write('satzNr: $satzNr, ')
          ..write('gewichtKg: $gewichtKg, ')
          ..write('wdh: $wdh, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymEntwuerfeTable extends GymEntwuerfe
    with TableInfo<$GymEntwuerfeTable, GymEntwurfRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymEntwuerfeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (id = 0)',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _workoutMeta = const VerificationMeta(
    'workout',
  );
  @override
  late final GeneratedColumn<String> workout = GeneratedColumn<String>(
    'workout',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sitzungIdMeta = const VerificationMeta(
    'sitzungId',
  );
  @override
  late final GeneratedColumn<String> sitzungId = GeneratedColumn<String>(
    'sitzung_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dauerMeta = const VerificationMeta('dauer');
  @override
  late final GeneratedColumn<String> dauer = GeneratedColumn<String>(
    'dauer',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _gespeichertAmMeta = const VerificationMeta(
    'gespeichertAm',
  );
  @override
  late final GeneratedColumn<DateTime> gespeichertAm =
      GeneratedColumn<DateTime>(
        'gespeichert_am',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _felderMeta = const VerificationMeta('felder');
  @override
  late final GeneratedColumn<String> felder = GeneratedColumn<String>(
    'felder',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    workout,
    sitzungId,
    zeitpunkt,
    dauer,
    notiz,
    gespeichertAm,
    felder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_entwuerfe';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymEntwurfRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('workout')) {
      context.handle(
        _workoutMeta,
        workout.isAcceptableOrUnknown(data['workout']!, _workoutMeta),
      );
    } else if (isInserting) {
      context.missing(_workoutMeta);
    }
    if (data.containsKey('sitzung_id')) {
      context.handle(
        _sitzungIdMeta,
        sitzungId.isAcceptableOrUnknown(data['sitzung_id']!, _sitzungIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sitzungIdMeta);
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('dauer')) {
      context.handle(
        _dauerMeta,
        dauer.isAcceptableOrUnknown(data['dauer']!, _dauerMeta),
      );
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    if (data.containsKey('gespeichert_am')) {
      context.handle(
        _gespeichertAmMeta,
        gespeichertAm.isAcceptableOrUnknown(
          data['gespeichert_am']!,
          _gespeichertAmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_gespeichertAmMeta);
    }
    if (data.containsKey('felder')) {
      context.handle(
        _felderMeta,
        felder.isAcceptableOrUnknown(data['felder']!, _felderMeta),
      );
    } else if (isInserting) {
      context.missing(_felderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GymEntwurfRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymEntwurfRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      workout: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workout'],
      )!,
      sitzungId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sitzung_id'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      dauer: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dauer'],
      ),
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
      gespeichertAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}gespeichert_am'],
      )!,
      felder: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}felder'],
      )!,
    );
  }

  @override
  $GymEntwuerfeTable createAlias(String alias) {
    return $GymEntwuerfeTable(attachedDatabase, alias);
  }
}

class GymEntwurfRow extends DataClass implements Insertable<GymEntwurfRow> {
  /// Immer `0` — die Tabelle trägt **einen** Entwurf, nicht sieben (Tims
  /// Entscheidung vom 10.11.2026; wer ein zweites Training anfängt,
  /// bekommt eine Rückfrage).
  ///
  /// **Das `CHECK` ist nötig, der Vorgabewert allein trägt nicht.** Eine
  /// `INTEGER`-Spalte, die alleiniger Primärschlüssel ist, wird in SQLite
  /// zum Alias der `rowid`: Fehlt die Spalte beim Einfügen, vergibt SQLite
  /// selbst eine Nummer und **übergeht den `DEFAULT` stillschweigend**.
  /// Ohne das `CHECK` stünden nach zwei rohen Einfügungen zwei Entwürfe
  /// da, obwohl die Spalte das Gegenteil behauptet — eine Zusage, die der
  /// Code nicht durchsetzt. Aufgefallen beim Bauen: Der Test „die
  /// Datenbank selbst lässt keine zweite Zeile zu" war mit der vorigen
  /// Form in keiner Implementierung erfüllbar.
  ///
  /// Dieselbe Falle steht in `ziel_werte`, `stammdaten` und
  /// `ki_einstellungen`; dort hält die Eindeutigkeit nur, weil jeder
  /// Schreibweg die `id` ausdrücklich setzt.
  final int id;

  /// Die Kennung des Trainings — `Workout.code` oder, ab Schema v25, die
  /// UUID eines eigenen Trainings (Spec 4.7) — **nicht nullbar**: Ein Entwurf
  /// ohne Training wäre keiner, die Fokus-Karte zeigt ihn unter seinem
  /// Namen.
  final String workout;

  /// Die UUID, die die fertige Sitzung tragen wird (#418 Punkt 1).
  final String sitzungId;

  /// Das eingestellte Datum des Trainings, als UTC.
  final DateTime zeitpunkt;

  /// Die getippte Dauer als **roher Text**, nullbar.
  final String? dauer;
  final String? notiz;

  /// Wann zuletzt zwischengespeichert wurde — für den Haken in der Leiste.
  final DateTime gespeichertAm;

  /// Die Satzzeilen als JSON-Text, roh. Je Übung der Umschalterzustand und
  /// die getippten Felder.
  final String felder;
  const GymEntwurfRow({
    required this.id,
    required this.workout,
    required this.sitzungId,
    required this.zeitpunkt,
    this.dauer,
    this.notiz,
    required this.gespeichertAm,
    required this.felder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['workout'] = Variable<String>(workout);
    map['sitzung_id'] = Variable<String>(sitzungId);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    if (!nullToAbsent || dauer != null) {
      map['dauer'] = Variable<String>(dauer);
    }
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    map['gespeichert_am'] = Variable<DateTime>(gespeichertAm);
    map['felder'] = Variable<String>(felder);
    return map;
  }

  GymEntwuerfeCompanion toCompanion(bool nullToAbsent) {
    return GymEntwuerfeCompanion(
      id: Value(id),
      workout: Value(workout),
      sitzungId: Value(sitzungId),
      zeitpunkt: Value(zeitpunkt),
      dauer: dauer == null && nullToAbsent
          ? const Value.absent()
          : Value(dauer),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
      gespeichertAm: Value(gespeichertAm),
      felder: Value(felder),
    );
  }

  factory GymEntwurfRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymEntwurfRow(
      id: serializer.fromJson<int>(json['id']),
      workout: serializer.fromJson<String>(json['workout']),
      sitzungId: serializer.fromJson<String>(json['sitzungId']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      dauer: serializer.fromJson<String?>(json['dauer']),
      notiz: serializer.fromJson<String?>(json['notiz']),
      gespeichertAm: serializer.fromJson<DateTime>(json['gespeichertAm']),
      felder: serializer.fromJson<String>(json['felder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'workout': serializer.toJson<String>(workout),
      'sitzungId': serializer.toJson<String>(sitzungId),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'dauer': serializer.toJson<String?>(dauer),
      'notiz': serializer.toJson<String?>(notiz),
      'gespeichertAm': serializer.toJson<DateTime>(gespeichertAm),
      'felder': serializer.toJson<String>(felder),
    };
  }

  GymEntwurfRow copyWith({
    int? id,
    String? workout,
    String? sitzungId,
    DateTime? zeitpunkt,
    Value<String?> dauer = const Value.absent(),
    Value<String?> notiz = const Value.absent(),
    DateTime? gespeichertAm,
    String? felder,
  }) => GymEntwurfRow(
    id: id ?? this.id,
    workout: workout ?? this.workout,
    sitzungId: sitzungId ?? this.sitzungId,
    zeitpunkt: zeitpunkt ?? this.zeitpunkt,
    dauer: dauer.present ? dauer.value : this.dauer,
    notiz: notiz.present ? notiz.value : this.notiz,
    gespeichertAm: gespeichertAm ?? this.gespeichertAm,
    felder: felder ?? this.felder,
  );
  GymEntwurfRow copyWithCompanion(GymEntwuerfeCompanion data) {
    return GymEntwurfRow(
      id: data.id.present ? data.id.value : this.id,
      workout: data.workout.present ? data.workout.value : this.workout,
      sitzungId: data.sitzungId.present ? data.sitzungId.value : this.sitzungId,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      dauer: data.dauer.present ? data.dauer.value : this.dauer,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
      gespeichertAm: data.gespeichertAm.present
          ? data.gespeichertAm.value
          : this.gespeichertAm,
      felder: data.felder.present ? data.felder.value : this.felder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymEntwurfRow(')
          ..write('id: $id, ')
          ..write('workout: $workout, ')
          ..write('sitzungId: $sitzungId, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('dauer: $dauer, ')
          ..write('notiz: $notiz, ')
          ..write('gespeichertAm: $gespeichertAm, ')
          ..write('felder: $felder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    workout,
    sitzungId,
    zeitpunkt,
    dauer,
    notiz,
    gespeichertAm,
    felder,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymEntwurfRow &&
          other.id == this.id &&
          other.workout == this.workout &&
          other.sitzungId == this.sitzungId &&
          other.zeitpunkt == this.zeitpunkt &&
          other.dauer == this.dauer &&
          other.notiz == this.notiz &&
          other.gespeichertAm == this.gespeichertAm &&
          other.felder == this.felder);
}

class GymEntwuerfeCompanion extends UpdateCompanion<GymEntwurfRow> {
  final Value<int> id;
  final Value<String> workout;
  final Value<String> sitzungId;
  final Value<DateTime> zeitpunkt;
  final Value<String?> dauer;
  final Value<String?> notiz;
  final Value<DateTime> gespeichertAm;
  final Value<String> felder;
  const GymEntwuerfeCompanion({
    this.id = const Value.absent(),
    this.workout = const Value.absent(),
    this.sitzungId = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.dauer = const Value.absent(),
    this.notiz = const Value.absent(),
    this.gespeichertAm = const Value.absent(),
    this.felder = const Value.absent(),
  });
  GymEntwuerfeCompanion.insert({
    this.id = const Value.absent(),
    required String workout,
    required String sitzungId,
    required DateTime zeitpunkt,
    this.dauer = const Value.absent(),
    this.notiz = const Value.absent(),
    required DateTime gespeichertAm,
    required String felder,
  }) : workout = Value(workout),
       sitzungId = Value(sitzungId),
       zeitpunkt = Value(zeitpunkt),
       gespeichertAm = Value(gespeichertAm),
       felder = Value(felder);
  static Insertable<GymEntwurfRow> custom({
    Expression<int>? id,
    Expression<String>? workout,
    Expression<String>? sitzungId,
    Expression<DateTime>? zeitpunkt,
    Expression<String>? dauer,
    Expression<String>? notiz,
    Expression<DateTime>? gespeichertAm,
    Expression<String>? felder,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (workout != null) 'workout': workout,
      if (sitzungId != null) 'sitzung_id': sitzungId,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (dauer != null) 'dauer': dauer,
      if (notiz != null) 'notiz': notiz,
      if (gespeichertAm != null) 'gespeichert_am': gespeichertAm,
      if (felder != null) 'felder': felder,
    });
  }

  GymEntwuerfeCompanion copyWith({
    Value<int>? id,
    Value<String>? workout,
    Value<String>? sitzungId,
    Value<DateTime>? zeitpunkt,
    Value<String?>? dauer,
    Value<String?>? notiz,
    Value<DateTime>? gespeichertAm,
    Value<String>? felder,
  }) {
    return GymEntwuerfeCompanion(
      id: id ?? this.id,
      workout: workout ?? this.workout,
      sitzungId: sitzungId ?? this.sitzungId,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      dauer: dauer ?? this.dauer,
      notiz: notiz ?? this.notiz,
      gespeichertAm: gespeichertAm ?? this.gespeichertAm,
      felder: felder ?? this.felder,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (workout.present) {
      map['workout'] = Variable<String>(workout.value);
    }
    if (sitzungId.present) {
      map['sitzung_id'] = Variable<String>(sitzungId.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (dauer.present) {
      map['dauer'] = Variable<String>(dauer.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (gespeichertAm.present) {
      map['gespeichert_am'] = Variable<DateTime>(gespeichertAm.value);
    }
    if (felder.present) {
      map['felder'] = Variable<String>(felder.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymEntwuerfeCompanion(')
          ..write('id: $id, ')
          ..write('workout: $workout, ')
          ..write('sitzungId: $sitzungId, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('dauer: $dauer, ')
          ..write('notiz: $notiz, ')
          ..write('gespeichertAm: $gespeichertAm, ')
          ..write('felder: $felder')
          ..write(')'))
        .toString();
  }
}

class $KalorienzieleTable extends Kalorienziele
    with TableInfo<$KalorienzieleTable, KalorienzielRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KalorienzieleTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _abTagMeta = const VerificationMeta('abTag');
  @override
  late final GeneratedColumn<String> abTag = GeneratedColumn<String>(
    'ab_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kcalMeta = const VerificationMeta('kcal');
  @override
  late final GeneratedColumn<double> kcal = GeneratedColumn<double>(
    'kcal',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _herkunftMeta = const VerificationMeta(
    'herkunft',
  );
  @override
  late final GeneratedColumn<String> herkunft = GeneratedColumn<String>(
    'herkunft',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _grundumsatzKcalMeta = const VerificationMeta(
    'grundumsatzKcal',
  );
  @override
  late final GeneratedColumn<double> grundumsatzKcal = GeneratedColumn<double>(
    'grundumsatz_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _aktivKcalMeta = const VerificationMeta(
    'aktivKcal',
  );
  @override
  late final GeneratedColumn<double> aktivKcal = GeneratedColumn<double>(
    'aktiv_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _koerperzielKcalMeta = const VerificationMeta(
    'koerperzielKcal',
  );
  @override
  late final GeneratedColumn<double> koerperzielKcal = GeneratedColumn<double>(
    'koerperziel_kcal',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    abTag,
    kcal,
    herkunft,
    grundumsatzKcal,
    aktivKcal,
    koerperzielKcal,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kalorienziele';
  @override
  VerificationContext validateIntegrity(
    Insertable<KalorienzielRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ab_tag')) {
      context.handle(
        _abTagMeta,
        abTag.isAcceptableOrUnknown(data['ab_tag']!, _abTagMeta),
      );
    } else if (isInserting) {
      context.missing(_abTagMeta);
    }
    if (data.containsKey('kcal')) {
      context.handle(
        _kcalMeta,
        kcal.isAcceptableOrUnknown(data['kcal']!, _kcalMeta),
      );
    } else if (isInserting) {
      context.missing(_kcalMeta);
    }
    if (data.containsKey('herkunft')) {
      context.handle(
        _herkunftMeta,
        herkunft.isAcceptableOrUnknown(data['herkunft']!, _herkunftMeta),
      );
    } else if (isInserting) {
      context.missing(_herkunftMeta);
    }
    if (data.containsKey('grundumsatz_kcal')) {
      context.handle(
        _grundumsatzKcalMeta,
        grundumsatzKcal.isAcceptableOrUnknown(
          data['grundumsatz_kcal']!,
          _grundumsatzKcalMeta,
        ),
      );
    }
    if (data.containsKey('aktiv_kcal')) {
      context.handle(
        _aktivKcalMeta,
        aktivKcal.isAcceptableOrUnknown(data['aktiv_kcal']!, _aktivKcalMeta),
      );
    }
    if (data.containsKey('koerperziel_kcal')) {
      context.handle(
        _koerperzielKcalMeta,
        koerperzielKcal.isAcceptableOrUnknown(
          data['koerperziel_kcal']!,
          _koerperzielKcalMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {abTag};
  @override
  KalorienzielRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KalorienzielRow(
      abTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ab_tag'],
      )!,
      kcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kcal'],
      )!,
      herkunft: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}herkunft'],
      )!,
      grundumsatzKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}grundumsatz_kcal'],
      ),
      aktivKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}aktiv_kcal'],
      ),
      koerperzielKcal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}koerperziel_kcal'],
      ),
    );
  }

  @override
  $KalorienzieleTable createAlias(String alias) {
    return $KalorienzieleTable(attachedDatabase, alias);
  }
}

class KalorienzielRow extends DataClass implements Insertable<KalorienzielRow> {
  /// Der Tag, ab dem das Ziel gilt, als ISO-Tagesschlüssel. **Der
  /// Primärschlüssel**: Je Tag gilt höchstens ein Ziel (Festlegung des
  /// Test-Agenten, nicht von Tim). `ab_tag <= ?` vergleicht lexikografisch
  /// richtig.
  final String abTag;

  /// Das Ziel in kcal. `REAL`, denn die gerechnete Zahl hat Nachkommastellen,
  /// und Runden wäre eine stille Änderung.
  final double kcal;

  /// `berechnet` oder `hand` (später `coach`). **Ohne Vorgabewert** — ein
  /// Vorgabewert behauptete eine Herkunft, die niemand festgehalten hat.
  final String herkunft;

  /// Die drei Anteile einer berechneten Festlegung, damit die Herleitung an
  /// einem festen Tag die Zahl im Ring erklärt und nicht die von heute
  /// (#314). **Nullbar, ohne Vorgabewert**: Ein Ziel von Hand hat keine
  /// Anteile, und eine `0` behauptete welche (Fehler `01`).
  final double? grundumsatzKcal;
  final double? aktivKcal;
  final double? koerperzielKcal;
  const KalorienzielRow({
    required this.abTag,
    required this.kcal,
    required this.herkunft,
    this.grundumsatzKcal,
    this.aktivKcal,
    this.koerperzielKcal,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ab_tag'] = Variable<String>(abTag);
    map['kcal'] = Variable<double>(kcal);
    map['herkunft'] = Variable<String>(herkunft);
    if (!nullToAbsent || grundumsatzKcal != null) {
      map['grundumsatz_kcal'] = Variable<double>(grundumsatzKcal);
    }
    if (!nullToAbsent || aktivKcal != null) {
      map['aktiv_kcal'] = Variable<double>(aktivKcal);
    }
    if (!nullToAbsent || koerperzielKcal != null) {
      map['koerperziel_kcal'] = Variable<double>(koerperzielKcal);
    }
    return map;
  }

  KalorienzieleCompanion toCompanion(bool nullToAbsent) {
    return KalorienzieleCompanion(
      abTag: Value(abTag),
      kcal: Value(kcal),
      herkunft: Value(herkunft),
      grundumsatzKcal: grundumsatzKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(grundumsatzKcal),
      aktivKcal: aktivKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(aktivKcal),
      koerperzielKcal: koerperzielKcal == null && nullToAbsent
          ? const Value.absent()
          : Value(koerperzielKcal),
    );
  }

  factory KalorienzielRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KalorienzielRow(
      abTag: serializer.fromJson<String>(json['abTag']),
      kcal: serializer.fromJson<double>(json['kcal']),
      herkunft: serializer.fromJson<String>(json['herkunft']),
      grundumsatzKcal: serializer.fromJson<double?>(json['grundumsatzKcal']),
      aktivKcal: serializer.fromJson<double?>(json['aktivKcal']),
      koerperzielKcal: serializer.fromJson<double?>(json['koerperzielKcal']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'abTag': serializer.toJson<String>(abTag),
      'kcal': serializer.toJson<double>(kcal),
      'herkunft': serializer.toJson<String>(herkunft),
      'grundumsatzKcal': serializer.toJson<double?>(grundumsatzKcal),
      'aktivKcal': serializer.toJson<double?>(aktivKcal),
      'koerperzielKcal': serializer.toJson<double?>(koerperzielKcal),
    };
  }

  KalorienzielRow copyWith({
    String? abTag,
    double? kcal,
    String? herkunft,
    Value<double?> grundumsatzKcal = const Value.absent(),
    Value<double?> aktivKcal = const Value.absent(),
    Value<double?> koerperzielKcal = const Value.absent(),
  }) => KalorienzielRow(
    abTag: abTag ?? this.abTag,
    kcal: kcal ?? this.kcal,
    herkunft: herkunft ?? this.herkunft,
    grundumsatzKcal: grundumsatzKcal.present
        ? grundumsatzKcal.value
        : this.grundumsatzKcal,
    aktivKcal: aktivKcal.present ? aktivKcal.value : this.aktivKcal,
    koerperzielKcal: koerperzielKcal.present
        ? koerperzielKcal.value
        : this.koerperzielKcal,
  );
  KalorienzielRow copyWithCompanion(KalorienzieleCompanion data) {
    return KalorienzielRow(
      abTag: data.abTag.present ? data.abTag.value : this.abTag,
      kcal: data.kcal.present ? data.kcal.value : this.kcal,
      herkunft: data.herkunft.present ? data.herkunft.value : this.herkunft,
      grundumsatzKcal: data.grundumsatzKcal.present
          ? data.grundumsatzKcal.value
          : this.grundumsatzKcal,
      aktivKcal: data.aktivKcal.present ? data.aktivKcal.value : this.aktivKcal,
      koerperzielKcal: data.koerperzielKcal.present
          ? data.koerperzielKcal.value
          : this.koerperzielKcal,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KalorienzielRow(')
          ..write('abTag: $abTag, ')
          ..write('kcal: $kcal, ')
          ..write('herkunft: $herkunft, ')
          ..write('grundumsatzKcal: $grundumsatzKcal, ')
          ..write('aktivKcal: $aktivKcal, ')
          ..write('koerperzielKcal: $koerperzielKcal')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    abTag,
    kcal,
    herkunft,
    grundumsatzKcal,
    aktivKcal,
    koerperzielKcal,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KalorienzielRow &&
          other.abTag == this.abTag &&
          other.kcal == this.kcal &&
          other.herkunft == this.herkunft &&
          other.grundumsatzKcal == this.grundumsatzKcal &&
          other.aktivKcal == this.aktivKcal &&
          other.koerperzielKcal == this.koerperzielKcal);
}

class KalorienzieleCompanion extends UpdateCompanion<KalorienzielRow> {
  final Value<String> abTag;
  final Value<double> kcal;
  final Value<String> herkunft;
  final Value<double?> grundumsatzKcal;
  final Value<double?> aktivKcal;
  final Value<double?> koerperzielKcal;
  final Value<int> rowid;
  const KalorienzieleCompanion({
    this.abTag = const Value.absent(),
    this.kcal = const Value.absent(),
    this.herkunft = const Value.absent(),
    this.grundumsatzKcal = const Value.absent(),
    this.aktivKcal = const Value.absent(),
    this.koerperzielKcal = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  KalorienzieleCompanion.insert({
    required String abTag,
    required double kcal,
    required String herkunft,
    this.grundumsatzKcal = const Value.absent(),
    this.aktivKcal = const Value.absent(),
    this.koerperzielKcal = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : abTag = Value(abTag),
       kcal = Value(kcal),
       herkunft = Value(herkunft);
  static Insertable<KalorienzielRow> custom({
    Expression<String>? abTag,
    Expression<double>? kcal,
    Expression<String>? herkunft,
    Expression<double>? grundumsatzKcal,
    Expression<double>? aktivKcal,
    Expression<double>? koerperzielKcal,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (abTag != null) 'ab_tag': abTag,
      if (kcal != null) 'kcal': kcal,
      if (herkunft != null) 'herkunft': herkunft,
      if (grundumsatzKcal != null) 'grundumsatz_kcal': grundumsatzKcal,
      if (aktivKcal != null) 'aktiv_kcal': aktivKcal,
      if (koerperzielKcal != null) 'koerperziel_kcal': koerperzielKcal,
      if (rowid != null) 'rowid': rowid,
    });
  }

  KalorienzieleCompanion copyWith({
    Value<String>? abTag,
    Value<double>? kcal,
    Value<String>? herkunft,
    Value<double?>? grundumsatzKcal,
    Value<double?>? aktivKcal,
    Value<double?>? koerperzielKcal,
    Value<int>? rowid,
  }) {
    return KalorienzieleCompanion(
      abTag: abTag ?? this.abTag,
      kcal: kcal ?? this.kcal,
      herkunft: herkunft ?? this.herkunft,
      grundumsatzKcal: grundumsatzKcal ?? this.grundumsatzKcal,
      aktivKcal: aktivKcal ?? this.aktivKcal,
      koerperzielKcal: koerperzielKcal ?? this.koerperzielKcal,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (abTag.present) {
      map['ab_tag'] = Variable<String>(abTag.value);
    }
    if (kcal.present) {
      map['kcal'] = Variable<double>(kcal.value);
    }
    if (herkunft.present) {
      map['herkunft'] = Variable<String>(herkunft.value);
    }
    if (grundumsatzKcal.present) {
      map['grundumsatz_kcal'] = Variable<double>(grundumsatzKcal.value);
    }
    if (aktivKcal.present) {
      map['aktiv_kcal'] = Variable<double>(aktivKcal.value);
    }
    if (koerperzielKcal.present) {
      map['koerperziel_kcal'] = Variable<double>(koerperzielKcal.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KalorienzieleCompanion(')
          ..write('abTag: $abTag, ')
          ..write('kcal: $kcal, ')
          ..write('herkunft: $herkunft, ')
          ..write('grundumsatzKcal: $grundumsatzKcal, ')
          ..write('aktivKcal: $aktivKcal, ')
          ..write('koerperzielKcal: $koerperzielKcal, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MahlzeitAufteilungenTable extends MahlzeitAufteilungen
    with TableInfo<$MahlzeitAufteilungenTable, MahlzeitAufteilungRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MahlzeitAufteilungenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _abTagMeta = const VerificationMeta('abTag');
  @override
  late final GeneratedColumn<String> abTag = GeneratedColumn<String>(
    'ab_tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fruehstueckPctMeta = const VerificationMeta(
    'fruehstueckPct',
  );
  @override
  late final GeneratedColumn<int> fruehstueckPct = GeneratedColumn<int>(
    'fruehstueck_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mittagPctMeta = const VerificationMeta(
    'mittagPct',
  );
  @override
  late final GeneratedColumn<int> mittagPct = GeneratedColumn<int>(
    'mittag_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abendPctMeta = const VerificationMeta(
    'abendPct',
  );
  @override
  late final GeneratedColumn<int> abendPct = GeneratedColumn<int>(
    'abend_pct',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    abTag,
    fruehstueckPct,
    mittagPct,
    abendPct,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'mahlzeit_aufteilungen';
  @override
  VerificationContext validateIntegrity(
    Insertable<MahlzeitAufteilungRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('ab_tag')) {
      context.handle(
        _abTagMeta,
        abTag.isAcceptableOrUnknown(data['ab_tag']!, _abTagMeta),
      );
    } else if (isInserting) {
      context.missing(_abTagMeta);
    }
    if (data.containsKey('fruehstueck_pct')) {
      context.handle(
        _fruehstueckPctMeta,
        fruehstueckPct.isAcceptableOrUnknown(
          data['fruehstueck_pct']!,
          _fruehstueckPctMeta,
        ),
      );
    }
    if (data.containsKey('mittag_pct')) {
      context.handle(
        _mittagPctMeta,
        mittagPct.isAcceptableOrUnknown(data['mittag_pct']!, _mittagPctMeta),
      );
    }
    if (data.containsKey('abend_pct')) {
      context.handle(
        _abendPctMeta,
        abendPct.isAcceptableOrUnknown(data['abend_pct']!, _abendPctMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {abTag};
  @override
  MahlzeitAufteilungRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MahlzeitAufteilungRow(
      abTag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ab_tag'],
      )!,
      fruehstueckPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fruehstueck_pct'],
      ),
      mittagPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}mittag_pct'],
      ),
      abendPct: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}abend_pct'],
      ),
    );
  }

  @override
  $MahlzeitAufteilungenTable createAlias(String alias) {
    return $MahlzeitAufteilungenTable(attachedDatabase, alias);
  }
}

class MahlzeitAufteilungRow extends DataClass
    implements Insertable<MahlzeitAufteilungRow> {
  /// Der Berliner Kalendertag, ab dem die Aufteilung gilt, als
  /// ISO-Tagesschlüssel. **Der Primärschlüssel**: Je Tag gilt höchstens
  /// eine, ein zweites Sichern am selben Tag ersetzt die Zeile (V2).
  /// `ab_tag <= ?` vergleicht lexikografisch richtig.
  final String abTag;

  /// Der Anteil des Frühstücks in ganzen Prozent.
  ///
  /// Alle drei Prozentspalten sind **nullbar und ohne Vorgabewert** (V1).
  /// Eine Vorgabe behauptete eine Einstellung, die niemand gemacht hat.
  /// Nullbar auch deshalb, weil `_reconcileSchema` eine fehlende
  /// `NOT NULL`-Spalte ohne Vorgabe nicht in eine Tabelle mit Zeilen
  /// nachziehen kann — eine solche Spalte wäre auf einem Gerät mit fremdem
  /// Zwischenstand nicht zu reparieren.
  final int? fruehstueckPct;

  /// Der Anteil des Mittagessens in ganzen Prozent; siehe [fruehstueckPct].
  final int? mittagPct;

  /// Der Anteil des Abendessens in ganzen Prozent; siehe [fruehstueckPct].
  final int? abendPct;
  const MahlzeitAufteilungRow({
    required this.abTag,
    this.fruehstueckPct,
    this.mittagPct,
    this.abendPct,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['ab_tag'] = Variable<String>(abTag);
    if (!nullToAbsent || fruehstueckPct != null) {
      map['fruehstueck_pct'] = Variable<int>(fruehstueckPct);
    }
    if (!nullToAbsent || mittagPct != null) {
      map['mittag_pct'] = Variable<int>(mittagPct);
    }
    if (!nullToAbsent || abendPct != null) {
      map['abend_pct'] = Variable<int>(abendPct);
    }
    return map;
  }

  MahlzeitAufteilungenCompanion toCompanion(bool nullToAbsent) {
    return MahlzeitAufteilungenCompanion(
      abTag: Value(abTag),
      fruehstueckPct: fruehstueckPct == null && nullToAbsent
          ? const Value.absent()
          : Value(fruehstueckPct),
      mittagPct: mittagPct == null && nullToAbsent
          ? const Value.absent()
          : Value(mittagPct),
      abendPct: abendPct == null && nullToAbsent
          ? const Value.absent()
          : Value(abendPct),
    );
  }

  factory MahlzeitAufteilungRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MahlzeitAufteilungRow(
      abTag: serializer.fromJson<String>(json['abTag']),
      fruehstueckPct: serializer.fromJson<int?>(json['fruehstueckPct']),
      mittagPct: serializer.fromJson<int?>(json['mittagPct']),
      abendPct: serializer.fromJson<int?>(json['abendPct']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'abTag': serializer.toJson<String>(abTag),
      'fruehstueckPct': serializer.toJson<int?>(fruehstueckPct),
      'mittagPct': serializer.toJson<int?>(mittagPct),
      'abendPct': serializer.toJson<int?>(abendPct),
    };
  }

  MahlzeitAufteilungRow copyWith({
    String? abTag,
    Value<int?> fruehstueckPct = const Value.absent(),
    Value<int?> mittagPct = const Value.absent(),
    Value<int?> abendPct = const Value.absent(),
  }) => MahlzeitAufteilungRow(
    abTag: abTag ?? this.abTag,
    fruehstueckPct: fruehstueckPct.present
        ? fruehstueckPct.value
        : this.fruehstueckPct,
    mittagPct: mittagPct.present ? mittagPct.value : this.mittagPct,
    abendPct: abendPct.present ? abendPct.value : this.abendPct,
  );
  MahlzeitAufteilungRow copyWithCompanion(MahlzeitAufteilungenCompanion data) {
    return MahlzeitAufteilungRow(
      abTag: data.abTag.present ? data.abTag.value : this.abTag,
      fruehstueckPct: data.fruehstueckPct.present
          ? data.fruehstueckPct.value
          : this.fruehstueckPct,
      mittagPct: data.mittagPct.present ? data.mittagPct.value : this.mittagPct,
      abendPct: data.abendPct.present ? data.abendPct.value : this.abendPct,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MahlzeitAufteilungRow(')
          ..write('abTag: $abTag, ')
          ..write('fruehstueckPct: $fruehstueckPct, ')
          ..write('mittagPct: $mittagPct, ')
          ..write('abendPct: $abendPct')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(abTag, fruehstueckPct, mittagPct, abendPct);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MahlzeitAufteilungRow &&
          other.abTag == this.abTag &&
          other.fruehstueckPct == this.fruehstueckPct &&
          other.mittagPct == this.mittagPct &&
          other.abendPct == this.abendPct);
}

class MahlzeitAufteilungenCompanion
    extends UpdateCompanion<MahlzeitAufteilungRow> {
  final Value<String> abTag;
  final Value<int?> fruehstueckPct;
  final Value<int?> mittagPct;
  final Value<int?> abendPct;
  final Value<int> rowid;
  const MahlzeitAufteilungenCompanion({
    this.abTag = const Value.absent(),
    this.fruehstueckPct = const Value.absent(),
    this.mittagPct = const Value.absent(),
    this.abendPct = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MahlzeitAufteilungenCompanion.insert({
    required String abTag,
    this.fruehstueckPct = const Value.absent(),
    this.mittagPct = const Value.absent(),
    this.abendPct = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : abTag = Value(abTag);
  static Insertable<MahlzeitAufteilungRow> custom({
    Expression<String>? abTag,
    Expression<int>? fruehstueckPct,
    Expression<int>? mittagPct,
    Expression<int>? abendPct,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (abTag != null) 'ab_tag': abTag,
      if (fruehstueckPct != null) 'fruehstueck_pct': fruehstueckPct,
      if (mittagPct != null) 'mittag_pct': mittagPct,
      if (abendPct != null) 'abend_pct': abendPct,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MahlzeitAufteilungenCompanion copyWith({
    Value<String>? abTag,
    Value<int?>? fruehstueckPct,
    Value<int?>? mittagPct,
    Value<int?>? abendPct,
    Value<int>? rowid,
  }) {
    return MahlzeitAufteilungenCompanion(
      abTag: abTag ?? this.abTag,
      fruehstueckPct: fruehstueckPct ?? this.fruehstueckPct,
      mittagPct: mittagPct ?? this.mittagPct,
      abendPct: abendPct ?? this.abendPct,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (abTag.present) {
      map['ab_tag'] = Variable<String>(abTag.value);
    }
    if (fruehstueckPct.present) {
      map['fruehstueck_pct'] = Variable<int>(fruehstueckPct.value);
    }
    if (mittagPct.present) {
      map['mittag_pct'] = Variable<int>(mittagPct.value);
    }
    if (abendPct.present) {
      map['abend_pct'] = Variable<int>(abendPct.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MahlzeitAufteilungenCompanion(')
          ..write('abTag: $abTag, ')
          ..write('fruehstueckPct: $fruehstueckPct, ')
          ..write('mittagPct: $mittagPct, ')
          ..write('abendPct: $abendPct, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $EreignisseTable extends Ereignisse
    with TableInfo<$EreignisseTable, EreignisRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EreignisseTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _artMeta = const VerificationMeta('art');
  @override
  late final GeneratedColumn<String> art = GeneratedColumn<String>(
    'art',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _vonMeta = const VerificationMeta('von');
  @override
  late final GeneratedColumn<String> von = GeneratedColumn<String>(
    'von',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bisMeta = const VerificationMeta('bis');
  @override
  late final GeneratedColumn<String> bis = GeneratedColumn<String>(
    'bis',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _angelegtMeta = const VerificationMeta(
    'angelegt',
  );
  @override
  late final GeneratedColumn<DateTime> angelegt = GeneratedColumn<DateTime>(
    'angelegt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _geaendertMeta = const VerificationMeta(
    'geaendert',
  );
  @override
  late final GeneratedColumn<DateTime> geaendert = GeneratedColumn<DateTime>(
    'geaendert',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    art,
    von,
    bis,
    notiz,
    angelegt,
    geaendert,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ereignisse';
  @override
  VerificationContext validateIntegrity(
    Insertable<EreignisRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('art')) {
      context.handle(
        _artMeta,
        art.isAcceptableOrUnknown(data['art']!, _artMeta),
      );
    } else if (isInserting) {
      context.missing(_artMeta);
    }
    if (data.containsKey('von')) {
      context.handle(
        _vonMeta,
        von.isAcceptableOrUnknown(data['von']!, _vonMeta),
      );
    } else if (isInserting) {
      context.missing(_vonMeta);
    }
    if (data.containsKey('bis')) {
      context.handle(
        _bisMeta,
        bis.isAcceptableOrUnknown(data['bis']!, _bisMeta),
      );
    } else if (isInserting) {
      context.missing(_bisMeta);
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    if (data.containsKey('angelegt')) {
      context.handle(
        _angelegtMeta,
        angelegt.isAcceptableOrUnknown(data['angelegt']!, _angelegtMeta),
      );
    } else if (isInserting) {
      context.missing(_angelegtMeta);
    }
    if (data.containsKey('geaendert')) {
      context.handle(
        _geaendertMeta,
        geaendert.isAcceptableOrUnknown(data['geaendert']!, _geaendertMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  EreignisRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return EreignisRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      art: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art'],
      )!,
      von: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}von'],
      )!,
      bis: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bis'],
      )!,
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
      angelegt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}angelegt'],
      )!,
      geaendert: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geaendert'],
      ),
    );
  }

  @override
  $EreignisseTable createAlias(String alias) {
    return $EreignisseTable(attachedDatabase, alias);
  }
}

class EreignisRow extends DataClass implements Insertable<EreignisRow> {
  /// Fortlaufende Nummer. `AUTOINCREMENT`, damit eine gelöschte Nummer nie
  /// wieder vergeben wird: Bei gleichem `bis` nennt die Herleitung die
  /// zuletzt angelegte Auszeit, erkannt an der höchsten `id` (V3).
  final int id;

  /// Der Name aus `EreignisArt` (`op`, `krankheit`, `verletzung`,
  /// `urlaub`). **Ohne `CHECK`:** Eine spätere Fassung schreibt `spieltag`
  /// (#389); unbekannte Werte übergeht das Lesen, nicht die Tabelle (V20).
  final String art;

  /// Der erste Tag, als ISO-Tagesschlüssel. Ein Tag ist eine
  /// Kalenderangabe, kein Zeitpunkt; `WHERE von <= ? AND bis >= ?`
  /// vergleicht lexikografisch richtig.
  final String von;

  /// Der letzte Tag, einschließlich, als ISO-Tagesschlüssel. Dass er nicht
  /// vor [von] liegt, sichert das Formular (V5), nicht die Tabelle.
  final String bis;

  /// Freitext, `NULL`, wenn keiner eingetragen ist.
  final String? notiz;

  /// Wann die Zeile angelegt wurde, UTC, als Text (`storeDateTimeAsText`).
  final DateTime angelegt;

  /// Wann die Zeile zuletzt geändert wurde, UTC. **`NULL` bis zur ersten
  /// Änderung** — ein Zeitstempel beim Anlegen behauptete eine Änderung,
  /// die es nie gab.
  final DateTime? geaendert;
  const EreignisRow({
    required this.id,
    required this.art,
    required this.von,
    required this.bis,
    this.notiz,
    required this.angelegt,
    this.geaendert,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['art'] = Variable<String>(art);
    map['von'] = Variable<String>(von);
    map['bis'] = Variable<String>(bis);
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    map['angelegt'] = Variable<DateTime>(angelegt);
    if (!nullToAbsent || geaendert != null) {
      map['geaendert'] = Variable<DateTime>(geaendert);
    }
    return map;
  }

  EreignisseCompanion toCompanion(bool nullToAbsent) {
    return EreignisseCompanion(
      id: Value(id),
      art: Value(art),
      von: Value(von),
      bis: Value(bis),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
      angelegt: Value(angelegt),
      geaendert: geaendert == null && nullToAbsent
          ? const Value.absent()
          : Value(geaendert),
    );
  }

  factory EreignisRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return EreignisRow(
      id: serializer.fromJson<int>(json['id']),
      art: serializer.fromJson<String>(json['art']),
      von: serializer.fromJson<String>(json['von']),
      bis: serializer.fromJson<String>(json['bis']),
      notiz: serializer.fromJson<String?>(json['notiz']),
      angelegt: serializer.fromJson<DateTime>(json['angelegt']),
      geaendert: serializer.fromJson<DateTime?>(json['geaendert']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'art': serializer.toJson<String>(art),
      'von': serializer.toJson<String>(von),
      'bis': serializer.toJson<String>(bis),
      'notiz': serializer.toJson<String?>(notiz),
      'angelegt': serializer.toJson<DateTime>(angelegt),
      'geaendert': serializer.toJson<DateTime?>(geaendert),
    };
  }

  EreignisRow copyWith({
    int? id,
    String? art,
    String? von,
    String? bis,
    Value<String?> notiz = const Value.absent(),
    DateTime? angelegt,
    Value<DateTime?> geaendert = const Value.absent(),
  }) => EreignisRow(
    id: id ?? this.id,
    art: art ?? this.art,
    von: von ?? this.von,
    bis: bis ?? this.bis,
    notiz: notiz.present ? notiz.value : this.notiz,
    angelegt: angelegt ?? this.angelegt,
    geaendert: geaendert.present ? geaendert.value : this.geaendert,
  );
  EreignisRow copyWithCompanion(EreignisseCompanion data) {
    return EreignisRow(
      id: data.id.present ? data.id.value : this.id,
      art: data.art.present ? data.art.value : this.art,
      von: data.von.present ? data.von.value : this.von,
      bis: data.bis.present ? data.bis.value : this.bis,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
      angelegt: data.angelegt.present ? data.angelegt.value : this.angelegt,
      geaendert: data.geaendert.present ? data.geaendert.value : this.geaendert,
    );
  }

  @override
  String toString() {
    return (StringBuffer('EreignisRow(')
          ..write('id: $id, ')
          ..write('art: $art, ')
          ..write('von: $von, ')
          ..write('bis: $bis, ')
          ..write('notiz: $notiz, ')
          ..write('angelegt: $angelegt, ')
          ..write('geaendert: $geaendert')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, art, von, bis, notiz, angelegt, geaendert);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EreignisRow &&
          other.id == this.id &&
          other.art == this.art &&
          other.von == this.von &&
          other.bis == this.bis &&
          other.notiz == this.notiz &&
          other.angelegt == this.angelegt &&
          other.geaendert == this.geaendert);
}

class EreignisseCompanion extends UpdateCompanion<EreignisRow> {
  final Value<int> id;
  final Value<String> art;
  final Value<String> von;
  final Value<String> bis;
  final Value<String?> notiz;
  final Value<DateTime> angelegt;
  final Value<DateTime?> geaendert;
  const EreignisseCompanion({
    this.id = const Value.absent(),
    this.art = const Value.absent(),
    this.von = const Value.absent(),
    this.bis = const Value.absent(),
    this.notiz = const Value.absent(),
    this.angelegt = const Value.absent(),
    this.geaendert = const Value.absent(),
  });
  EreignisseCompanion.insert({
    this.id = const Value.absent(),
    required String art,
    required String von,
    required String bis,
    this.notiz = const Value.absent(),
    required DateTime angelegt,
    this.geaendert = const Value.absent(),
  }) : art = Value(art),
       von = Value(von),
       bis = Value(bis),
       angelegt = Value(angelegt);
  static Insertable<EreignisRow> custom({
    Expression<int>? id,
    Expression<String>? art,
    Expression<String>? von,
    Expression<String>? bis,
    Expression<String>? notiz,
    Expression<DateTime>? angelegt,
    Expression<DateTime>? geaendert,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (art != null) 'art': art,
      if (von != null) 'von': von,
      if (bis != null) 'bis': bis,
      if (notiz != null) 'notiz': notiz,
      if (angelegt != null) 'angelegt': angelegt,
      if (geaendert != null) 'geaendert': geaendert,
    });
  }

  EreignisseCompanion copyWith({
    Value<int>? id,
    Value<String>? art,
    Value<String>? von,
    Value<String>? bis,
    Value<String?>? notiz,
    Value<DateTime>? angelegt,
    Value<DateTime?>? geaendert,
  }) {
    return EreignisseCompanion(
      id: id ?? this.id,
      art: art ?? this.art,
      von: von ?? this.von,
      bis: bis ?? this.bis,
      notiz: notiz ?? this.notiz,
      angelegt: angelegt ?? this.angelegt,
      geaendert: geaendert ?? this.geaendert,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (art.present) {
      map['art'] = Variable<String>(art.value);
    }
    if (von.present) {
      map['von'] = Variable<String>(von.value);
    }
    if (bis.present) {
      map['bis'] = Variable<String>(bis.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (angelegt.present) {
      map['angelegt'] = Variable<DateTime>(angelegt.value);
    }
    if (geaendert.present) {
      map['geaendert'] = Variable<DateTime>(geaendert.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EreignisseCompanion(')
          ..write('id: $id, ')
          ..write('art: $art, ')
          ..write('von: $von, ')
          ..write('bis: $bis, ')
          ..write('notiz: $notiz, ')
          ..write('angelegt: $angelegt, ')
          ..write('geaendert: $geaendert')
          ..write(')'))
        .toString();
  }
}

class $WachBelegeTable extends WachBelege
    with TableInfo<$WachBelegeTable, WachBelegRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WachBelegeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _zeitpunktMeta = const VerificationMeta(
    'zeitpunkt',
  );
  @override
  late final GeneratedColumn<DateTime> zeitpunkt = GeneratedColumn<DateTime>(
    'zeitpunkt',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _artMeta = const VerificationMeta('art');
  @override
  late final GeneratedColumn<String> art = GeneratedColumn<String>(
    'art',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, zeitpunkt, art];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wach_belege';
  @override
  VerificationContext validateIntegrity(
    Insertable<WachBelegRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('zeitpunkt')) {
      context.handle(
        _zeitpunktMeta,
        zeitpunkt.isAcceptableOrUnknown(data['zeitpunkt']!, _zeitpunktMeta),
      );
    } else if (isInserting) {
      context.missing(_zeitpunktMeta);
    }
    if (data.containsKey('art')) {
      context.handle(
        _artMeta,
        art.isAcceptableOrUnknown(data['art']!, _artMeta),
      );
    } else if (isInserting) {
      context.missing(_artMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WachBelegRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WachBelegRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      zeitpunkt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}zeitpunkt'],
      )!,
      art: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}art'],
      )!,
    );
  }

  @override
  $WachBelegeTable createAlias(String alias) {
    return $WachBelegeTable(attachedDatabase, alias);
  }
}

class WachBelegRow extends DataClass implements Insertable<WachBelegRow> {
  /// Fortlaufende Nummer.
  final int id;

  /// Wann Tim wach war, UTC, als Text (`storeDateTimeAsText`).
  final DateTime zeitpunkt;

  /// Der Name aus `WachArt` (`oeffnen`, `buchung`, V13). **Ohne `CHECK`
  /// und ohne Vorgabe:** Unbekannte Werte übergeht das Lesen, nicht die
  /// Tabelle.
  final String art;
  const WachBelegRow({
    required this.id,
    required this.zeitpunkt,
    required this.art,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['zeitpunkt'] = Variable<DateTime>(zeitpunkt);
    map['art'] = Variable<String>(art);
    return map;
  }

  WachBelegeCompanion toCompanion(bool nullToAbsent) {
    return WachBelegeCompanion(
      id: Value(id),
      zeitpunkt: Value(zeitpunkt),
      art: Value(art),
    );
  }

  factory WachBelegRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WachBelegRow(
      id: serializer.fromJson<int>(json['id']),
      zeitpunkt: serializer.fromJson<DateTime>(json['zeitpunkt']),
      art: serializer.fromJson<String>(json['art']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'zeitpunkt': serializer.toJson<DateTime>(zeitpunkt),
      'art': serializer.toJson<String>(art),
    };
  }

  WachBelegRow copyWith({int? id, DateTime? zeitpunkt, String? art}) =>
      WachBelegRow(
        id: id ?? this.id,
        zeitpunkt: zeitpunkt ?? this.zeitpunkt,
        art: art ?? this.art,
      );
  WachBelegRow copyWithCompanion(WachBelegeCompanion data) {
    return WachBelegRow(
      id: data.id.present ? data.id.value : this.id,
      zeitpunkt: data.zeitpunkt.present ? data.zeitpunkt.value : this.zeitpunkt,
      art: data.art.present ? data.art.value : this.art,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WachBelegRow(')
          ..write('id: $id, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('art: $art')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, zeitpunkt, art);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WachBelegRow &&
          other.id == this.id &&
          other.zeitpunkt == this.zeitpunkt &&
          other.art == this.art);
}

class WachBelegeCompanion extends UpdateCompanion<WachBelegRow> {
  final Value<int> id;
  final Value<DateTime> zeitpunkt;
  final Value<String> art;
  const WachBelegeCompanion({
    this.id = const Value.absent(),
    this.zeitpunkt = const Value.absent(),
    this.art = const Value.absent(),
  });
  WachBelegeCompanion.insert({
    this.id = const Value.absent(),
    required DateTime zeitpunkt,
    required String art,
  }) : zeitpunkt = Value(zeitpunkt),
       art = Value(art);
  static Insertable<WachBelegRow> custom({
    Expression<int>? id,
    Expression<DateTime>? zeitpunkt,
    Expression<String>? art,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (zeitpunkt != null) 'zeitpunkt': zeitpunkt,
      if (art != null) 'art': art,
    });
  }

  WachBelegeCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? zeitpunkt,
    Value<String>? art,
  }) {
    return WachBelegeCompanion(
      id: id ?? this.id,
      zeitpunkt: zeitpunkt ?? this.zeitpunkt,
      art: art ?? this.art,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (zeitpunkt.present) {
      map['zeitpunkt'] = Variable<DateTime>(zeitpunkt.value);
    }
    if (art.present) {
      map['art'] = Variable<String>(art.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WachBelegeCompanion(')
          ..write('id: $id, ')
          ..write('zeitpunkt: $zeitpunkt, ')
          ..write('art: $art')
          ..write(')'))
        .toString();
  }
}

class $UmfaengeTable extends Umfaenge
    with TableInfo<$UmfaengeTable, UmfangRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UmfaengeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _massMeta = const VerificationMeta('mass');
  @override
  late final GeneratedColumn<String> mass = GeneratedColumn<String>(
    'mass',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _zentimeterMeta = const VerificationMeta(
    'zentimeter',
  );
  @override
  late final GeneratedColumn<double> zentimeter = GeneratedColumn<double>(
    'zentimeter',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eingetragenAmMeta = const VerificationMeta(
    'eingetragenAm',
  );
  @override
  late final GeneratedColumn<DateTime> eingetragenAm =
      GeneratedColumn<DateTime>(
        'eingetragen_am',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _quelleMeta = const VerificationMeta('quelle');
  @override
  late final GeneratedColumn<String> quelle = GeneratedColumn<String>(
    'quelle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    mass,
    zentimeter,
    eingetragenAm,
    quelle,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'umfaenge';
  @override
  VerificationContext validateIntegrity(
    Insertable<UmfangRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('mass')) {
      context.handle(
        _massMeta,
        mass.isAcceptableOrUnknown(data['mass']!, _massMeta),
      );
    } else if (isInserting) {
      context.missing(_massMeta);
    }
    if (data.containsKey('zentimeter')) {
      context.handle(
        _zentimeterMeta,
        zentimeter.isAcceptableOrUnknown(data['zentimeter']!, _zentimeterMeta),
      );
    } else if (isInserting) {
      context.missing(_zentimeterMeta);
    }
    if (data.containsKey('eingetragen_am')) {
      context.handle(
        _eingetragenAmMeta,
        eingetragenAm.isAcceptableOrUnknown(
          data['eingetragen_am']!,
          _eingetragenAmMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_eingetragenAmMeta);
    }
    if (data.containsKey('quelle')) {
      context.handle(
        _quelleMeta,
        quelle.isAcceptableOrUnknown(data['quelle']!, _quelleMeta),
      );
    } else if (isInserting) {
      context.missing(_quelleMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag, mass, quelle};
  @override
  UmfangRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UmfangRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      mass: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mass'],
      )!,
      zentimeter: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}zentimeter'],
      )!,
      eingetragenAm: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}eingetragen_am'],
      )!,
      quelle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quelle'],
      )!,
    );
  }

  @override
  $UmfaengeTable createAlias(String alias) {
    return $UmfaengeTable(attachedDatabase, alias);
  }
}

class UmfangRow extends DataClass implements Insertable<UmfangRow> {
  /// Der Tag der Messung als ISO-Tagesstring aus `BerlinCalendar.dayKey`
  /// (`YYYY-MM-DD`), kein Zeitpunkt und keine Epoch-Zahl — derselbe
  /// Schlüsseltyp wie [TagesWerte.tag]. Ein Tag ist eine Kalenderangabe:
  /// So vergleicht `WHERE tag >= ?` lexikografisch richtig und übersteht
  /// jede Zeitumstellung.
  final String tag;

  /// Der stabile Schlüssel des Maßes (Bauch, Brust, Oberarm links …), nicht
  /// seine Beschriftung. Die deutschen Namen stehen in der Ansicht; ein
  /// umbenanntes Maß darf die abgelegten Messungen nicht verwaisen lassen.
  final String mass;

  /// Der gemessene Umfang in Zentimetern.
  ///
  /// **`RealColumn` und Pflicht.** Ein Umfang ist eine Kommazahl: 41,4 cm
  /// sind nicht 41 cm, und die Totzone des Fortschritts rechnet mit 0,2 cm
  /// — sie kann nichts entscheiden, wenn die Ablage rundet. Ein fehlendes
  /// Maß ist keine Zeile; es wird weder als `NULL`-Zeile noch als `0`
  /// abgelegt, denn `0` behauptete einen gemessenen Umfang von null
  /// Zentimetern (`CLAUDE.md`, „`0` ist keine Antwort auf ‚kein Wert'").
  final double zentimeter;

  /// Wann die Messung eingetragen wurde, UTC, als Text
  /// (`storeDateTimeAsText`). Driftets Standard (Unix-Sekunden) gäbe den
  /// Zeitpunkt als Ortszeit zurück, und der wäre dann ungleich sich selbst.
  final DateTime eingetragenAm;

  /// Woher der Wert stammt: `getippt` oder `import`.
  ///
  /// **Die Quelle gehört in den Schlüssel.** Stünde sie nicht darin,
  /// überschriebe der Import beim nächsten Lauf den getippten Wert, und das
  /// Zusammenführen hätte nichts mehr zu entscheiden. Es passiert beim
  /// **Lesen**, nicht beim Schreiben — und dafür müssen beide Zeilen
  /// nebeneinander liegen bleiben.
  final String quelle;
  const UmfangRow({
    required this.tag,
    required this.mass,
    required this.zentimeter,
    required this.eingetragenAm,
    required this.quelle,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    map['mass'] = Variable<String>(mass);
    map['zentimeter'] = Variable<double>(zentimeter);
    map['eingetragen_am'] = Variable<DateTime>(eingetragenAm);
    map['quelle'] = Variable<String>(quelle);
    return map;
  }

  UmfaengeCompanion toCompanion(bool nullToAbsent) {
    return UmfaengeCompanion(
      tag: Value(tag),
      mass: Value(mass),
      zentimeter: Value(zentimeter),
      eingetragenAm: Value(eingetragenAm),
      quelle: Value(quelle),
    );
  }

  factory UmfangRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UmfangRow(
      tag: serializer.fromJson<String>(json['tag']),
      mass: serializer.fromJson<String>(json['mass']),
      zentimeter: serializer.fromJson<double>(json['zentimeter']),
      eingetragenAm: serializer.fromJson<DateTime>(json['eingetragenAm']),
      quelle: serializer.fromJson<String>(json['quelle']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'mass': serializer.toJson<String>(mass),
      'zentimeter': serializer.toJson<double>(zentimeter),
      'eingetragenAm': serializer.toJson<DateTime>(eingetragenAm),
      'quelle': serializer.toJson<String>(quelle),
    };
  }

  UmfangRow copyWith({
    String? tag,
    String? mass,
    double? zentimeter,
    DateTime? eingetragenAm,
    String? quelle,
  }) => UmfangRow(
    tag: tag ?? this.tag,
    mass: mass ?? this.mass,
    zentimeter: zentimeter ?? this.zentimeter,
    eingetragenAm: eingetragenAm ?? this.eingetragenAm,
    quelle: quelle ?? this.quelle,
  );
  UmfangRow copyWithCompanion(UmfaengeCompanion data) {
    return UmfangRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      mass: data.mass.present ? data.mass.value : this.mass,
      zentimeter: data.zentimeter.present
          ? data.zentimeter.value
          : this.zentimeter,
      eingetragenAm: data.eingetragenAm.present
          ? data.eingetragenAm.value
          : this.eingetragenAm,
      quelle: data.quelle.present ? data.quelle.value : this.quelle,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UmfangRow(')
          ..write('tag: $tag, ')
          ..write('mass: $mass, ')
          ..write('zentimeter: $zentimeter, ')
          ..write('eingetragenAm: $eingetragenAm, ')
          ..write('quelle: $quelle')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(tag, mass, zentimeter, eingetragenAm, quelle);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UmfangRow &&
          other.tag == this.tag &&
          other.mass == this.mass &&
          other.zentimeter == this.zentimeter &&
          other.eingetragenAm == this.eingetragenAm &&
          other.quelle == this.quelle);
}

class UmfaengeCompanion extends UpdateCompanion<UmfangRow> {
  final Value<String> tag;
  final Value<String> mass;
  final Value<double> zentimeter;
  final Value<DateTime> eingetragenAm;
  final Value<String> quelle;
  final Value<int> rowid;
  const UmfaengeCompanion({
    this.tag = const Value.absent(),
    this.mass = const Value.absent(),
    this.zentimeter = const Value.absent(),
    this.eingetragenAm = const Value.absent(),
    this.quelle = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UmfaengeCompanion.insert({
    required String tag,
    required String mass,
    required double zentimeter,
    required DateTime eingetragenAm,
    required String quelle,
    this.rowid = const Value.absent(),
  }) : tag = Value(tag),
       mass = Value(mass),
       zentimeter = Value(zentimeter),
       eingetragenAm = Value(eingetragenAm),
       quelle = Value(quelle);
  static Insertable<UmfangRow> custom({
    Expression<String>? tag,
    Expression<String>? mass,
    Expression<double>? zentimeter,
    Expression<DateTime>? eingetragenAm,
    Expression<String>? quelle,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (mass != null) 'mass': mass,
      if (zentimeter != null) 'zentimeter': zentimeter,
      if (eingetragenAm != null) 'eingetragen_am': eingetragenAm,
      if (quelle != null) 'quelle': quelle,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UmfaengeCompanion copyWith({
    Value<String>? tag,
    Value<String>? mass,
    Value<double>? zentimeter,
    Value<DateTime>? eingetragenAm,
    Value<String>? quelle,
    Value<int>? rowid,
  }) {
    return UmfaengeCompanion(
      tag: tag ?? this.tag,
      mass: mass ?? this.mass,
      zentimeter: zentimeter ?? this.zentimeter,
      eingetragenAm: eingetragenAm ?? this.eingetragenAm,
      quelle: quelle ?? this.quelle,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (mass.present) {
      map['mass'] = Variable<String>(mass.value);
    }
    if (zentimeter.present) {
      map['zentimeter'] = Variable<double>(zentimeter.value);
    }
    if (eingetragenAm.present) {
      map['eingetragen_am'] = Variable<DateTime>(eingetragenAm.value);
    }
    if (quelle.present) {
      map['quelle'] = Variable<String>(quelle.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UmfaengeCompanion(')
          ..write('tag: $tag, ')
          ..write('mass: $mass, ')
          ..write('zentimeter: $zentimeter, ')
          ..write('eingetragenAm: $eingetragenAm, ')
          ..write('quelle: $quelle, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZyklusEintraegeTable extends ZyklusEintraege
    with TableInfo<$ZyklusEintraegeTable, ZyklusEintragRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZyklusEintraegeTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _blutungMeta = const VerificationMeta(
    'blutung',
  );
  @override
  late final GeneratedColumn<String> blutung = GeneratedColumn<String>(
    'blutung',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _zwischenblutungMeta = const VerificationMeta(
    'zwischenblutung',
  );
  @override
  late final GeneratedColumn<bool> zwischenblutung = GeneratedColumn<bool>(
    'zwischenblutung',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("zwischenblutung" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _schmerzMeta = const VerificationMeta(
    'schmerz',
  );
  @override
  late final GeneratedColumn<String> schmerz = GeneratedColumn<String>(
    'schmerz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _symptomeMeta = const VerificationMeta(
    'symptome',
  );
  @override
  late final GeneratedColumn<String> symptome = GeneratedColumn<String>(
    'symptome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sexMeta = const VerificationMeta('sex');
  @override
  late final GeneratedColumn<bool> sex = GeneratedColumn<bool>(
    'sex',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sex" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _verhuetetMeta = const VerificationMeta(
    'verhuetet',
  );
  @override
  late final GeneratedColumn<bool> verhuetet = GeneratedColumn<bool>(
    'verhuetet',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verhuetet" IN (0, 1))',
    ),
  );
  static const VerificationMeta _testMeta = const VerificationMeta('test');
  @override
  late final GeneratedColumn<String> test = GeneratedColumn<String>(
    'test',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notizMeta = const VerificationMeta('notiz');
  @override
  late final GeneratedColumn<String> notiz = GeneratedColumn<String>(
    'notiz',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _quelleMeta = const VerificationMeta('quelle');
  @override
  late final GeneratedColumn<String> quelle = GeneratedColumn<String>(
    'quelle',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('eigen'),
  );
  static const VerificationMeta _geaendertMeta = const VerificationMeta(
    'geaendert',
  );
  @override
  late final GeneratedColumn<DateTime> geaendert = GeneratedColumn<DateTime>(
    'geaendert',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    tag,
    blutung,
    zwischenblutung,
    schmerz,
    symptome,
    sex,
    verhuetet,
    test,
    notiz,
    quelle,
    geaendert,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zyklus_eintraege';
  @override
  VerificationContext validateIntegrity(
    Insertable<ZyklusEintragRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('blutung')) {
      context.handle(
        _blutungMeta,
        blutung.isAcceptableOrUnknown(data['blutung']!, _blutungMeta),
      );
    }
    if (data.containsKey('zwischenblutung')) {
      context.handle(
        _zwischenblutungMeta,
        zwischenblutung.isAcceptableOrUnknown(
          data['zwischenblutung']!,
          _zwischenblutungMeta,
        ),
      );
    }
    if (data.containsKey('schmerz')) {
      context.handle(
        _schmerzMeta,
        schmerz.isAcceptableOrUnknown(data['schmerz']!, _schmerzMeta),
      );
    }
    if (data.containsKey('symptome')) {
      context.handle(
        _symptomeMeta,
        symptome.isAcceptableOrUnknown(data['symptome']!, _symptomeMeta),
      );
    }
    if (data.containsKey('sex')) {
      context.handle(
        _sexMeta,
        sex.isAcceptableOrUnknown(data['sex']!, _sexMeta),
      );
    }
    if (data.containsKey('verhuetet')) {
      context.handle(
        _verhuetetMeta,
        verhuetet.isAcceptableOrUnknown(data['verhuetet']!, _verhuetetMeta),
      );
    }
    if (data.containsKey('test')) {
      context.handle(
        _testMeta,
        test.isAcceptableOrUnknown(data['test']!, _testMeta),
      );
    }
    if (data.containsKey('notiz')) {
      context.handle(
        _notizMeta,
        notiz.isAcceptableOrUnknown(data['notiz']!, _notizMeta),
      );
    }
    if (data.containsKey('quelle')) {
      context.handle(
        _quelleMeta,
        quelle.isAcceptableOrUnknown(data['quelle']!, _quelleMeta),
      );
    }
    if (data.containsKey('geaendert')) {
      context.handle(
        _geaendertMeta,
        geaendert.isAcceptableOrUnknown(data['geaendert']!, _geaendertMeta),
      );
    } else if (isInserting) {
      context.missing(_geaendertMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {tag};
  @override
  ZyklusEintragRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZyklusEintragRow(
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      blutung: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}blutung'],
      ),
      zwischenblutung: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}zwischenblutung'],
      )!,
      schmerz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}schmerz'],
      ),
      symptome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}symptome'],
      )!,
      sex: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sex'],
      )!,
      verhuetet: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verhuetet'],
      ),
      test: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}test'],
      ),
      notiz: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notiz'],
      ),
      quelle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quelle'],
      )!,
      geaendert: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}geaendert'],
      )!,
    );
  }

  @override
  $ZyklusEintraegeTable createAlias(String alias) {
    return $ZyklusEintraegeTable(attachedDatabase, alias);
  }
}

class ZyklusEintragRow extends DataClass
    implements Insertable<ZyklusEintragRow> {
  /// Der Tag als ISO-Tagesstring (`YYYY-MM-DD`), kein Zeitpunkt und keine
  /// Epoch-Zahl. Ein Tag ist eine Kalenderangabe: So vergleicht
  /// `WHERE tag >= ?` lexikografisch richtig und übersteht jede
  /// Zeitumstellung.
  final String tag;

  /// Der Name aus `Blutungsstaerke` (`leicht`, `mittel`, `stark`),
  /// `NULL`, wenn an diesem Tag keine Blutung eingetragen ist.
  ///
  /// **Ohne `CHECK`:** Eine spätere Fassung schreibt vielleicht eine
  /// vierte Stufe, und eine ältere soll die Datei trotzdem öffnen.
  /// Unbekannte Werte übergeht das **Lesen**, nicht die Tabelle — dieselbe
  /// Regel wie bei `ereignisse.art` (V20).
  ///
  /// **`NULL` und nicht `0` oder „keine":** `0` ist keine Antwort auf
  /// „kein Wert" (`CLAUDE.md`).
  final String? blutung;

  /// Eine Zwischenblutung — ein eigenes Feld und kein Blutungstag
  /// (Spec 1), damit sie nicht in die Periodenerkennung einfließt.
  final bool zwischenblutung;

  /// Der Name aus `Schmerzstaerke` (`leicht`, `mittel`, `stark`),
  /// `NULL`, wenn kein Schmerz eingetragen ist. Ohne `CHECK`, siehe
  /// [blutung].
  final String? schmerz;

  /// Die gewählten Symptomschlüssel, kommagetrennt (Spec 4.1). Keine
  /// Symptome heißen **leerer Text**, nicht `NULL`: Es gibt keinen
  /// Unterschied zwischen „keine gewählt" und „nicht gefragt", und zwei
  /// Schreibweisen für dasselbe wären eine Fehlerquelle mehr.
  ///
  /// Die Schlüssel selbst stehen in `lib/zyklus/zyklus_symptome.dart` und
  /// sind Speicherformat — wer einen umbenennt, macht jeden Tag unlesbar,
  /// der ihn trägt.
  final String symptome;

  /// Sex an diesem Tag.
  final bool sex;

  /// Ob verhütet wurde; `NULL`, wenn nichts dazu eingetragen ist. Nur
  /// sinnvoll, wenn [sex] (Spec 4.1) — erzwungen wird das nicht, das
  /// Formular kann den Zustand gar nicht erzeugen.
  final bool? verhuetet;

  /// Der Name aus `Testergebnis` (`positiv`, `negativ`), `NULL`, wenn
  /// kein Test eingetragen ist. Ohne `CHECK`, siehe [blutung].
  final String? test;

  /// Freitext, `NULL`, wenn keiner eingetragen ist.
  final String? notiz;

  /// Der Name aus `ZyklusQuelle` (`eigen` oder `health`). Vorgabe
  /// `eigen`: Ein Tag kommt von der Nutzerin, wenn niemand etwas anderes
  /// sagt — vor dem Erstimport gab es keinen anderen Weg in diese
  /// Tabelle. Ohne `CHECK`, siehe [blutung].
  final String quelle;

  /// Wann die Zeile zuletzt geschrieben wurde, UTC, als Text
  /// (`storeDateTimeAsText`).
  ///
  /// **Pflicht und ohne Vorgabewert.** Ein `CURRENT_TIMESTAMP` erfände den
  /// Zeitpunkt einer Änderung, die niemand gemacht hat — derselbe Fehler
  /// wie eine Migration, die alte Zeilen frisch aussehen lässt. Drifts
  /// Standard (Unix-Sekunden) gäbe den Zeitpunkt als Ortszeit zurück, und
  /// der wäre dann ungleich sich selbst.
  final DateTime geaendert;
  const ZyklusEintragRow({
    required this.tag,
    this.blutung,
    required this.zwischenblutung,
    this.schmerz,
    required this.symptome,
    required this.sex,
    this.verhuetet,
    this.test,
    this.notiz,
    required this.quelle,
    required this.geaendert,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['tag'] = Variable<String>(tag);
    if (!nullToAbsent || blutung != null) {
      map['blutung'] = Variable<String>(blutung);
    }
    map['zwischenblutung'] = Variable<bool>(zwischenblutung);
    if (!nullToAbsent || schmerz != null) {
      map['schmerz'] = Variable<String>(schmerz);
    }
    map['symptome'] = Variable<String>(symptome);
    map['sex'] = Variable<bool>(sex);
    if (!nullToAbsent || verhuetet != null) {
      map['verhuetet'] = Variable<bool>(verhuetet);
    }
    if (!nullToAbsent || test != null) {
      map['test'] = Variable<String>(test);
    }
    if (!nullToAbsent || notiz != null) {
      map['notiz'] = Variable<String>(notiz);
    }
    map['quelle'] = Variable<String>(quelle);
    map['geaendert'] = Variable<DateTime>(geaendert);
    return map;
  }

  ZyklusEintraegeCompanion toCompanion(bool nullToAbsent) {
    return ZyklusEintraegeCompanion(
      tag: Value(tag),
      blutung: blutung == null && nullToAbsent
          ? const Value.absent()
          : Value(blutung),
      zwischenblutung: Value(zwischenblutung),
      schmerz: schmerz == null && nullToAbsent
          ? const Value.absent()
          : Value(schmerz),
      symptome: Value(symptome),
      sex: Value(sex),
      verhuetet: verhuetet == null && nullToAbsent
          ? const Value.absent()
          : Value(verhuetet),
      test: test == null && nullToAbsent ? const Value.absent() : Value(test),
      notiz: notiz == null && nullToAbsent
          ? const Value.absent()
          : Value(notiz),
      quelle: Value(quelle),
      geaendert: Value(geaendert),
    );
  }

  factory ZyklusEintragRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZyklusEintragRow(
      tag: serializer.fromJson<String>(json['tag']),
      blutung: serializer.fromJson<String?>(json['blutung']),
      zwischenblutung: serializer.fromJson<bool>(json['zwischenblutung']),
      schmerz: serializer.fromJson<String?>(json['schmerz']),
      symptome: serializer.fromJson<String>(json['symptome']),
      sex: serializer.fromJson<bool>(json['sex']),
      verhuetet: serializer.fromJson<bool?>(json['verhuetet']),
      test: serializer.fromJson<String?>(json['test']),
      notiz: serializer.fromJson<String?>(json['notiz']),
      quelle: serializer.fromJson<String>(json['quelle']),
      geaendert: serializer.fromJson<DateTime>(json['geaendert']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'tag': serializer.toJson<String>(tag),
      'blutung': serializer.toJson<String?>(blutung),
      'zwischenblutung': serializer.toJson<bool>(zwischenblutung),
      'schmerz': serializer.toJson<String?>(schmerz),
      'symptome': serializer.toJson<String>(symptome),
      'sex': serializer.toJson<bool>(sex),
      'verhuetet': serializer.toJson<bool?>(verhuetet),
      'test': serializer.toJson<String?>(test),
      'notiz': serializer.toJson<String?>(notiz),
      'quelle': serializer.toJson<String>(quelle),
      'geaendert': serializer.toJson<DateTime>(geaendert),
    };
  }

  ZyklusEintragRow copyWith({
    String? tag,
    Value<String?> blutung = const Value.absent(),
    bool? zwischenblutung,
    Value<String?> schmerz = const Value.absent(),
    String? symptome,
    bool? sex,
    Value<bool?> verhuetet = const Value.absent(),
    Value<String?> test = const Value.absent(),
    Value<String?> notiz = const Value.absent(),
    String? quelle,
    DateTime? geaendert,
  }) => ZyklusEintragRow(
    tag: tag ?? this.tag,
    blutung: blutung.present ? blutung.value : this.blutung,
    zwischenblutung: zwischenblutung ?? this.zwischenblutung,
    schmerz: schmerz.present ? schmerz.value : this.schmerz,
    symptome: symptome ?? this.symptome,
    sex: sex ?? this.sex,
    verhuetet: verhuetet.present ? verhuetet.value : this.verhuetet,
    test: test.present ? test.value : this.test,
    notiz: notiz.present ? notiz.value : this.notiz,
    quelle: quelle ?? this.quelle,
    geaendert: geaendert ?? this.geaendert,
  );
  ZyklusEintragRow copyWithCompanion(ZyklusEintraegeCompanion data) {
    return ZyklusEintragRow(
      tag: data.tag.present ? data.tag.value : this.tag,
      blutung: data.blutung.present ? data.blutung.value : this.blutung,
      zwischenblutung: data.zwischenblutung.present
          ? data.zwischenblutung.value
          : this.zwischenblutung,
      schmerz: data.schmerz.present ? data.schmerz.value : this.schmerz,
      symptome: data.symptome.present ? data.symptome.value : this.symptome,
      sex: data.sex.present ? data.sex.value : this.sex,
      verhuetet: data.verhuetet.present ? data.verhuetet.value : this.verhuetet,
      test: data.test.present ? data.test.value : this.test,
      notiz: data.notiz.present ? data.notiz.value : this.notiz,
      quelle: data.quelle.present ? data.quelle.value : this.quelle,
      geaendert: data.geaendert.present ? data.geaendert.value : this.geaendert,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusEintragRow(')
          ..write('tag: $tag, ')
          ..write('blutung: $blutung, ')
          ..write('zwischenblutung: $zwischenblutung, ')
          ..write('schmerz: $schmerz, ')
          ..write('symptome: $symptome, ')
          ..write('sex: $sex, ')
          ..write('verhuetet: $verhuetet, ')
          ..write('test: $test, ')
          ..write('notiz: $notiz, ')
          ..write('quelle: $quelle, ')
          ..write('geaendert: $geaendert')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    tag,
    blutung,
    zwischenblutung,
    schmerz,
    symptome,
    sex,
    verhuetet,
    test,
    notiz,
    quelle,
    geaendert,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZyklusEintragRow &&
          other.tag == this.tag &&
          other.blutung == this.blutung &&
          other.zwischenblutung == this.zwischenblutung &&
          other.schmerz == this.schmerz &&
          other.symptome == this.symptome &&
          other.sex == this.sex &&
          other.verhuetet == this.verhuetet &&
          other.test == this.test &&
          other.notiz == this.notiz &&
          other.quelle == this.quelle &&
          other.geaendert == this.geaendert);
}

class ZyklusEintraegeCompanion extends UpdateCompanion<ZyklusEintragRow> {
  final Value<String> tag;
  final Value<String?> blutung;
  final Value<bool> zwischenblutung;
  final Value<String?> schmerz;
  final Value<String> symptome;
  final Value<bool> sex;
  final Value<bool?> verhuetet;
  final Value<String?> test;
  final Value<String?> notiz;
  final Value<String> quelle;
  final Value<DateTime> geaendert;
  final Value<int> rowid;
  const ZyklusEintraegeCompanion({
    this.tag = const Value.absent(),
    this.blutung = const Value.absent(),
    this.zwischenblutung = const Value.absent(),
    this.schmerz = const Value.absent(),
    this.symptome = const Value.absent(),
    this.sex = const Value.absent(),
    this.verhuetet = const Value.absent(),
    this.test = const Value.absent(),
    this.notiz = const Value.absent(),
    this.quelle = const Value.absent(),
    this.geaendert = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZyklusEintraegeCompanion.insert({
    required String tag,
    this.blutung = const Value.absent(),
    this.zwischenblutung = const Value.absent(),
    this.schmerz = const Value.absent(),
    this.symptome = const Value.absent(),
    this.sex = const Value.absent(),
    this.verhuetet = const Value.absent(),
    this.test = const Value.absent(),
    this.notiz = const Value.absent(),
    this.quelle = const Value.absent(),
    required DateTime geaendert,
    this.rowid = const Value.absent(),
  }) : tag = Value(tag),
       geaendert = Value(geaendert);
  static Insertable<ZyklusEintragRow> custom({
    Expression<String>? tag,
    Expression<String>? blutung,
    Expression<bool>? zwischenblutung,
    Expression<String>? schmerz,
    Expression<String>? symptome,
    Expression<bool>? sex,
    Expression<bool>? verhuetet,
    Expression<String>? test,
    Expression<String>? notiz,
    Expression<String>? quelle,
    Expression<DateTime>? geaendert,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (tag != null) 'tag': tag,
      if (blutung != null) 'blutung': blutung,
      if (zwischenblutung != null) 'zwischenblutung': zwischenblutung,
      if (schmerz != null) 'schmerz': schmerz,
      if (symptome != null) 'symptome': symptome,
      if (sex != null) 'sex': sex,
      if (verhuetet != null) 'verhuetet': verhuetet,
      if (test != null) 'test': test,
      if (notiz != null) 'notiz': notiz,
      if (quelle != null) 'quelle': quelle,
      if (geaendert != null) 'geaendert': geaendert,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZyklusEintraegeCompanion copyWith({
    Value<String>? tag,
    Value<String?>? blutung,
    Value<bool>? zwischenblutung,
    Value<String?>? schmerz,
    Value<String>? symptome,
    Value<bool>? sex,
    Value<bool?>? verhuetet,
    Value<String?>? test,
    Value<String?>? notiz,
    Value<String>? quelle,
    Value<DateTime>? geaendert,
    Value<int>? rowid,
  }) {
    return ZyklusEintraegeCompanion(
      tag: tag ?? this.tag,
      blutung: blutung ?? this.blutung,
      zwischenblutung: zwischenblutung ?? this.zwischenblutung,
      schmerz: schmerz ?? this.schmerz,
      symptome: symptome ?? this.symptome,
      sex: sex ?? this.sex,
      verhuetet: verhuetet ?? this.verhuetet,
      test: test ?? this.test,
      notiz: notiz ?? this.notiz,
      quelle: quelle ?? this.quelle,
      geaendert: geaendert ?? this.geaendert,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (blutung.present) {
      map['blutung'] = Variable<String>(blutung.value);
    }
    if (zwischenblutung.present) {
      map['zwischenblutung'] = Variable<bool>(zwischenblutung.value);
    }
    if (schmerz.present) {
      map['schmerz'] = Variable<String>(schmerz.value);
    }
    if (symptome.present) {
      map['symptome'] = Variable<String>(symptome.value);
    }
    if (sex.present) {
      map['sex'] = Variable<bool>(sex.value);
    }
    if (verhuetet.present) {
      map['verhuetet'] = Variable<bool>(verhuetet.value);
    }
    if (test.present) {
      map['test'] = Variable<String>(test.value);
    }
    if (notiz.present) {
      map['notiz'] = Variable<String>(notiz.value);
    }
    if (quelle.present) {
      map['quelle'] = Variable<String>(quelle.value);
    }
    if (geaendert.present) {
      map['geaendert'] = Variable<DateTime>(geaendert.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusEintraegeCompanion(')
          ..write('tag: $tag, ')
          ..write('blutung: $blutung, ')
          ..write('zwischenblutung: $zwischenblutung, ')
          ..write('schmerz: $schmerz, ')
          ..write('symptome: $symptome, ')
          ..write('sex: $sex, ')
          ..write('verhuetet: $verhuetet, ')
          ..write('test: $test, ')
          ..write('notiz: $notiz, ')
          ..write('quelle: $quelle, ')
          ..write('geaendert: $geaendert, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZyklusHealthSpiegelTable extends ZyklusHealthSpiegel
    with TableInfo<$ZyklusHealthSpiegelTable, ZyklusSpiegelRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZyklusHealthSpiegelTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typMeta = const VerificationMeta('typ');
  @override
  late final GeneratedColumn<String> typ = GeneratedColumn<String>(
    'typ',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uuid, tag, typ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zyklus_health_spiegel';
  @override
  VerificationContext validateIntegrity(
    Insertable<ZyklusSpiegelRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    } else if (isInserting) {
      context.missing(_uuidMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    if (data.containsKey('typ')) {
      context.handle(
        _typMeta,
        typ.isAcceptableOrUnknown(data['typ']!, _typMeta),
      );
    } else if (isInserting) {
      context.missing(_typMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uuid};
  @override
  ZyklusSpiegelRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZyklusSpiegelRow(
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
      typ: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}typ'],
      )!,
    );
  }

  @override
  $ZyklusHealthSpiegelTable createAlias(String alias) {
    return $ZyklusHealthSpiegelTable(attachedDatabase, alias);
  }
}

class ZyklusSpiegelRow extends DataClass
    implements Insertable<ZyklusSpiegelRow> {
  /// Die Sample-UUID aus HealthKit. **Der Schlüssel:** Dasselbe Sample
  /// zweimal zu merken wäre dieselbe Zeile.
  final String uuid;

  /// Der Tag, zu dem das Sample gehört, als ISO-Tagesstring — damit der
  /// Spiegel je Tag abfragbar ist.
  final String tag;

  /// Der HealthKit-Typbezeichner des Samples.
  final String typ;
  const ZyklusSpiegelRow({
    required this.uuid,
    required this.tag,
    required this.typ,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uuid'] = Variable<String>(uuid);
    map['tag'] = Variable<String>(tag);
    map['typ'] = Variable<String>(typ);
    return map;
  }

  ZyklusHealthSpiegelCompanion toCompanion(bool nullToAbsent) {
    return ZyklusHealthSpiegelCompanion(
      uuid: Value(uuid),
      tag: Value(tag),
      typ: Value(typ),
    );
  }

  factory ZyklusSpiegelRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZyklusSpiegelRow(
      uuid: serializer.fromJson<String>(json['uuid']),
      tag: serializer.fromJson<String>(json['tag']),
      typ: serializer.fromJson<String>(json['typ']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uuid': serializer.toJson<String>(uuid),
      'tag': serializer.toJson<String>(tag),
      'typ': serializer.toJson<String>(typ),
    };
  }

  ZyklusSpiegelRow copyWith({String? uuid, String? tag, String? typ}) =>
      ZyklusSpiegelRow(
        uuid: uuid ?? this.uuid,
        tag: tag ?? this.tag,
        typ: typ ?? this.typ,
      );
  ZyklusSpiegelRow copyWithCompanion(ZyklusHealthSpiegelCompanion data) {
    return ZyklusSpiegelRow(
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      tag: data.tag.present ? data.tag.value : this.tag,
      typ: data.typ.present ? data.typ.value : this.typ,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusSpiegelRow(')
          ..write('uuid: $uuid, ')
          ..write('tag: $tag, ')
          ..write('typ: $typ')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uuid, tag, typ);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZyklusSpiegelRow &&
          other.uuid == this.uuid &&
          other.tag == this.tag &&
          other.typ == this.typ);
}

class ZyklusHealthSpiegelCompanion extends UpdateCompanion<ZyklusSpiegelRow> {
  final Value<String> uuid;
  final Value<String> tag;
  final Value<String> typ;
  final Value<int> rowid;
  const ZyklusHealthSpiegelCompanion({
    this.uuid = const Value.absent(),
    this.tag = const Value.absent(),
    this.typ = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ZyklusHealthSpiegelCompanion.insert({
    required String uuid,
    required String tag,
    required String typ,
    this.rowid = const Value.absent(),
  }) : uuid = Value(uuid),
       tag = Value(tag),
       typ = Value(typ);
  static Insertable<ZyklusSpiegelRow> custom({
    Expression<String>? uuid,
    Expression<String>? tag,
    Expression<String>? typ,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uuid != null) 'uuid': uuid,
      if (tag != null) 'tag': tag,
      if (typ != null) 'typ': typ,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ZyklusHealthSpiegelCompanion copyWith({
    Value<String>? uuid,
    Value<String>? tag,
    Value<String>? typ,
    Value<int>? rowid,
  }) {
    return ZyklusHealthSpiegelCompanion(
      uuid: uuid ?? this.uuid,
      tag: tag ?? this.tag,
      typ: typ ?? this.typ,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (typ.present) {
      map['typ'] = Variable<String>(typ.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusHealthSpiegelCompanion(')
          ..write('uuid: $uuid, ')
          ..write('tag: $tag, ')
          ..write('typ: $typ, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ZyklusEinstellungenTable extends ZyklusEinstellungen
    with TableInfo<$ZyklusEinstellungenTable, ZyklusEinstellungenRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZyklusEinstellungenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _kalenderAnMeta = const VerificationMeta(
    'kalenderAn',
  );
  @override
  late final GeneratedColumn<bool> kalenderAn = GeneratedColumn<bool>(
    'kalender_an',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("kalender_an" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sichtMeta = const VerificationMeta('sicht');
  @override
  late final GeneratedColumn<String> sicht = GeneratedColumn<String>(
    'sicht',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('ueberblick'),
  );
  static const VerificationMeta _verhuetungAnMeta = const VerificationMeta(
    'verhuetungAn',
  );
  @override
  late final GeneratedColumn<bool> verhuetungAn = GeneratedColumn<bool>(
    'verhuetung_an',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verhuetung_an" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _verhuetungSeitMeta = const VerificationMeta(
    'verhuetungSeit',
  );
  @override
  late final GeneratedColumn<String> verhuetungSeit = GeneratedColumn<String>(
    'verhuetung_seit',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verhuetungArtMeta = const VerificationMeta(
    'verhuetungArt',
  );
  @override
  late final GeneratedColumn<String> verhuetungArt = GeneratedColumn<String>(
    'verhuetung_art',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _importGelaufenMeta = const VerificationMeta(
    'importGelaufen',
  );
  @override
  late final GeneratedColumn<bool> importGelaufen = GeneratedColumn<bool>(
    'import_gelaufen',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("import_gelaufen" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _vorhersagePausiertMeta =
      const VerificationMeta('vorhersagePausiert');
  @override
  late final GeneratedColumn<bool> vorhersagePausiert = GeneratedColumn<bool>(
    'vorhersage_pausiert',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vorhersage_pausiert" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kalenderAn,
    sicht,
    verhuetungAn,
    verhuetungSeit,
    verhuetungArt,
    importGelaufen,
    vorhersagePausiert,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zyklus_einstellungen';
  @override
  VerificationContext validateIntegrity(
    Insertable<ZyklusEinstellungenRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('kalender_an')) {
      context.handle(
        _kalenderAnMeta,
        kalenderAn.isAcceptableOrUnknown(data['kalender_an']!, _kalenderAnMeta),
      );
    }
    if (data.containsKey('sicht')) {
      context.handle(
        _sichtMeta,
        sicht.isAcceptableOrUnknown(data['sicht']!, _sichtMeta),
      );
    }
    if (data.containsKey('verhuetung_an')) {
      context.handle(
        _verhuetungAnMeta,
        verhuetungAn.isAcceptableOrUnknown(
          data['verhuetung_an']!,
          _verhuetungAnMeta,
        ),
      );
    }
    if (data.containsKey('verhuetung_seit')) {
      context.handle(
        _verhuetungSeitMeta,
        verhuetungSeit.isAcceptableOrUnknown(
          data['verhuetung_seit']!,
          _verhuetungSeitMeta,
        ),
      );
    }
    if (data.containsKey('verhuetung_art')) {
      context.handle(
        _verhuetungArtMeta,
        verhuetungArt.isAcceptableOrUnknown(
          data['verhuetung_art']!,
          _verhuetungArtMeta,
        ),
      );
    }
    if (data.containsKey('import_gelaufen')) {
      context.handle(
        _importGelaufenMeta,
        importGelaufen.isAcceptableOrUnknown(
          data['import_gelaufen']!,
          _importGelaufenMeta,
        ),
      );
    }
    if (data.containsKey('vorhersage_pausiert')) {
      context.handle(
        _vorhersagePausiertMeta,
        vorhersagePausiert.isAcceptableOrUnknown(
          data['vorhersage_pausiert']!,
          _vorhersagePausiertMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ZyklusEinstellungenRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZyklusEinstellungenRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      kalenderAn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}kalender_an'],
      )!,
      sicht: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sicht'],
      )!,
      verhuetungAn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verhuetung_an'],
      )!,
      verhuetungSeit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verhuetung_seit'],
      ),
      verhuetungArt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}verhuetung_art'],
      ),
      importGelaufen: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}import_gelaufen'],
      )!,
      vorhersagePausiert: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vorhersage_pausiert'],
      )!,
    );
  }

  @override
  $ZyklusEinstellungenTable createAlias(String alias) {
    return $ZyklusEinstellungenTable(attachedDatabase, alias);
  }
}

class ZyklusEinstellungenRow extends DataClass
    implements Insertable<ZyklusEinstellungenRow> {
  /// Der Schlüssel der einen Zeile.
  final int id;

  /// Ob der Kalender überhaupt geführt wird. **Aus**, bis jemand ihn
  /// einschaltet — er erscheint unter *Mehr* nur, wenn eingeschaltet
  /// (Spec 7).
  final bool kalenderAn;

  /// Der Name aus `ZyklusSicht` (`ueberblick` oder `kinderwunsch`). Ohne
  /// `CHECK`, aus demselben Grund wie bei [ZyklusEintraege.blutung].
  final String sicht;

  /// Ob verhütet wird.
  final bool verhuetungAn;

  /// Seit wann, als ISO-Tagesstring; `NULL`, solange nicht verhütet wird.
  ///
  /// **Nicht bloß ein Flag:** Nur so bleibt rückwirkend erkennbar, welcher
  /// Zyklus unter Verhütung lief (Spec 3.7) — ein Flag verlöre das beim
  /// nächsten Umschalten.
  final String? verhuetungSeit;

  /// Die Art der Verhütung als Freitext, `NULL`, wenn keine eingetragen
  /// ist. **Keine Aufzählung** (Spec 4.3): Die Arten aus 6.2 gehören zu
  /// den Mitteilungen, nicht zur Ablage.
  final String? verhuetungArt;

  /// Ob der Erstimport aus Apple Health schon gelaufen ist.
  final bool importGelaufen;

  /// Ob die Vorhersage pausiert — etwa nach einem positiven Test
  /// (Spec 3.8).
  final bool vorhersagePausiert;
  const ZyklusEinstellungenRow({
    required this.id,
    required this.kalenderAn,
    required this.sicht,
    required this.verhuetungAn,
    this.verhuetungSeit,
    this.verhuetungArt,
    required this.importGelaufen,
    required this.vorhersagePausiert,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['kalender_an'] = Variable<bool>(kalenderAn);
    map['sicht'] = Variable<String>(sicht);
    map['verhuetung_an'] = Variable<bool>(verhuetungAn);
    if (!nullToAbsent || verhuetungSeit != null) {
      map['verhuetung_seit'] = Variable<String>(verhuetungSeit);
    }
    if (!nullToAbsent || verhuetungArt != null) {
      map['verhuetung_art'] = Variable<String>(verhuetungArt);
    }
    map['import_gelaufen'] = Variable<bool>(importGelaufen);
    map['vorhersage_pausiert'] = Variable<bool>(vorhersagePausiert);
    return map;
  }

  ZyklusEinstellungenCompanion toCompanion(bool nullToAbsent) {
    return ZyklusEinstellungenCompanion(
      id: Value(id),
      kalenderAn: Value(kalenderAn),
      sicht: Value(sicht),
      verhuetungAn: Value(verhuetungAn),
      verhuetungSeit: verhuetungSeit == null && nullToAbsent
          ? const Value.absent()
          : Value(verhuetungSeit),
      verhuetungArt: verhuetungArt == null && nullToAbsent
          ? const Value.absent()
          : Value(verhuetungArt),
      importGelaufen: Value(importGelaufen),
      vorhersagePausiert: Value(vorhersagePausiert),
    );
  }

  factory ZyklusEinstellungenRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZyklusEinstellungenRow(
      id: serializer.fromJson<int>(json['id']),
      kalenderAn: serializer.fromJson<bool>(json['kalenderAn']),
      sicht: serializer.fromJson<String>(json['sicht']),
      verhuetungAn: serializer.fromJson<bool>(json['verhuetungAn']),
      verhuetungSeit: serializer.fromJson<String?>(json['verhuetungSeit']),
      verhuetungArt: serializer.fromJson<String?>(json['verhuetungArt']),
      importGelaufen: serializer.fromJson<bool>(json['importGelaufen']),
      vorhersagePausiert: serializer.fromJson<bool>(json['vorhersagePausiert']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'kalenderAn': serializer.toJson<bool>(kalenderAn),
      'sicht': serializer.toJson<String>(sicht),
      'verhuetungAn': serializer.toJson<bool>(verhuetungAn),
      'verhuetungSeit': serializer.toJson<String?>(verhuetungSeit),
      'verhuetungArt': serializer.toJson<String?>(verhuetungArt),
      'importGelaufen': serializer.toJson<bool>(importGelaufen),
      'vorhersagePausiert': serializer.toJson<bool>(vorhersagePausiert),
    };
  }

  ZyklusEinstellungenRow copyWith({
    int? id,
    bool? kalenderAn,
    String? sicht,
    bool? verhuetungAn,
    Value<String?> verhuetungSeit = const Value.absent(),
    Value<String?> verhuetungArt = const Value.absent(),
    bool? importGelaufen,
    bool? vorhersagePausiert,
  }) => ZyklusEinstellungenRow(
    id: id ?? this.id,
    kalenderAn: kalenderAn ?? this.kalenderAn,
    sicht: sicht ?? this.sicht,
    verhuetungAn: verhuetungAn ?? this.verhuetungAn,
    verhuetungSeit: verhuetungSeit.present
        ? verhuetungSeit.value
        : this.verhuetungSeit,
    verhuetungArt: verhuetungArt.present
        ? verhuetungArt.value
        : this.verhuetungArt,
    importGelaufen: importGelaufen ?? this.importGelaufen,
    vorhersagePausiert: vorhersagePausiert ?? this.vorhersagePausiert,
  );
  ZyklusEinstellungenRow copyWithCompanion(ZyklusEinstellungenCompanion data) {
    return ZyklusEinstellungenRow(
      id: data.id.present ? data.id.value : this.id,
      kalenderAn: data.kalenderAn.present
          ? data.kalenderAn.value
          : this.kalenderAn,
      sicht: data.sicht.present ? data.sicht.value : this.sicht,
      verhuetungAn: data.verhuetungAn.present
          ? data.verhuetungAn.value
          : this.verhuetungAn,
      verhuetungSeit: data.verhuetungSeit.present
          ? data.verhuetungSeit.value
          : this.verhuetungSeit,
      verhuetungArt: data.verhuetungArt.present
          ? data.verhuetungArt.value
          : this.verhuetungArt,
      importGelaufen: data.importGelaufen.present
          ? data.importGelaufen.value
          : this.importGelaufen,
      vorhersagePausiert: data.vorhersagePausiert.present
          ? data.vorhersagePausiert.value
          : this.vorhersagePausiert,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusEinstellungenRow(')
          ..write('id: $id, ')
          ..write('kalenderAn: $kalenderAn, ')
          ..write('sicht: $sicht, ')
          ..write('verhuetungAn: $verhuetungAn, ')
          ..write('verhuetungSeit: $verhuetungSeit, ')
          ..write('verhuetungArt: $verhuetungArt, ')
          ..write('importGelaufen: $importGelaufen, ')
          ..write('vorhersagePausiert: $vorhersagePausiert')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kalenderAn,
    sicht,
    verhuetungAn,
    verhuetungSeit,
    verhuetungArt,
    importGelaufen,
    vorhersagePausiert,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZyklusEinstellungenRow &&
          other.id == this.id &&
          other.kalenderAn == this.kalenderAn &&
          other.sicht == this.sicht &&
          other.verhuetungAn == this.verhuetungAn &&
          other.verhuetungSeit == this.verhuetungSeit &&
          other.verhuetungArt == this.verhuetungArt &&
          other.importGelaufen == this.importGelaufen &&
          other.vorhersagePausiert == this.vorhersagePausiert);
}

class ZyklusEinstellungenCompanion
    extends UpdateCompanion<ZyklusEinstellungenRow> {
  final Value<int> id;
  final Value<bool> kalenderAn;
  final Value<String> sicht;
  final Value<bool> verhuetungAn;
  final Value<String?> verhuetungSeit;
  final Value<String?> verhuetungArt;
  final Value<bool> importGelaufen;
  final Value<bool> vorhersagePausiert;
  const ZyklusEinstellungenCompanion({
    this.id = const Value.absent(),
    this.kalenderAn = const Value.absent(),
    this.sicht = const Value.absent(),
    this.verhuetungAn = const Value.absent(),
    this.verhuetungSeit = const Value.absent(),
    this.verhuetungArt = const Value.absent(),
    this.importGelaufen = const Value.absent(),
    this.vorhersagePausiert = const Value.absent(),
  });
  ZyklusEinstellungenCompanion.insert({
    this.id = const Value.absent(),
    this.kalenderAn = const Value.absent(),
    this.sicht = const Value.absent(),
    this.verhuetungAn = const Value.absent(),
    this.verhuetungSeit = const Value.absent(),
    this.verhuetungArt = const Value.absent(),
    this.importGelaufen = const Value.absent(),
    this.vorhersagePausiert = const Value.absent(),
  });
  static Insertable<ZyklusEinstellungenRow> custom({
    Expression<int>? id,
    Expression<bool>? kalenderAn,
    Expression<String>? sicht,
    Expression<bool>? verhuetungAn,
    Expression<String>? verhuetungSeit,
    Expression<String>? verhuetungArt,
    Expression<bool>? importGelaufen,
    Expression<bool>? vorhersagePausiert,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kalenderAn != null) 'kalender_an': kalenderAn,
      if (sicht != null) 'sicht': sicht,
      if (verhuetungAn != null) 'verhuetung_an': verhuetungAn,
      if (verhuetungSeit != null) 'verhuetung_seit': verhuetungSeit,
      if (verhuetungArt != null) 'verhuetung_art': verhuetungArt,
      if (importGelaufen != null) 'import_gelaufen': importGelaufen,
      if (vorhersagePausiert != null) 'vorhersage_pausiert': vorhersagePausiert,
    });
  }

  ZyklusEinstellungenCompanion copyWith({
    Value<int>? id,
    Value<bool>? kalenderAn,
    Value<String>? sicht,
    Value<bool>? verhuetungAn,
    Value<String?>? verhuetungSeit,
    Value<String?>? verhuetungArt,
    Value<bool>? importGelaufen,
    Value<bool>? vorhersagePausiert,
  }) {
    return ZyklusEinstellungenCompanion(
      id: id ?? this.id,
      kalenderAn: kalenderAn ?? this.kalenderAn,
      sicht: sicht ?? this.sicht,
      verhuetungAn: verhuetungAn ?? this.verhuetungAn,
      verhuetungSeit: verhuetungSeit ?? this.verhuetungSeit,
      verhuetungArt: verhuetungArt ?? this.verhuetungArt,
      importGelaufen: importGelaufen ?? this.importGelaufen,
      vorhersagePausiert: vorhersagePausiert ?? this.vorhersagePausiert,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (kalenderAn.present) {
      map['kalender_an'] = Variable<bool>(kalenderAn.value);
    }
    if (sicht.present) {
      map['sicht'] = Variable<String>(sicht.value);
    }
    if (verhuetungAn.present) {
      map['verhuetung_an'] = Variable<bool>(verhuetungAn.value);
    }
    if (verhuetungSeit.present) {
      map['verhuetung_seit'] = Variable<String>(verhuetungSeit.value);
    }
    if (verhuetungArt.present) {
      map['verhuetung_art'] = Variable<String>(verhuetungArt.value);
    }
    if (importGelaufen.present) {
      map['import_gelaufen'] = Variable<bool>(importGelaufen.value);
    }
    if (vorhersagePausiert.present) {
      map['vorhersage_pausiert'] = Variable<bool>(vorhersagePausiert.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZyklusEinstellungenCompanion(')
          ..write('id: $id, ')
          ..write('kalenderAn: $kalenderAn, ')
          ..write('sicht: $sicht, ')
          ..write('verhuetungAn: $verhuetungAn, ')
          ..write('verhuetungSeit: $verhuetungSeit, ')
          ..write('verhuetungArt: $verhuetungArt, ')
          ..write('importGelaufen: $importGelaufen, ')
          ..write('vorhersagePausiert: $vorhersagePausiert')
          ..write(')'))
        .toString();
  }
}

class $GymTrainingsTable extends GymTrainings
    with TableInfo<$GymTrainingsTable, GymTrainingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymTrainingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kategorieMeta = const VerificationMeta(
    'kategorie',
  );
  @override
  late final GeneratedColumn<String> kategorie = GeneratedColumn<String>(
    'kategorie',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    $customConstraints:
        'NOT NULL CHECK (kategorie IN (\'template\', \'eigene\'))',
  );
  static const VerificationMeta _dauerEingetragenMinMeta =
      const VerificationMeta('dauerEingetragenMin');
  @override
  late final GeneratedColumn<int> dauerEingetragenMin = GeneratedColumn<int>(
    'dauer_eingetragen_min',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _istEntwurfMeta = const VerificationMeta(
    'istEntwurf',
  );
  @override
  late final GeneratedColumn<bool> istEntwurf = GeneratedColumn<bool>(
    'ist_entwurf',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK (ist_entwurf = 0 OR kategorie = \'eigene\')',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _geloeschtMeta = const VerificationMeta(
    'geloescht',
  );
  @override
  late final GeneratedColumn<bool> geloescht = GeneratedColumn<bool>(
    'geloescht',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    $customConstraints:
        'NOT NULL DEFAULT 0 CHECK (geloescht = 0 OR kategorie = \'template\')',
    defaultValue: const CustomExpression('0'),
  );
  static const VerificationMeta _reihenfolgeMeta = const VerificationMeta(
    'reihenfolge',
  );
  @override
  late final GeneratedColumn<int> reihenfolge = GeneratedColumn<int>(
    'reihenfolge',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entwurfVonMeta = const VerificationMeta(
    'entwurfVon',
  );
  @override
  late final GeneratedColumn<String> entwurfVon = GeneratedColumn<String>(
    'entwurf_von',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (entwurf_von IS NULL OR (ist_entwurf = 1 AND kategorie = \'eigene\'))',
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    kategorie,
    dauerEingetragenMin,
    istEntwurf,
    geloescht,
    reihenfolge,
    entwurfVon,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_trainings';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymTrainingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('kategorie')) {
      context.handle(
        _kategorieMeta,
        kategorie.isAcceptableOrUnknown(data['kategorie']!, _kategorieMeta),
      );
    } else if (isInserting) {
      context.missing(_kategorieMeta);
    }
    if (data.containsKey('dauer_eingetragen_min')) {
      context.handle(
        _dauerEingetragenMinMeta,
        dauerEingetragenMin.isAcceptableOrUnknown(
          data['dauer_eingetragen_min']!,
          _dauerEingetragenMinMeta,
        ),
      );
    }
    if (data.containsKey('ist_entwurf')) {
      context.handle(
        _istEntwurfMeta,
        istEntwurf.isAcceptableOrUnknown(data['ist_entwurf']!, _istEntwurfMeta),
      );
    }
    if (data.containsKey('geloescht')) {
      context.handle(
        _geloeschtMeta,
        geloescht.isAcceptableOrUnknown(data['geloescht']!, _geloeschtMeta),
      );
    }
    if (data.containsKey('reihenfolge')) {
      context.handle(
        _reihenfolgeMeta,
        reihenfolge.isAcceptableOrUnknown(
          data['reihenfolge']!,
          _reihenfolgeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_reihenfolgeMeta);
    }
    if (data.containsKey('entwurf_von')) {
      context.handle(
        _entwurfVonMeta,
        entwurfVon.isAcceptableOrUnknown(data['entwurf_von']!, _entwurfVonMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {entwurfVon},
  ];
  @override
  GymTrainingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymTrainingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      kategorie: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kategorie'],
      )!,
      dauerEingetragenMin: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dauer_eingetragen_min'],
      ),
      istEntwurf: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}ist_entwurf'],
      )!,
      geloescht: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}geloescht'],
      )!,
      reihenfolge: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}reihenfolge'],
      )!,
      entwurfVon: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entwurf_von'],
      ),
    );
  }

  @override
  $GymTrainingsTable createAlias(String alias) {
    return $GymTrainingsTable(attachedDatabase, alias);
  }
}

class GymTrainingRow extends DataClass implements Insertable<GymTrainingRow> {
  /// Templates: ihre feste Kennung (`'Push'`, …, `Workout.code`). Eigene:
  /// eine UUID in Großbuchstaben, vergeben beim Anlegen.
  final String id;

  /// Der ganze Name, z. B. `Push — Brust, Schultern, Trizeps`.
  final String name;

  /// `'template'` oder `'eigene'` — wortgleich mit `WorkoutCategory.code`.
  /// Ausgeschrieben aus dem Grund im Dateikopf; wer dem Kern eine dritte
  /// Kategorie gibt, braucht eine neue Stufe, denn eine `CHECK`-Bedingung
  /// steht in `CREATE TABLE` und ändert sich nicht von selbst.
  final String kategorie;

  /// Die eingetragene Dauer in Minuten. **`NULL` heißt „geschätzt"**, nicht
  /// „0 Minuten" (Fehler `01`); die Schätzung wird nie gespeichert.
  final int? dauerEingetragenMin;

  /// Ein Zwischenstand des Editors. **Ein Template ist nie ein Entwurf.**
  final bool istEntwurf;

  /// Der Tombstone — **nur bei Templates.** Eigene Trainings werden wirklich
  /// gelöscht, weil nur ein Update Templates neu einspielt.
  final bool geloescht;

  /// Die Anzeigereihenfolge **innerhalb der Kategorie**: Templates = Platz in
  /// der Startbefüllung (1…), Eigene = größte vorhandene Zahl der Eigenen + 1.
  /// Kein Zeitstempel — die Spalte braucht keine Uhr.
  final int reihenfolge;

  /// **Vorschlag des Plans (Plan 1), von Tim nicht beantwortet:** Hängt ein
  /// Zwischenstand an einem bestehenden Training, steht hier dessen
  /// Kennung. `NULL` für alles andere, auch für einen frei stehenden
  /// Entwurf. Je Training höchstens ein Zwischenstand (`UNIQUE`); der
  /// Zwischenstand ersetzt das Training erst beim Speichern.
  final String? entwurfVon;
  const GymTrainingRow({
    required this.id,
    required this.name,
    required this.kategorie,
    this.dauerEingetragenMin,
    required this.istEntwurf,
    required this.geloescht,
    required this.reihenfolge,
    this.entwurfVon,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['kategorie'] = Variable<String>(kategorie);
    if (!nullToAbsent || dauerEingetragenMin != null) {
      map['dauer_eingetragen_min'] = Variable<int>(dauerEingetragenMin);
    }
    map['ist_entwurf'] = Variable<bool>(istEntwurf);
    map['geloescht'] = Variable<bool>(geloescht);
    map['reihenfolge'] = Variable<int>(reihenfolge);
    if (!nullToAbsent || entwurfVon != null) {
      map['entwurf_von'] = Variable<String>(entwurfVon);
    }
    return map;
  }

  GymTrainingsCompanion toCompanion(bool nullToAbsent) {
    return GymTrainingsCompanion(
      id: Value(id),
      name: Value(name),
      kategorie: Value(kategorie),
      dauerEingetragenMin: dauerEingetragenMin == null && nullToAbsent
          ? const Value.absent()
          : Value(dauerEingetragenMin),
      istEntwurf: Value(istEntwurf),
      geloescht: Value(geloescht),
      reihenfolge: Value(reihenfolge),
      entwurfVon: entwurfVon == null && nullToAbsent
          ? const Value.absent()
          : Value(entwurfVon),
    );
  }

  factory GymTrainingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymTrainingRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      kategorie: serializer.fromJson<String>(json['kategorie']),
      dauerEingetragenMin: serializer.fromJson<int?>(
        json['dauerEingetragenMin'],
      ),
      istEntwurf: serializer.fromJson<bool>(json['istEntwurf']),
      geloescht: serializer.fromJson<bool>(json['geloescht']),
      reihenfolge: serializer.fromJson<int>(json['reihenfolge']),
      entwurfVon: serializer.fromJson<String?>(json['entwurfVon']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'kategorie': serializer.toJson<String>(kategorie),
      'dauerEingetragenMin': serializer.toJson<int?>(dauerEingetragenMin),
      'istEntwurf': serializer.toJson<bool>(istEntwurf),
      'geloescht': serializer.toJson<bool>(geloescht),
      'reihenfolge': serializer.toJson<int>(reihenfolge),
      'entwurfVon': serializer.toJson<String?>(entwurfVon),
    };
  }

  GymTrainingRow copyWith({
    String? id,
    String? name,
    String? kategorie,
    Value<int?> dauerEingetragenMin = const Value.absent(),
    bool? istEntwurf,
    bool? geloescht,
    int? reihenfolge,
    Value<String?> entwurfVon = const Value.absent(),
  }) => GymTrainingRow(
    id: id ?? this.id,
    name: name ?? this.name,
    kategorie: kategorie ?? this.kategorie,
    dauerEingetragenMin: dauerEingetragenMin.present
        ? dauerEingetragenMin.value
        : this.dauerEingetragenMin,
    istEntwurf: istEntwurf ?? this.istEntwurf,
    geloescht: geloescht ?? this.geloescht,
    reihenfolge: reihenfolge ?? this.reihenfolge,
    entwurfVon: entwurfVon.present ? entwurfVon.value : this.entwurfVon,
  );
  GymTrainingRow copyWithCompanion(GymTrainingsCompanion data) {
    return GymTrainingRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      kategorie: data.kategorie.present ? data.kategorie.value : this.kategorie,
      dauerEingetragenMin: data.dauerEingetragenMin.present
          ? data.dauerEingetragenMin.value
          : this.dauerEingetragenMin,
      istEntwurf: data.istEntwurf.present
          ? data.istEntwurf.value
          : this.istEntwurf,
      geloescht: data.geloescht.present ? data.geloescht.value : this.geloescht,
      reihenfolge: data.reihenfolge.present
          ? data.reihenfolge.value
          : this.reihenfolge,
      entwurfVon: data.entwurfVon.present
          ? data.entwurfVon.value
          : this.entwurfVon,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kategorie: $kategorie, ')
          ..write('dauerEingetragenMin: $dauerEingetragenMin, ')
          ..write('istEntwurf: $istEntwurf, ')
          ..write('geloescht: $geloescht, ')
          ..write('reihenfolge: $reihenfolge, ')
          ..write('entwurfVon: $entwurfVon')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    kategorie,
    dauerEingetragenMin,
    istEntwurf,
    geloescht,
    reihenfolge,
    entwurfVon,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymTrainingRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.kategorie == this.kategorie &&
          other.dauerEingetragenMin == this.dauerEingetragenMin &&
          other.istEntwurf == this.istEntwurf &&
          other.geloescht == this.geloescht &&
          other.reihenfolge == this.reihenfolge &&
          other.entwurfVon == this.entwurfVon);
}

class GymTrainingsCompanion extends UpdateCompanion<GymTrainingRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> kategorie;
  final Value<int?> dauerEingetragenMin;
  final Value<bool> istEntwurf;
  final Value<bool> geloescht;
  final Value<int> reihenfolge;
  final Value<String?> entwurfVon;
  final Value<int> rowid;
  const GymTrainingsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.kategorie = const Value.absent(),
    this.dauerEingetragenMin = const Value.absent(),
    this.istEntwurf = const Value.absent(),
    this.geloescht = const Value.absent(),
    this.reihenfolge = const Value.absent(),
    this.entwurfVon = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymTrainingsCompanion.insert({
    required String id,
    required String name,
    required String kategorie,
    this.dauerEingetragenMin = const Value.absent(),
    this.istEntwurf = const Value.absent(),
    this.geloescht = const Value.absent(),
    required int reihenfolge,
    this.entwurfVon = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       kategorie = Value(kategorie),
       reihenfolge = Value(reihenfolge);
  static Insertable<GymTrainingRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? kategorie,
    Expression<int>? dauerEingetragenMin,
    Expression<bool>? istEntwurf,
    Expression<bool>? geloescht,
    Expression<int>? reihenfolge,
    Expression<String>? entwurfVon,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (kategorie != null) 'kategorie': kategorie,
      if (dauerEingetragenMin != null)
        'dauer_eingetragen_min': dauerEingetragenMin,
      if (istEntwurf != null) 'ist_entwurf': istEntwurf,
      if (geloescht != null) 'geloescht': geloescht,
      if (reihenfolge != null) 'reihenfolge': reihenfolge,
      if (entwurfVon != null) 'entwurf_von': entwurfVon,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymTrainingsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? kategorie,
    Value<int?>? dauerEingetragenMin,
    Value<bool>? istEntwurf,
    Value<bool>? geloescht,
    Value<int>? reihenfolge,
    Value<String?>? entwurfVon,
    Value<int>? rowid,
  }) {
    return GymTrainingsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      kategorie: kategorie ?? this.kategorie,
      dauerEingetragenMin: dauerEingetragenMin ?? this.dauerEingetragenMin,
      istEntwurf: istEntwurf ?? this.istEntwurf,
      geloescht: geloescht ?? this.geloescht,
      reihenfolge: reihenfolge ?? this.reihenfolge,
      entwurfVon: entwurfVon ?? this.entwurfVon,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (kategorie.present) {
      map['kategorie'] = Variable<String>(kategorie.value);
    }
    if (dauerEingetragenMin.present) {
      map['dauer_eingetragen_min'] = Variable<int>(dauerEingetragenMin.value);
    }
    if (istEntwurf.present) {
      map['ist_entwurf'] = Variable<bool>(istEntwurf.value);
    }
    if (geloescht.present) {
      map['geloescht'] = Variable<bool>(geloescht.value);
    }
    if (reihenfolge.present) {
      map['reihenfolge'] = Variable<int>(reihenfolge.value);
    }
    if (entwurfVon.present) {
      map['entwurf_von'] = Variable<String>(entwurfVon.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('kategorie: $kategorie, ')
          ..write('dauerEingetragenMin: $dauerEingetragenMin, ')
          ..write('istEntwurf: $istEntwurf, ')
          ..write('geloescht: $geloescht, ')
          ..write('reihenfolge: $reihenfolge, ')
          ..write('entwurfVon: $entwurfVon, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymTrainingUebungenTable extends GymTrainingUebungen
    with TableInfo<$GymTrainingUebungenTable, GymTrainingUebungRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymTrainingUebungenTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trainingIdMeta = const VerificationMeta(
    'trainingId',
  );
  @override
  late final GeneratedColumn<String> trainingId = GeneratedColumn<String>(
    'training_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<int> pos = GeneratedColumn<int>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (pos >= 1)',
  );
  static const VerificationMeta _uebungIdMeta = const VerificationMeta(
    'uebungId',
  );
  @override
  late final GeneratedColumn<String> uebungId = GeneratedColumn<String>(
    'uebung_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _saetzeMeta = const VerificationMeta('saetze');
  @override
  late final GeneratedColumn<int> saetze = GeneratedColumn<int>(
    'saetze',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (saetze >= 1)',
  );
  static const VerificationMeta _wdhVonMeta = const VerificationMeta('wdhVon');
  @override
  late final GeneratedColumn<int> wdhVon = GeneratedColumn<int>(
    'wdh_von',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (wdh_von >= 1)',
  );
  static const VerificationMeta _wdhBisMeta = const VerificationMeta('wdhBis');
  @override
  late final GeneratedColumn<int> wdhBis = GeneratedColumn<int>(
    'wdh_bis',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (wdh_bis >= wdh_von)',
  );
  static const VerificationMeta _steigerungMeta = const VerificationMeta(
    'steigerung',
  );
  @override
  late final GeneratedColumn<double> steigerung = GeneratedColumn<double>(
    'steigerung',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    trainingId,
    pos,
    uebungId,
    saetze,
    wdhVon,
    wdhBis,
    steigerung,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_training_uebungen';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymTrainingUebungRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('training_id')) {
      context.handle(
        _trainingIdMeta,
        trainingId.isAcceptableOrUnknown(data['training_id']!, _trainingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trainingIdMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('uebung_id')) {
      context.handle(
        _uebungIdMeta,
        uebungId.isAcceptableOrUnknown(data['uebung_id']!, _uebungIdMeta),
      );
    } else if (isInserting) {
      context.missing(_uebungIdMeta);
    }
    if (data.containsKey('saetze')) {
      context.handle(
        _saetzeMeta,
        saetze.isAcceptableOrUnknown(data['saetze']!, _saetzeMeta),
      );
    } else if (isInserting) {
      context.missing(_saetzeMeta);
    }
    if (data.containsKey('wdh_von')) {
      context.handle(
        _wdhVonMeta,
        wdhVon.isAcceptableOrUnknown(data['wdh_von']!, _wdhVonMeta),
      );
    } else if (isInserting) {
      context.missing(_wdhVonMeta);
    }
    if (data.containsKey('wdh_bis')) {
      context.handle(
        _wdhBisMeta,
        wdhBis.isAcceptableOrUnknown(data['wdh_bis']!, _wdhBisMeta),
      );
    } else if (isInserting) {
      context.missing(_wdhBisMeta);
    }
    if (data.containsKey('steigerung')) {
      context.handle(
        _steigerungMeta,
        steigerung.isAcceptableOrUnknown(data['steigerung']!, _steigerungMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trainingId, uebungId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trainingId, pos},
  ];
  @override
  GymTrainingUebungRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymTrainingUebungRow(
      trainingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_id'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos'],
      )!,
      uebungId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uebung_id'],
      )!,
      saetze: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saetze'],
      )!,
      wdhVon: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wdh_von'],
      )!,
      wdhBis: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}wdh_bis'],
      )!,
      steigerung: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}steigerung'],
      ),
    );
  }

  @override
  $GymTrainingUebungenTable createAlias(String alias) {
    return $GymTrainingUebungenTable(attachedDatabase, alias);
  }
}

class GymTrainingUebungRow extends DataClass
    implements Insertable<GymTrainingUebungRow> {
  final String trainingId;

  /// Die Position, **ab 1** — abgelegt, nicht aus der Zeilenreihenfolge der
  /// Abfrage gerechnet (dieselbe Begründung wie `gym_saetze.uebung_pos`).
  final int pos;

  /// Die `Exercise.id` aus dem Katalog. **Keine Prüfung gegen den Katalog in
  /// der Datenbank:** Eine ID, die der Katalog nicht (mehr) kennt, wird beim
  /// Lesen benannt (Spec 6.2), nicht beim Schreiben verhindert.
  final String uebungId;
  final int saetze;

  /// Untere Grenze des Wiederholungsbereichs, bei Zeitübungen Sekunden.
  final int wdhVon;
  final int wdhBis;

  /// **Platz für #537.** `NULL` heißt „aus dem Katalog". Kein Schirm liest die
  /// Spalte als Eingabe, solange #537 nicht gebaut ist; die Ablage schreibt
  /// und liest sie, was sie bekommt (siehe `GymTrainingRepository`).
  final double? steigerung;
  const GymTrainingUebungRow({
    required this.trainingId,
    required this.pos,
    required this.uebungId,
    required this.saetze,
    required this.wdhVon,
    required this.wdhBis,
    this.steigerung,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['training_id'] = Variable<String>(trainingId);
    map['pos'] = Variable<int>(pos);
    map['uebung_id'] = Variable<String>(uebungId);
    map['saetze'] = Variable<int>(saetze);
    map['wdh_von'] = Variable<int>(wdhVon);
    map['wdh_bis'] = Variable<int>(wdhBis);
    if (!nullToAbsent || steigerung != null) {
      map['steigerung'] = Variable<double>(steigerung);
    }
    return map;
  }

  GymTrainingUebungenCompanion toCompanion(bool nullToAbsent) {
    return GymTrainingUebungenCompanion(
      trainingId: Value(trainingId),
      pos: Value(pos),
      uebungId: Value(uebungId),
      saetze: Value(saetze),
      wdhVon: Value(wdhVon),
      wdhBis: Value(wdhBis),
      steigerung: steigerung == null && nullToAbsent
          ? const Value.absent()
          : Value(steigerung),
    );
  }

  factory GymTrainingUebungRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymTrainingUebungRow(
      trainingId: serializer.fromJson<String>(json['trainingId']),
      pos: serializer.fromJson<int>(json['pos']),
      uebungId: serializer.fromJson<String>(json['uebungId']),
      saetze: serializer.fromJson<int>(json['saetze']),
      wdhVon: serializer.fromJson<int>(json['wdhVon']),
      wdhBis: serializer.fromJson<int>(json['wdhBis']),
      steigerung: serializer.fromJson<double?>(json['steigerung']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trainingId': serializer.toJson<String>(trainingId),
      'pos': serializer.toJson<int>(pos),
      'uebungId': serializer.toJson<String>(uebungId),
      'saetze': serializer.toJson<int>(saetze),
      'wdhVon': serializer.toJson<int>(wdhVon),
      'wdhBis': serializer.toJson<int>(wdhBis),
      'steigerung': serializer.toJson<double?>(steigerung),
    };
  }

  GymTrainingUebungRow copyWith({
    String? trainingId,
    int? pos,
    String? uebungId,
    int? saetze,
    int? wdhVon,
    int? wdhBis,
    Value<double?> steigerung = const Value.absent(),
  }) => GymTrainingUebungRow(
    trainingId: trainingId ?? this.trainingId,
    pos: pos ?? this.pos,
    uebungId: uebungId ?? this.uebungId,
    saetze: saetze ?? this.saetze,
    wdhVon: wdhVon ?? this.wdhVon,
    wdhBis: wdhBis ?? this.wdhBis,
    steigerung: steigerung.present ? steigerung.value : this.steigerung,
  );
  GymTrainingUebungRow copyWithCompanion(GymTrainingUebungenCompanion data) {
    return GymTrainingUebungRow(
      trainingId: data.trainingId.present
          ? data.trainingId.value
          : this.trainingId,
      pos: data.pos.present ? data.pos.value : this.pos,
      uebungId: data.uebungId.present ? data.uebungId.value : this.uebungId,
      saetze: data.saetze.present ? data.saetze.value : this.saetze,
      wdhVon: data.wdhVon.present ? data.wdhVon.value : this.wdhVon,
      wdhBis: data.wdhBis.present ? data.wdhBis.value : this.wdhBis,
      steigerung: data.steigerung.present
          ? data.steigerung.value
          : this.steigerung,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingUebungRow(')
          ..write('trainingId: $trainingId, ')
          ..write('pos: $pos, ')
          ..write('uebungId: $uebungId, ')
          ..write('saetze: $saetze, ')
          ..write('wdhVon: $wdhVon, ')
          ..write('wdhBis: $wdhBis, ')
          ..write('steigerung: $steigerung')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    trainingId,
    pos,
    uebungId,
    saetze,
    wdhVon,
    wdhBis,
    steigerung,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymTrainingUebungRow &&
          other.trainingId == this.trainingId &&
          other.pos == this.pos &&
          other.uebungId == this.uebungId &&
          other.saetze == this.saetze &&
          other.wdhVon == this.wdhVon &&
          other.wdhBis == this.wdhBis &&
          other.steigerung == this.steigerung);
}

class GymTrainingUebungenCompanion
    extends UpdateCompanion<GymTrainingUebungRow> {
  final Value<String> trainingId;
  final Value<int> pos;
  final Value<String> uebungId;
  final Value<int> saetze;
  final Value<int> wdhVon;
  final Value<int> wdhBis;
  final Value<double?> steigerung;
  final Value<int> rowid;
  const GymTrainingUebungenCompanion({
    this.trainingId = const Value.absent(),
    this.pos = const Value.absent(),
    this.uebungId = const Value.absent(),
    this.saetze = const Value.absent(),
    this.wdhVon = const Value.absent(),
    this.wdhBis = const Value.absent(),
    this.steigerung = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymTrainingUebungenCompanion.insert({
    required String trainingId,
    required int pos,
    required String uebungId,
    required int saetze,
    required int wdhVon,
    required int wdhBis,
    this.steigerung = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : trainingId = Value(trainingId),
       pos = Value(pos),
       uebungId = Value(uebungId),
       saetze = Value(saetze),
       wdhVon = Value(wdhVon),
       wdhBis = Value(wdhBis);
  static Insertable<GymTrainingUebungRow> custom({
    Expression<String>? trainingId,
    Expression<int>? pos,
    Expression<String>? uebungId,
    Expression<int>? saetze,
    Expression<int>? wdhVon,
    Expression<int>? wdhBis,
    Expression<double>? steigerung,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trainingId != null) 'training_id': trainingId,
      if (pos != null) 'pos': pos,
      if (uebungId != null) 'uebung_id': uebungId,
      if (saetze != null) 'saetze': saetze,
      if (wdhVon != null) 'wdh_von': wdhVon,
      if (wdhBis != null) 'wdh_bis': wdhBis,
      if (steigerung != null) 'steigerung': steigerung,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymTrainingUebungenCompanion copyWith({
    Value<String>? trainingId,
    Value<int>? pos,
    Value<String>? uebungId,
    Value<int>? saetze,
    Value<int>? wdhVon,
    Value<int>? wdhBis,
    Value<double?>? steigerung,
    Value<int>? rowid,
  }) {
    return GymTrainingUebungenCompanion(
      trainingId: trainingId ?? this.trainingId,
      pos: pos ?? this.pos,
      uebungId: uebungId ?? this.uebungId,
      saetze: saetze ?? this.saetze,
      wdhVon: wdhVon ?? this.wdhVon,
      wdhBis: wdhBis ?? this.wdhBis,
      steigerung: steigerung ?? this.steigerung,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trainingId.present) {
      map['training_id'] = Variable<String>(trainingId.value);
    }
    if (pos.present) {
      map['pos'] = Variable<int>(pos.value);
    }
    if (uebungId.present) {
      map['uebung_id'] = Variable<String>(uebungId.value);
    }
    if (saetze.present) {
      map['saetze'] = Variable<int>(saetze.value);
    }
    if (wdhVon.present) {
      map['wdh_von'] = Variable<int>(wdhVon.value);
    }
    if (wdhBis.present) {
      map['wdh_bis'] = Variable<int>(wdhBis.value);
    }
    if (steigerung.present) {
      map['steigerung'] = Variable<double>(steigerung.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingUebungenCompanion(')
          ..write('trainingId: $trainingId, ')
          ..write('pos: $pos, ')
          ..write('uebungId: $uebungId, ')
          ..write('saetze: $saetze, ')
          ..write('wdhVon: $wdhVon, ')
          ..write('wdhBis: $wdhBis, ')
          ..write('steigerung: $steigerung, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymTrainingTagsTable extends GymTrainingTags
    with TableInfo<$GymTrainingTagsTable, GymTrainingTagRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymTrainingTagsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trainingIdMeta = const VerificationMeta(
    'trainingId',
  );
  @override
  late final GeneratedColumn<String> trainingId = GeneratedColumn<String>(
    'training_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<int> pos = GeneratedColumn<int>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    $customConstraints: 'NOT NULL CHECK (pos >= 1)',
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [trainingId, pos, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_training_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymTrainingTagRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('training_id')) {
      context.handle(
        _trainingIdMeta,
        trainingId.isAcceptableOrUnknown(data['training_id']!, _trainingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trainingIdMeta);
    }
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    } else if (isInserting) {
      context.missing(_posMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trainingId, tag};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trainingId, pos},
  ];
  @override
  GymTrainingTagRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymTrainingTagRow(
      trainingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_id'],
      )!,
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $GymTrainingTagsTable createAlias(String alias) {
    return $GymTrainingTagsTable(attachedDatabase, alias);
  }
}

class GymTrainingTagRow extends DataClass
    implements Insertable<GymTrainingTagRow> {
  final String trainingId;

  /// Die Reihenfolge der Anzeige, **ab 1**.
  final int pos;

  /// Schon normalisiert (`WorkoutTags.normalize`).
  final String tag;
  const GymTrainingTagRow({
    required this.trainingId,
    required this.pos,
    required this.tag,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['training_id'] = Variable<String>(trainingId);
    map['pos'] = Variable<int>(pos);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  GymTrainingTagsCompanion toCompanion(bool nullToAbsent) {
    return GymTrainingTagsCompanion(
      trainingId: Value(trainingId),
      pos: Value(pos),
      tag: Value(tag),
    );
  }

  factory GymTrainingTagRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymTrainingTagRow(
      trainingId: serializer.fromJson<String>(json['trainingId']),
      pos: serializer.fromJson<int>(json['pos']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trainingId': serializer.toJson<String>(trainingId),
      'pos': serializer.toJson<int>(pos),
      'tag': serializer.toJson<String>(tag),
    };
  }

  GymTrainingTagRow copyWith({String? trainingId, int? pos, String? tag}) =>
      GymTrainingTagRow(
        trainingId: trainingId ?? this.trainingId,
        pos: pos ?? this.pos,
        tag: tag ?? this.tag,
      );
  GymTrainingTagRow copyWithCompanion(GymTrainingTagsCompanion data) {
    return GymTrainingTagRow(
      trainingId: data.trainingId.present
          ? data.trainingId.value
          : this.trainingId,
      pos: data.pos.present ? data.pos.value : this.pos,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingTagRow(')
          ..write('trainingId: $trainingId, ')
          ..write('pos: $pos, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trainingId, pos, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymTrainingTagRow &&
          other.trainingId == this.trainingId &&
          other.pos == this.pos &&
          other.tag == this.tag);
}

class GymTrainingTagsCompanion extends UpdateCompanion<GymTrainingTagRow> {
  final Value<String> trainingId;
  final Value<int> pos;
  final Value<String> tag;
  final Value<int> rowid;
  const GymTrainingTagsCompanion({
    this.trainingId = const Value.absent(),
    this.pos = const Value.absent(),
    this.tag = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GymTrainingTagsCompanion.insert({
    required String trainingId,
    required int pos,
    required String tag,
    this.rowid = const Value.absent(),
  }) : trainingId = Value(trainingId),
       pos = Value(pos),
       tag = Value(tag);
  static Insertable<GymTrainingTagRow> custom({
    Expression<String>? trainingId,
    Expression<int>? pos,
    Expression<String>? tag,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trainingId != null) 'training_id': trainingId,
      if (pos != null) 'pos': pos,
      if (tag != null) 'tag': tag,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GymTrainingTagsCompanion copyWith({
    Value<String>? trainingId,
    Value<int>? pos,
    Value<String>? tag,
    Value<int>? rowid,
  }) {
    return GymTrainingTagsCompanion(
      trainingId: trainingId ?? this.trainingId,
      pos: pos ?? this.pos,
      tag: tag ?? this.tag,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trainingId.present) {
      map['training_id'] = Variable<String>(trainingId.value);
    }
    if (pos.present) {
      map['pos'] = Variable<int>(pos.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymTrainingTagsCompanion(')
          ..write('trainingId: $trainingId, ')
          ..write('pos: $pos, ')
          ..write('tag: $tag, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GymRotationTable extends GymRotation
    with TableInfo<$GymRotationTable, GymRotationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GymRotationTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _posMeta = const VerificationMeta('pos');
  @override
  late final GeneratedColumn<int> pos = GeneratedColumn<int>(
    'pos',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL CHECK (pos >= 1)',
  );
  static const VerificationMeta _trainingIdMeta = const VerificationMeta(
    'trainingId',
  );
  @override
  late final GeneratedColumn<String> trainingId = GeneratedColumn<String>(
    'training_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [pos, trainingId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'gym_rotation';
  @override
  VerificationContext validateIntegrity(
    Insertable<GymRotationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('pos')) {
      context.handle(
        _posMeta,
        pos.isAcceptableOrUnknown(data['pos']!, _posMeta),
      );
    }
    if (data.containsKey('training_id')) {
      context.handle(
        _trainingIdMeta,
        trainingId.isAcceptableOrUnknown(data['training_id']!, _trainingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_trainingIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pos};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {trainingId},
  ];
  @override
  GymRotationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GymRotationRow(
      pos: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pos'],
      )!,
      trainingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}training_id'],
      )!,
    );
  }

  @override
  $GymRotationTable createAlias(String alias) {
    return $GymRotationTable(attachedDatabase, alias);
  }
}

class GymRotationRow extends DataClass implements Insertable<GymRotationRow> {
  /// Der Platz, **ab 1**.
  final int pos;

  /// Die Kennung eines Trainings. Kein Fremdschlüssel: Ob es das Training
  /// gibt, hält das Repository.
  final String trainingId;
  const GymRotationRow({required this.pos, required this.trainingId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['pos'] = Variable<int>(pos);
    map['training_id'] = Variable<String>(trainingId);
    return map;
  }

  GymRotationCompanion toCompanion(bool nullToAbsent) {
    return GymRotationCompanion(pos: Value(pos), trainingId: Value(trainingId));
  }

  factory GymRotationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GymRotationRow(
      pos: serializer.fromJson<int>(json['pos']),
      trainingId: serializer.fromJson<String>(json['trainingId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pos': serializer.toJson<int>(pos),
      'trainingId': serializer.toJson<String>(trainingId),
    };
  }

  GymRotationRow copyWith({int? pos, String? trainingId}) => GymRotationRow(
    pos: pos ?? this.pos,
    trainingId: trainingId ?? this.trainingId,
  );
  GymRotationRow copyWithCompanion(GymRotationCompanion data) {
    return GymRotationRow(
      pos: data.pos.present ? data.pos.value : this.pos,
      trainingId: data.trainingId.present
          ? data.trainingId.value
          : this.trainingId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GymRotationRow(')
          ..write('pos: $pos, ')
          ..write('trainingId: $trainingId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pos, trainingId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GymRotationRow &&
          other.pos == this.pos &&
          other.trainingId == this.trainingId);
}

class GymRotationCompanion extends UpdateCompanion<GymRotationRow> {
  final Value<int> pos;
  final Value<String> trainingId;
  const GymRotationCompanion({
    this.pos = const Value.absent(),
    this.trainingId = const Value.absent(),
  });
  GymRotationCompanion.insert({
    this.pos = const Value.absent(),
    required String trainingId,
  }) : trainingId = Value(trainingId);
  static Insertable<GymRotationRow> custom({
    Expression<int>? pos,
    Expression<String>? trainingId,
  }) {
    return RawValuesInsertable({
      if (pos != null) 'pos': pos,
      if (trainingId != null) 'training_id': trainingId,
    });
  }

  GymRotationCompanion copyWith({Value<int>? pos, Value<String>? trainingId}) {
    return GymRotationCompanion(
      pos: pos ?? this.pos,
      trainingId: trainingId ?? this.trainingId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pos.present) {
      map['pos'] = Variable<int>(pos.value);
    }
    if (trainingId.present) {
      map['training_id'] = Variable<String>(trainingId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GymRotationCompanion(')
          ..write('pos: $pos, ')
          ..write('trainingId: $trainingId')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppCache extends GeneratedDatabase {
  _$AppCache(QueryExecutor e) : super(e);
  $AppCacheManager get managers => $AppCacheManager(this);
  late final $TagesWerteTable tagesWerte = $TagesWerteTable(this);
  late final $StundenSchritteTable stundenSchritte = $StundenSchritteTable(
    this,
  );
  late final $EigeneDatenTable eigeneDaten = $EigeneDatenTable(this);
  late final $NaechteTable naechte = $NaechteTable(this);
  late final $SchlafAbschnitteTable schlafAbschnitte = $SchlafAbschnitteTable(
    this,
  );
  late final $ZielWerteTable zielWerte = $ZielWerteTable(this);
  late final $SchlafEintraegeTable schlafEintraege = $SchlafEintraegeTable(
    this,
  );
  late final $StammdatenTable stammdaten = $StammdatenTable(this);
  late final $LebensmittelTable lebensmittel = $LebensmittelTable(this);
  late final $PortionenTable portionen = $PortionenTable(this);
  late final $EintraegeTable eintraege = $EintraegeTable(this);
  late final $RezepteTable rezepte = $RezepteTable(this);
  late final $RezeptZutatenTable rezeptZutaten = $RezeptZutatenTable(this);
  late final $KiEinstellungenTable kiEinstellungen = $KiEinstellungenTable(
    this,
  );
  late final $KiAnfragenTable kiAnfragen = $KiAnfragenTable(this);
  late final $WasserEintraegeTable wasserEintraege = $WasserEintraegeTable(
    this,
  );
  late final $GymSitzungenTable gymSitzungen = $GymSitzungenTable(this);
  late final $GymSaetzeTable gymSaetze = $GymSaetzeTable(this);
  late final $GymEntwuerfeTable gymEntwuerfe = $GymEntwuerfeTable(this);
  late final $KalorienzieleTable kalorienziele = $KalorienzieleTable(this);
  late final $MahlzeitAufteilungenTable mahlzeitAufteilungen =
      $MahlzeitAufteilungenTable(this);
  late final $EreignisseTable ereignisse = $EreignisseTable(this);
  late final $WachBelegeTable wachBelege = $WachBelegeTable(this);
  late final $UmfaengeTable umfaenge = $UmfaengeTable(this);
  late final $ZyklusEintraegeTable zyklusEintraege = $ZyklusEintraegeTable(
    this,
  );
  late final $ZyklusHealthSpiegelTable zyklusHealthSpiegel =
      $ZyklusHealthSpiegelTable(this);
  late final $ZyklusEinstellungenTable zyklusEinstellungen =
      $ZyklusEinstellungenTable(this);
  late final $GymTrainingsTable gymTrainings = $GymTrainingsTable(this);
  late final $GymTrainingUebungenTable gymTrainingUebungen =
      $GymTrainingUebungenTable(this);
  late final $GymTrainingTagsTable gymTrainingTags = $GymTrainingTagsTable(
    this,
  );
  late final $GymRotationTable gymRotation = $GymRotationTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tagesWerte,
    stundenSchritte,
    eigeneDaten,
    naechte,
    schlafAbschnitte,
    zielWerte,
    schlafEintraege,
    stammdaten,
    lebensmittel,
    portionen,
    eintraege,
    rezepte,
    rezeptZutaten,
    kiEinstellungen,
    kiAnfragen,
    wasserEintraege,
    gymSitzungen,
    gymSaetze,
    gymEntwuerfe,
    kalorienziele,
    mahlzeitAufteilungen,
    ereignisse,
    wachBelege,
    umfaenge,
    zyklusEintraege,
    zyklusHealthSpiegel,
    zyklusEinstellungen,
    gymTrainings,
    gymTrainingUebungen,
    gymTrainingTags,
    gymRotation,
  ];
}

typedef $$TagesWerteTableCreateCompanionBuilder = TagesWerteCompanion Function({
  required String tag,
  Value<int?> schritte,
  Value<int?> ruhepulsBpm,
  Value<DateTime?> gelesenAm,
  Value<double?> hrvMs,
  Value<double?> respRate,
  Value<int?> recoveryHrDrop,
  Value<double?> gewichtKg,
  Value<double?> trainingsMinuten,
  Value<double?> koerperfettPct,
  Value<double?> fettfreiKg,
  Value<double?> vo2max,
  Value<int> rowid,
});
typedef $$TagesWerteTableUpdateCompanionBuilder = TagesWerteCompanion Function({
  Value<String> tag,
  Value<int?> schritte,
  Value<int?> ruhepulsBpm,
  Value<DateTime?> gelesenAm,
  Value<double?> hrvMs,
  Value<double?> respRate,
  Value<int?> recoveryHrDrop,
  Value<double?> gewichtKg,
  Value<double?> trainingsMinuten,
  Value<double?> koerperfettPct,
  Value<double?> fettfreiKg,
  Value<double?> vo2max,
  Value<int> rowid,
});

class $$TagesWerteTableFilterComposer
    extends Composer<_$AppCache, $TagesWerteTable> {
  $$TagesWerteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schritte => $composableBuilder(
    column: $table.schritte,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gelesenAm => $composableBuilder(
    column: $table.gelesenAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hrvMs => $composableBuilder(
    column: $table.hrvMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get respRate => $composableBuilder(
    column: $table.respRate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get recoveryHrDrop => $composableBuilder(
    column: $table.recoveryHrDrop,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gewichtKg => $composableBuilder(
    column: $table.gewichtKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get trainingsMinuten => $composableBuilder(
    column: $table.trainingsMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get koerperfettPct => $composableBuilder(
    column: $table.koerperfettPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fettfreiKg => $composableBuilder(
    column: $table.fettfreiKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vo2max => $composableBuilder(
    column: $table.vo2max,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TagesWerteTableOrderingComposer
    extends Composer<_$AppCache, $TagesWerteTable> {
  $$TagesWerteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schritte => $composableBuilder(
    column: $table.schritte,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gelesenAm => $composableBuilder(
    column: $table.gelesenAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hrvMs => $composableBuilder(
    column: $table.hrvMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get respRate => $composableBuilder(
    column: $table.respRate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get recoveryHrDrop => $composableBuilder(
    column: $table.recoveryHrDrop,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gewichtKg => $composableBuilder(
    column: $table.gewichtKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get trainingsMinuten => $composableBuilder(
    column: $table.trainingsMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get koerperfettPct => $composableBuilder(
    column: $table.koerperfettPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fettfreiKg => $composableBuilder(
    column: $table.fettfreiKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vo2max => $composableBuilder(
    column: $table.vo2max,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TagesWerteTableAnnotationComposer
    extends Composer<_$AppCache, $TagesWerteTable> {
  $$TagesWerteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<int> get schritte =>
      $composableBuilder(column: $table.schritte, builder: (column) => column);

  GeneratedColumn<int> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get gelesenAm =>
      $composableBuilder(column: $table.gelesenAm, builder: (column) => column);

  GeneratedColumn<double> get hrvMs =>
      $composableBuilder(column: $table.hrvMs, builder: (column) => column);

  GeneratedColumn<double> get respRate =>
      $composableBuilder(column: $table.respRate, builder: (column) => column);

  GeneratedColumn<int> get recoveryHrDrop => $composableBuilder(
    column: $table.recoveryHrDrop,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gewichtKg =>
      $composableBuilder(column: $table.gewichtKg, builder: (column) => column);

  GeneratedColumn<double> get trainingsMinuten => $composableBuilder(
    column: $table.trainingsMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<double> get koerperfettPct => $composableBuilder(
    column: $table.koerperfettPct,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fettfreiKg => $composableBuilder(
    column: $table.fettfreiKg,
    builder: (column) => column,
  );

  GeneratedColumn<double> get vo2max =>
      $composableBuilder(column: $table.vo2max, builder: (column) => column);
}

class $$TagesWerteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $TagesWerteTable,
          TagesWerteRow,
          $$TagesWerteTableFilterComposer,
          $$TagesWerteTableOrderingComposer,
          $$TagesWerteTableAnnotationComposer,
          $$TagesWerteTableCreateCompanionBuilder,
          $$TagesWerteTableUpdateCompanionBuilder,
          (
            TagesWerteRow,
            BaseReferences<_$AppCache, $TagesWerteTable, TagesWerteRow>,
          ),
          TagesWerteRow,
          PrefetchHooks Function()
        > {
  $$TagesWerteTableTableManager(_$AppCache db, $TagesWerteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TagesWerteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TagesWerteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TagesWerteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<int?> schritte = const Value.absent(),
                Value<int?> ruhepulsBpm = const Value.absent(),
                Value<DateTime?> gelesenAm = const Value.absent(),
                Value<double?> hrvMs = const Value.absent(),
                Value<double?> respRate = const Value.absent(),
                Value<int?> recoveryHrDrop = const Value.absent(),
                Value<double?> gewichtKg = const Value.absent(),
                Value<double?> trainingsMinuten = const Value.absent(),
                Value<double?> koerperfettPct = const Value.absent(),
                Value<double?> fettfreiKg = const Value.absent(),
                Value<double?> vo2max = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagesWerteCompanion(
                tag: tag,
                schritte: schritte,
                ruhepulsBpm: ruhepulsBpm,
                gelesenAm: gelesenAm,
                hrvMs: hrvMs,
                respRate: respRate,
                recoveryHrDrop: recoveryHrDrop,
                gewichtKg: gewichtKg,
                trainingsMinuten: trainingsMinuten,
                koerperfettPct: koerperfettPct,
                fettfreiKg: fettfreiKg,
                vo2max: vo2max,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                Value<int?> schritte = const Value.absent(),
                Value<int?> ruhepulsBpm = const Value.absent(),
                Value<DateTime?> gelesenAm = const Value.absent(),
                Value<double?> hrvMs = const Value.absent(),
                Value<double?> respRate = const Value.absent(),
                Value<int?> recoveryHrDrop = const Value.absent(),
                Value<double?> gewichtKg = const Value.absent(),
                Value<double?> trainingsMinuten = const Value.absent(),
                Value<double?> koerperfettPct = const Value.absent(),
                Value<double?> fettfreiKg = const Value.absent(),
                Value<double?> vo2max = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TagesWerteCompanion.insert(
                tag: tag,
                schritte: schritte,
                ruhepulsBpm: ruhepulsBpm,
                gelesenAm: gelesenAm,
                hrvMs: hrvMs,
                respRate: respRate,
                recoveryHrDrop: recoveryHrDrop,
                gewichtKg: gewichtKg,
                trainingsMinuten: trainingsMinuten,
                koerperfettPct: koerperfettPct,
                fettfreiKg: fettfreiKg,
                vo2max: vo2max,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TagesWerteTable, TagesWerteRow>(table),
                  BaseReferences<_$AppCache, $TagesWerteTable, TagesWerteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TagesWerteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $TagesWerteTable,
      TagesWerteRow,
      $$TagesWerteTableFilterComposer,
      $$TagesWerteTableOrderingComposer,
      $$TagesWerteTableAnnotationComposer,
      $$TagesWerteTableCreateCompanionBuilder,
      $$TagesWerteTableUpdateCompanionBuilder,
      (
        TagesWerteRow,
        BaseReferences<_$AppCache, $TagesWerteTable, TagesWerteRow>,
      ),
      TagesWerteRow,
      PrefetchHooks Function()
    >;
typedef $$StundenSchritteTableCreateCompanionBuilder =
    StundenSchritteCompanion Function({
      required String tag,
      required int stunde,
      Value<int?> schritte,
      Value<int> rowid,
    });
typedef $$StundenSchritteTableUpdateCompanionBuilder =
    StundenSchritteCompanion Function({
      Value<String> tag,
      Value<int> stunde,
      Value<int?> schritte,
      Value<int> rowid,
    });

class $$StundenSchritteTableFilterComposer
    extends Composer<_$AppCache, $StundenSchritteTable> {
  $$StundenSchritteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stunde => $composableBuilder(
    column: $table.stunde,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schritte => $composableBuilder(
    column: $table.schritte,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StundenSchritteTableOrderingComposer
    extends Composer<_$AppCache, $StundenSchritteTable> {
  $$StundenSchritteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stunde => $composableBuilder(
    column: $table.stunde,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schritte => $composableBuilder(
    column: $table.schritte,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StundenSchritteTableAnnotationComposer
    extends Composer<_$AppCache, $StundenSchritteTable> {
  $$StundenSchritteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<int> get stunde =>
      $composableBuilder(column: $table.stunde, builder: (column) => column);

  GeneratedColumn<int> get schritte =>
      $composableBuilder(column: $table.schritte, builder: (column) => column);
}

class $$StundenSchritteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $StundenSchritteTable,
          StundenSchritteRow,
          $$StundenSchritteTableFilterComposer,
          $$StundenSchritteTableOrderingComposer,
          $$StundenSchritteTableAnnotationComposer,
          $$StundenSchritteTableCreateCompanionBuilder,
          $$StundenSchritteTableUpdateCompanionBuilder,
          (
            StundenSchritteRow,
            BaseReferences<
              _$AppCache,
              $StundenSchritteTable,
              StundenSchritteRow
            >,
          ),
          StundenSchritteRow,
          PrefetchHooks Function()
        > {
  $$StundenSchritteTableTableManager(_$AppCache db, $StundenSchritteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StundenSchritteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StundenSchritteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StundenSchritteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<int> stunde = const Value.absent(),
                Value<int?> schritte = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StundenSchritteCompanion(
                tag: tag,
                stunde: stunde,
                schritte: schritte,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                required int stunde,
                Value<int?> schritte = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StundenSchritteCompanion.insert(
                tag: tag,
                stunde: stunde,
                schritte: schritte,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StundenSchritteTable, StundenSchritteRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $StundenSchritteTable,
                    StundenSchritteRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StundenSchritteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $StundenSchritteTable,
      StundenSchritteRow,
      $$StundenSchritteTableFilterComposer,
      $$StundenSchritteTableOrderingComposer,
      $$StundenSchritteTableAnnotationComposer,
      $$StundenSchritteTableCreateCompanionBuilder,
      $$StundenSchritteTableUpdateCompanionBuilder,
      (
        StundenSchritteRow,
        BaseReferences<_$AppCache, $StundenSchritteTable, StundenSchritteRow>,
      ),
      StundenSchritteRow,
      PrefetchHooks Function()
    >;
typedef $$EigeneDatenTableCreateCompanionBuilder =
    EigeneDatenCompanion Function({
      Value<int> id,
      required String tag,
      required String inhalt,
    });
typedef $$EigeneDatenTableUpdateCompanionBuilder =
    EigeneDatenCompanion Function({
      Value<int> id,
      Value<String> tag,
      Value<String> inhalt,
    });

class $$EigeneDatenTableFilterComposer
    extends Composer<_$AppCache, $EigeneDatenTable> {
  $$EigeneDatenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get inhalt => $composableBuilder(
    column: $table.inhalt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EigeneDatenTableOrderingComposer
    extends Composer<_$AppCache, $EigeneDatenTable> {
  $$EigeneDatenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get inhalt => $composableBuilder(
    column: $table.inhalt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EigeneDatenTableAnnotationComposer
    extends Composer<_$AppCache, $EigeneDatenTable> {
  $$EigeneDatenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get inhalt =>
      $composableBuilder(column: $table.inhalt, builder: (column) => column);
}

class $$EigeneDatenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $EigeneDatenTable,
          EigeneDatenRow,
          $$EigeneDatenTableFilterComposer,
          $$EigeneDatenTableOrderingComposer,
          $$EigeneDatenTableAnnotationComposer,
          $$EigeneDatenTableCreateCompanionBuilder,
          $$EigeneDatenTableUpdateCompanionBuilder,
          (
            EigeneDatenRow,
            BaseReferences<_$AppCache, $EigeneDatenTable, EigeneDatenRow>,
          ),
          EigeneDatenRow,
          PrefetchHooks Function()
        > {
  $$EigeneDatenTableTableManager(_$AppCache db, $EigeneDatenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EigeneDatenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EigeneDatenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EigeneDatenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> tag = const Value.absent(),
            Value<String> inhalt = const Value.absent(),
          }) => EigeneDatenCompanion(id: id, tag: tag, inhalt: inhalt),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String tag,
            required String inhalt,
          }) => EigeneDatenCompanion.insert(id: id, tag: tag, inhalt: inhalt),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EigeneDatenTable, EigeneDatenRow>(table),
                  BaseReferences<_$AppCache, $EigeneDatenTable, EigeneDatenRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EigeneDatenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $EigeneDatenTable,
      EigeneDatenRow,
      $$EigeneDatenTableFilterComposer,
      $$EigeneDatenTableOrderingComposer,
      $$EigeneDatenTableAnnotationComposer,
      $$EigeneDatenTableCreateCompanionBuilder,
      $$EigeneDatenTableUpdateCompanionBuilder,
      (
        EigeneDatenRow,
        BaseReferences<_$AppCache, $EigeneDatenTable, EigeneDatenRow>,
      ),
      EigeneDatenRow,
      PrefetchHooks Function()
    >;
typedef $$NaechteTableCreateCompanionBuilder = NaechteCompanion Function({
  required String tag,
  Value<DateTime?> gelesenAm,
  Value<double?> ruhepulsBpm,
  Value<double?> hrvMs,
  Value<double?> respRate,
  Value<int> rowid,
});
typedef $$NaechteTableUpdateCompanionBuilder = NaechteCompanion Function({
  Value<String> tag,
  Value<DateTime?> gelesenAm,
  Value<double?> ruhepulsBpm,
  Value<double?> hrvMs,
  Value<double?> respRate,
  Value<int> rowid,
});

class $$NaechteTableFilterComposer extends Composer<_$AppCache, $NaechteTable> {
  $$NaechteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gelesenAm => $composableBuilder(
    column: $table.gelesenAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hrvMs => $composableBuilder(
    column: $table.hrvMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get respRate => $composableBuilder(
    column: $table.respRate,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NaechteTableOrderingComposer
    extends Composer<_$AppCache, $NaechteTable> {
  $$NaechteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gelesenAm => $composableBuilder(
    column: $table.gelesenAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hrvMs => $composableBuilder(
    column: $table.hrvMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get respRate => $composableBuilder(
    column: $table.respRate,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NaechteTableAnnotationComposer
    extends Composer<_$AppCache, $NaechteTable> {
  $$NaechteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<DateTime> get gelesenAm =>
      $composableBuilder(column: $table.gelesenAm, builder: (column) => column);

  GeneratedColumn<double> get ruhepulsBpm => $composableBuilder(
    column: $table.ruhepulsBpm,
    builder: (column) => column,
  );

  GeneratedColumn<double> get hrvMs =>
      $composableBuilder(column: $table.hrvMs, builder: (column) => column);

  GeneratedColumn<double> get respRate =>
      $composableBuilder(column: $table.respRate, builder: (column) => column);
}

class $$NaechteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $NaechteTable,
          NachtRow,
          $$NaechteTableFilterComposer,
          $$NaechteTableOrderingComposer,
          $$NaechteTableAnnotationComposer,
          $$NaechteTableCreateCompanionBuilder,
          $$NaechteTableUpdateCompanionBuilder,
          (NachtRow, BaseReferences<_$AppCache, $NaechteTable, NachtRow>),
          NachtRow,
          PrefetchHooks Function()
        > {
  $$NaechteTableTableManager(_$AppCache db, $NaechteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NaechteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NaechteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NaechteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<DateTime?> gelesenAm = const Value.absent(),
                Value<double?> ruhepulsBpm = const Value.absent(),
                Value<double?> hrvMs = const Value.absent(),
                Value<double?> respRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NaechteCompanion(
                tag: tag,
                gelesenAm: gelesenAm,
                ruhepulsBpm: ruhepulsBpm,
                hrvMs: hrvMs,
                respRate: respRate,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                Value<DateTime?> gelesenAm = const Value.absent(),
                Value<double?> ruhepulsBpm = const Value.absent(),
                Value<double?> hrvMs = const Value.absent(),
                Value<double?> respRate = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NaechteCompanion.insert(
                tag: tag,
                gelesenAm: gelesenAm,
                ruhepulsBpm: ruhepulsBpm,
                hrvMs: hrvMs,
                respRate: respRate,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NaechteTable, NachtRow>(table),
                  BaseReferences<_$AppCache, $NaechteTable, NachtRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NaechteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $NaechteTable,
      NachtRow,
      $$NaechteTableFilterComposer,
      $$NaechteTableOrderingComposer,
      $$NaechteTableAnnotationComposer,
      $$NaechteTableCreateCompanionBuilder,
      $$NaechteTableUpdateCompanionBuilder,
      (NachtRow, BaseReferences<_$AppCache, $NaechteTable, NachtRow>),
      NachtRow,
      PrefetchHooks Function()
    >;
typedef $$SchlafAbschnitteTableCreateCompanionBuilder =
    SchlafAbschnitteCompanion Function({
      required String tag,
      required int quelle,
      required int lfdNr,
      required String phase,
      required DateTime beginn,
      required DateTime ende,
      Value<int> rowid,
    });
typedef $$SchlafAbschnitteTableUpdateCompanionBuilder =
    SchlafAbschnitteCompanion Function({
      Value<String> tag,
      Value<int> quelle,
      Value<int> lfdNr,
      Value<String> phase,
      Value<DateTime> beginn,
      Value<DateTime> ende,
      Value<int> rowid,
    });

class $$SchlafAbschnitteTableFilterComposer
    extends Composer<_$AppCache, $SchlafAbschnitteTable> {
  $$SchlafAbschnitteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lfdNr => $composableBuilder(
    column: $table.lfdNr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get beginn => $composableBuilder(
    column: $table.beginn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get ende => $composableBuilder(
    column: $table.ende,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchlafAbschnitteTableOrderingComposer
    extends Composer<_$AppCache, $SchlafAbschnitteTable> {
  $$SchlafAbschnitteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lfdNr => $composableBuilder(
    column: $table.lfdNr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phase => $composableBuilder(
    column: $table.phase,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get beginn => $composableBuilder(
    column: $table.beginn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get ende => $composableBuilder(
    column: $table.ende,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchlafAbschnitteTableAnnotationComposer
    extends Composer<_$AppCache, $SchlafAbschnitteTable> {
  $$SchlafAbschnitteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<int> get quelle =>
      $composableBuilder(column: $table.quelle, builder: (column) => column);

  GeneratedColumn<int> get lfdNr =>
      $composableBuilder(column: $table.lfdNr, builder: (column) => column);

  GeneratedColumn<String> get phase =>
      $composableBuilder(column: $table.phase, builder: (column) => column);

  GeneratedColumn<DateTime> get beginn =>
      $composableBuilder(column: $table.beginn, builder: (column) => column);

  GeneratedColumn<DateTime> get ende =>
      $composableBuilder(column: $table.ende, builder: (column) => column);
}

class $$SchlafAbschnitteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $SchlafAbschnitteTable,
          SchlafAbschnittRow,
          $$SchlafAbschnitteTableFilterComposer,
          $$SchlafAbschnitteTableOrderingComposer,
          $$SchlafAbschnitteTableAnnotationComposer,
          $$SchlafAbschnitteTableCreateCompanionBuilder,
          $$SchlafAbschnitteTableUpdateCompanionBuilder,
          (
            SchlafAbschnittRow,
            BaseReferences<
              _$AppCache,
              $SchlafAbschnitteTable,
              SchlafAbschnittRow
            >,
          ),
          SchlafAbschnittRow,
          PrefetchHooks Function()
        > {
  $$SchlafAbschnitteTableTableManager(
    _$AppCache db,
    $SchlafAbschnitteTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchlafAbschnitteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchlafAbschnitteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchlafAbschnitteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<int> quelle = const Value.absent(),
                Value<int> lfdNr = const Value.absent(),
                Value<String> phase = const Value.absent(),
                Value<DateTime> beginn = const Value.absent(),
                Value<DateTime> ende = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchlafAbschnitteCompanion(
                tag: tag,
                quelle: quelle,
                lfdNr: lfdNr,
                phase: phase,
                beginn: beginn,
                ende: ende,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                required int quelle,
                required int lfdNr,
                required String phase,
                required DateTime beginn,
                required DateTime ende,
                Value<int> rowid = const Value.absent(),
              }) => SchlafAbschnitteCompanion.insert(
                tag: tag,
                quelle: quelle,
                lfdNr: lfdNr,
                phase: phase,
                beginn: beginn,
                ende: ende,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SchlafAbschnitteTable, SchlafAbschnittRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppCache,
                    $SchlafAbschnitteTable,
                    SchlafAbschnittRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchlafAbschnitteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $SchlafAbschnitteTable,
      SchlafAbschnittRow,
      $$SchlafAbschnitteTableFilterComposer,
      $$SchlafAbschnitteTableOrderingComposer,
      $$SchlafAbschnitteTableAnnotationComposer,
      $$SchlafAbschnitteTableCreateCompanionBuilder,
      $$SchlafAbschnitteTableUpdateCompanionBuilder,
      (
        SchlafAbschnittRow,
        BaseReferences<_$AppCache, $SchlafAbschnitteTable, SchlafAbschnittRow>,
      ),
      SchlafAbschnittRow,
      PrefetchHooks Function()
    >;
typedef $$ZielWerteTableCreateCompanionBuilder = ZielWerteCompanion Function({
  Value<int> id,
  required int schlafzielMinuten,
  required int schlafenszeitMinuten,
  required int wochenzielTrainingsminuten,
});
typedef $$ZielWerteTableUpdateCompanionBuilder = ZielWerteCompanion Function({
  Value<int> id,
  Value<int> schlafzielMinuten,
  Value<int> schlafenszeitMinuten,
  Value<int> wochenzielTrainingsminuten,
});

class $$ZielWerteTableFilterComposer
    extends Composer<_$AppCache, $ZielWerteTable> {
  $$ZielWerteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schlafzielMinuten => $composableBuilder(
    column: $table.schlafzielMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schlafenszeitMinuten => $composableBuilder(
    column: $table.schlafenszeitMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wochenzielTrainingsminuten => $composableBuilder(
    column: $table.wochenzielTrainingsminuten,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZielWerteTableOrderingComposer
    extends Composer<_$AppCache, $ZielWerteTable> {
  $$ZielWerteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schlafzielMinuten => $composableBuilder(
    column: $table.schlafzielMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schlafenszeitMinuten => $composableBuilder(
    column: $table.schlafenszeitMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wochenzielTrainingsminuten => $composableBuilder(
    column: $table.wochenzielTrainingsminuten,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZielWerteTableAnnotationComposer
    extends Composer<_$AppCache, $ZielWerteTable> {
  $$ZielWerteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get schlafzielMinuten => $composableBuilder(
    column: $table.schlafzielMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<int> get schlafenszeitMinuten => $composableBuilder(
    column: $table.schlafenszeitMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<int> get wochenzielTrainingsminuten => $composableBuilder(
    column: $table.wochenzielTrainingsminuten,
    builder: (column) => column,
  );
}

class $$ZielWerteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $ZielWerteTable,
          ZielWerteRow,
          $$ZielWerteTableFilterComposer,
          $$ZielWerteTableOrderingComposer,
          $$ZielWerteTableAnnotationComposer,
          $$ZielWerteTableCreateCompanionBuilder,
          $$ZielWerteTableUpdateCompanionBuilder,
          (
            ZielWerteRow,
            BaseReferences<_$AppCache, $ZielWerteTable, ZielWerteRow>,
          ),
          ZielWerteRow,
          PrefetchHooks Function()
        > {
  $$ZielWerteTableTableManager(_$AppCache db, $ZielWerteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZielWerteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZielWerteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZielWerteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> schlafzielMinuten = const Value.absent(),
                Value<int> schlafenszeitMinuten = const Value.absent(),
                Value<int> wochenzielTrainingsminuten = const Value.absent(),
              }) => ZielWerteCompanion(
                id: id,
                schlafzielMinuten: schlafzielMinuten,
                schlafenszeitMinuten: schlafenszeitMinuten,
                wochenzielTrainingsminuten: wochenzielTrainingsminuten,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int schlafzielMinuten,
                required int schlafenszeitMinuten,
                required int wochenzielTrainingsminuten,
              }) => ZielWerteCompanion.insert(
                id: id,
                schlafzielMinuten: schlafzielMinuten,
                schlafenszeitMinuten: schlafenszeitMinuten,
                wochenzielTrainingsminuten: wochenzielTrainingsminuten,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ZielWerteTable, ZielWerteRow>(table),
                  BaseReferences<_$AppCache, $ZielWerteTable, ZielWerteRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZielWerteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $ZielWerteTable,
      ZielWerteRow,
      $$ZielWerteTableFilterComposer,
      $$ZielWerteTableOrderingComposer,
      $$ZielWerteTableAnnotationComposer,
      $$ZielWerteTableCreateCompanionBuilder,
      $$ZielWerteTableUpdateCompanionBuilder,
      (ZielWerteRow, BaseReferences<_$AppCache, $ZielWerteTable, ZielWerteRow>),
      ZielWerteRow,
      PrefetchHooks Function()
    >;
typedef $$SchlafEintraegeTableCreateCompanionBuilder =
    SchlafEintraegeCompanion Function({
      required String tag,
      required String art,
      required int lfdNr,
      required int schlafMinuten,
      Value<int?> beginnMinuten,
      Value<int?> endeMinuten,
      Value<String?> notiz,
      Value<int> rowid,
    });
typedef $$SchlafEintraegeTableUpdateCompanionBuilder =
    SchlafEintraegeCompanion Function({
      Value<String> tag,
      Value<String> art,
      Value<int> lfdNr,
      Value<int> schlafMinuten,
      Value<int?> beginnMinuten,
      Value<int?> endeMinuten,
      Value<String?> notiz,
      Value<int> rowid,
    });

class $$SchlafEintraegeTableFilterComposer
    extends Composer<_$AppCache, $SchlafEintraegeTable> {
  $$SchlafEintraegeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lfdNr => $composableBuilder(
    column: $table.lfdNr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get schlafMinuten => $composableBuilder(
    column: $table.schlafMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get beginnMinuten => $composableBuilder(
    column: $table.beginnMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get endeMinuten => $composableBuilder(
    column: $table.endeMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SchlafEintraegeTableOrderingComposer
    extends Composer<_$AppCache, $SchlafEintraegeTable> {
  $$SchlafEintraegeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lfdNr => $composableBuilder(
    column: $table.lfdNr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get schlafMinuten => $composableBuilder(
    column: $table.schlafMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get beginnMinuten => $composableBuilder(
    column: $table.beginnMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get endeMinuten => $composableBuilder(
    column: $table.endeMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SchlafEintraegeTableAnnotationComposer
    extends Composer<_$AppCache, $SchlafEintraegeTable> {
  $$SchlafEintraegeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get art =>
      $composableBuilder(column: $table.art, builder: (column) => column);

  GeneratedColumn<int> get lfdNr =>
      $composableBuilder(column: $table.lfdNr, builder: (column) => column);

  GeneratedColumn<int> get schlafMinuten => $composableBuilder(
    column: $table.schlafMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<int> get beginnMinuten => $composableBuilder(
    column: $table.beginnMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<int> get endeMinuten => $composableBuilder(
    column: $table.endeMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);
}

class $$SchlafEintraegeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $SchlafEintraegeTable,
          SchlafEintragRow,
          $$SchlafEintraegeTableFilterComposer,
          $$SchlafEintraegeTableOrderingComposer,
          $$SchlafEintraegeTableAnnotationComposer,
          $$SchlafEintraegeTableCreateCompanionBuilder,
          $$SchlafEintraegeTableUpdateCompanionBuilder,
          (
            SchlafEintragRow,
            BaseReferences<_$AppCache, $SchlafEintraegeTable, SchlafEintragRow>,
          ),
          SchlafEintragRow,
          PrefetchHooks Function()
        > {
  $$SchlafEintraegeTableTableManager(_$AppCache db, $SchlafEintraegeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SchlafEintraegeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SchlafEintraegeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SchlafEintraegeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<String> art = const Value.absent(),
                Value<int> lfdNr = const Value.absent(),
                Value<int> schlafMinuten = const Value.absent(),
                Value<int?> beginnMinuten = const Value.absent(),
                Value<int?> endeMinuten = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchlafEintraegeCompanion(
                tag: tag,
                art: art,
                lfdNr: lfdNr,
                schlafMinuten: schlafMinuten,
                beginnMinuten: beginnMinuten,
                endeMinuten: endeMinuten,
                notiz: notiz,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                required String art,
                required int lfdNr,
                required int schlafMinuten,
                Value<int?> beginnMinuten = const Value.absent(),
                Value<int?> endeMinuten = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SchlafEintraegeCompanion.insert(
                tag: tag,
                art: art,
                lfdNr: lfdNr,
                schlafMinuten: schlafMinuten,
                beginnMinuten: beginnMinuten,
                endeMinuten: endeMinuten,
                notiz: notiz,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SchlafEintraegeTable, SchlafEintragRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $SchlafEintraegeTable,
                    SchlafEintragRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SchlafEintraegeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $SchlafEintraegeTable,
      SchlafEintragRow,
      $$SchlafEintraegeTableFilterComposer,
      $$SchlafEintraegeTableOrderingComposer,
      $$SchlafEintraegeTableAnnotationComposer,
      $$SchlafEintraegeTableCreateCompanionBuilder,
      $$SchlafEintraegeTableUpdateCompanionBuilder,
      (
        SchlafEintragRow,
        BaseReferences<_$AppCache, $SchlafEintraegeTable, SchlafEintragRow>,
      ),
      SchlafEintragRow,
      PrefetchHooks Function()
    >;
typedef $$StammdatenTableCreateCompanionBuilder = StammdatenCompanion Function({
  Value<int> id,
  Value<int?> groesseCm,
  Value<int?> geburtsjahr,
  Value<double?> zielgewichtKg,
  Value<String?> zieldatum,
});
typedef $$StammdatenTableUpdateCompanionBuilder = StammdatenCompanion Function({
  Value<int> id,
  Value<int?> groesseCm,
  Value<int?> geburtsjahr,
  Value<double?> zielgewichtKg,
  Value<String?> zieldatum,
});

class $$StammdatenTableFilterComposer
    extends Composer<_$AppCache, $StammdatenTable> {
  $$StammdatenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get groesseCm => $composableBuilder(
    column: $table.groesseCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get geburtsjahr => $composableBuilder(
    column: $table.geburtsjahr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get zielgewichtKg => $composableBuilder(
    column: $table.zielgewichtKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zieldatum => $composableBuilder(
    column: $table.zieldatum,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StammdatenTableOrderingComposer
    extends Composer<_$AppCache, $StammdatenTable> {
  $$StammdatenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get groesseCm => $composableBuilder(
    column: $table.groesseCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get geburtsjahr => $composableBuilder(
    column: $table.geburtsjahr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get zielgewichtKg => $composableBuilder(
    column: $table.zielgewichtKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zieldatum => $composableBuilder(
    column: $table.zieldatum,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StammdatenTableAnnotationComposer
    extends Composer<_$AppCache, $StammdatenTable> {
  $$StammdatenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get groesseCm =>
      $composableBuilder(column: $table.groesseCm, builder: (column) => column);

  GeneratedColumn<int> get geburtsjahr => $composableBuilder(
    column: $table.geburtsjahr,
    builder: (column) => column,
  );

  GeneratedColumn<double> get zielgewichtKg => $composableBuilder(
    column: $table.zielgewichtKg,
    builder: (column) => column,
  );

  GeneratedColumn<String> get zieldatum =>
      $composableBuilder(column: $table.zieldatum, builder: (column) => column);
}

class $$StammdatenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $StammdatenTable,
          StammdatenRow,
          $$StammdatenTableFilterComposer,
          $$StammdatenTableOrderingComposer,
          $$StammdatenTableAnnotationComposer,
          $$StammdatenTableCreateCompanionBuilder,
          $$StammdatenTableUpdateCompanionBuilder,
          (
            StammdatenRow,
            BaseReferences<_$AppCache, $StammdatenTable, StammdatenRow>,
          ),
          StammdatenRow,
          PrefetchHooks Function()
        > {
  $$StammdatenTableTableManager(_$AppCache db, $StammdatenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StammdatenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StammdatenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StammdatenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groesseCm = const Value.absent(),
                Value<int?> geburtsjahr = const Value.absent(),
                Value<double?> zielgewichtKg = const Value.absent(),
                Value<String?> zieldatum = const Value.absent(),
              }) => StammdatenCompanion(
                id: id,
                groesseCm: groesseCm,
                geburtsjahr: geburtsjahr,
                zielgewichtKg: zielgewichtKg,
                zieldatum: zieldatum,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> groesseCm = const Value.absent(),
                Value<int?> geburtsjahr = const Value.absent(),
                Value<double?> zielgewichtKg = const Value.absent(),
                Value<String?> zieldatum = const Value.absent(),
              }) => StammdatenCompanion.insert(
                id: id,
                groesseCm: groesseCm,
                geburtsjahr: geburtsjahr,
                zielgewichtKg: zielgewichtKg,
                zieldatum: zieldatum,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StammdatenTable, StammdatenRow>(table),
                  BaseReferences<_$AppCache, $StammdatenTable, StammdatenRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StammdatenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $StammdatenTable,
      StammdatenRow,
      $$StammdatenTableFilterComposer,
      $$StammdatenTableOrderingComposer,
      $$StammdatenTableAnnotationComposer,
      $$StammdatenTableCreateCompanionBuilder,
      $$StammdatenTableUpdateCompanionBuilder,
      (
        StammdatenRow,
        BaseReferences<_$AppCache, $StammdatenTable, StammdatenRow>,
      ),
      StammdatenRow,
      PrefetchHooks Function()
    >;
typedef $$LebensmittelTableCreateCompanionBuilder =
    LebensmittelCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double?> kcal,
      Value<double?> eiweissG,
      Value<double?> kohlenhydrateG,
      Value<double?> fettG,
      Value<double?> zuckerG,
      Value<double?> ballaststoffeG,
      Value<double?> gesaettigtG,
      Value<double?> wasserMl,
      Value<String> extra,
      Value<bool> fluessig,
      Value<DateTime?> zuletztBenutzt,
      Value<String?> barcode,
      Value<String> herkunft,
      Value<DateTime?> portionenAbgefragtAm,
      Value<String?> uuid,
      Value<DateTime?> geaendertAm,
      Value<DateTime?> geloeschtAm,
      Value<String?> autor,
      Value<String?> quelleSchluessel,
    });
typedef $$LebensmittelTableUpdateCompanionBuilder =
    LebensmittelCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<double?> kcal,
      Value<double?> eiweissG,
      Value<double?> kohlenhydrateG,
      Value<double?> fettG,
      Value<double?> zuckerG,
      Value<double?> ballaststoffeG,
      Value<double?> gesaettigtG,
      Value<double?> wasserMl,
      Value<String> extra,
      Value<bool> fluessig,
      Value<DateTime?> zuletztBenutzt,
      Value<String?> barcode,
      Value<String> herkunft,
      Value<DateTime?> portionenAbgefragtAm,
      Value<String?> uuid,
      Value<DateTime?> geaendertAm,
      Value<DateTime?> geloeschtAm,
      Value<String?> autor,
      Value<String?> quelleSchluessel,
    });

class $$LebensmittelTableFilterComposer
    extends Composer<_$AppCache, $LebensmittelTable> {
  $$LebensmittelTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get eiweissG => $composableBuilder(
    column: $table.eiweissG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fettG => $composableBuilder(
    column: $table.fettG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get zuckerG => $composableBuilder(
    column: $table.zuckerG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wasserMl => $composableBuilder(
    column: $table.wasserMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fluessig => $composableBuilder(
    column: $table.fluessig,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zuletztBenutzt => $composableBuilder(
    column: $table.zuletztBenutzt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get portionenAbgefragtAm => $composableBuilder(
    column: $table.portionenAbgefragtAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quelleSchluessel => $composableBuilder(
    column: $table.quelleSchluessel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LebensmittelTableOrderingComposer
    extends Composer<_$AppCache, $LebensmittelTable> {
  $$LebensmittelTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get eiweissG => $composableBuilder(
    column: $table.eiweissG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fettG => $composableBuilder(
    column: $table.fettG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get zuckerG => $composableBuilder(
    column: $table.zuckerG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wasserMl => $composableBuilder(
    column: $table.wasserMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fluessig => $composableBuilder(
    column: $table.fluessig,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zuletztBenutzt => $composableBuilder(
    column: $table.zuletztBenutzt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get portionenAbgefragtAm => $composableBuilder(
    column: $table.portionenAbgefragtAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quelleSchluessel => $composableBuilder(
    column: $table.quelleSchluessel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LebensmittelTableAnnotationComposer
    extends Composer<_$AppCache, $LebensmittelTable> {
  $$LebensmittelTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get eiweissG =>
      $composableBuilder(column: $table.eiweissG, builder: (column) => column);

  GeneratedColumn<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fettG =>
      $composableBuilder(column: $table.fettG, builder: (column) => column);

  GeneratedColumn<double> get zuckerG =>
      $composableBuilder(column: $table.zuckerG, builder: (column) => column);

  GeneratedColumn<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wasserMl =>
      $composableBuilder(column: $table.wasserMl, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);

  GeneratedColumn<bool> get fluessig =>
      $composableBuilder(column: $table.fluessig, builder: (column) => column);

  GeneratedColumn<DateTime> get zuletztBenutzt => $composableBuilder(
    column: $table.zuletztBenutzt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<String> get herkunft =>
      $composableBuilder(column: $table.herkunft, builder: (column) => column);

  GeneratedColumn<DateTime> get portionenAbgefragtAm => $composableBuilder(
    column: $table.portionenAbgefragtAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get autor =>
      $composableBuilder(column: $table.autor, builder: (column) => column);

  GeneratedColumn<String> get quelleSchluessel => $composableBuilder(
    column: $table.quelleSchluessel,
    builder: (column) => column,
  );
}

class $$LebensmittelTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $LebensmittelTable,
          LebensmittelRow,
          $$LebensmittelTableFilterComposer,
          $$LebensmittelTableOrderingComposer,
          $$LebensmittelTableAnnotationComposer,
          $$LebensmittelTableCreateCompanionBuilder,
          $$LebensmittelTableUpdateCompanionBuilder,
          (
            LebensmittelRow,
            BaseReferences<_$AppCache, $LebensmittelTable, LebensmittelRow>,
          ),
          LebensmittelRow,
          PrefetchHooks Function()
        > {
  $$LebensmittelTableTableManager(_$AppCache db, $LebensmittelTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LebensmittelTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LebensmittelTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LebensmittelTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> eiweissG = const Value.absent(),
                Value<double?> kohlenhydrateG = const Value.absent(),
                Value<double?> fettG = const Value.absent(),
                Value<double?> zuckerG = const Value.absent(),
                Value<double?> ballaststoffeG = const Value.absent(),
                Value<double?> gesaettigtG = const Value.absent(),
                Value<double?> wasserMl = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<bool> fluessig = const Value.absent(),
                Value<DateTime?> zuletztBenutzt = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> herkunft = const Value.absent(),
                Value<DateTime?> portionenAbgefragtAm = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<DateTime?> geaendertAm = const Value.absent(),
                Value<DateTime?> geloeschtAm = const Value.absent(),
                Value<String?> autor = const Value.absent(),
                Value<String?> quelleSchluessel = const Value.absent(),
              }) => LebensmittelCompanion(
                id: id,
                name: name,
                kcal: kcal,
                eiweissG: eiweissG,
                kohlenhydrateG: kohlenhydrateG,
                fettG: fettG,
                zuckerG: zuckerG,
                ballaststoffeG: ballaststoffeG,
                gesaettigtG: gesaettigtG,
                wasserMl: wasserMl,
                extra: extra,
                fluessig: fluessig,
                zuletztBenutzt: zuletztBenutzt,
                barcode: barcode,
                herkunft: herkunft,
                portionenAbgefragtAm: portionenAbgefragtAm,
                uuid: uuid,
                geaendertAm: geaendertAm,
                geloeschtAm: geloeschtAm,
                autor: autor,
                quelleSchluessel: quelleSchluessel,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> eiweissG = const Value.absent(),
                Value<double?> kohlenhydrateG = const Value.absent(),
                Value<double?> fettG = const Value.absent(),
                Value<double?> zuckerG = const Value.absent(),
                Value<double?> ballaststoffeG = const Value.absent(),
                Value<double?> gesaettigtG = const Value.absent(),
                Value<double?> wasserMl = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<bool> fluessig = const Value.absent(),
                Value<DateTime?> zuletztBenutzt = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<String> herkunft = const Value.absent(),
                Value<DateTime?> portionenAbgefragtAm = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<DateTime?> geaendertAm = const Value.absent(),
                Value<DateTime?> geloeschtAm = const Value.absent(),
                Value<String?> autor = const Value.absent(),
                Value<String?> quelleSchluessel = const Value.absent(),
              }) => LebensmittelCompanion.insert(
                id: id,
                name: name,
                kcal: kcal,
                eiweissG: eiweissG,
                kohlenhydrateG: kohlenhydrateG,
                fettG: fettG,
                zuckerG: zuckerG,
                ballaststoffeG: ballaststoffeG,
                gesaettigtG: gesaettigtG,
                wasserMl: wasserMl,
                extra: extra,
                fluessig: fluessig,
                zuletztBenutzt: zuletztBenutzt,
                barcode: barcode,
                herkunft: herkunft,
                portionenAbgefragtAm: portionenAbgefragtAm,
                uuid: uuid,
                geaendertAm: geaendertAm,
                geloeschtAm: geloeschtAm,
                autor: autor,
                quelleSchluessel: quelleSchluessel,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LebensmittelTable, LebensmittelRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $LebensmittelTable,
                    LebensmittelRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LebensmittelTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $LebensmittelTable,
      LebensmittelRow,
      $$LebensmittelTableFilterComposer,
      $$LebensmittelTableOrderingComposer,
      $$LebensmittelTableAnnotationComposer,
      $$LebensmittelTableCreateCompanionBuilder,
      $$LebensmittelTableUpdateCompanionBuilder,
      (
        LebensmittelRow,
        BaseReferences<_$AppCache, $LebensmittelTable, LebensmittelRow>,
      ),
      LebensmittelRow,
      PrefetchHooks Function()
    >;
typedef $$PortionenTableCreateCompanionBuilder = PortionenCompanion Function({
  Value<int> id,
  Value<int?> lebensmittelId,
  Value<String> name,
  Value<double?> mengeG,
  Value<String> herkunft,
});
typedef $$PortionenTableUpdateCompanionBuilder = PortionenCompanion Function({
  Value<int> id,
  Value<int?> lebensmittelId,
  Value<String> name,
  Value<double?> mengeG,
  Value<String> herkunft,
});

class $$PortionenTableFilterComposer
    extends Composer<_$AppCache, $PortionenTable> {
  $$PortionenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mengeG => $composableBuilder(
    column: $table.mengeG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PortionenTableOrderingComposer
    extends Composer<_$AppCache, $PortionenTable> {
  $$PortionenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mengeG => $composableBuilder(
    column: $table.mengeG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PortionenTableAnnotationComposer
    extends Composer<_$AppCache, $PortionenTable> {
  $$PortionenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get mengeG =>
      $composableBuilder(column: $table.mengeG, builder: (column) => column);

  GeneratedColumn<String> get herkunft =>
      $composableBuilder(column: $table.herkunft, builder: (column) => column);
}

class $$PortionenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $PortionenTable,
          PortionRow,
          $$PortionenTableFilterComposer,
          $$PortionenTableOrderingComposer,
          $$PortionenTableAnnotationComposer,
          $$PortionenTableCreateCompanionBuilder,
          $$PortionenTableUpdateCompanionBuilder,
          (PortionRow, BaseReferences<_$AppCache, $PortionenTable, PortionRow>),
          PortionRow,
          PrefetchHooks Function()
        > {
  $$PortionenTableTableManager(_$AppCache db, $PortionenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PortionenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PortionenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PortionenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lebensmittelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> mengeG = const Value.absent(),
                Value<String> herkunft = const Value.absent(),
              }) => PortionenCompanion(
                id: id,
                lebensmittelId: lebensmittelId,
                name: name,
                mengeG: mengeG,
                herkunft: herkunft,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> lebensmittelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> mengeG = const Value.absent(),
                Value<String> herkunft = const Value.absent(),
              }) => PortionenCompanion.insert(
                id: id,
                lebensmittelId: lebensmittelId,
                name: name,
                mengeG: mengeG,
                herkunft: herkunft,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PortionenTable, PortionRow>(table),
                  BaseReferences<_$AppCache, $PortionenTable, PortionRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PortionenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $PortionenTable,
      PortionRow,
      $$PortionenTableFilterComposer,
      $$PortionenTableOrderingComposer,
      $$PortionenTableAnnotationComposer,
      $$PortionenTableCreateCompanionBuilder,
      $$PortionenTableUpdateCompanionBuilder,
      (PortionRow, BaseReferences<_$AppCache, $PortionenTable, PortionRow>),
      PortionRow,
      PrefetchHooks Function()
    >;
typedef $$EintraegeTableCreateCompanionBuilder = EintraegeCompanion Function({
  Value<int> id,
  required String tagesSchluessel,
  required String mahlzeit,
  required DateTime zeitpunkt,
  Value<int?> lebensmittelId,
  required String name,
  Value<double?> mengeG,
  Value<double?> kcal,
  Value<double?> eiweissG,
  Value<double?> kohlenhydrateG,
  Value<double?> fettG,
  Value<double?> zuckerG,
  Value<double?> ballaststoffeG,
  Value<double?> gesaettigtG,
  Value<double?> wasserMl,
  Value<String> extra,
  Value<String?> healthUuid,
  Value<String> healthStand,
  Value<String?> vorschlag,
  Value<int?> portionId,
  Value<String?> portionName,
  Value<double?> portionG,
  Value<bool?> fluessig,
});
typedef $$EintraegeTableUpdateCompanionBuilder = EintraegeCompanion Function({
  Value<int> id,
  Value<String> tagesSchluessel,
  Value<String> mahlzeit,
  Value<DateTime> zeitpunkt,
  Value<int?> lebensmittelId,
  Value<String> name,
  Value<double?> mengeG,
  Value<double?> kcal,
  Value<double?> eiweissG,
  Value<double?> kohlenhydrateG,
  Value<double?> fettG,
  Value<double?> zuckerG,
  Value<double?> ballaststoffeG,
  Value<double?> gesaettigtG,
  Value<double?> wasserMl,
  Value<String> extra,
  Value<String?> healthUuid,
  Value<String> healthStand,
  Value<String?> vorschlag,
  Value<int?> portionId,
  Value<String?> portionName,
  Value<double?> portionG,
  Value<bool?> fluessig,
});

class $$EintraegeTableFilterComposer
    extends Composer<_$AppCache, $EintraegeTable> {
  $$EintraegeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mahlzeit => $composableBuilder(
    column: $table.mahlzeit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mengeG => $composableBuilder(
    column: $table.mengeG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get eiweissG => $composableBuilder(
    column: $table.eiweissG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fettG => $composableBuilder(
    column: $table.fettG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get zuckerG => $composableBuilder(
    column: $table.zuckerG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get wasserMl => $composableBuilder(
    column: $table.wasserMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get vorschlag => $composableBuilder(
    column: $table.vorschlag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get portionId => $composableBuilder(
    column: $table.portionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get portionG => $composableBuilder(
    column: $table.portionG,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get fluessig => $composableBuilder(
    column: $table.fluessig,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EintraegeTableOrderingComposer
    extends Composer<_$AppCache, $EintraegeTable> {
  $$EintraegeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mahlzeit => $composableBuilder(
    column: $table.mahlzeit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mengeG => $composableBuilder(
    column: $table.mengeG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get eiweissG => $composableBuilder(
    column: $table.eiweissG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fettG => $composableBuilder(
    column: $table.fettG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get zuckerG => $composableBuilder(
    column: $table.zuckerG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get wasserMl => $composableBuilder(
    column: $table.wasserMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extra => $composableBuilder(
    column: $table.extra,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get vorschlag => $composableBuilder(
    column: $table.vorschlag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get portionId => $composableBuilder(
    column: $table.portionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get portionG => $composableBuilder(
    column: $table.portionG,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get fluessig => $composableBuilder(
    column: $table.fluessig,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EintraegeTableAnnotationComposer
    extends Composer<_$AppCache, $EintraegeTable> {
  $$EintraegeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mahlzeit =>
      $composableBuilder(column: $table.mahlzeit, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<int> get lebensmittelId => $composableBuilder(
    column: $table.lebensmittelId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<double> get mengeG =>
      $composableBuilder(column: $table.mengeG, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<double> get eiweissG =>
      $composableBuilder(column: $table.eiweissG, builder: (column) => column);

  GeneratedColumn<double> get kohlenhydrateG => $composableBuilder(
    column: $table.kohlenhydrateG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get fettG =>
      $composableBuilder(column: $table.fettG, builder: (column) => column);

  GeneratedColumn<double> get zuckerG =>
      $composableBuilder(column: $table.zuckerG, builder: (column) => column);

  GeneratedColumn<double> get ballaststoffeG => $composableBuilder(
    column: $table.ballaststoffeG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get gesaettigtG => $composableBuilder(
    column: $table.gesaettigtG,
    builder: (column) => column,
  );

  GeneratedColumn<double> get wasserMl =>
      $composableBuilder(column: $table.wasserMl, builder: (column) => column);

  GeneratedColumn<String> get extra =>
      $composableBuilder(column: $table.extra, builder: (column) => column);

  GeneratedColumn<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => column,
  );

  GeneratedColumn<String> get vorschlag =>
      $composableBuilder(column: $table.vorschlag, builder: (column) => column);

  GeneratedColumn<int> get portionId =>
      $composableBuilder(column: $table.portionId, builder: (column) => column);

  GeneratedColumn<String> get portionName => $composableBuilder(
    column: $table.portionName,
    builder: (column) => column,
  );

  GeneratedColumn<double> get portionG =>
      $composableBuilder(column: $table.portionG, builder: (column) => column);

  GeneratedColumn<bool> get fluessig =>
      $composableBuilder(column: $table.fluessig, builder: (column) => column);
}

class $$EintraegeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $EintraegeTable,
          EintragRow,
          $$EintraegeTableFilterComposer,
          $$EintraegeTableOrderingComposer,
          $$EintraegeTableAnnotationComposer,
          $$EintraegeTableCreateCompanionBuilder,
          $$EintraegeTableUpdateCompanionBuilder,
          (EintragRow, BaseReferences<_$AppCache, $EintraegeTable, EintragRow>),
          EintragRow,
          PrefetchHooks Function()
        > {
  $$EintraegeTableTableManager(_$AppCache db, $EintraegeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EintraegeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EintraegeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EintraegeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tagesSchluessel = const Value.absent(),
                Value<String> mahlzeit = const Value.absent(),
                Value<DateTime> zeitpunkt = const Value.absent(),
                Value<int?> lebensmittelId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<double?> mengeG = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> eiweissG = const Value.absent(),
                Value<double?> kohlenhydrateG = const Value.absent(),
                Value<double?> fettG = const Value.absent(),
                Value<double?> zuckerG = const Value.absent(),
                Value<double?> ballaststoffeG = const Value.absent(),
                Value<double?> gesaettigtG = const Value.absent(),
                Value<double?> wasserMl = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<String?> healthUuid = const Value.absent(),
                Value<String> healthStand = const Value.absent(),
                Value<String?> vorschlag = const Value.absent(),
                Value<int?> portionId = const Value.absent(),
                Value<String?> portionName = const Value.absent(),
                Value<double?> portionG = const Value.absent(),
                Value<bool?> fluessig = const Value.absent(),
              }) => EintraegeCompanion(
                id: id,
                tagesSchluessel: tagesSchluessel,
                mahlzeit: mahlzeit,
                zeitpunkt: zeitpunkt,
                lebensmittelId: lebensmittelId,
                name: name,
                mengeG: mengeG,
                kcal: kcal,
                eiweissG: eiweissG,
                kohlenhydrateG: kohlenhydrateG,
                fettG: fettG,
                zuckerG: zuckerG,
                ballaststoffeG: ballaststoffeG,
                gesaettigtG: gesaettigtG,
                wasserMl: wasserMl,
                extra: extra,
                healthUuid: healthUuid,
                healthStand: healthStand,
                vorschlag: vorschlag,
                portionId: portionId,
                portionName: portionName,
                portionG: portionG,
                fluessig: fluessig,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tagesSchluessel,
                required String mahlzeit,
                required DateTime zeitpunkt,
                Value<int?> lebensmittelId = const Value.absent(),
                required String name,
                Value<double?> mengeG = const Value.absent(),
                Value<double?> kcal = const Value.absent(),
                Value<double?> eiweissG = const Value.absent(),
                Value<double?> kohlenhydrateG = const Value.absent(),
                Value<double?> fettG = const Value.absent(),
                Value<double?> zuckerG = const Value.absent(),
                Value<double?> ballaststoffeG = const Value.absent(),
                Value<double?> gesaettigtG = const Value.absent(),
                Value<double?> wasserMl = const Value.absent(),
                Value<String> extra = const Value.absent(),
                Value<String?> healthUuid = const Value.absent(),
                Value<String> healthStand = const Value.absent(),
                Value<String?> vorschlag = const Value.absent(),
                Value<int?> portionId = const Value.absent(),
                Value<String?> portionName = const Value.absent(),
                Value<double?> portionG = const Value.absent(),
                Value<bool?> fluessig = const Value.absent(),
              }) => EintraegeCompanion.insert(
                id: id,
                tagesSchluessel: tagesSchluessel,
                mahlzeit: mahlzeit,
                zeitpunkt: zeitpunkt,
                lebensmittelId: lebensmittelId,
                name: name,
                mengeG: mengeG,
                kcal: kcal,
                eiweissG: eiweissG,
                kohlenhydrateG: kohlenhydrateG,
                fettG: fettG,
                zuckerG: zuckerG,
                ballaststoffeG: ballaststoffeG,
                gesaettigtG: gesaettigtG,
                wasserMl: wasserMl,
                extra: extra,
                healthUuid: healthUuid,
                healthStand: healthStand,
                vorschlag: vorschlag,
                portionId: portionId,
                portionName: portionName,
                portionG: portionG,
                fluessig: fluessig,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EintraegeTable, EintragRow>(table),
                  BaseReferences<_$AppCache, $EintraegeTable, EintragRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EintraegeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $EintraegeTable,
      EintragRow,
      $$EintraegeTableFilterComposer,
      $$EintraegeTableOrderingComposer,
      $$EintraegeTableAnnotationComposer,
      $$EintraegeTableCreateCompanionBuilder,
      $$EintraegeTableUpdateCompanionBuilder,
      (EintragRow, BaseReferences<_$AppCache, $EintraegeTable, EintragRow>),
      EintragRow,
      PrefetchHooks Function()
    >;
typedef $$RezepteTableCreateCompanionBuilder = RezepteCompanion Function({
  Value<int> id,
  Value<String?> uuid,
  Value<DateTime?> geaendertAm,
  Value<DateTime?> geloeschtAm,
  Value<String?> autor,
});
typedef $$RezepteTableUpdateCompanionBuilder = RezepteCompanion Function({
  Value<int> id,
  Value<String?> uuid,
  Value<DateTime?> geaendertAm,
  Value<DateTime?> geloeschtAm,
  Value<String?> autor,
});

class $$RezepteTableFilterComposer extends Composer<_$AppCache, $RezepteTable> {
  $$RezepteTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RezepteTableOrderingComposer
    extends Composer<_$AppCache, $RezepteTable> {
  $$RezepteTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get autor => $composableBuilder(
    column: $table.autor,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RezepteTableAnnotationComposer
    extends Composer<_$AppCache, $RezepteTable> {
  $$RezepteTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get geaendertAm => $composableBuilder(
    column: $table.geaendertAm,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get geloeschtAm => $composableBuilder(
    column: $table.geloeschtAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get autor =>
      $composableBuilder(column: $table.autor, builder: (column) => column);
}

class $$RezepteTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $RezepteTable,
          RezeptRow,
          $$RezepteTableFilterComposer,
          $$RezepteTableOrderingComposer,
          $$RezepteTableAnnotationComposer,
          $$RezepteTableCreateCompanionBuilder,
          $$RezepteTableUpdateCompanionBuilder,
          (RezeptRow, BaseReferences<_$AppCache, $RezepteTable, RezeptRow>),
          RezeptRow,
          PrefetchHooks Function()
        > {
  $$RezepteTableTableManager(_$AppCache db, $RezepteTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RezepteTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RezepteTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RezepteTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<DateTime?> geaendertAm = const Value.absent(),
                Value<DateTime?> geloeschtAm = const Value.absent(),
                Value<String?> autor = const Value.absent(),
              }) => RezepteCompanion(
                id: id,
                uuid: uuid,
                geaendertAm: geaendertAm,
                geloeschtAm: geloeschtAm,
                autor: autor,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> uuid = const Value.absent(),
                Value<DateTime?> geaendertAm = const Value.absent(),
                Value<DateTime?> geloeschtAm = const Value.absent(),
                Value<String?> autor = const Value.absent(),
              }) => RezepteCompanion.insert(
                id: id,
                uuid: uuid,
                geaendertAm: geaendertAm,
                geloeschtAm: geloeschtAm,
                autor: autor,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RezepteTable, RezeptRow>(table),
                  BaseReferences<_$AppCache, $RezepteTable, RezeptRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RezepteTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $RezepteTable,
      RezeptRow,
      $$RezepteTableFilterComposer,
      $$RezepteTableOrderingComposer,
      $$RezepteTableAnnotationComposer,
      $$RezepteTableCreateCompanionBuilder,
      $$RezepteTableUpdateCompanionBuilder,
      (RezeptRow, BaseReferences<_$AppCache, $RezepteTable, RezeptRow>),
      RezeptRow,
      PrefetchHooks Function()
    >;
typedef $$RezeptZutatenTableCreateCompanionBuilder =
    RezeptZutatenCompanion Function({Value<int> id});
typedef $$RezeptZutatenTableUpdateCompanionBuilder =
    RezeptZutatenCompanion Function({Value<int> id});

class $$RezeptZutatenTableFilterComposer
    extends Composer<_$AppCache, $RezeptZutatenTable> {
  $$RezeptZutatenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RezeptZutatenTableOrderingComposer
    extends Composer<_$AppCache, $RezeptZutatenTable> {
  $$RezeptZutatenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RezeptZutatenTableAnnotationComposer
    extends Composer<_$AppCache, $RezeptZutatenTable> {
  $$RezeptZutatenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);
}

class $$RezeptZutatenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $RezeptZutatenTable,
          RezeptZutatRow,
          $$RezeptZutatenTableFilterComposer,
          $$RezeptZutatenTableOrderingComposer,
          $$RezeptZutatenTableAnnotationComposer,
          $$RezeptZutatenTableCreateCompanionBuilder,
          $$RezeptZutatenTableUpdateCompanionBuilder,
          (
            RezeptZutatRow,
            BaseReferences<_$AppCache, $RezeptZutatenTable, RezeptZutatRow>,
          ),
          RezeptZutatRow,
          PrefetchHooks Function()
        > {
  $$RezeptZutatenTableTableManager(_$AppCache db, $RezeptZutatenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RezeptZutatenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RezeptZutatenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RezeptZutatenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              RezeptZutatenCompanion(id: id),
          createCompanionCallback: ({Value<int> id = const Value.absent()}) =>
              RezeptZutatenCompanion.insert(id: id),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RezeptZutatenTable, RezeptZutatRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $RezeptZutatenTable,
                    RezeptZutatRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RezeptZutatenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $RezeptZutatenTable,
      RezeptZutatRow,
      $$RezeptZutatenTableFilterComposer,
      $$RezeptZutatenTableOrderingComposer,
      $$RezeptZutatenTableAnnotationComposer,
      $$RezeptZutatenTableCreateCompanionBuilder,
      $$RezeptZutatenTableUpdateCompanionBuilder,
      (
        RezeptZutatRow,
        BaseReferences<_$AppCache, $RezeptZutatenTable, RezeptZutatRow>,
      ),
      RezeptZutatRow,
      PrefetchHooks Function()
    >;
typedef $$KiEinstellungenTableCreateCompanionBuilder =
    KiEinstellungenCompanion Function({
      Value<int> id,
      Value<String?> modell,
      Value<double?> limitUsd,
      Value<String> preise,
      Value<DateTime?> geprueftAm,
      Value<String?> pruefErgebnis,
    });
typedef $$KiEinstellungenTableUpdateCompanionBuilder =
    KiEinstellungenCompanion Function({
      Value<int> id,
      Value<String?> modell,
      Value<double?> limitUsd,
      Value<String> preise,
      Value<DateTime?> geprueftAm,
      Value<String?> pruefErgebnis,
    });

class $$KiEinstellungenTableFilterComposer
    extends Composer<_$AppCache, $KiEinstellungenTable> {
  $$KiEinstellungenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modell => $composableBuilder(
    column: $table.modell,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get limitUsd => $composableBuilder(
    column: $table.limitUsd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preise => $composableBuilder(
    column: $table.preise,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geprueftAm => $composableBuilder(
    column: $table.geprueftAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pruefErgebnis => $composableBuilder(
    column: $table.pruefErgebnis,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KiEinstellungenTableOrderingComposer
    extends Composer<_$AppCache, $KiEinstellungenTable> {
  $$KiEinstellungenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modell => $composableBuilder(
    column: $table.modell,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get limitUsd => $composableBuilder(
    column: $table.limitUsd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preise => $composableBuilder(
    column: $table.preise,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geprueftAm => $composableBuilder(
    column: $table.geprueftAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pruefErgebnis => $composableBuilder(
    column: $table.pruefErgebnis,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KiEinstellungenTableAnnotationComposer
    extends Composer<_$AppCache, $KiEinstellungenTable> {
  $$KiEinstellungenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get modell =>
      $composableBuilder(column: $table.modell, builder: (column) => column);

  GeneratedColumn<double> get limitUsd =>
      $composableBuilder(column: $table.limitUsd, builder: (column) => column);

  GeneratedColumn<String> get preise =>
      $composableBuilder(column: $table.preise, builder: (column) => column);

  GeneratedColumn<DateTime> get geprueftAm => $composableBuilder(
    column: $table.geprueftAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pruefErgebnis => $composableBuilder(
    column: $table.pruefErgebnis,
    builder: (column) => column,
  );
}

class $$KiEinstellungenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $KiEinstellungenTable,
          KiEinstellungenRow,
          $$KiEinstellungenTableFilterComposer,
          $$KiEinstellungenTableOrderingComposer,
          $$KiEinstellungenTableAnnotationComposer,
          $$KiEinstellungenTableCreateCompanionBuilder,
          $$KiEinstellungenTableUpdateCompanionBuilder,
          (
            KiEinstellungenRow,
            BaseReferences<
              _$AppCache,
              $KiEinstellungenTable,
              KiEinstellungenRow
            >,
          ),
          KiEinstellungenRow,
          PrefetchHooks Function()
        > {
  $$KiEinstellungenTableTableManager(_$AppCache db, $KiEinstellungenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KiEinstellungenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KiEinstellungenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KiEinstellungenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> modell = const Value.absent(),
                Value<double?> limitUsd = const Value.absent(),
                Value<String> preise = const Value.absent(),
                Value<DateTime?> geprueftAm = const Value.absent(),
                Value<String?> pruefErgebnis = const Value.absent(),
              }) => KiEinstellungenCompanion(
                id: id,
                modell: modell,
                limitUsd: limitUsd,
                preise: preise,
                geprueftAm: geprueftAm,
                pruefErgebnis: pruefErgebnis,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> modell = const Value.absent(),
                Value<double?> limitUsd = const Value.absent(),
                Value<String> preise = const Value.absent(),
                Value<DateTime?> geprueftAm = const Value.absent(),
                Value<String?> pruefErgebnis = const Value.absent(),
              }) => KiEinstellungenCompanion.insert(
                id: id,
                modell: modell,
                limitUsd: limitUsd,
                preise: preise,
                geprueftAm: geprueftAm,
                pruefErgebnis: pruefErgebnis,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KiEinstellungenTable, KiEinstellungenRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $KiEinstellungenTable,
                    KiEinstellungenRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KiEinstellungenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $KiEinstellungenTable,
      KiEinstellungenRow,
      $$KiEinstellungenTableFilterComposer,
      $$KiEinstellungenTableOrderingComposer,
      $$KiEinstellungenTableAnnotationComposer,
      $$KiEinstellungenTableCreateCompanionBuilder,
      $$KiEinstellungenTableUpdateCompanionBuilder,
      (
        KiEinstellungenRow,
        BaseReferences<_$AppCache, $KiEinstellungenTable, KiEinstellungenRow>,
      ),
      KiEinstellungenRow,
      PrefetchHooks Function()
    >;
typedef $$KiAnfragenTableCreateCompanionBuilder = KiAnfragenCompanion Function({
  Value<int> id,
  required DateTime zeitpunkt,
  required String monat,
  required String modell,
  required String zweck,
  required int eingabeToken,
  required int ausgabeToken,
  required int denkToken,
  Value<double?> kostenUsd,
});
typedef $$KiAnfragenTableUpdateCompanionBuilder = KiAnfragenCompanion Function({
  Value<int> id,
  Value<DateTime> zeitpunkt,
  Value<String> monat,
  Value<String> modell,
  Value<String> zweck,
  Value<int> eingabeToken,
  Value<int> ausgabeToken,
  Value<int> denkToken,
  Value<double?> kostenUsd,
});

class $$KiAnfragenTableFilterComposer
    extends Composer<_$AppCache, $KiAnfragenTable> {
  $$KiAnfragenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get monat => $composableBuilder(
    column: $table.monat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get modell => $composableBuilder(
    column: $table.modell,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get zweck => $composableBuilder(
    column: $table.zweck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get eingabeToken => $composableBuilder(
    column: $table.eingabeToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ausgabeToken => $composableBuilder(
    column: $table.ausgabeToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get denkToken => $composableBuilder(
    column: $table.denkToken,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kostenUsd => $composableBuilder(
    column: $table.kostenUsd,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KiAnfragenTableOrderingComposer
    extends Composer<_$AppCache, $KiAnfragenTable> {
  $$KiAnfragenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get monat => $composableBuilder(
    column: $table.monat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get modell => $composableBuilder(
    column: $table.modell,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get zweck => $composableBuilder(
    column: $table.zweck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get eingabeToken => $composableBuilder(
    column: $table.eingabeToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ausgabeToken => $composableBuilder(
    column: $table.ausgabeToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get denkToken => $composableBuilder(
    column: $table.denkToken,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kostenUsd => $composableBuilder(
    column: $table.kostenUsd,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KiAnfragenTableAnnotationComposer
    extends Composer<_$AppCache, $KiAnfragenTable> {
  $$KiAnfragenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<String> get monat =>
      $composableBuilder(column: $table.monat, builder: (column) => column);

  GeneratedColumn<String> get modell =>
      $composableBuilder(column: $table.modell, builder: (column) => column);

  GeneratedColumn<String> get zweck =>
      $composableBuilder(column: $table.zweck, builder: (column) => column);

  GeneratedColumn<int> get eingabeToken => $composableBuilder(
    column: $table.eingabeToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get ausgabeToken => $composableBuilder(
    column: $table.ausgabeToken,
    builder: (column) => column,
  );

  GeneratedColumn<int> get denkToken =>
      $composableBuilder(column: $table.denkToken, builder: (column) => column);

  GeneratedColumn<double> get kostenUsd =>
      $composableBuilder(column: $table.kostenUsd, builder: (column) => column);
}

class $$KiAnfragenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $KiAnfragenTable,
          KiAnfrageRow,
          $$KiAnfragenTableFilterComposer,
          $$KiAnfragenTableOrderingComposer,
          $$KiAnfragenTableAnnotationComposer,
          $$KiAnfragenTableCreateCompanionBuilder,
          $$KiAnfragenTableUpdateCompanionBuilder,
          (
            KiAnfrageRow,
            BaseReferences<_$AppCache, $KiAnfragenTable, KiAnfrageRow>,
          ),
          KiAnfrageRow,
          PrefetchHooks Function()
        > {
  $$KiAnfragenTableTableManager(_$AppCache db, $KiAnfragenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KiAnfragenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KiAnfragenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KiAnfragenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> zeitpunkt = const Value.absent(),
                Value<String> monat = const Value.absent(),
                Value<String> modell = const Value.absent(),
                Value<String> zweck = const Value.absent(),
                Value<int> eingabeToken = const Value.absent(),
                Value<int> ausgabeToken = const Value.absent(),
                Value<int> denkToken = const Value.absent(),
                Value<double?> kostenUsd = const Value.absent(),
              }) => KiAnfragenCompanion(
                id: id,
                zeitpunkt: zeitpunkt,
                monat: monat,
                modell: modell,
                zweck: zweck,
                eingabeToken: eingabeToken,
                ausgabeToken: ausgabeToken,
                denkToken: denkToken,
                kostenUsd: kostenUsd,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime zeitpunkt,
                required String monat,
                required String modell,
                required String zweck,
                required int eingabeToken,
                required int ausgabeToken,
                required int denkToken,
                Value<double?> kostenUsd = const Value.absent(),
              }) => KiAnfragenCompanion.insert(
                id: id,
                zeitpunkt: zeitpunkt,
                monat: monat,
                modell: modell,
                zweck: zweck,
                eingabeToken: eingabeToken,
                ausgabeToken: ausgabeToken,
                denkToken: denkToken,
                kostenUsd: kostenUsd,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KiAnfragenTable, KiAnfrageRow>(table),
                  BaseReferences<_$AppCache, $KiAnfragenTable, KiAnfrageRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KiAnfragenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $KiAnfragenTable,
      KiAnfrageRow,
      $$KiAnfragenTableFilterComposer,
      $$KiAnfragenTableOrderingComposer,
      $$KiAnfragenTableAnnotationComposer,
      $$KiAnfragenTableCreateCompanionBuilder,
      $$KiAnfragenTableUpdateCompanionBuilder,
      (
        KiAnfrageRow,
        BaseReferences<_$AppCache, $KiAnfragenTable, KiAnfrageRow>,
      ),
      KiAnfrageRow,
      PrefetchHooks Function()
    >;
typedef $$WasserEintraegeTableCreateCompanionBuilder =
    WasserEintraegeCompanion Function({
      Value<int> id,
      required String tagesSchluessel,
      required DateTime zeitpunkt,
      required double mengeMl,
      Value<String?> healthUuid,
      Value<String> healthStand,
    });
typedef $$WasserEintraegeTableUpdateCompanionBuilder =
    WasserEintraegeCompanion Function({
      Value<int> id,
      Value<String> tagesSchluessel,
      Value<DateTime> zeitpunkt,
      Value<double> mengeMl,
      Value<String?> healthUuid,
      Value<String> healthStand,
    });

class $$WasserEintraegeTableFilterComposer
    extends Composer<_$AppCache, $WasserEintraegeTable> {
  $$WasserEintraegeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get mengeMl => $composableBuilder(
    column: $table.mengeMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WasserEintraegeTableOrderingComposer
    extends Composer<_$AppCache, $WasserEintraegeTable> {
  $$WasserEintraegeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get mengeMl => $composableBuilder(
    column: $table.mengeMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WasserEintraegeTableAnnotationComposer
    extends Composer<_$AppCache, $WasserEintraegeTable> {
  $$WasserEintraegeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tagesSchluessel => $composableBuilder(
    column: $table.tagesSchluessel,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<double> get mengeMl =>
      $composableBuilder(column: $table.mengeMl, builder: (column) => column);

  GeneratedColumn<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get healthStand => $composableBuilder(
    column: $table.healthStand,
    builder: (column) => column,
  );
}

class $$WasserEintraegeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $WasserEintraegeTable,
          WasserEintragRow,
          $$WasserEintraegeTableFilterComposer,
          $$WasserEintraegeTableOrderingComposer,
          $$WasserEintraegeTableAnnotationComposer,
          $$WasserEintraegeTableCreateCompanionBuilder,
          $$WasserEintraegeTableUpdateCompanionBuilder,
          (
            WasserEintragRow,
            BaseReferences<_$AppCache, $WasserEintraegeTable, WasserEintragRow>,
          ),
          WasserEintragRow,
          PrefetchHooks Function()
        > {
  $$WasserEintraegeTableTableManager(_$AppCache db, $WasserEintraegeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WasserEintraegeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WasserEintraegeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WasserEintraegeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> tagesSchluessel = const Value.absent(),
                Value<DateTime> zeitpunkt = const Value.absent(),
                Value<double> mengeMl = const Value.absent(),
                Value<String?> healthUuid = const Value.absent(),
                Value<String> healthStand = const Value.absent(),
              }) => WasserEintraegeCompanion(
                id: id,
                tagesSchluessel: tagesSchluessel,
                zeitpunkt: zeitpunkt,
                mengeMl: mengeMl,
                healthUuid: healthUuid,
                healthStand: healthStand,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String tagesSchluessel,
                required DateTime zeitpunkt,
                required double mengeMl,
                Value<String?> healthUuid = const Value.absent(),
                Value<String> healthStand = const Value.absent(),
              }) => WasserEintraegeCompanion.insert(
                id: id,
                tagesSchluessel: tagesSchluessel,
                zeitpunkt: zeitpunkt,
                mengeMl: mengeMl,
                healthUuid: healthUuid,
                healthStand: healthStand,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WasserEintraegeTable, WasserEintragRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $WasserEintraegeTable,
                    WasserEintragRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WasserEintraegeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $WasserEintraegeTable,
      WasserEintragRow,
      $$WasserEintraegeTableFilterComposer,
      $$WasserEintraegeTableOrderingComposer,
      $$WasserEintraegeTableAnnotationComposer,
      $$WasserEintraegeTableCreateCompanionBuilder,
      $$WasserEintraegeTableUpdateCompanionBuilder,
      (
        WasserEintragRow,
        BaseReferences<_$AppCache, $WasserEintraegeTable, WasserEintragRow>,
      ),
      WasserEintragRow,
      PrefetchHooks Function()
    >;
typedef $$GymSitzungenTableCreateCompanionBuilder =
    GymSitzungenCompanion Function({
      required String id,
      required String tag,
      required DateTime zeitpunkt,
      Value<String?> workout,
      Value<int?> minuten,
      Value<String?> notiz,
      Value<String?> healthUuid,
      Value<String?> aufwaermenArt,
      Value<int?> aufwaermenMinuten,
      Value<double?> aufwaermenKm,
      Value<bool> aufwaermenUebersprungen,
      Value<String?> aufwaermenHealthUuid,
      Value<String?> trainingsName,
      Value<int> rowid,
    });
typedef $$GymSitzungenTableUpdateCompanionBuilder =
    GymSitzungenCompanion Function({
      Value<String> id,
      Value<String> tag,
      Value<DateTime> zeitpunkt,
      Value<String?> workout,
      Value<int?> minuten,
      Value<String?> notiz,
      Value<String?> healthUuid,
      Value<String?> aufwaermenArt,
      Value<int?> aufwaermenMinuten,
      Value<double?> aufwaermenKm,
      Value<bool> aufwaermenUebersprungen,
      Value<String?> aufwaermenHealthUuid,
      Value<String?> trainingsName,
      Value<int> rowid,
    });

class $$GymSitzungenTableFilterComposer
    extends Composer<_$AppCache, $GymSitzungenTable> {
  $$GymSitzungenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workout => $composableBuilder(
    column: $table.workout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get minuten => $composableBuilder(
    column: $table.minuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aufwaermenArt => $composableBuilder(
    column: $table.aufwaermenArt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aufwaermenMinuten => $composableBuilder(
    column: $table.aufwaermenMinuten,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aufwaermenKm => $composableBuilder(
    column: $table.aufwaermenKm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get aufwaermenUebersprungen => $composableBuilder(
    column: $table.aufwaermenUebersprungen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aufwaermenHealthUuid => $composableBuilder(
    column: $table.aufwaermenHealthUuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainingsName => $composableBuilder(
    column: $table.trainingsName,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymSitzungenTableOrderingComposer
    extends Composer<_$AppCache, $GymSitzungenTable> {
  $$GymSitzungenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workout => $composableBuilder(
    column: $table.workout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get minuten => $composableBuilder(
    column: $table.minuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aufwaermenArt => $composableBuilder(
    column: $table.aufwaermenArt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aufwaermenMinuten => $composableBuilder(
    column: $table.aufwaermenMinuten,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aufwaermenKm => $composableBuilder(
    column: $table.aufwaermenKm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get aufwaermenUebersprungen => $composableBuilder(
    column: $table.aufwaermenUebersprungen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aufwaermenHealthUuid => $composableBuilder(
    column: $table.aufwaermenHealthUuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainingsName => $composableBuilder(
    column: $table.trainingsName,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymSitzungenTableAnnotationComposer
    extends Composer<_$AppCache, $GymSitzungenTable> {
  $$GymSitzungenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<String> get workout =>
      $composableBuilder(column: $table.workout, builder: (column) => column);

  GeneratedColumn<int> get minuten =>
      $composableBuilder(column: $table.minuten, builder: (column) => column);

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);

  GeneratedColumn<String> get healthUuid => $composableBuilder(
    column: $table.healthUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aufwaermenArt => $composableBuilder(
    column: $table.aufwaermenArt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aufwaermenMinuten => $composableBuilder(
    column: $table.aufwaermenMinuten,
    builder: (column) => column,
  );

  GeneratedColumn<double> get aufwaermenKm => $composableBuilder(
    column: $table.aufwaermenKm,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get aufwaermenUebersprungen => $composableBuilder(
    column: $table.aufwaermenUebersprungen,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aufwaermenHealthUuid => $composableBuilder(
    column: $table.aufwaermenHealthUuid,
    builder: (column) => column,
  );

  GeneratedColumn<String> get trainingsName => $composableBuilder(
    column: $table.trainingsName,
    builder: (column) => column,
  );
}

class $$GymSitzungenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymSitzungenTable,
          GymSitzungRow,
          $$GymSitzungenTableFilterComposer,
          $$GymSitzungenTableOrderingComposer,
          $$GymSitzungenTableAnnotationComposer,
          $$GymSitzungenTableCreateCompanionBuilder,
          $$GymSitzungenTableUpdateCompanionBuilder,
          (
            GymSitzungRow,
            BaseReferences<_$AppCache, $GymSitzungenTable, GymSitzungRow>,
          ),
          GymSitzungRow,
          PrefetchHooks Function()
        > {
  $$GymSitzungenTableTableManager(_$AppCache db, $GymSitzungenTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymSitzungenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymSitzungenTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymSitzungenTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<DateTime> zeitpunkt = const Value.absent(),
                Value<String?> workout = const Value.absent(),
                Value<int?> minuten = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<String?> healthUuid = const Value.absent(),
                Value<String?> aufwaermenArt = const Value.absent(),
                Value<int?> aufwaermenMinuten = const Value.absent(),
                Value<double?> aufwaermenKm = const Value.absent(),
                Value<bool> aufwaermenUebersprungen = const Value.absent(),
                Value<String?> aufwaermenHealthUuid = const Value.absent(),
                Value<String?> trainingsName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymSitzungenCompanion(
                id: id,
                tag: tag,
                zeitpunkt: zeitpunkt,
                workout: workout,
                minuten: minuten,
                notiz: notiz,
                healthUuid: healthUuid,
                aufwaermenArt: aufwaermenArt,
                aufwaermenMinuten: aufwaermenMinuten,
                aufwaermenKm: aufwaermenKm,
                aufwaermenUebersprungen: aufwaermenUebersprungen,
                aufwaermenHealthUuid: aufwaermenHealthUuid,
                trainingsName: trainingsName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String tag,
                required DateTime zeitpunkt,
                Value<String?> workout = const Value.absent(),
                Value<int?> minuten = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<String?> healthUuid = const Value.absent(),
                Value<String?> aufwaermenArt = const Value.absent(),
                Value<int?> aufwaermenMinuten = const Value.absent(),
                Value<double?> aufwaermenKm = const Value.absent(),
                Value<bool> aufwaermenUebersprungen = const Value.absent(),
                Value<String?> aufwaermenHealthUuid = const Value.absent(),
                Value<String?> trainingsName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymSitzungenCompanion.insert(
                id: id,
                tag: tag,
                zeitpunkt: zeitpunkt,
                workout: workout,
                minuten: minuten,
                notiz: notiz,
                healthUuid: healthUuid,
                aufwaermenArt: aufwaermenArt,
                aufwaermenMinuten: aufwaermenMinuten,
                aufwaermenKm: aufwaermenKm,
                aufwaermenUebersprungen: aufwaermenUebersprungen,
                aufwaermenHealthUuid: aufwaermenHealthUuid,
                trainingsName: trainingsName,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymSitzungenTable, GymSitzungRow>(table),
                  BaseReferences<_$AppCache, $GymSitzungenTable, GymSitzungRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymSitzungenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymSitzungenTable,
      GymSitzungRow,
      $$GymSitzungenTableFilterComposer,
      $$GymSitzungenTableOrderingComposer,
      $$GymSitzungenTableAnnotationComposer,
      $$GymSitzungenTableCreateCompanionBuilder,
      $$GymSitzungenTableUpdateCompanionBuilder,
      (
        GymSitzungRow,
        BaseReferences<_$AppCache, $GymSitzungenTable, GymSitzungRow>,
      ),
      GymSitzungRow,
      PrefetchHooks Function()
    >;
typedef $$GymSaetzeTableCreateCompanionBuilder = GymSaetzeCompanion Function({
  required String sitzungId,
  required String uebungId,
  required int uebungPos,
  required int satzNr,
  required double gewichtKg,
  required int wdh,
  Value<DateTime?> zeitpunkt,
  Value<int> rowid,
});
typedef $$GymSaetzeTableUpdateCompanionBuilder = GymSaetzeCompanion Function({
  Value<String> sitzungId,
  Value<String> uebungId,
  Value<int> uebungPos,
  Value<int> satzNr,
  Value<double> gewichtKg,
  Value<int> wdh,
  Value<DateTime?> zeitpunkt,
  Value<int> rowid,
});

class $$GymSaetzeTableFilterComposer
    extends Composer<_$AppCache, $GymSaetzeTable> {
  $$GymSaetzeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sitzungId => $composableBuilder(
    column: $table.sitzungId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uebungId => $composableBuilder(
    column: $table.uebungId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uebungPos => $composableBuilder(
    column: $table.uebungPos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get satzNr => $composableBuilder(
    column: $table.satzNr,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gewichtKg => $composableBuilder(
    column: $table.gewichtKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wdh => $composableBuilder(
    column: $table.wdh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymSaetzeTableOrderingComposer
    extends Composer<_$AppCache, $GymSaetzeTable> {
  $$GymSaetzeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sitzungId => $composableBuilder(
    column: $table.sitzungId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uebungId => $composableBuilder(
    column: $table.uebungId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uebungPos => $composableBuilder(
    column: $table.uebungPos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get satzNr => $composableBuilder(
    column: $table.satzNr,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gewichtKg => $composableBuilder(
    column: $table.gewichtKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wdh => $composableBuilder(
    column: $table.wdh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymSaetzeTableAnnotationComposer
    extends Composer<_$AppCache, $GymSaetzeTable> {
  $$GymSaetzeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sitzungId =>
      $composableBuilder(column: $table.sitzungId, builder: (column) => column);

  GeneratedColumn<String> get uebungId =>
      $composableBuilder(column: $table.uebungId, builder: (column) => column);

  GeneratedColumn<int> get uebungPos =>
      $composableBuilder(column: $table.uebungPos, builder: (column) => column);

  GeneratedColumn<int> get satzNr =>
      $composableBuilder(column: $table.satzNr, builder: (column) => column);

  GeneratedColumn<double> get gewichtKg =>
      $composableBuilder(column: $table.gewichtKg, builder: (column) => column);

  GeneratedColumn<int> get wdh =>
      $composableBuilder(column: $table.wdh, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);
}

class $$GymSaetzeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymSaetzeTable,
          GymSatzRow,
          $$GymSaetzeTableFilterComposer,
          $$GymSaetzeTableOrderingComposer,
          $$GymSaetzeTableAnnotationComposer,
          $$GymSaetzeTableCreateCompanionBuilder,
          $$GymSaetzeTableUpdateCompanionBuilder,
          (GymSatzRow, BaseReferences<_$AppCache, $GymSaetzeTable, GymSatzRow>),
          GymSatzRow,
          PrefetchHooks Function()
        > {
  $$GymSaetzeTableTableManager(_$AppCache db, $GymSaetzeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymSaetzeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymSaetzeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymSaetzeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sitzungId = const Value.absent(),
                Value<String> uebungId = const Value.absent(),
                Value<int> uebungPos = const Value.absent(),
                Value<int> satzNr = const Value.absent(),
                Value<double> gewichtKg = const Value.absent(),
                Value<int> wdh = const Value.absent(),
                Value<DateTime?> zeitpunkt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymSaetzeCompanion(
                sitzungId: sitzungId,
                uebungId: uebungId,
                uebungPos: uebungPos,
                satzNr: satzNr,
                gewichtKg: gewichtKg,
                wdh: wdh,
                zeitpunkt: zeitpunkt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sitzungId,
                required String uebungId,
                required int uebungPos,
                required int satzNr,
                required double gewichtKg,
                required int wdh,
                Value<DateTime?> zeitpunkt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymSaetzeCompanion.insert(
                sitzungId: sitzungId,
                uebungId: uebungId,
                uebungPos: uebungPos,
                satzNr: satzNr,
                gewichtKg: gewichtKg,
                wdh: wdh,
                zeitpunkt: zeitpunkt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymSaetzeTable, GymSatzRow>(table),
                  BaseReferences<_$AppCache, $GymSaetzeTable, GymSatzRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymSaetzeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymSaetzeTable,
      GymSatzRow,
      $$GymSaetzeTableFilterComposer,
      $$GymSaetzeTableOrderingComposer,
      $$GymSaetzeTableAnnotationComposer,
      $$GymSaetzeTableCreateCompanionBuilder,
      $$GymSaetzeTableUpdateCompanionBuilder,
      (GymSatzRow, BaseReferences<_$AppCache, $GymSaetzeTable, GymSatzRow>),
      GymSatzRow,
      PrefetchHooks Function()
    >;
typedef $$GymEntwuerfeTableCreateCompanionBuilder =
    GymEntwuerfeCompanion Function({
      Value<int> id,
      required String workout,
      required String sitzungId,
      required DateTime zeitpunkt,
      Value<String?> dauer,
      Value<String?> notiz,
      required DateTime gespeichertAm,
      required String felder,
    });
typedef $$GymEntwuerfeTableUpdateCompanionBuilder =
    GymEntwuerfeCompanion Function({
      Value<int> id,
      Value<String> workout,
      Value<String> sitzungId,
      Value<DateTime> zeitpunkt,
      Value<String?> dauer,
      Value<String?> notiz,
      Value<DateTime> gespeichertAm,
      Value<String> felder,
    });

class $$GymEntwuerfeTableFilterComposer
    extends Composer<_$AppCache, $GymEntwuerfeTable> {
  $$GymEntwuerfeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workout => $composableBuilder(
    column: $table.workout,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sitzungId => $composableBuilder(
    column: $table.sitzungId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dauer => $composableBuilder(
    column: $table.dauer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get gespeichertAm => $composableBuilder(
    column: $table.gespeichertAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get felder => $composableBuilder(
    column: $table.felder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymEntwuerfeTableOrderingComposer
    extends Composer<_$AppCache, $GymEntwuerfeTable> {
  $$GymEntwuerfeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workout => $composableBuilder(
    column: $table.workout,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sitzungId => $composableBuilder(
    column: $table.sitzungId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dauer => $composableBuilder(
    column: $table.dauer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get gespeichertAm => $composableBuilder(
    column: $table.gespeichertAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get felder => $composableBuilder(
    column: $table.felder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymEntwuerfeTableAnnotationComposer
    extends Composer<_$AppCache, $GymEntwuerfeTable> {
  $$GymEntwuerfeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get workout =>
      $composableBuilder(column: $table.workout, builder: (column) => column);

  GeneratedColumn<String> get sitzungId =>
      $composableBuilder(column: $table.sitzungId, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<String> get dauer =>
      $composableBuilder(column: $table.dauer, builder: (column) => column);

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);

  GeneratedColumn<DateTime> get gespeichertAm => $composableBuilder(
    column: $table.gespeichertAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get felder =>
      $composableBuilder(column: $table.felder, builder: (column) => column);
}

class $$GymEntwuerfeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymEntwuerfeTable,
          GymEntwurfRow,
          $$GymEntwuerfeTableFilterComposer,
          $$GymEntwuerfeTableOrderingComposer,
          $$GymEntwuerfeTableAnnotationComposer,
          $$GymEntwuerfeTableCreateCompanionBuilder,
          $$GymEntwuerfeTableUpdateCompanionBuilder,
          (
            GymEntwurfRow,
            BaseReferences<_$AppCache, $GymEntwuerfeTable, GymEntwurfRow>,
          ),
          GymEntwurfRow,
          PrefetchHooks Function()
        > {
  $$GymEntwuerfeTableTableManager(_$AppCache db, $GymEntwuerfeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymEntwuerfeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymEntwuerfeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymEntwuerfeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> workout = const Value.absent(),
                Value<String> sitzungId = const Value.absent(),
                Value<DateTime> zeitpunkt = const Value.absent(),
                Value<String?> dauer = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<DateTime> gespeichertAm = const Value.absent(),
                Value<String> felder = const Value.absent(),
              }) => GymEntwuerfeCompanion(
                id: id,
                workout: workout,
                sitzungId: sitzungId,
                zeitpunkt: zeitpunkt,
                dauer: dauer,
                notiz: notiz,
                gespeichertAm: gespeichertAm,
                felder: felder,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String workout,
                required String sitzungId,
                required DateTime zeitpunkt,
                Value<String?> dauer = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                required DateTime gespeichertAm,
                required String felder,
              }) => GymEntwuerfeCompanion.insert(
                id: id,
                workout: workout,
                sitzungId: sitzungId,
                zeitpunkt: zeitpunkt,
                dauer: dauer,
                notiz: notiz,
                gespeichertAm: gespeichertAm,
                felder: felder,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymEntwuerfeTable, GymEntwurfRow>(table),
                  BaseReferences<_$AppCache, $GymEntwuerfeTable, GymEntwurfRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymEntwuerfeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymEntwuerfeTable,
      GymEntwurfRow,
      $$GymEntwuerfeTableFilterComposer,
      $$GymEntwuerfeTableOrderingComposer,
      $$GymEntwuerfeTableAnnotationComposer,
      $$GymEntwuerfeTableCreateCompanionBuilder,
      $$GymEntwuerfeTableUpdateCompanionBuilder,
      (
        GymEntwurfRow,
        BaseReferences<_$AppCache, $GymEntwuerfeTable, GymEntwurfRow>,
      ),
      GymEntwurfRow,
      PrefetchHooks Function()
    >;
typedef $$KalorienzieleTableCreateCompanionBuilder =
    KalorienzieleCompanion Function({
      required String abTag,
      required double kcal,
      required String herkunft,
      Value<double?> grundumsatzKcal,
      Value<double?> aktivKcal,
      Value<double?> koerperzielKcal,
      Value<int> rowid,
    });
typedef $$KalorienzieleTableUpdateCompanionBuilder =
    KalorienzieleCompanion Function({
      Value<String> abTag,
      Value<double> kcal,
      Value<String> herkunft,
      Value<double?> grundumsatzKcal,
      Value<double?> aktivKcal,
      Value<double?> koerperzielKcal,
      Value<int> rowid,
    });

class $$KalorienzieleTableFilterComposer
    extends Composer<_$AppCache, $KalorienzieleTable> {
  $$KalorienzieleTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get abTag => $composableBuilder(
    column: $table.abTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get grundumsatzKcal => $composableBuilder(
    column: $table.grundumsatzKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get aktivKcal => $composableBuilder(
    column: $table.aktivKcal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get koerperzielKcal => $composableBuilder(
    column: $table.koerperzielKcal,
    builder: (column) => ColumnFilters(column),
  );
}

class $$KalorienzieleTableOrderingComposer
    extends Composer<_$AppCache, $KalorienzieleTable> {
  $$KalorienzieleTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get abTag => $composableBuilder(
    column: $table.abTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kcal => $composableBuilder(
    column: $table.kcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get herkunft => $composableBuilder(
    column: $table.herkunft,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get grundumsatzKcal => $composableBuilder(
    column: $table.grundumsatzKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get aktivKcal => $composableBuilder(
    column: $table.aktivKcal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get koerperzielKcal => $composableBuilder(
    column: $table.koerperzielKcal,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$KalorienzieleTableAnnotationComposer
    extends Composer<_$AppCache, $KalorienzieleTable> {
  $$KalorienzieleTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get abTag =>
      $composableBuilder(column: $table.abTag, builder: (column) => column);

  GeneratedColumn<double> get kcal =>
      $composableBuilder(column: $table.kcal, builder: (column) => column);

  GeneratedColumn<String> get herkunft =>
      $composableBuilder(column: $table.herkunft, builder: (column) => column);

  GeneratedColumn<double> get grundumsatzKcal => $composableBuilder(
    column: $table.grundumsatzKcal,
    builder: (column) => column,
  );

  GeneratedColumn<double> get aktivKcal =>
      $composableBuilder(column: $table.aktivKcal, builder: (column) => column);

  GeneratedColumn<double> get koerperzielKcal => $composableBuilder(
    column: $table.koerperzielKcal,
    builder: (column) => column,
  );
}

class $$KalorienzieleTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $KalorienzieleTable,
          KalorienzielRow,
          $$KalorienzieleTableFilterComposer,
          $$KalorienzieleTableOrderingComposer,
          $$KalorienzieleTableAnnotationComposer,
          $$KalorienzieleTableCreateCompanionBuilder,
          $$KalorienzieleTableUpdateCompanionBuilder,
          (
            KalorienzielRow,
            BaseReferences<_$AppCache, $KalorienzieleTable, KalorienzielRow>,
          ),
          KalorienzielRow,
          PrefetchHooks Function()
        > {
  $$KalorienzieleTableTableManager(_$AppCache db, $KalorienzieleTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KalorienzieleTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KalorienzieleTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KalorienzieleTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> abTag = const Value.absent(),
                Value<double> kcal = const Value.absent(),
                Value<String> herkunft = const Value.absent(),
                Value<double?> grundumsatzKcal = const Value.absent(),
                Value<double?> aktivKcal = const Value.absent(),
                Value<double?> koerperzielKcal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KalorienzieleCompanion(
                abTag: abTag,
                kcal: kcal,
                herkunft: herkunft,
                grundumsatzKcal: grundumsatzKcal,
                aktivKcal: aktivKcal,
                koerperzielKcal: koerperzielKcal,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String abTag,
                required double kcal,
                required String herkunft,
                Value<double?> grundumsatzKcal = const Value.absent(),
                Value<double?> aktivKcal = const Value.absent(),
                Value<double?> koerperzielKcal = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => KalorienzieleCompanion.insert(
                abTag: abTag,
                kcal: kcal,
                herkunft: herkunft,
                grundumsatzKcal: grundumsatzKcal,
                aktivKcal: aktivKcal,
                koerperzielKcal: koerperzielKcal,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$KalorienzieleTable, KalorienzielRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $KalorienzieleTable,
                    KalorienzielRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$KalorienzieleTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $KalorienzieleTable,
      KalorienzielRow,
      $$KalorienzieleTableFilterComposer,
      $$KalorienzieleTableOrderingComposer,
      $$KalorienzieleTableAnnotationComposer,
      $$KalorienzieleTableCreateCompanionBuilder,
      $$KalorienzieleTableUpdateCompanionBuilder,
      (
        KalorienzielRow,
        BaseReferences<_$AppCache, $KalorienzieleTable, KalorienzielRow>,
      ),
      KalorienzielRow,
      PrefetchHooks Function()
    >;
typedef $$MahlzeitAufteilungenTableCreateCompanionBuilder =
    MahlzeitAufteilungenCompanion Function({
      required String abTag,
      Value<int?> fruehstueckPct,
      Value<int?> mittagPct,
      Value<int?> abendPct,
      Value<int> rowid,
    });
typedef $$MahlzeitAufteilungenTableUpdateCompanionBuilder =
    MahlzeitAufteilungenCompanion Function({
      Value<String> abTag,
      Value<int?> fruehstueckPct,
      Value<int?> mittagPct,
      Value<int?> abendPct,
      Value<int> rowid,
    });

class $$MahlzeitAufteilungenTableFilterComposer
    extends Composer<_$AppCache, $MahlzeitAufteilungenTable> {
  $$MahlzeitAufteilungenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get abTag => $composableBuilder(
    column: $table.abTag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fruehstueckPct => $composableBuilder(
    column: $table.fruehstueckPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get mittagPct => $composableBuilder(
    column: $table.mittagPct,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get abendPct => $composableBuilder(
    column: $table.abendPct,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MahlzeitAufteilungenTableOrderingComposer
    extends Composer<_$AppCache, $MahlzeitAufteilungenTable> {
  $$MahlzeitAufteilungenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get abTag => $composableBuilder(
    column: $table.abTag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fruehstueckPct => $composableBuilder(
    column: $table.fruehstueckPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get mittagPct => $composableBuilder(
    column: $table.mittagPct,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get abendPct => $composableBuilder(
    column: $table.abendPct,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MahlzeitAufteilungenTableAnnotationComposer
    extends Composer<_$AppCache, $MahlzeitAufteilungenTable> {
  $$MahlzeitAufteilungenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get abTag =>
      $composableBuilder(column: $table.abTag, builder: (column) => column);

  GeneratedColumn<int> get fruehstueckPct => $composableBuilder(
    column: $table.fruehstueckPct,
    builder: (column) => column,
  );

  GeneratedColumn<int> get mittagPct =>
      $composableBuilder(column: $table.mittagPct, builder: (column) => column);

  GeneratedColumn<int> get abendPct =>
      $composableBuilder(column: $table.abendPct, builder: (column) => column);
}

class $$MahlzeitAufteilungenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $MahlzeitAufteilungenTable,
          MahlzeitAufteilungRow,
          $$MahlzeitAufteilungenTableFilterComposer,
          $$MahlzeitAufteilungenTableOrderingComposer,
          $$MahlzeitAufteilungenTableAnnotationComposer,
          $$MahlzeitAufteilungenTableCreateCompanionBuilder,
          $$MahlzeitAufteilungenTableUpdateCompanionBuilder,
          (
            MahlzeitAufteilungRow,
            BaseReferences<
              _$AppCache,
              $MahlzeitAufteilungenTable,
              MahlzeitAufteilungRow
            >,
          ),
          MahlzeitAufteilungRow,
          PrefetchHooks Function()
        > {
  $$MahlzeitAufteilungenTableTableManager(
    _$AppCache db,
    $MahlzeitAufteilungenTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MahlzeitAufteilungenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MahlzeitAufteilungenTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$MahlzeitAufteilungenTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> abTag = const Value.absent(),
                Value<int?> fruehstueckPct = const Value.absent(),
                Value<int?> mittagPct = const Value.absent(),
                Value<int?> abendPct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MahlzeitAufteilungenCompanion(
                abTag: abTag,
                fruehstueckPct: fruehstueckPct,
                mittagPct: mittagPct,
                abendPct: abendPct,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String abTag,
                Value<int?> fruehstueckPct = const Value.absent(),
                Value<int?> mittagPct = const Value.absent(),
                Value<int?> abendPct = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MahlzeitAufteilungenCompanion.insert(
                abTag: abTag,
                fruehstueckPct: fruehstueckPct,
                mittagPct: mittagPct,
                abendPct: abendPct,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $MahlzeitAufteilungenTable,
                    MahlzeitAufteilungRow
                  >(table),
                  BaseReferences<
                    _$AppCache,
                    $MahlzeitAufteilungenTable,
                    MahlzeitAufteilungRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MahlzeitAufteilungenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $MahlzeitAufteilungenTable,
      MahlzeitAufteilungRow,
      $$MahlzeitAufteilungenTableFilterComposer,
      $$MahlzeitAufteilungenTableOrderingComposer,
      $$MahlzeitAufteilungenTableAnnotationComposer,
      $$MahlzeitAufteilungenTableCreateCompanionBuilder,
      $$MahlzeitAufteilungenTableUpdateCompanionBuilder,
      (
        MahlzeitAufteilungRow,
        BaseReferences<
          _$AppCache,
          $MahlzeitAufteilungenTable,
          MahlzeitAufteilungRow
        >,
      ),
      MahlzeitAufteilungRow,
      PrefetchHooks Function()
    >;
typedef $$EreignisseTableCreateCompanionBuilder = EreignisseCompanion Function({
  Value<int> id,
  required String art,
  required String von,
  required String bis,
  Value<String?> notiz,
  required DateTime angelegt,
  Value<DateTime?> geaendert,
});
typedef $$EreignisseTableUpdateCompanionBuilder = EreignisseCompanion Function({
  Value<int> id,
  Value<String> art,
  Value<String> von,
  Value<String> bis,
  Value<String?> notiz,
  Value<DateTime> angelegt,
  Value<DateTime?> geaendert,
});

class $$EreignisseTableFilterComposer
    extends Composer<_$AppCache, $EreignisseTable> {
  $$EreignisseTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get von => $composableBuilder(
    column: $table.von,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bis => $composableBuilder(
    column: $table.bis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get angelegt => $composableBuilder(
    column: $table.angelegt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geaendert => $composableBuilder(
    column: $table.geaendert,
    builder: (column) => ColumnFilters(column),
  );
}

class $$EreignisseTableOrderingComposer
    extends Composer<_$AppCache, $EreignisseTable> {
  $$EreignisseTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get von => $composableBuilder(
    column: $table.von,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bis => $composableBuilder(
    column: $table.bis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get angelegt => $composableBuilder(
    column: $table.angelegt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geaendert => $composableBuilder(
    column: $table.geaendert,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$EreignisseTableAnnotationComposer
    extends Composer<_$AppCache, $EreignisseTable> {
  $$EreignisseTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get art =>
      $composableBuilder(column: $table.art, builder: (column) => column);

  GeneratedColumn<String> get von =>
      $composableBuilder(column: $table.von, builder: (column) => column);

  GeneratedColumn<String> get bis =>
      $composableBuilder(column: $table.bis, builder: (column) => column);

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);

  GeneratedColumn<DateTime> get angelegt =>
      $composableBuilder(column: $table.angelegt, builder: (column) => column);

  GeneratedColumn<DateTime> get geaendert =>
      $composableBuilder(column: $table.geaendert, builder: (column) => column);
}

class $$EreignisseTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $EreignisseTable,
          EreignisRow,
          $$EreignisseTableFilterComposer,
          $$EreignisseTableOrderingComposer,
          $$EreignisseTableAnnotationComposer,
          $$EreignisseTableCreateCompanionBuilder,
          $$EreignisseTableUpdateCompanionBuilder,
          (
            EreignisRow,
            BaseReferences<_$AppCache, $EreignisseTable, EreignisRow>,
          ),
          EreignisRow,
          PrefetchHooks Function()
        > {
  $$EreignisseTableTableManager(_$AppCache db, $EreignisseTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$EreignisseTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$EreignisseTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$EreignisseTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> art = const Value.absent(),
                Value<String> von = const Value.absent(),
                Value<String> bis = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<DateTime> angelegt = const Value.absent(),
                Value<DateTime?> geaendert = const Value.absent(),
              }) => EreignisseCompanion(
                id: id,
                art: art,
                von: von,
                bis: bis,
                notiz: notiz,
                angelegt: angelegt,
                geaendert: geaendert,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String art,
                required String von,
                required String bis,
                Value<String?> notiz = const Value.absent(),
                required DateTime angelegt,
                Value<DateTime?> geaendert = const Value.absent(),
              }) => EreignisseCompanion.insert(
                id: id,
                art: art,
                von: von,
                bis: bis,
                notiz: notiz,
                angelegt: angelegt,
                geaendert: geaendert,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$EreignisseTable, EreignisRow>(table),
                  BaseReferences<_$AppCache, $EreignisseTable, EreignisRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$EreignisseTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $EreignisseTable,
      EreignisRow,
      $$EreignisseTableFilterComposer,
      $$EreignisseTableOrderingComposer,
      $$EreignisseTableAnnotationComposer,
      $$EreignisseTableCreateCompanionBuilder,
      $$EreignisseTableUpdateCompanionBuilder,
      (EreignisRow, BaseReferences<_$AppCache, $EreignisseTable, EreignisRow>),
      EreignisRow,
      PrefetchHooks Function()
    >;
typedef $$WachBelegeTableCreateCompanionBuilder = WachBelegeCompanion Function({
  Value<int> id,
  required DateTime zeitpunkt,
  required String art,
});
typedef $$WachBelegeTableUpdateCompanionBuilder = WachBelegeCompanion Function({
  Value<int> id,
  Value<DateTime> zeitpunkt,
  Value<String> art,
});

class $$WachBelegeTableFilterComposer
    extends Composer<_$AppCache, $WachBelegeTable> {
  $$WachBelegeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WachBelegeTableOrderingComposer
    extends Composer<_$AppCache, $WachBelegeTable> {
  $$WachBelegeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get zeitpunkt => $composableBuilder(
    column: $table.zeitpunkt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get art => $composableBuilder(
    column: $table.art,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WachBelegeTableAnnotationComposer
    extends Composer<_$AppCache, $WachBelegeTable> {
  $$WachBelegeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get zeitpunkt =>
      $composableBuilder(column: $table.zeitpunkt, builder: (column) => column);

  GeneratedColumn<String> get art =>
      $composableBuilder(column: $table.art, builder: (column) => column);
}

class $$WachBelegeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $WachBelegeTable,
          WachBelegRow,
          $$WachBelegeTableFilterComposer,
          $$WachBelegeTableOrderingComposer,
          $$WachBelegeTableAnnotationComposer,
          $$WachBelegeTableCreateCompanionBuilder,
          $$WachBelegeTableUpdateCompanionBuilder,
          (
            WachBelegRow,
            BaseReferences<_$AppCache, $WachBelegeTable, WachBelegRow>,
          ),
          WachBelegRow,
          PrefetchHooks Function()
        > {
  $$WachBelegeTableTableManager(_$AppCache db, $WachBelegeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WachBelegeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WachBelegeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WachBelegeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<DateTime> zeitpunkt = const Value.absent(),
            Value<String> art = const Value.absent(),
          }) => WachBelegeCompanion(id: id, zeitpunkt: zeitpunkt, art: art),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime zeitpunkt,
                required String art,
              }) => WachBelegeCompanion.insert(
                id: id,
                zeitpunkt: zeitpunkt,
                art: art,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$WachBelegeTable, WachBelegRow>(table),
                  BaseReferences<_$AppCache, $WachBelegeTable, WachBelegRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WachBelegeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $WachBelegeTable,
      WachBelegRow,
      $$WachBelegeTableFilterComposer,
      $$WachBelegeTableOrderingComposer,
      $$WachBelegeTableAnnotationComposer,
      $$WachBelegeTableCreateCompanionBuilder,
      $$WachBelegeTableUpdateCompanionBuilder,
      (
        WachBelegRow,
        BaseReferences<_$AppCache, $WachBelegeTable, WachBelegRow>,
      ),
      WachBelegRow,
      PrefetchHooks Function()
    >;
typedef $$UmfaengeTableCreateCompanionBuilder = UmfaengeCompanion Function({
  required String tag,
  required String mass,
  required double zentimeter,
  required DateTime eingetragenAm,
  required String quelle,
  Value<int> rowid,
});
typedef $$UmfaengeTableUpdateCompanionBuilder = UmfaengeCompanion Function({
  Value<String> tag,
  Value<String> mass,
  Value<double> zentimeter,
  Value<DateTime> eingetragenAm,
  Value<String> quelle,
  Value<int> rowid,
});

class $$UmfaengeTableFilterComposer
    extends Composer<_$AppCache, $UmfaengeTable> {
  $$UmfaengeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mass => $composableBuilder(
    column: $table.mass,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get zentimeter => $composableBuilder(
    column: $table.zentimeter,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get eingetragenAm => $composableBuilder(
    column: $table.eingetragenAm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UmfaengeTableOrderingComposer
    extends Composer<_$AppCache, $UmfaengeTable> {
  $$UmfaengeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mass => $composableBuilder(
    column: $table.mass,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get zentimeter => $composableBuilder(
    column: $table.zentimeter,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get eingetragenAm => $composableBuilder(
    column: $table.eingetragenAm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UmfaengeTableAnnotationComposer
    extends Composer<_$AppCache, $UmfaengeTable> {
  $$UmfaengeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get mass =>
      $composableBuilder(column: $table.mass, builder: (column) => column);

  GeneratedColumn<double> get zentimeter => $composableBuilder(
    column: $table.zentimeter,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get eingetragenAm => $composableBuilder(
    column: $table.eingetragenAm,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quelle =>
      $composableBuilder(column: $table.quelle, builder: (column) => column);
}

class $$UmfaengeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $UmfaengeTable,
          UmfangRow,
          $$UmfaengeTableFilterComposer,
          $$UmfaengeTableOrderingComposer,
          $$UmfaengeTableAnnotationComposer,
          $$UmfaengeTableCreateCompanionBuilder,
          $$UmfaengeTableUpdateCompanionBuilder,
          (UmfangRow, BaseReferences<_$AppCache, $UmfaengeTable, UmfangRow>),
          UmfangRow,
          PrefetchHooks Function()
        > {
  $$UmfaengeTableTableManager(_$AppCache db, $UmfaengeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UmfaengeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UmfaengeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UmfaengeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<String> mass = const Value.absent(),
                Value<double> zentimeter = const Value.absent(),
                Value<DateTime> eingetragenAm = const Value.absent(),
                Value<String> quelle = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => UmfaengeCompanion(
                tag: tag,
                mass: mass,
                zentimeter: zentimeter,
                eingetragenAm: eingetragenAm,
                quelle: quelle,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                required String mass,
                required double zentimeter,
                required DateTime eingetragenAm,
                required String quelle,
                Value<int> rowid = const Value.absent(),
              }) => UmfaengeCompanion.insert(
                tag: tag,
                mass: mass,
                zentimeter: zentimeter,
                eingetragenAm: eingetragenAm,
                quelle: quelle,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UmfaengeTable, UmfangRow>(table),
                  BaseReferences<_$AppCache, $UmfaengeTable, UmfangRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UmfaengeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $UmfaengeTable,
      UmfangRow,
      $$UmfaengeTableFilterComposer,
      $$UmfaengeTableOrderingComposer,
      $$UmfaengeTableAnnotationComposer,
      $$UmfaengeTableCreateCompanionBuilder,
      $$UmfaengeTableUpdateCompanionBuilder,
      (UmfangRow, BaseReferences<_$AppCache, $UmfaengeTable, UmfangRow>),
      UmfangRow,
      PrefetchHooks Function()
    >;
typedef $$ZyklusEintraegeTableCreateCompanionBuilder =
    ZyklusEintraegeCompanion Function({
      required String tag,
      Value<String?> blutung,
      Value<bool> zwischenblutung,
      Value<String?> schmerz,
      Value<String> symptome,
      Value<bool> sex,
      Value<bool?> verhuetet,
      Value<String?> test,
      Value<String?> notiz,
      Value<String> quelle,
      required DateTime geaendert,
      Value<int> rowid,
    });
typedef $$ZyklusEintraegeTableUpdateCompanionBuilder =
    ZyklusEintraegeCompanion Function({
      Value<String> tag,
      Value<String?> blutung,
      Value<bool> zwischenblutung,
      Value<String?> schmerz,
      Value<String> symptome,
      Value<bool> sex,
      Value<bool?> verhuetet,
      Value<String?> test,
      Value<String?> notiz,
      Value<String> quelle,
      Value<DateTime> geaendert,
      Value<int> rowid,
    });

class $$ZyklusEintraegeTableFilterComposer
    extends Composer<_$AppCache, $ZyklusEintraegeTable> {
  $$ZyklusEintraegeTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get blutung => $composableBuilder(
    column: $table.blutung,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get zwischenblutung => $composableBuilder(
    column: $table.zwischenblutung,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get schmerz => $composableBuilder(
    column: $table.schmerz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get symptome => $composableBuilder(
    column: $table.symptome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verhuetet => $composableBuilder(
    column: $table.verhuetet,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get test => $composableBuilder(
    column: $table.test,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get geaendert => $composableBuilder(
    column: $table.geaendert,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZyklusEintraegeTableOrderingComposer
    extends Composer<_$AppCache, $ZyklusEintraegeTable> {
  $$ZyklusEintraegeTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blutung => $composableBuilder(
    column: $table.blutung,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get zwischenblutung => $composableBuilder(
    column: $table.zwischenblutung,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get schmerz => $composableBuilder(
    column: $table.schmerz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get symptome => $composableBuilder(
    column: $table.symptome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get sex => $composableBuilder(
    column: $table.sex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verhuetet => $composableBuilder(
    column: $table.verhuetet,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get test => $composableBuilder(
    column: $table.test,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notiz => $composableBuilder(
    column: $table.notiz,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quelle => $composableBuilder(
    column: $table.quelle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get geaendert => $composableBuilder(
    column: $table.geaendert,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZyklusEintraegeTableAnnotationComposer
    extends Composer<_$AppCache, $ZyklusEintraegeTable> {
  $$ZyklusEintraegeTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get blutung =>
      $composableBuilder(column: $table.blutung, builder: (column) => column);

  GeneratedColumn<bool> get zwischenblutung => $composableBuilder(
    column: $table.zwischenblutung,
    builder: (column) => column,
  );

  GeneratedColumn<String> get schmerz =>
      $composableBuilder(column: $table.schmerz, builder: (column) => column);

  GeneratedColumn<String> get symptome =>
      $composableBuilder(column: $table.symptome, builder: (column) => column);

  GeneratedColumn<bool> get sex =>
      $composableBuilder(column: $table.sex, builder: (column) => column);

  GeneratedColumn<bool> get verhuetet =>
      $composableBuilder(column: $table.verhuetet, builder: (column) => column);

  GeneratedColumn<String> get test =>
      $composableBuilder(column: $table.test, builder: (column) => column);

  GeneratedColumn<String> get notiz =>
      $composableBuilder(column: $table.notiz, builder: (column) => column);

  GeneratedColumn<String> get quelle =>
      $composableBuilder(column: $table.quelle, builder: (column) => column);

  GeneratedColumn<DateTime> get geaendert =>
      $composableBuilder(column: $table.geaendert, builder: (column) => column);
}

class $$ZyklusEintraegeTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $ZyklusEintraegeTable,
          ZyklusEintragRow,
          $$ZyklusEintraegeTableFilterComposer,
          $$ZyklusEintraegeTableOrderingComposer,
          $$ZyklusEintraegeTableAnnotationComposer,
          $$ZyklusEintraegeTableCreateCompanionBuilder,
          $$ZyklusEintraegeTableUpdateCompanionBuilder,
          (
            ZyklusEintragRow,
            BaseReferences<_$AppCache, $ZyklusEintraegeTable, ZyklusEintragRow>,
          ),
          ZyklusEintragRow,
          PrefetchHooks Function()
        > {
  $$ZyklusEintraegeTableTableManager(_$AppCache db, $ZyklusEintraegeTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZyklusEintraegeTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZyklusEintraegeTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZyklusEintraegeTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> tag = const Value.absent(),
                Value<String?> blutung = const Value.absent(),
                Value<bool> zwischenblutung = const Value.absent(),
                Value<String?> schmerz = const Value.absent(),
                Value<String> symptome = const Value.absent(),
                Value<bool> sex = const Value.absent(),
                Value<bool?> verhuetet = const Value.absent(),
                Value<String?> test = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<String> quelle = const Value.absent(),
                Value<DateTime> geaendert = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZyklusEintraegeCompanion(
                tag: tag,
                blutung: blutung,
                zwischenblutung: zwischenblutung,
                schmerz: schmerz,
                symptome: symptome,
                sex: sex,
                verhuetet: verhuetet,
                test: test,
                notiz: notiz,
                quelle: quelle,
                geaendert: geaendert,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String tag,
                Value<String?> blutung = const Value.absent(),
                Value<bool> zwischenblutung = const Value.absent(),
                Value<String?> schmerz = const Value.absent(),
                Value<String> symptome = const Value.absent(),
                Value<bool> sex = const Value.absent(),
                Value<bool?> verhuetet = const Value.absent(),
                Value<String?> test = const Value.absent(),
                Value<String?> notiz = const Value.absent(),
                Value<String> quelle = const Value.absent(),
                required DateTime geaendert,
                Value<int> rowid = const Value.absent(),
              }) => ZyklusEintraegeCompanion.insert(
                tag: tag,
                blutung: blutung,
                zwischenblutung: zwischenblutung,
                schmerz: schmerz,
                symptome: symptome,
                sex: sex,
                verhuetet: verhuetet,
                test: test,
                notiz: notiz,
                quelle: quelle,
                geaendert: geaendert,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ZyklusEintraegeTable, ZyklusEintragRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $ZyklusEintraegeTable,
                    ZyklusEintragRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZyklusEintraegeTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $ZyklusEintraegeTable,
      ZyklusEintragRow,
      $$ZyklusEintraegeTableFilterComposer,
      $$ZyklusEintraegeTableOrderingComposer,
      $$ZyklusEintraegeTableAnnotationComposer,
      $$ZyklusEintraegeTableCreateCompanionBuilder,
      $$ZyklusEintraegeTableUpdateCompanionBuilder,
      (
        ZyklusEintragRow,
        BaseReferences<_$AppCache, $ZyklusEintraegeTable, ZyklusEintragRow>,
      ),
      ZyklusEintragRow,
      PrefetchHooks Function()
    >;
typedef $$ZyklusHealthSpiegelTableCreateCompanionBuilder =
    ZyklusHealthSpiegelCompanion Function({
      required String uuid,
      required String tag,
      required String typ,
      Value<int> rowid,
    });
typedef $$ZyklusHealthSpiegelTableUpdateCompanionBuilder =
    ZyklusHealthSpiegelCompanion Function({
      Value<String> uuid,
      Value<String> tag,
      Value<String> typ,
      Value<int> rowid,
    });

class $$ZyklusHealthSpiegelTableFilterComposer
    extends Composer<_$AppCache, $ZyklusHealthSpiegelTable> {
  $$ZyklusHealthSpiegelTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get typ => $composableBuilder(
    column: $table.typ,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZyklusHealthSpiegelTableOrderingComposer
    extends Composer<_$AppCache, $ZyklusHealthSpiegelTable> {
  $$ZyklusHealthSpiegelTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get typ => $composableBuilder(
    column: $table.typ,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZyklusHealthSpiegelTableAnnotationComposer
    extends Composer<_$AppCache, $ZyklusHealthSpiegelTable> {
  $$ZyklusHealthSpiegelTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  GeneratedColumn<String> get typ =>
      $composableBuilder(column: $table.typ, builder: (column) => column);
}

class $$ZyklusHealthSpiegelTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $ZyklusHealthSpiegelTable,
          ZyklusSpiegelRow,
          $$ZyklusHealthSpiegelTableFilterComposer,
          $$ZyklusHealthSpiegelTableOrderingComposer,
          $$ZyklusHealthSpiegelTableAnnotationComposer,
          $$ZyklusHealthSpiegelTableCreateCompanionBuilder,
          $$ZyklusHealthSpiegelTableUpdateCompanionBuilder,
          (
            ZyklusSpiegelRow,
            BaseReferences<
              _$AppCache,
              $ZyklusHealthSpiegelTable,
              ZyklusSpiegelRow
            >,
          ),
          ZyklusSpiegelRow,
          PrefetchHooks Function()
        > {
  $$ZyklusHealthSpiegelTableTableManager(
    _$AppCache db,
    $ZyklusHealthSpiegelTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZyklusHealthSpiegelTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZyklusHealthSpiegelTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ZyklusHealthSpiegelTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> uuid = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<String> typ = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ZyklusHealthSpiegelCompanion(
                uuid: uuid,
                tag: tag,
                typ: typ,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uuid,
                required String tag,
                required String typ,
                Value<int> rowid = const Value.absent(),
              }) => ZyklusHealthSpiegelCompanion.insert(
                uuid: uuid,
                tag: tag,
                typ: typ,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ZyklusHealthSpiegelTable, ZyklusSpiegelRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppCache,
                    $ZyklusHealthSpiegelTable,
                    ZyklusSpiegelRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZyklusHealthSpiegelTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $ZyklusHealthSpiegelTable,
      ZyklusSpiegelRow,
      $$ZyklusHealthSpiegelTableFilterComposer,
      $$ZyklusHealthSpiegelTableOrderingComposer,
      $$ZyklusHealthSpiegelTableAnnotationComposer,
      $$ZyklusHealthSpiegelTableCreateCompanionBuilder,
      $$ZyklusHealthSpiegelTableUpdateCompanionBuilder,
      (
        ZyklusSpiegelRow,
        BaseReferences<_$AppCache, $ZyklusHealthSpiegelTable, ZyklusSpiegelRow>,
      ),
      ZyklusSpiegelRow,
      PrefetchHooks Function()
    >;
typedef $$ZyklusEinstellungenTableCreateCompanionBuilder =
    ZyklusEinstellungenCompanion Function({
      Value<int> id,
      Value<bool> kalenderAn,
      Value<String> sicht,
      Value<bool> verhuetungAn,
      Value<String?> verhuetungSeit,
      Value<String?> verhuetungArt,
      Value<bool> importGelaufen,
      Value<bool> vorhersagePausiert,
    });
typedef $$ZyklusEinstellungenTableUpdateCompanionBuilder =
    ZyklusEinstellungenCompanion Function({
      Value<int> id,
      Value<bool> kalenderAn,
      Value<String> sicht,
      Value<bool> verhuetungAn,
      Value<String?> verhuetungSeit,
      Value<String?> verhuetungArt,
      Value<bool> importGelaufen,
      Value<bool> vorhersagePausiert,
    });

class $$ZyklusEinstellungenTableFilterComposer
    extends Composer<_$AppCache, $ZyklusEinstellungenTable> {
  $$ZyklusEinstellungenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get kalenderAn => $composableBuilder(
    column: $table.kalenderAn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sicht => $composableBuilder(
    column: $table.sicht,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verhuetungAn => $composableBuilder(
    column: $table.verhuetungAn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verhuetungSeit => $composableBuilder(
    column: $table.verhuetungSeit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get verhuetungArt => $composableBuilder(
    column: $table.verhuetungArt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get importGelaufen => $composableBuilder(
    column: $table.importGelaufen,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vorhersagePausiert => $composableBuilder(
    column: $table.vorhersagePausiert,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ZyklusEinstellungenTableOrderingComposer
    extends Composer<_$AppCache, $ZyklusEinstellungenTable> {
  $$ZyklusEinstellungenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get kalenderAn => $composableBuilder(
    column: $table.kalenderAn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sicht => $composableBuilder(
    column: $table.sicht,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verhuetungAn => $composableBuilder(
    column: $table.verhuetungAn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verhuetungSeit => $composableBuilder(
    column: $table.verhuetungSeit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get verhuetungArt => $composableBuilder(
    column: $table.verhuetungArt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get importGelaufen => $composableBuilder(
    column: $table.importGelaufen,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vorhersagePausiert => $composableBuilder(
    column: $table.vorhersagePausiert,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ZyklusEinstellungenTableAnnotationComposer
    extends Composer<_$AppCache, $ZyklusEinstellungenTable> {
  $$ZyklusEinstellungenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get kalenderAn => $composableBuilder(
    column: $table.kalenderAn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sicht =>
      $composableBuilder(column: $table.sicht, builder: (column) => column);

  GeneratedColumn<bool> get verhuetungAn => $composableBuilder(
    column: $table.verhuetungAn,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verhuetungSeit => $composableBuilder(
    column: $table.verhuetungSeit,
    builder: (column) => column,
  );

  GeneratedColumn<String> get verhuetungArt => $composableBuilder(
    column: $table.verhuetungArt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get importGelaufen => $composableBuilder(
    column: $table.importGelaufen,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vorhersagePausiert => $composableBuilder(
    column: $table.vorhersagePausiert,
    builder: (column) => column,
  );
}

class $$ZyklusEinstellungenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $ZyklusEinstellungenTable,
          ZyklusEinstellungenRow,
          $$ZyklusEinstellungenTableFilterComposer,
          $$ZyklusEinstellungenTableOrderingComposer,
          $$ZyklusEinstellungenTableAnnotationComposer,
          $$ZyklusEinstellungenTableCreateCompanionBuilder,
          $$ZyklusEinstellungenTableUpdateCompanionBuilder,
          (
            ZyklusEinstellungenRow,
            BaseReferences<
              _$AppCache,
              $ZyklusEinstellungenTable,
              ZyklusEinstellungenRow
            >,
          ),
          ZyklusEinstellungenRow,
          PrefetchHooks Function()
        > {
  $$ZyklusEinstellungenTableTableManager(
    _$AppCache db,
    $ZyklusEinstellungenTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZyklusEinstellungenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZyklusEinstellungenTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ZyklusEinstellungenTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> kalenderAn = const Value.absent(),
                Value<String> sicht = const Value.absent(),
                Value<bool> verhuetungAn = const Value.absent(),
                Value<String?> verhuetungSeit = const Value.absent(),
                Value<String?> verhuetungArt = const Value.absent(),
                Value<bool> importGelaufen = const Value.absent(),
                Value<bool> vorhersagePausiert = const Value.absent(),
              }) => ZyklusEinstellungenCompanion(
                id: id,
                kalenderAn: kalenderAn,
                sicht: sicht,
                verhuetungAn: verhuetungAn,
                verhuetungSeit: verhuetungSeit,
                verhuetungArt: verhuetungArt,
                importGelaufen: importGelaufen,
                vorhersagePausiert: vorhersagePausiert,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> kalenderAn = const Value.absent(),
                Value<String> sicht = const Value.absent(),
                Value<bool> verhuetungAn = const Value.absent(),
                Value<String?> verhuetungSeit = const Value.absent(),
                Value<String?> verhuetungArt = const Value.absent(),
                Value<bool> importGelaufen = const Value.absent(),
                Value<bool> vorhersagePausiert = const Value.absent(),
              }) => ZyklusEinstellungenCompanion.insert(
                id: id,
                kalenderAn: kalenderAn,
                sicht: sicht,
                verhuetungAn: verhuetungAn,
                verhuetungSeit: verhuetungSeit,
                verhuetungArt: verhuetungArt,
                importGelaufen: importGelaufen,
                vorhersagePausiert: vorhersagePausiert,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ZyklusEinstellungenTable,
                    ZyklusEinstellungenRow
                  >(table),
                  BaseReferences<
                    _$AppCache,
                    $ZyklusEinstellungenTable,
                    ZyklusEinstellungenRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ZyklusEinstellungenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $ZyklusEinstellungenTable,
      ZyklusEinstellungenRow,
      $$ZyklusEinstellungenTableFilterComposer,
      $$ZyklusEinstellungenTableOrderingComposer,
      $$ZyklusEinstellungenTableAnnotationComposer,
      $$ZyklusEinstellungenTableCreateCompanionBuilder,
      $$ZyklusEinstellungenTableUpdateCompanionBuilder,
      (
        ZyklusEinstellungenRow,
        BaseReferences<
          _$AppCache,
          $ZyklusEinstellungenTable,
          ZyklusEinstellungenRow
        >,
      ),
      ZyklusEinstellungenRow,
      PrefetchHooks Function()
    >;
typedef $$GymTrainingsTableCreateCompanionBuilder =
    GymTrainingsCompanion Function({
      required String id,
      required String name,
      required String kategorie,
      Value<int?> dauerEingetragenMin,
      Value<bool> istEntwurf,
      Value<bool> geloescht,
      required int reihenfolge,
      Value<String?> entwurfVon,
      Value<int> rowid,
    });
typedef $$GymTrainingsTableUpdateCompanionBuilder =
    GymTrainingsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> kategorie,
      Value<int?> dauerEingetragenMin,
      Value<bool> istEntwurf,
      Value<bool> geloescht,
      Value<int> reihenfolge,
      Value<String?> entwurfVon,
      Value<int> rowid,
    });

class $$GymTrainingsTableFilterComposer
    extends Composer<_$AppCache, $GymTrainingsTable> {
  $$GymTrainingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kategorie => $composableBuilder(
    column: $table.kategorie,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dauerEingetragenMin => $composableBuilder(
    column: $table.dauerEingetragenMin,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get istEntwurf => $composableBuilder(
    column: $table.istEntwurf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get geloescht => $composableBuilder(
    column: $table.geloescht,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get reihenfolge => $composableBuilder(
    column: $table.reihenfolge,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entwurfVon => $composableBuilder(
    column: $table.entwurfVon,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymTrainingsTableOrderingComposer
    extends Composer<_$AppCache, $GymTrainingsTable> {
  $$GymTrainingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kategorie => $composableBuilder(
    column: $table.kategorie,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dauerEingetragenMin => $composableBuilder(
    column: $table.dauerEingetragenMin,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get istEntwurf => $composableBuilder(
    column: $table.istEntwurf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get geloescht => $composableBuilder(
    column: $table.geloescht,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get reihenfolge => $composableBuilder(
    column: $table.reihenfolge,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entwurfVon => $composableBuilder(
    column: $table.entwurfVon,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymTrainingsTableAnnotationComposer
    extends Composer<_$AppCache, $GymTrainingsTable> {
  $$GymTrainingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get kategorie =>
      $composableBuilder(column: $table.kategorie, builder: (column) => column);

  GeneratedColumn<int> get dauerEingetragenMin => $composableBuilder(
    column: $table.dauerEingetragenMin,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get istEntwurf => $composableBuilder(
    column: $table.istEntwurf,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get geloescht =>
      $composableBuilder(column: $table.geloescht, builder: (column) => column);

  GeneratedColumn<int> get reihenfolge => $composableBuilder(
    column: $table.reihenfolge,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entwurfVon => $composableBuilder(
    column: $table.entwurfVon,
    builder: (column) => column,
  );
}

class $$GymTrainingsTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymTrainingsTable,
          GymTrainingRow,
          $$GymTrainingsTableFilterComposer,
          $$GymTrainingsTableOrderingComposer,
          $$GymTrainingsTableAnnotationComposer,
          $$GymTrainingsTableCreateCompanionBuilder,
          $$GymTrainingsTableUpdateCompanionBuilder,
          (
            GymTrainingRow,
            BaseReferences<_$AppCache, $GymTrainingsTable, GymTrainingRow>,
          ),
          GymTrainingRow,
          PrefetchHooks Function()
        > {
  $$GymTrainingsTableTableManager(_$AppCache db, $GymTrainingsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymTrainingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymTrainingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymTrainingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> kategorie = const Value.absent(),
                Value<int?> dauerEingetragenMin = const Value.absent(),
                Value<bool> istEntwurf = const Value.absent(),
                Value<bool> geloescht = const Value.absent(),
                Value<int> reihenfolge = const Value.absent(),
                Value<String?> entwurfVon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingsCompanion(
                id: id,
                name: name,
                kategorie: kategorie,
                dauerEingetragenMin: dauerEingetragenMin,
                istEntwurf: istEntwurf,
                geloescht: geloescht,
                reihenfolge: reihenfolge,
                entwurfVon: entwurfVon,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String kategorie,
                Value<int?> dauerEingetragenMin = const Value.absent(),
                Value<bool> istEntwurf = const Value.absent(),
                Value<bool> geloescht = const Value.absent(),
                required int reihenfolge,
                Value<String?> entwurfVon = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingsCompanion.insert(
                id: id,
                name: name,
                kategorie: kategorie,
                dauerEingetragenMin: dauerEingetragenMin,
                istEntwurf: istEntwurf,
                geloescht: geloescht,
                reihenfolge: reihenfolge,
                entwurfVon: entwurfVon,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymTrainingsTable, GymTrainingRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $GymTrainingsTable,
                    GymTrainingRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymTrainingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymTrainingsTable,
      GymTrainingRow,
      $$GymTrainingsTableFilterComposer,
      $$GymTrainingsTableOrderingComposer,
      $$GymTrainingsTableAnnotationComposer,
      $$GymTrainingsTableCreateCompanionBuilder,
      $$GymTrainingsTableUpdateCompanionBuilder,
      (
        GymTrainingRow,
        BaseReferences<_$AppCache, $GymTrainingsTable, GymTrainingRow>,
      ),
      GymTrainingRow,
      PrefetchHooks Function()
    >;
typedef $$GymTrainingUebungenTableCreateCompanionBuilder =
    GymTrainingUebungenCompanion Function({
      required String trainingId,
      required int pos,
      required String uebungId,
      required int saetze,
      required int wdhVon,
      required int wdhBis,
      Value<double?> steigerung,
      Value<int> rowid,
    });
typedef $$GymTrainingUebungenTableUpdateCompanionBuilder =
    GymTrainingUebungenCompanion Function({
      Value<String> trainingId,
      Value<int> pos,
      Value<String> uebungId,
      Value<int> saetze,
      Value<int> wdhVon,
      Value<int> wdhBis,
      Value<double?> steigerung,
      Value<int> rowid,
    });

class $$GymTrainingUebungenTableFilterComposer
    extends Composer<_$AppCache, $GymTrainingUebungenTable> {
  $$GymTrainingUebungenTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uebungId => $composableBuilder(
    column: $table.uebungId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get saetze => $composableBuilder(
    column: $table.saetze,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wdhVon => $composableBuilder(
    column: $table.wdhVon,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get wdhBis => $composableBuilder(
    column: $table.wdhBis,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get steigerung => $composableBuilder(
    column: $table.steigerung,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymTrainingUebungenTableOrderingComposer
    extends Composer<_$AppCache, $GymTrainingUebungenTable> {
  $$GymTrainingUebungenTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uebungId => $composableBuilder(
    column: $table.uebungId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get saetze => $composableBuilder(
    column: $table.saetze,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wdhVon => $composableBuilder(
    column: $table.wdhVon,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get wdhBis => $composableBuilder(
    column: $table.wdhBis,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get steigerung => $composableBuilder(
    column: $table.steigerung,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymTrainingUebungenTableAnnotationComposer
    extends Composer<_$AppCache, $GymTrainingUebungenTable> {
  $$GymTrainingUebungenTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get uebungId =>
      $composableBuilder(column: $table.uebungId, builder: (column) => column);

  GeneratedColumn<int> get saetze =>
      $composableBuilder(column: $table.saetze, builder: (column) => column);

  GeneratedColumn<int> get wdhVon =>
      $composableBuilder(column: $table.wdhVon, builder: (column) => column);

  GeneratedColumn<int> get wdhBis =>
      $composableBuilder(column: $table.wdhBis, builder: (column) => column);

  GeneratedColumn<double> get steigerung => $composableBuilder(
    column: $table.steigerung,
    builder: (column) => column,
  );
}

class $$GymTrainingUebungenTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymTrainingUebungenTable,
          GymTrainingUebungRow,
          $$GymTrainingUebungenTableFilterComposer,
          $$GymTrainingUebungenTableOrderingComposer,
          $$GymTrainingUebungenTableAnnotationComposer,
          $$GymTrainingUebungenTableCreateCompanionBuilder,
          $$GymTrainingUebungenTableUpdateCompanionBuilder,
          (
            GymTrainingUebungRow,
            BaseReferences<
              _$AppCache,
              $GymTrainingUebungenTable,
              GymTrainingUebungRow
            >,
          ),
          GymTrainingUebungRow,
          PrefetchHooks Function()
        > {
  $$GymTrainingUebungenTableTableManager(
    _$AppCache db,
    $GymTrainingUebungenTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymTrainingUebungenTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymTrainingUebungenTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$GymTrainingUebungenTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> trainingId = const Value.absent(),
                Value<int> pos = const Value.absent(),
                Value<String> uebungId = const Value.absent(),
                Value<int> saetze = const Value.absent(),
                Value<int> wdhVon = const Value.absent(),
                Value<int> wdhBis = const Value.absent(),
                Value<double?> steigerung = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingUebungenCompanion(
                trainingId: trainingId,
                pos: pos,
                uebungId: uebungId,
                saetze: saetze,
                wdhVon: wdhVon,
                wdhBis: wdhBis,
                steigerung: steigerung,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trainingId,
                required int pos,
                required String uebungId,
                required int saetze,
                required int wdhVon,
                required int wdhBis,
                Value<double?> steigerung = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingUebungenCompanion.insert(
                trainingId: trainingId,
                pos: pos,
                uebungId: uebungId,
                saetze: saetze,
                wdhVon: wdhVon,
                wdhBis: wdhBis,
                steigerung: steigerung,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymTrainingUebungenTable, GymTrainingUebungRow>(
                    table,
                  ),
                  BaseReferences<
                    _$AppCache,
                    $GymTrainingUebungenTable,
                    GymTrainingUebungRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymTrainingUebungenTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymTrainingUebungenTable,
      GymTrainingUebungRow,
      $$GymTrainingUebungenTableFilterComposer,
      $$GymTrainingUebungenTableOrderingComposer,
      $$GymTrainingUebungenTableAnnotationComposer,
      $$GymTrainingUebungenTableCreateCompanionBuilder,
      $$GymTrainingUebungenTableUpdateCompanionBuilder,
      (
        GymTrainingUebungRow,
        BaseReferences<
          _$AppCache,
          $GymTrainingUebungenTable,
          GymTrainingUebungRow
        >,
      ),
      GymTrainingUebungRow,
      PrefetchHooks Function()
    >;
typedef $$GymTrainingTagsTableCreateCompanionBuilder =
    GymTrainingTagsCompanion Function({
      required String trainingId,
      required int pos,
      required String tag,
      Value<int> rowid,
    });
typedef $$GymTrainingTagsTableUpdateCompanionBuilder =
    GymTrainingTagsCompanion Function({
      Value<String> trainingId,
      Value<int> pos,
      Value<String> tag,
      Value<int> rowid,
    });

class $$GymTrainingTagsTableFilterComposer
    extends Composer<_$AppCache, $GymTrainingTagsTable> {
  $$GymTrainingTagsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymTrainingTagsTableOrderingComposer
    extends Composer<_$AppCache, $GymTrainingTagsTable> {
  $$GymTrainingTagsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymTrainingTagsTableAnnotationComposer
    extends Composer<_$AppCache, $GymTrainingTagsTable> {
  $$GymTrainingTagsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);
}

class $$GymTrainingTagsTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymTrainingTagsTable,
          GymTrainingTagRow,
          $$GymTrainingTagsTableFilterComposer,
          $$GymTrainingTagsTableOrderingComposer,
          $$GymTrainingTagsTableAnnotationComposer,
          $$GymTrainingTagsTableCreateCompanionBuilder,
          $$GymTrainingTagsTableUpdateCompanionBuilder,
          (
            GymTrainingTagRow,
            BaseReferences<
              _$AppCache,
              $GymTrainingTagsTable,
              GymTrainingTagRow
            >,
          ),
          GymTrainingTagRow,
          PrefetchHooks Function()
        > {
  $$GymTrainingTagsTableTableManager(_$AppCache db, $GymTrainingTagsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymTrainingTagsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymTrainingTagsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymTrainingTagsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> trainingId = const Value.absent(),
                Value<int> pos = const Value.absent(),
                Value<String> tag = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingTagsCompanion(
                trainingId: trainingId,
                pos: pos,
                tag: tag,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String trainingId,
                required int pos,
                required String tag,
                Value<int> rowid = const Value.absent(),
              }) => GymTrainingTagsCompanion.insert(
                trainingId: trainingId,
                pos: pos,
                tag: tag,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymTrainingTagsTable, GymTrainingTagRow>(table),
                  BaseReferences<
                    _$AppCache,
                    $GymTrainingTagsTable,
                    GymTrainingTagRow
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymTrainingTagsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymTrainingTagsTable,
      GymTrainingTagRow,
      $$GymTrainingTagsTableFilterComposer,
      $$GymTrainingTagsTableOrderingComposer,
      $$GymTrainingTagsTableAnnotationComposer,
      $$GymTrainingTagsTableCreateCompanionBuilder,
      $$GymTrainingTagsTableUpdateCompanionBuilder,
      (
        GymTrainingTagRow,
        BaseReferences<_$AppCache, $GymTrainingTagsTable, GymTrainingTagRow>,
      ),
      GymTrainingTagRow,
      PrefetchHooks Function()
    >;
typedef $$GymRotationTableCreateCompanionBuilder =
    GymRotationCompanion Function({Value<int> pos, required String trainingId});
typedef $$GymRotationTableUpdateCompanionBuilder =
    GymRotationCompanion Function({Value<int> pos, Value<String> trainingId});

class $$GymRotationTableFilterComposer
    extends Composer<_$AppCache, $GymRotationTable> {
  $$GymRotationTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GymRotationTableOrderingComposer
    extends Composer<_$AppCache, $GymRotationTable> {
  $$GymRotationTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get pos => $composableBuilder(
    column: $table.pos,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GymRotationTableAnnotationComposer
    extends Composer<_$AppCache, $GymRotationTable> {
  $$GymRotationTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get pos =>
      $composableBuilder(column: $table.pos, builder: (column) => column);

  GeneratedColumn<String> get trainingId => $composableBuilder(
    column: $table.trainingId,
    builder: (column) => column,
  );
}

class $$GymRotationTableTableManager
    extends
        RootTableManager<
          _$AppCache,
          $GymRotationTable,
          GymRotationRow,
          $$GymRotationTableFilterComposer,
          $$GymRotationTableOrderingComposer,
          $$GymRotationTableAnnotationComposer,
          $$GymRotationTableCreateCompanionBuilder,
          $$GymRotationTableUpdateCompanionBuilder,
          (
            GymRotationRow,
            BaseReferences<_$AppCache, $GymRotationTable, GymRotationRow>,
          ),
          GymRotationRow,
          PrefetchHooks Function()
        > {
  $$GymRotationTableTableManager(_$AppCache db, $GymRotationTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GymRotationTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GymRotationTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GymRotationTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> pos = const Value.absent(),
            Value<String> trainingId = const Value.absent(),
          }) => GymRotationCompanion(pos: pos, trainingId: trainingId),
          createCompanionCallback: ({
            Value<int> pos = const Value.absent(),
            required String trainingId,
          }) => GymRotationCompanion.insert(pos: pos, trainingId: trainingId),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$GymRotationTable, GymRotationRow>(table),
                  BaseReferences<_$AppCache, $GymRotationTable, GymRotationRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GymRotationTableProcessedTableManager =
    ProcessedTableManager<
      _$AppCache,
      $GymRotationTable,
      GymRotationRow,
      $$GymRotationTableFilterComposer,
      $$GymRotationTableOrderingComposer,
      $$GymRotationTableAnnotationComposer,
      $$GymRotationTableCreateCompanionBuilder,
      $$GymRotationTableUpdateCompanionBuilder,
      (
        GymRotationRow,
        BaseReferences<_$AppCache, $GymRotationTable, GymRotationRow>,
      ),
      GymRotationRow,
      PrefetchHooks Function()
    >;

class $AppCacheManager {
  final _$AppCache _db;
  $AppCacheManager(this._db);
  $$TagesWerteTableTableManager get tagesWerte =>
      $$TagesWerteTableTableManager(_db, _db.tagesWerte);
  $$StundenSchritteTableTableManager get stundenSchritte =>
      $$StundenSchritteTableTableManager(_db, _db.stundenSchritte);
  $$EigeneDatenTableTableManager get eigeneDaten =>
      $$EigeneDatenTableTableManager(_db, _db.eigeneDaten);
  $$NaechteTableTableManager get naechte =>
      $$NaechteTableTableManager(_db, _db.naechte);
  $$SchlafAbschnitteTableTableManager get schlafAbschnitte =>
      $$SchlafAbschnitteTableTableManager(_db, _db.schlafAbschnitte);
  $$ZielWerteTableTableManager get zielWerte =>
      $$ZielWerteTableTableManager(_db, _db.zielWerte);
  $$SchlafEintraegeTableTableManager get schlafEintraege =>
      $$SchlafEintraegeTableTableManager(_db, _db.schlafEintraege);
  $$StammdatenTableTableManager get stammdaten =>
      $$StammdatenTableTableManager(_db, _db.stammdaten);
  $$LebensmittelTableTableManager get lebensmittel =>
      $$LebensmittelTableTableManager(_db, _db.lebensmittel);
  $$PortionenTableTableManager get portionen =>
      $$PortionenTableTableManager(_db, _db.portionen);
  $$EintraegeTableTableManager get eintraege =>
      $$EintraegeTableTableManager(_db, _db.eintraege);
  $$RezepteTableTableManager get rezepte =>
      $$RezepteTableTableManager(_db, _db.rezepte);
  $$RezeptZutatenTableTableManager get rezeptZutaten =>
      $$RezeptZutatenTableTableManager(_db, _db.rezeptZutaten);
  $$KiEinstellungenTableTableManager get kiEinstellungen =>
      $$KiEinstellungenTableTableManager(_db, _db.kiEinstellungen);
  $$KiAnfragenTableTableManager get kiAnfragen =>
      $$KiAnfragenTableTableManager(_db, _db.kiAnfragen);
  $$WasserEintraegeTableTableManager get wasserEintraege =>
      $$WasserEintraegeTableTableManager(_db, _db.wasserEintraege);
  $$GymSitzungenTableTableManager get gymSitzungen =>
      $$GymSitzungenTableTableManager(_db, _db.gymSitzungen);
  $$GymSaetzeTableTableManager get gymSaetze =>
      $$GymSaetzeTableTableManager(_db, _db.gymSaetze);
  $$GymEntwuerfeTableTableManager get gymEntwuerfe =>
      $$GymEntwuerfeTableTableManager(_db, _db.gymEntwuerfe);
  $$KalorienzieleTableTableManager get kalorienziele =>
      $$KalorienzieleTableTableManager(_db, _db.kalorienziele);
  $$MahlzeitAufteilungenTableTableManager get mahlzeitAufteilungen =>
      $$MahlzeitAufteilungenTableTableManager(_db, _db.mahlzeitAufteilungen);
  $$EreignisseTableTableManager get ereignisse =>
      $$EreignisseTableTableManager(_db, _db.ereignisse);
  $$WachBelegeTableTableManager get wachBelege =>
      $$WachBelegeTableTableManager(_db, _db.wachBelege);
  $$UmfaengeTableTableManager get umfaenge =>
      $$UmfaengeTableTableManager(_db, _db.umfaenge);
  $$ZyklusEintraegeTableTableManager get zyklusEintraege =>
      $$ZyklusEintraegeTableTableManager(_db, _db.zyklusEintraege);
  $$ZyklusHealthSpiegelTableTableManager get zyklusHealthSpiegel =>
      $$ZyklusHealthSpiegelTableTableManager(_db, _db.zyklusHealthSpiegel);
  $$ZyklusEinstellungenTableTableManager get zyklusEinstellungen =>
      $$ZyklusEinstellungenTableTableManager(_db, _db.zyklusEinstellungen);
  $$GymTrainingsTableTableManager get gymTrainings =>
      $$GymTrainingsTableTableManager(_db, _db.gymTrainings);
  $$GymTrainingUebungenTableTableManager get gymTrainingUebungen =>
      $$GymTrainingUebungenTableTableManager(_db, _db.gymTrainingUebungen);
  $$GymTrainingTagsTableTableManager get gymTrainingTags =>
      $$GymTrainingTagsTableTableManager(_db, _db.gymTrainingTags);
  $$GymRotationTableTableManager get gymRotation =>
      $$GymRotationTableTableManager(_db, _db.gymRotation);
}
