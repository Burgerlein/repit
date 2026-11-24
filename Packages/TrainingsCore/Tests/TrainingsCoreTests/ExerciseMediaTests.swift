import Testing
@testable import TrainingsCore

/// Die erwartete Zuordnung unserer Übungs-IDs auf Einträge des Datensatzes
/// `hasaneyldrm/exercises-dataset`. Dieselbe Tabelle liegt als JSON in
/// `docs/prototype/exercise-media.json` und dient dort zur Gegenprobe.
fileprivate struct ErwarteteZuordnung: Sendable, CustomTestStringConvertible {
    let exerciseID: String
    let datasetID: String
    let mediaID: String
    let datasetName: String
    var isApproximate: Bool = false

    var testDescription: String { exerciseID }

    static let alle: [ErwarteteZuordnung] = [
        .init(exerciseID: "benchPress", datasetID: "0025", mediaID: "0025-EIeI8Vf",
              datasetName: "barbell bench press"),
        .init(exerciseID: "inclineDumbbellPress", datasetID: "0314", mediaID: "0314-ns0SIbU",
              datasetName: "dumbbell incline bench press"),
        .init(exerciseID: "shoulderPressDumbbell", datasetID: "0405", mediaID: "0405-znQUdHY",
              datasetName: "dumbbell seated shoulder press"),
        .init(exerciseID: "dips", datasetID: "0251", mediaID: "0251-9WTm7dq",
              datasetName: "chest dip"),
        .init(exerciseID: "lateralRaise", datasetID: "0334", mediaID: "0334-DsgkuIt",
              datasetName: "dumbbell lateral raise"),
        .init(exerciseID: "overheadTriceps", datasetID: "0194", mediaID: "0194-2IxROQ1",
              datasetName: "cable overhead triceps extension (rope attachment)"),
        .init(exerciseID: "bicepsCurl", datasetID: "0294", mediaID: "0294-NbVPDMW",
              datasetName: "dumbbell biceps curl"),
        .init(exerciseID: "splitSquat", datasetID: "0410", mediaID: "0410-qx4fgX7",
              datasetName: "dumbbell single leg split squat"),
        .init(exerciseID: "romanianDeadlift", datasetID: "0085", mediaID: "0085-wQ2c4XD",
              datasetName: "barbell romanian deadlift"),
        .init(exerciseID: "hipThrust", datasetID: "3562", mediaID: "3562-qg2PGl6",
              datasetName: "barbell glute bridge two legs on bench (male)"),
        .init(exerciseID: "calfRaiseStanding", datasetID: "0409", mediaID: "0409-1kB3Wmk",
              datasetName: "dumbbell single leg calf raise"),
        .init(exerciseID: "calfRaiseSeated", datasetID: "0594", mediaID: "0594-bOOdeyc",
              datasetName: "lever seated calf raise"),
        .init(exerciseID: "cableFly", datasetID: "0188", mediaID: "0188-xLYSdtg",
              datasetName: "cable middle fly"),
        .init(exerciseID: "sidePlank", datasetID: "3544", mediaID: "3544-5VXmnV5",
              datasetName: "bodyweight incline side plank"),
        .init(exerciseID: "pullUp", datasetID: "0652", mediaID: "0652-lBDjFxJ",
              datasetName: "pull-up"),
        .init(exerciseID: "oneArmRow", datasetID: "0292", mediaID: "0292-C0MA9bC",
              datasetName: "dumbbell one arm bent-over row"),
        .init(exerciseID: "cableRowClose", datasetID: "1320", mediaID: "1320-UFGF6gk",
              datasetName: "cable rope crossover seated row"),
        // Einzige Näherung: Der Datensatz kennt keinen Face Pull.
        .init(exerciseID: "facePull", datasetID: "0233", mediaID: "0233-ZfyAGhK",
              datasetName: "cable standing rear delt row (with rope)", isApproximate: true),
        .init(exerciseID: "ezCurl", datasetID: "0447", mediaID: "0447-6TG6x2w",
              datasetName: "ez barbell curl"),
        .init(exerciseID: "hammerCurl", datasetID: "0313", mediaID: "0313-slDvUAU",
              datasetName: "dumbbell hammer curl"),
        .init(exerciseID: "tricepsPushdown", datasetID: "0200", mediaID: "0200-dU605di",
              datasetName: "cable pushdown (with rope attachment)"),
        .init(exerciseID: "closeGripBench", datasetID: "0030", mediaID: "0030-J6Dx1Mu",
              datasetName: "barbell close-grip bench press"),
        .init(exerciseID: "shoulderPressMachine", datasetID: "0603", mediaID: "0603-67n3r98",
              datasetName: "lever shoulder press"),
        .init(exerciseID: "reverseFly", datasetID: "0383", mediaID: "0383-EAs3xL9",
              datasetName: "dumbbell reverse fly"),
        .init(exerciseID: "inclineCurl", datasetID: "0315", mediaID: "0315-F3xgbjF",
              datasetName: "dumbbell incline biceps curl")
    ]
}

@Suite("Übungs-Medien")
struct ExerciseMediaTests {

    @Test("Jede Übung zeigt den zugeordneten Datensatz-Eintrag",
          arguments: ErwarteteZuordnung.alle)
    fileprivate func mediaMatchesMapping(_ erwartet: ErwarteteZuordnung) throws {
        let media = try #require(ExerciseMediaCatalog.media(for: erwartet.exerciseID),
                                 "\(erwartet.exerciseID): keine Medien im Katalog")
        #expect(media.datasetID == erwartet.datasetID)
        #expect(media.mediaID == erwartet.mediaID)
        #expect(media.datasetName == erwartet.datasetName)
        #expect(media.isApproximate == erwartet.isApproximate)
    }

    @Test("Der Katalog enthält genau die 25 zugeordneten Übungen")
    func catalogHasExpectedCount() {
        // Die sieben neuen Übungen aus SPEC 4.4 bringen keine Medien mit;
        // diese Zahl bleibt deshalb stehen.
        #expect(ExerciseMediaCatalog.all.count == ErwarteteZuordnung.alle.count)
        #expect(ErwarteteZuordnung.alle.count == 25)
    }

    @Test("Zugeordnet und unzugeordnet ergeben zusammen den ganzen Übungskatalog")
    func mediaAndUnmatchedCoverTheCatalog() {
        let abgedeckt = Set(ExerciseMediaCatalog.all.keys)
            .union(ExerciseMediaCatalog.unmatchedExerciseIDs)
        #expect(abgedeckt == Set(ExerciseCatalog.all.keys),
                "offen: \(Set(ExerciseCatalog.all.keys).subtracting(abgedeckt).sorted())")
    }

    @Test("Face Pulls sind die einzige Näherung")
    func onlyFacePullIsApproximate() {
        let approximate = ExerciseMediaCatalog.all.values
            .filter(\.isApproximate)
            .map(\.exerciseID)
            .sorted()
        #expect(approximate == ["facePull"])
    }

    /// Acht Übungen bleiben ohne Animation. Die Datensatz-ID ließe sich für
    /// sie nur raten, und eine geratene ID zeigt eine andere Übung — eine
    /// falsche Animation ist schlechter als gar keine, weil sie richtig
    /// aussieht.
    @Test("Diese acht Übungen haben keinen Eintrag im Datensatz")
    func unmatchedExercises() {
        #expect(ExerciseMediaCatalog.unmatchedExerciseIDs
                == ["tibialisRaise", "barbellRow", "straightArmPulldown",
                    "backExtension", "legPress", "legCurl", "hipAbduction",
                    "legExtension"])
        #expect(ExerciseMediaCatalog.unmatchedExerciseIDs.count == 8)
    }

    @Test("Keine unzugeordnete Übung steht trotzdem im Medienkatalog",
          arguments: ["tibialisRaise", "barbellRow", "straightArmPulldown",
                      "backExtension", "legPress", "legCurl", "hipAbduction",
                      "legExtension"])
    func unmatchedExerciseHasNoMedia(_ id: String) {
        #expect(ExerciseMediaCatalog.media(for: id) == nil)
        #expect(ExerciseMediaCatalog.all[id] == nil)
    }

    @Test("Jede Übung des Katalogs hat Medien oder steht als unzugeordnet fest")
    func everyExerciseIsAccountedFor() {
        for id in ExerciseCatalog.all.keys {
            let hasMedia = ExerciseMediaCatalog.media(for: id) != nil
            let isUnmatched = ExerciseMediaCatalog.unmatchedExerciseIDs.contains(id)
            #expect(hasMedia != isUnmatched,
                    "\(id): Medien \(hasMedia), unzugeordnet \(isUnmatched) — genau eines muss gelten")
        }
    }

    @Test("Der Medienkatalog kennt keine Karteileichen")
    func noOrphanedMediaEntries() {
        for id in ExerciseMediaCatalog.all.keys {
            #expect(ExerciseCatalog.all[id] != nil,
                    "\(id): keine Übung dieses Namens im Übungskatalog")
        }
        for id in ExerciseMediaCatalog.unmatchedExerciseIDs {
            #expect(ExerciseCatalog.all[id] != nil,
                    "\(id): keine Übung dieses Namens im Übungskatalog")
        }
    }

    @Test("Schlüssel und exerciseID stimmen überein")
    func keyMatchesExerciseID() {
        for (key, media) in ExerciseMediaCatalog.all {
            #expect(media.exerciseID == key,
                    "Schlüssel \(key) trägt die exerciseID \(media.exerciseID)")
        }
    }

    @Test("Jede mediaID beginnt mit ihrer datasetID und einem Bindestrich")
    func mediaIDStartsWithDatasetID() {
        for media in ExerciseMediaCatalog.all.values {
            #expect(media.mediaID.hasPrefix(media.datasetID + "-"),
                    "\(media.exerciseID): \(media.mediaID) passt nicht zu \(media.datasetID)")
        }
    }

    @Test("Keine zwei Übungen zeigen dieselbe Animation")
    func mediaIDsAreUnique() {
        let ids = ExerciseMediaCatalog.all.values.map(\.mediaID)
        #expect(Set(ids).count == ids.count, "doppelte mediaID in \(ids.sorted())")
    }

    @Test("Die Pfade folgen dem Aufbau des Datensatzes")
    func relativePathsFollowDatasetLayout() {
        for media in ExerciseMediaCatalog.all.values {
            #expect(media.relativeGIFPath == "videos/\(media.mediaID).gif",
                    "\(media.exerciseID): \(media.relativeGIFPath)")
            #expect(media.relativeImagePath == "images/\(media.mediaID).jpg",
                    "\(media.exerciseID): \(media.relativeImagePath)")
        }
    }

    @Test("Bankdrücken zeigt die Pfade aus dem Datensatz")
    func benchPressPaths() throws {
        let media = try #require(ExerciseMediaCatalog.media(for: "benchPress"))
        #expect(media.relativeGIFPath == "videos/0025-EIeI8Vf.gif")
        #expect(media.relativeImagePath == "images/0025-EIeI8Vf.jpg")
    }

    @Test("Die Lizenz verlangt diese Urheberangabe wörtlich")
    func attributionIsVerbatim() {
        #expect(ExerciseMediaCatalog.attribution == "© Gym visual — https://gymvisual.com/")
    }
}
