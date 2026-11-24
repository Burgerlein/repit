import Foundation

/// Zuordnung einer Übung auf ihren Eintrag im Datensatz
/// `hasaneyldrm/exercises-dataset`, aus dem die Bewegungs-Animationen kommen.
///
/// Hier stehen nur Pfade, keine URLs und kein Netzwerk: Das Paket importiert
/// ausschließlich Foundation, und wo die Dateien herkommen, geht die
/// Berechnungen nichts an. Den Host und den Zwischenspeicher kennt das
/// App-Target.
public struct ExerciseMedia: Equatable, Sendable {

    /// Unsere ID aus `ExerciseCatalog`.
    public let exerciseID: String
    /// Die vierstellige ID des Datensatzes, etwa `0025`.
    public let datasetID: String
    /// ID der Mediendatei, etwa `0025-EIeI8Vf`. Beginnt mit `datasetID`.
    public let mediaID: String
    /// Englischer Name im Datensatz. Nur zur Nachvollziehbarkeit — angezeigt
    /// wird der deutsche Name aus `ExerciseCatalog`.
    public let datasetName: String
    /// Der Datensatz trifft die Übung nicht genau. Dann ist die Animation ein
    /// Anhaltspunkt und keine Vorlage.
    public let isApproximate: Bool

    public init(exerciseID: String, datasetID: String, mediaID: String,
                datasetName: String, isApproximate: Bool = false) {
        self.exerciseID = exerciseID
        self.datasetID = datasetID
        self.mediaID = mediaID
        self.datasetName = datasetName
        self.isApproximate = isApproximate
    }

    public var relativeGIFPath: String { "videos/\(mediaID).gif" }
    public var relativeImagePath: String { "images/\(mediaID).jpg" }
}

public enum ExerciseMediaCatalog {

    /// Die Medien sind nicht Teil der MIT-Lizenz des Datensatzes. Sie gehören
    /// Gym visual und dürfen nur mit dieser Angabe verwendet werden — deshalb
    /// steht sie als Konstante hier und nicht als Zeichenkette in einer View.
    public static let attribution = "© Gym visual — https://gymvisual.com/"

    /// Übungen, zu denen der Datensatz nichts Passendes hat. Dort bleibt es
    /// bei der YouTube-Suche.
    ///
    /// Die sieben Übungen aus Push, Pull und Legs stehen hier, weil ihre
    /// Datensatz-ID nicht nachgeschlagen, sondern nur geraten werden könnte.
    /// Eine geratene ID zeigt eine **andere** Übung, und eine falsche
    /// Animation ist schlechter als gar keine: Sie sieht richtig aus.
    /// Sobald die IDs geprüft sind, wandern sie nach `list` und hier raus.
    public static let unmatchedExerciseIDs: Set<String> = [
        "tibialisRaise",
        "barbellRow", "straightArmPulldown", "backExtension",
        "legPress", "legCurl", "hipAbduction", "legExtension"
    ]

    public static func media(for exerciseID: String) -> ExerciseMedia? {
        all[exerciseID]
    }

    public static let all: [String: ExerciseMedia] = Dictionary(
        uniqueKeysWithValues: list.map { ($0.exerciseID, $0) })

    private static let list: [ExerciseMedia] = [
        ExerciseMedia(exerciseID: "benchPress", datasetID: "0025",
                      mediaID: "0025-EIeI8Vf", datasetName: "barbell bench press"),
        ExerciseMedia(exerciseID: "inclineDumbbellPress", datasetID: "0314",
                      mediaID: "0314-ns0SIbU", datasetName: "dumbbell incline bench press"),
        ExerciseMedia(exerciseID: "shoulderPressDumbbell", datasetID: "0405",
                      mediaID: "0405-znQUdHY", datasetName: "dumbbell seated shoulder press"),
        ExerciseMedia(exerciseID: "dips", datasetID: "0251",
                      mediaID: "0251-9WTm7dq", datasetName: "chest dip"),
        ExerciseMedia(exerciseID: "lateralRaise", datasetID: "0334",
                      mediaID: "0334-DsgkuIt", datasetName: "dumbbell lateral raise"),
        ExerciseMedia(exerciseID: "overheadTriceps", datasetID: "0194",
                      mediaID: "0194-2IxROQ1",
                      datasetName: "cable overhead triceps extension (rope attachment)"),
        ExerciseMedia(exerciseID: "bicepsCurl", datasetID: "0294",
                      mediaID: "0294-NbVPDMW", datasetName: "dumbbell biceps curl"),

        // Gym B. Der Datensatz nennt den Bulgarian Split Squat „single leg
        // split squat“, die Schritte beschreiben aber den erhöhten hinteren
        // Fuß — also die richtige Übung unter falschem Namen.
        ExerciseMedia(exerciseID: "splitSquat", datasetID: "0410",
                      mediaID: "0410-qx4fgX7", datasetName: "dumbbell single leg split squat"),
        ExerciseMedia(exerciseID: "romanianDeadlift", datasetID: "0085",
                      mediaID: "0085-wQ2c4XD", datasetName: "barbell romanian deadlift"),
        // Heißt dort „glute bridge on bench“, ist der Schrittfolge nach aber
        // der Hip Thrust: oberer Rücken an der Bank, Hantel über der Hüfte.
        ExerciseMedia(exerciseID: "hipThrust", datasetID: "3562",
                      mediaID: "3562-qg2PGl6",
                      datasetName: "barbell glute bridge two legs on bench (male)"),
        ExerciseMedia(exerciseID: "calfRaiseStanding", datasetID: "0409",
                      mediaID: "0409-1kB3Wmk", datasetName: "dumbbell single leg calf raise"),
        ExerciseMedia(exerciseID: "calfRaiseSeated", datasetID: "0594",
                      mediaID: "0594-bOOdeyc", datasetName: "lever seated calf raise"),
        // tibialisRaise: Der Datensatz kennt nur eine Dehnübung dafür.
        ExerciseMedia(exerciseID: "cableFly", datasetID: "0188",
                      mediaID: "0188-xLYSdtg", datasetName: "cable middle fly"),
        // „incline“ im Namen führt in die Irre, die Schritte beschreiben den
        // normalen Seitstütz.
        ExerciseMedia(exerciseID: "sidePlank", datasetID: "3544",
                      mediaID: "3544-5VXmnV5", datasetName: "bodyweight incline side plank"),

        ExerciseMedia(exerciseID: "pullUp", datasetID: "0652",
                      mediaID: "0652-lBDjFxJ", datasetName: "pull-up"),
        ExerciseMedia(exerciseID: "oneArmRow", datasetID: "0292",
                      mediaID: "0292-C0MA9bC", datasetName: "dumbbell one arm bent-over row"),
        ExerciseMedia(exerciseID: "cableRowClose", datasetID: "1320",
                      mediaID: "1320-UFGF6gk", datasetName: "cable rope crossover seated row"),
        // Einziger Fall, der nicht sitzt: Der Datensatz hat keinen Face Pull.
        // Dieselbe Muskulatur, aber der Zug geht zum Oberkörper statt zum
        // Gesicht — darum als Näherung markiert.
        ExerciseMedia(exerciseID: "facePull", datasetID: "0233",
                      mediaID: "0233-ZfyAGhK",
                      datasetName: "cable standing rear delt row (with rope)",
                      isApproximate: true),
        ExerciseMedia(exerciseID: "ezCurl", datasetID: "0447",
                      mediaID: "0447-6TG6x2w", datasetName: "ez barbell curl"),
        ExerciseMedia(exerciseID: "hammerCurl", datasetID: "0313",
                      mediaID: "0313-slDvUAU", datasetName: "dumbbell hammer curl"),
        ExerciseMedia(exerciseID: "tricepsPushdown", datasetID: "0200",
                      mediaID: "0200-dU605di", datasetName: "cable pushdown (with rope attachment)"),

        ExerciseMedia(exerciseID: "closeGripBench", datasetID: "0030",
                      mediaID: "0030-J6Dx1Mu", datasetName: "barbell close-grip bench press"),
        ExerciseMedia(exerciseID: "shoulderPressMachine", datasetID: "0603",
                      mediaID: "0603-67n3r98", datasetName: "lever shoulder press"),
        ExerciseMedia(exerciseID: "reverseFly", datasetID: "0383",
                      mediaID: "0383-EAs3xL9", datasetName: "dumbbell reverse fly"),
        ExerciseMedia(exerciseID: "inclineCurl", datasetID: "0315",
                      mediaID: "0315-F3xgbjF", datasetName: "dumbbell incline biceps curl")
    ]
}
