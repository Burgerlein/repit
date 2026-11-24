import Foundation
import Testing
@testable import TrainingsCore

/// Das Gegenstück eines Maßes und sein Messhinweis — beides gehört zum Maß
/// und nicht zur Ansicht.
///
/// **Auslegung von „links ↔ rechts, locker ↔ angespannt" aus dem Entwurf:**
/// Das Gegenstück ist dieselbe Messart auf der **anderen Seite**, also locker
/// rechts ↔ locker links und angespannt rechts ↔ angespannt links. Locker und
/// angespannt desselben Arms sind **kein** Paar.
///
/// Begründung: Die Entscheidungstabelle in
/// `docs/superpowers/specs/2026-10-13-umfaenge-fortschritt-design.md` nennt
/// den Grund für die zweite Linie — „Die Seitendifferenz ist die Zahl, die man
/// sonst im Kopf ausrechnet". Locker gegen angespannt wäre keine
/// Seitendifferenz, sondern der Anspannungszuwachs, und der steht in keiner
/// der vier Zustände der Attrappe. Dazu kommt, dass Oberschenkel und Wade nur
/// die Seiten kennen: Nur die Seitenlesart ergibt für alle acht gepaarten Maße
/// dieselbe Aussage. Und weil jedes Maß genau ein Gegenstück hat, kann nur
/// eine der beiden Lesarten symmetrisch sein.
@Suite("Gegenstück und Messhinweis je Maß")
struct CircumferencePartnerTests {

    @Test("Locker rechts und locker links gehören zusammen")
    func relaxedArmsArePartners() {
        #expect(Circumference.upperArmRightRelaxed.partner == .upperArmLeftRelaxed)
        #expect(Circumference.upperArmLeftRelaxed.partner == .upperArmRightRelaxed)
    }

    @Test("Angespannt rechts und angespannt links gehören zusammen")
    func flexedArmsArePartners() {
        #expect(Circumference.upperArmRightFlexed.partner == .upperArmLeftFlexed)
        #expect(Circumference.upperArmLeftFlexed.partner == .upperArmRightFlexed)
    }

    @Test("Die beiden Oberschenkel gehören zusammen")
    func thighsArePartners() {
        #expect(Circumference.thighRight.partner == .thighLeft)
        #expect(Circumference.thighLeft.partner == .thighRight)
    }

    @Test("Die beiden Waden gehören zusammen")
    func calvesArePartners() {
        #expect(Circumference.calfRight.partner == .calfLeft)
        #expect(Circumference.calfLeft.partner == .calfRight)
    }

    @Test("Locker und angespannt desselben Arms sind kein Paar")
    func relaxedAndFlexedAreNotPartners() {
        // Siehe die Auslegung oben: Das Gegenstück ist die andere Seite, nicht
        // der andere Anspannungszustand.
        #expect(Circumference.upperArmRightRelaxed.partner != .upperArmRightFlexed)
        #expect(Circumference.upperArmRightFlexed.partner != .upperArmRightRelaxed)
        #expect(Circumference.upperArmLeftRelaxed.partner != .upperArmLeftFlexed)
        #expect(Circumference.upperArmLeftFlexed.partner != .upperArmLeftRelaxed)
    }

    @Test("Brust, Schultern, Taille, Hals und Hüfte haben kein Gegenstück")
    func singleMeasuresHaveNoPartner() {
        // Diese fünf gibt es nur einmal am Körper. Ihr Detailschirm zeigt eine
        // Linie.
        for measure in [Circumference.chest, .shoulders, .waist, .neck, .hips] {
            #expect(measure.partner == nil, "\(measure.german) hat ein Gegenstück")
        }
    }

    @Test("Acht Maße haben ein Gegenstück, fünf nicht")
    func eightOfThirteenArePaired() {
        let paired = Circumference.allCases.filter { $0.partner != nil }
        #expect(paired.count == 8)
        #expect(Circumference.allCases.count - paired.count == 5)
    }

    @Test("Kein Maß ist sein eigenes Gegenstück")
    func nothingPairsWithItself() {
        for measure in Circumference.allCases {
            #expect(measure.partner != measure, "\(measure.german) zeigt auf sich selbst")
        }
    }

    @Test("Die Beziehung ist symmetrisch")
    func theRelationIsSymmetric() {
        // Sonst zeichnete der Detailschirm des einen Maßes eine zweite Linie,
        // der des anderen aber nicht — derselbe Vergleich hinge davon ab, von
        // welcher Seite man ihn aufruft.
        for measure in Circumference.allCases {
            guard let partner = measure.partner else { continue }
            #expect(partner.partner == measure,
                    "\(measure.german) und \(partner.german) zeigen nicht aufeinander")
        }
    }

    @Test("Ein Gegenstück steht in derselben Gruppe")
    func partnersShareTheirGroup() {
        // Arme mit Armen, Beine mit Beinen: Ein Paar über zwei Karten hinweg
        // wäre im Formular wie im Diagramm ein Fehler.
        for measure in Circumference.allCases {
            guard let partner = measure.partner else { continue }
            #expect(partner.group == measure.group)
        }
    }

    @Test("Jedes Maß hat einen Messhinweis")
    func everyMeasureHasAHowTo() {
        for measure in Circumference.allCases {
            let howTo = measure.howTo.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(!howTo.isEmpty, "\(measure.german) hat keinen Messhinweis")
        }
    }

    @Test("Die dreizehn Messhinweise sind voneinander verschieden")
    func everyHowToIsItsOwnSentence() {
        // „Dickste Stelle, Arm entspannt" und „auf Nabelhöhe, nicht einziehen"
        // stehen im Detailschirm genau des Maßes, zu dem sie gehören. Ein
        // Sammelsatz, dreizehnmal wiederholt, hilft beim Messen nicht.
        let sentences = Circumference.allCases.map(\.howTo)
        #expect(Set(sentences).count == 13)
    }
}
