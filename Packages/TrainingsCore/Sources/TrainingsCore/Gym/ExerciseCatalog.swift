import Foundation

/// Die Workouts aus SPEC 4.4. Bewusst Konstanten und keine Datenbankzeilen:
/// Sie ändern sich nur mit dem Code, und als Zeilen wären sie bei jeder
/// Anpassung ein Migrationsproblem.
public enum ExerciseCatalog {

    public static func exercises(for workout: Workout) -> [Exercise] {
        order(for: workout).compactMap { all[$0] }
    }

    /// Entfallen in den „leicht"-Varianten von Gym B.
    public static let heavyLegIDs: Set<String> = ["splitSquat", "romanianDeadlift"]

    private static func order(for workout: Workout) -> [String] {
        switch workout {
        case .a: ["benchPress", "inclineDumbbellPress", "shoulderPressDumbbell",
                  "dips", "lateralRaise", "overheadTriceps", "bicepsCurl"]
        case .b: ["splitSquat", "romanianDeadlift", "legCurl", "hipAbduction",
                  "calfRaiseStanding", "tibialisRaise", "cableFly", "sidePlank"]
        case .c: ["pullUp", "oneArmRow", "cableRowClose", "facePull",
                  "ezCurl", "hammerCurl", "tricepsPushdown"]
        case .d: ["closeGripBench", "shoulderPressMachine", "lateralRaise",
                  "reverseFly", "overheadTriceps", "ezCurl", "inclineCurl"]
        case .push: ["benchPress", "inclineDumbbellPress", "shoulderPressMachine",
                     "cableFly", "lateralRaise", "tricepsPushdown", "overheadTriceps"]
        case .pull: ["pullUp", "barbellRow", "cableRowClose", "straightArmPulldown",
                     "facePull", "backExtension", "hammerCurl"]
        case .legs: ["legPress", "romanianDeadlift", "splitSquat", "legCurl",
                     "hipAbduction", "calfRaiseStanding", "legExtension"]
        }
    }

    public static let all: [String: Exercise] = Dictionary(
        uniqueKeysWithValues: list.map { ($0.id, $0) })

    private static let list: [Exercise] = [
        Exercise(id: "benchPress", name: "Bankdrücken Langhantel",
                 sets: 4, repLow: 6, repHigh: 10, increment: 2.5,
                 cue: "Schulterblätter zusammen, Füße fest am Boden, Stange zur unteren Brust.",
                 howTo: ["Auf der Bank liegen, Augen unter der Stange, Schulterblätter zusammenziehen.",
                         "Stange kontrolliert zur unteren Brust senken, Ellenbogen etwa 45 Grad.",
                         "Kraftvoll nach oben drücken, ohne das Gesäß zu heben."],
                 commonMistake: "Ellenbogen zu weit außen, das belastet die Schulter.",
                 youTubeQuery: "Bankdrücken Technik Anleitung",
                 muscles: [.chest: 1, .frontDelt: 0.5, .triceps: 0.5]),

        Exercise(id: "inclineDumbbellPress", name: "Schrägbankdrücken Kurzhantel",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2,
                 cue: "Bank auf 30 bis 45 Grad, Hanteln über der oberen Brust zusammenführen.",
                 howTo: ["Bank auf 30 bis 45 Grad stellen, Hanteln auf den Oberschenkeln ablegen.",
                         "Mit Schwung in die Startposition über der Brust bringen.",
                         "Kontrolliert senken, bis die Oberarme etwa waagerecht sind, dann drücken."],
                 commonMistake: "Bank zu steil, dann macht die Schulter die Arbeit statt der Brust.",
                 youTubeQuery: "Schrägbankdrücken Kurzhantel Technik",
                 muscles: [.chest: 1, .frontDelt: 0.5, .triceps: 0.5]),

        Exercise(id: "shoulderPressDumbbell", name: "Schulterdrücken Kurzhantel sitzend",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2,
                 cue: "Rücken an der Lehne, Hanteln auf Ohrhöhe starten, nicht hinter dem Kopf.",
                 howTo: ["Aufrecht sitzen, Rücken an der Lehne, Bauch fest.",
                         "Hanteln auf Ohrhöhe, Handflächen nach vorn.",
                         "Nach oben drücken, ohne die Ellenbogen ganz durchzustrecken."],
                 commonMistake: "Ins Hohlkreuz gehen, um mehr Gewicht zu bewegen.",
                 youTubeQuery: "Schulterdrücken Kurzhantel sitzend Technik",
                 muscles: [.frontDelt: 1, .sideDelt: 0.5, .triceps: 0.5]),

        Exercise(id: "dips", name: "Dips",
                 sets: 3, repLow: 6, repHigh: 12, increment: 2.5, allowsAssist: true,
                 cue: "Schultern tief weg von den Ohren, Oberkörper leicht nach vorn.",
                 howTo: ["An den Holmen aufstützen, Schultern tief weg von den Ohren.",
                         "Oberkörper leicht nach vorn, bis der Oberarm waagerecht ist absenken.",
                         "Nach oben drücken, ohne die Ellenbogen ganz durchzustrecken."],
                 commonMistake: "Zu tief gehen, das reizt die Schultervorderseite.",
                 youTubeQuery: "Dips Technik Anleitung",
                 muscles: [.triceps: 1, .chest: 0.5, .frontDelt: 0.5]),

        Exercise(id: "lateralRaise", name: "Seitheben",
                 sets: 4, repLow: 12, repHigh: 20, increment: 1,
                 cue: "Leicht gebeugte Ellenbogen, bis Schulterhöhe, kein Schwung.",
                 howTo: ["Aufrecht stehen, Hanteln seitlich am Körper, Ellenbogen leicht gebeugt.",
                         "Arme seitlich bis Schulterhöhe heben, kleiner Finger leicht höher.",
                         "Langsam senken, Spannung halten."],
                 commonMistake: "Mit Schwung aus den Knien arbeiten statt aus der Schulter.",
                 youTubeQuery: "Seitheben Technik Anleitung",
                 muscles: [.sideDelt: 1]),

        Exercise(id: "overheadTriceps", name: "Trizeps über Kopf am Kabel",
                 sets: 3, repLow: 10, repHigh: 15, increment: 2.5,
                 cue: "Oberarme ruhig neben den Ohren, nur der Unterarm bewegt sich.",
                 howTo: ["Mit dem Rücken zum Kabelzug, Seil über den Kopf greifen.",
                         "Oberarme neben den Ohren fixieren, Ellenbogen gebeugt starten.",
                         "Arme nach vorn oben strecken, die Oberarme bleiben ruhig."],
                 commonMistake: "Die Ellenbogen wandern nach außen und entlasten den Trizeps.",
                 youTubeQuery: "Trizeps über Kopf Kabel Technik",
                 muscles: [.triceps: 1]),

        Exercise(id: "bicepsCurl", name: "Bizeps-Curls Kurzhantel",
                 sets: 3, repLow: 8, repHigh: 12, increment: 1,
                 cue: "Ellenbogen am Körper, Oberkörper still.",
                 howTo: ["Aufrecht stehen, Hanteln hängen lassen, Handflächen nach vorn.",
                         "Nur den Unterarm beugen, die Ellenbogen bleiben am Körper.",
                         "Oben kurz halten, dann langsam senken."],
                 commonMistake: "Mit dem Oberkörper schwingen, sobald es schwer wird.",
                 youTubeQuery: "Bizeps Curls Kurzhantel Technik",
                 muscles: [.biceps: 1, .forearms: 0.5]),

        Exercise(id: "splitSquat", name: "Bulgarian Split Squat",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2,
                 cue: "Hinterer Fuß erhöht, vorderes Knie über dem Mittelfuß.",
                 howTo: ["Hinteren Fuß auf eine Bank legen, vorderen Fuß weit genug nach vorn.",
                         "Senkrecht absenken, bis der vordere Oberschenkel waagerecht ist.",
                         "Über die Ferse des vorderen Fußes nach oben drücken."],
                 commonMistake: "Der vordere Fuß steht zu nah, dann knickt das Knie nach vorn.",
                 youTubeQuery: "Bulgarian Split Squat Technik",
                 muscles: [.quads: 1, .glutes: 1]),

        Exercise(id: "romanianDeadlift", name: "Rumänisches Kreuzheben",
                 sets: 3, repLow: 8, repHigh: 10, increment: 2.5,
                 cue: "Rücken gerade, Hüfte nach hinten, Stange nah am Bein.",
                 howTo: ["Aufrecht stehen, Stange vor den Oberschenkeln, Knie leicht gebeugt.",
                         "Hüfte nach hinten schieben, Stange dicht am Bein nach unten führen.",
                         "Bei Zug in den Oberschenkelrückseiten umkehren und die Hüfte strecken."],
                 commonMistake: "Runder Rücken, sobald die Beweglichkeit nicht mehr reicht.",
                 youTubeQuery: "Rumänisches Kreuzheben Technik",
                 muscles: [.hamstrings: 1, .glutes: 0.5, .lowerBack: 0.5]),

        // Hip Thrust und Wadenheben sitzend stehen in keinem Workout mehr.
        // Sie bleiben trotzdem im Katalog: Frühere Sitzungen führen ihre IDs,
        // und `GymSessionBuilder` übergeht jede Übung, die der Katalog nicht
        // kennt — der Verlauf verlöre sonst stillschweigend Sätze.
        Exercise(id: "hipThrust", name: "Hip Thrust",
                 sets: 3, repLow: 8, repHigh: 12, increment: 5,
                 cue: "Oben Gesäß fest anspannen, Rippen unten lassen.",
                 howTo: ["Mit den Schulterblättern an eine Bank lehnen, Stange über der Hüfte.",
                         "Füße hüftbreit, Schienbeine am Umkehrpunkt senkrecht.",
                         "Hüfte strecken, bis Oberkörper und Oberschenkel eine Linie bilden."],
                 commonMistake: "Ins Hohlkreuz drücken statt das Gesäß anzuspannen.",
                 youTubeQuery: "Hip Thrust Technik Anleitung",
                 muscles: [.glutes: 1, .hamstrings: 0.5]),

        // Sechs Sätze, seit das sitzende Wadenheben aus Gym B gefallen ist:
        // Darunter bliebe die Wade unter ihrem Wochenziel von 6 Sätzen.
        Exercise(id: "calfRaiseStanding", name: "Wadenheben stehend einbeinig",
                 sets: 6, repLow: 12, repHigh: 15, increment: 2,
                 cue: "Volle Dehnung unten, oben kurz halten.",
                 howTo: ["Auf einer Stufe stehen, nur der Ballen hat Kontakt.",
                         "Ferse langsam so weit wie möglich absenken.",
                         "Auf den Ballen hochdrücken und oben eine Sekunde halten."],
                 commonMistake: "Zu schnell wippen, dann arbeitet die Sehne statt des Muskels.",
                 youTubeQuery: "Wadenheben stehend einbeinig Technik",
                 muscles: [.calves: 1]),

        Exercise(id: "calfRaiseSeated", name: "Wadenheben sitzend",
                 sets: 3, repLow: 15, repHigh: 20, increment: 5,
                 cue: "Trifft den tiefen Wadenmuskel, deshalb im Sitzen mit gebeugtem Knie.",
                 howTo: ["Polster auf die Oberschenkel nah am Knie legen.",
                         "Fersen langsam absenken, bis es zieht.",
                         "Auf die Ballen drücken und oben kurz halten."],
                 commonMistake: "Nur den halben Weg nutzen.",
                 youTubeQuery: "Wadenheben sitzend Technik",
                 muscles: [.calves: 1]),

        // Die ID bleibt `tibialisRaise`, obwohl die Übung anders heißt: Sie
        // steht so in schon gespeicherten Sitzungen, und ein Umbenennen der
        // ID ließe den Verlauf ins Leere zeigen. Der deutsche Name und der
        // Suchbegriff sind das, was man findet — „Tibialis Raises" findet
        // man nicht.
        Exercise(id: "tibialisRaise", name: "Zehenheben an der Wand",
                 sets: 3, repLow: 15, repHigh: 25, increment: 1,
                 cue: "Gegenspieler der Wade — hilft gegen Schienbeinschmerzen.",
                 howTo: ["Mit dem Rücken an der Wand stehen, Fersen etwa 30 cm davor.",
                         "Fußspitzen so weit wie möglich anheben, Fersen bleiben am Boden.",
                         "Langsam absenken, ohne die Zehen aufzusetzen."],
                 commonMistake: "Zu schnell und ohne volle Bewegung.",
                 youTubeQuery: "Zehenheben Schienbein Übung Läufer",
                 muscles: [.tibialis: 1]),

        Exercise(id: "cableFly", name: "Kabel-Flys",
                 sets: 3, repLow: 12, repHigh: 15, increment: 2.5,
                 cue: "Leicht gebeugte Arme, die Hände vor der Brust zusammenführen.",
                 howTo: ["Mittig zwischen den Kabelzügen stehen, einen Fuß vorsetzen.",
                         "Arme leicht gebeugt fixieren, Brust raus.",
                         "Hände vor dem Körper zusammenführen und kurz halten."],
                 commonMistake: "Die Arme beugen und daraus ein Drücken machen.",
                 youTubeQuery: "Kabel Flys Brust Technik",
                 muscles: [.chest: 1]),

        Exercise(id: "sidePlank", name: "Seitstütz",
                 sets: 3, repLow: 30, repHigh: 45, increment: 5, isTimed: true,
                 cue: "Körper in einer Linie, Hüfte oben halten.",
                 howTo: ["Auf die Seite legen, Unterarm unter der Schulter.",
                         "Hüfte anheben, bis Schulter, Hüfte und Fuß eine Linie bilden.",
                         "Ruhig atmen und die Zeit halten, dann Seite wechseln."],
                 commonMistake: "Die Hüfte sinkt ab, sobald es anstrengend wird.",
                 youTubeQuery: "Seitstütz Side Plank Technik",
                 muscles: [.core: 1]),

        Exercise(id: "pullUp", name: "Klimmzüge oder Latziehen",
                 sets: 4, repLow: 6, repHigh: 10, increment: 2.5, allowsAssist: true,
                 cue: "Brust zur Stange, Schultern zuerst nach unten ziehen.",
                 howTo: ["Etwas weiter als schulterbreit greifen, Schultern nach unten ziehen.",
                         "Brust Richtung Stange ziehen, Ellenbogen nach unten denken.",
                         "Kontrolliert ablassen, bis die Arme fast gestreckt sind."],
                 commonMistake: "Mit den Beinen schwingen, um die letzten Wiederholungen zu schaffen.",
                 youTubeQuery: "Klimmzüge Technik Anleitung",
                 muscles: [.lats: 1, .biceps: 0.5, .rearDelt: 0.5]),

        Exercise(id: "oneArmRow", name: "Rudern einarmig Kurzhantel",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2,
                 cue: "Rücken gerade, Hantel zur Hüfte ziehen, nicht zur Schulter.",
                 howTo: ["Ein Knie und eine Hand auf der Bank, Rücken waagerecht.",
                         "Hantel hängen lassen, Schulterblatt zuerst nach hinten ziehen.",
                         "Hantel Richtung Hüfte ziehen, oben kurz halten."],
                 commonMistake: "Den Oberkörper mitdrehen, um mehr Gewicht zu bewegen.",
                 youTubeQuery: "Rudern einarmig Kurzhantel Technik",
                 muscles: [.lats: 1, .upperBack: 0.5, .biceps: 0.5, .rearDelt: 0.5]),

        Exercise(id: "cableRowClose", name: "Kabelrudern eng",
                 sets: 3, repLow: 10, repHigh: 12, increment: 2.5,
                 cue: "Aufrecht sitzen, Griff zum Bauchnabel.",
                 howTo: ["Aufrecht sitzen, Knie leicht gebeugt, Griff mit gestreckten Armen halten.",
                         "Schulterblätter zusammenziehen, dann die Arme beugen.",
                         "Griff zum Bauchnabel ziehen, kurz halten, langsam zurück."],
                 commonMistake: "Mit dem Oberkörper nach hinten lehnen.",
                 youTubeQuery: "Kabelrudern eng Technik",
                 muscles: [.upperBack: 1, .lats: 0.5, .biceps: 0.5]),

        Exercise(id: "facePull", name: "Face Pulls",
                 sets: 3, repLow: 12, repHigh: 20, increment: 2.5,
                 cue: "Seil zum Gesicht, Hände auseinander, Ellenbogen hoch.",
                 howTo: ["Seil auf Gesichtshöhe einstellen, mit beiden Händen greifen.",
                         "Zum Gesicht ziehen und dabei die Hände auseinanderführen.",
                         "Hinten kurz halten, Schulterblätter zusammen."],
                 commonMistake: "Zu schwer wählen, dann wird daraus Rudern.",
                 youTubeQuery: "Face Pulls Technik Anleitung",
                 muscles: [.rearDelt: 1, .upperBack: 0.5]),

        Exercise(id: "ezCurl", name: "SZ-Curls",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2.5,
                 cue: "Ellenbogen am Körper, Handgelenke neutral.",
                 howTo: ["SZ-Stange an den schrägen Griffen fassen, aufrecht stehen.",
                         "Nur die Unterarme beugen, Oberkörper still.",
                         "Oben kurz halten, langsam senken."],
                 commonMistake: "Die Ellenbogen nach vorn ziehen und so die Spannung verlieren.",
                 youTubeQuery: "SZ Curls Technik Anleitung",
                 muscles: [.biceps: 1, .forearms: 0.5]),

        Exercise(id: "hammerCurl", name: "Hammer Curls",
                 sets: 3, repLow: 10, repHigh: 12, increment: 1,
                 cue: "Daumen zeigen nach oben, trifft zusätzlich den Unterarm.",
                 howTo: ["Hanteln seitlich halten, Daumen nach oben.",
                         "Beugen, ohne die Hand zu drehen.",
                         "Oben kurz halten, langsam senken."],
                 commonMistake: "Mit Schwung arbeiten.",
                 youTubeQuery: "Hammer Curls Technik Anleitung",
                 muscles: [.biceps: 1, .forearms: 1]),

        Exercise(id: "tricepsPushdown", name: "Trizepsdrücken am Kabel",
                 sets: 3, repLow: 10, repHigh: 15, increment: 2.5,
                 cue: "Ellenbogen am Körper, nur der Unterarm bewegt sich.",
                 howTo: ["Vor dem Kabelzug stehen, Griff auf Brusthöhe fassen.",
                         "Ellenbogen am Körper fixieren.",
                         "Nach unten strecken, unten kurz halten."],
                 commonMistake: "Den Oberkörper nach vorn lehnen und mit dem Gewicht drücken.",
                 youTubeQuery: "Trizepsdrücken Kabel Technik",
                 muscles: [.triceps: 1]),

        Exercise(id: "closeGripBench", name: "Enges Bankdrücken",
                 sets: 3, repLow: 6, repHigh: 10, increment: 2.5,
                 cue: "Schulterbreiter Griff, Ellenbogen nah am Körper.",
                 howTo: ["Etwa schulterbreit greifen, nicht enger.",
                         "Stange zur unteren Brust senken, Ellenbogen nah am Körper.",
                         "Nach oben drücken, der Trizeps führt."],
                 commonMistake: "Zu eng greifen, das belastet die Handgelenke.",
                 youTubeQuery: "Enges Bankdrücken Technik",
                 muscles: [.triceps: 1, .chest: 0.5]),

        Exercise(id: "shoulderPressMachine", name: "Schulterdrücken Maschine",
                 sets: 3, repLow: 8, repHigh: 12, increment: 2.5,
                 cue: "Sitzhöhe so, dass die Griffe auf Schulterhöhe sind.",
                 howTo: ["Sitzhöhe einstellen, Griffe auf Schulterhöhe.",
                         "Rücken an die Lehne, Bauch fest.",
                         "Nach oben drücken, ohne die Ellenbogen zu überstrecken."],
                 commonMistake: "Sitz zu tief, dann drückt man aus einem ungünstigen Winkel.",
                 youTubeQuery: "Schulterdrücken Maschine Technik",
                 muscles: [.frontDelt: 1, .sideDelt: 0.5, .triceps: 0.5]),

        Exercise(id: "reverseFly", name: "Reverse Flys",
                 sets: 3, repLow: 12, repHigh: 15, increment: 1,
                 cue: "Vorgebeugt, Arme leicht gebeugt seitlich öffnen.",
                 howTo: ["Oberkörper vorbeugen, Rücken gerade, Hanteln hängen lassen.",
                         "Arme leicht gebeugt seitlich öffnen bis Schulterhöhe.",
                         "Oben kurz halten, langsam senken."],
                 commonMistake: "Zu schwer wählen, dann übernimmt der obere Rücken.",
                 youTubeQuery: "Reverse Flys Technik Anleitung",
                 muscles: [.rearDelt: 1, .upperBack: 0.5]),

        Exercise(id: "inclineCurl", name: "Schrägbank-Curls",
                 sets: 3, repLow: 10, repHigh: 12, increment: 1,
                 cue: "Arme hängen hinter dem Körper, das dehnt den Bizeps stärker.",
                 howTo: ["Auf eine 45-Grad-Schrägbank legen, Arme hängen lassen.",
                         "Nur die Unterarme beugen, die Oberarme bleiben hinten.",
                         "Langsam in die volle Dehnung zurück."],
                 commonMistake: "Die Schultern nach vorn ziehen und so die Dehnung aufgeben.",
                 youTubeQuery: "Schrägbank Curls Technik",
                 muscles: [.biceps: 1]),

        // Ab hier die Übungen der frei wählbaren Workouts Push, Pull und
        // Legs. Beinbeuger und Abduktoren stehen zusätzlich in Gym B.

        Exercise(id: "barbellRow", name: "Langhantelrudern vorgebeugt",
                 sets: 4, repLow: 8, repHigh: 12, increment: 2.5,
                 cue: "Oberkörper etwa 45 Grad vorgebeugt, Stange zum Bauchnabel.",
                 howTo: ["Schulterbreit greifen, Knie leicht beugen, Hüfte nach hinten schieben.",
                         "Oberkörper auf etwa 45 Grad bringen, Rücken gerade, Stange hängen lassen.",
                         "Stange zum Bauchnabel ziehen, oben kurz halten, langsam ablassen."],
                 commonMistake: "Den Oberkörper bei jeder Wiederholung aufrichten und die Last so abgeben.",
                 youTubeQuery: "Langhantelrudern vorgebeugt Technik",
                 muscles: [.upperBack: 1, .lats: 0.5, .biceps: 0.5, .lowerBack: 0.5]),

        Exercise(id: "straightArmPulldown", name: "Überzüge am Kabel mit gestreckten Armen",
                 sets: 3, repLow: 12, repHigh: 15, increment: 2.5,
                 cue: "Arme bleiben gestreckt — die Bewegung kommt allein aus der Schulter.",
                 howTo: ["Stange am hohen Kabelzug greifen, einen Schritt zurücktreten.",
                         "Leicht vorbeugen, Arme gestreckt lassen, Ellenbogen nur minimal gebeugt.",
                         "Stange im Bogen zu den Oberschenkeln ziehen, unten kurz halten."],
                 commonMistake: "Die Ellenbogen beugen, dann wird daraus Trizepsdrücken.",
                 youTubeQuery: "Überzüge am Kabel gestreckte Arme Latissimus",
                 muscles: [.lats: 1]),

        Exercise(id: "backExtension", name: "Rückenstrecken",
                 sets: 3, repLow: 12, repHigh: 15, increment: 2.5,
                 cue: "Nur bis zur geraden Linie aufrichten, nicht ins Hohlkreuz.",
                 howTo: ["Im Gerät einstellen, bis die Polster knapp unter den Hüftknochen liegen.",
                         "Mit geradem Rücken absenken, bis es in den Oberschenkelrückseiten zieht.",
                         "Aufrichten, bis Rumpf und Beine eine Linie bilden, dort kurz halten."],
                 commonMistake: "Oben über die Linie hinaus ins Hohlkreuz schwingen.",
                 youTubeQuery: "Rückenstrecken Hyperextension Technik",
                 muscles: [.lowerBack: 1, .glutes: 0.5, .hamstrings: 0.5]),

        Exercise(id: "legPress", name: "Beinpresse",
                 sets: 4, repLow: 8, repHigh: 12, increment: 5,
                 cue: "Füße schulterbreit mittig auf der Platte, Rücken bleibt an der Lehne.",
                 howTo: ["Sitz so einstellen, dass die Knie am tiefsten Punkt etwa 90 Grad haben.",
                         "Platte kontrolliert heranlassen, das Becken bleibt an der Lehne.",
                         "Über die Fersen wegdrücken, ohne die Knie ganz durchzustrecken."],
                 commonMistake: "So tief absenken, dass das Becken abhebt und der untere Rücken rund wird.",
                 youTubeQuery: "Beinpresse Technik Anleitung",
                 muscles: [.quads: 1, .glutes: 0.5]),

        Exercise(id: "legCurl", name: "Beinbeuger-Maschine liegend",
                 sets: 3, repLow: 10, repHigh: 15, increment: 2.5,
                 cue: "Polster knapp über der Ferse, Hüfte bleibt auf der Bank.",
                 howTo: ["Bäuchlings einlegen, Drehpunkt der Maschine auf Kniehöhe.",
                         "Polster knapp über der Achillessehne, Hüfte fest auf die Bank drücken.",
                         "Fersen zum Gesäß ziehen, oben kurz halten, langsam ablassen."],
                 commonMistake: "Die Hüfte anheben, um die letzten Wiederholungen zu schaffen.",
                 youTubeQuery: "Beinbeuger Maschine liegend Technik",
                 muscles: [.hamstrings: 1]),

        Exercise(id: "hipAbduction", name: "Abduktoren-Maschine",
                 sets: 3, repLow: 12, repHigh: 20, increment: 5,
                 cue: "Trifft den seitlichen Gesäßmuskel — der hält beim Laufen das Becken stabil.",
                 howTo: ["Aufrecht sitzen, Polster außen an den Knien, Rücken an der Lehne.",
                         "Knie gegen die Polster nach außen drücken, bis es seitlich zieht.",
                         "Außen eine Sekunde halten, dann langsam schließen."],
                 commonMistake: "Mit dem Oberkörper nach hinten lehnen und das Gewicht wegschwingen.",
                 youTubeQuery: "Abduktoren Maschine Technik Gesäß",
                 muscles: [.glutes: 1]),

        Exercise(id: "legExtension", name: "Beinstrecker-Maschine",
                 sets: 3, repLow: 12, repHigh: 15, increment: 2.5,
                 cue: "Oben kurz halten, der vordere Oberschenkel arbeitet im Endbereich am stärksten.",
                 howTo: ["Sitz so einstellen, dass der Drehpunkt auf Höhe des Knies liegt.",
                         "Polster knapp über dem Spann, Hände an den Griffen.",
                         "Beine strecken, oben eine Sekunde halten, langsam ablassen."],
                 commonMistake: "Das Gewicht hochschleudern und oben sofort wieder fallen lassen.",
                 youTubeQuery: "Beinstrecker Maschine Technik",
                 muscles: [.quads: 1])
    ]
}
