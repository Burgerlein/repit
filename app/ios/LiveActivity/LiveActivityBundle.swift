import SwiftUI
import WidgetKit

/// Die einzige Extension der App (#365). Gym (#78) und Kochen (#134) kommen
/// später **in dieses Bündel**, als weitere `ActivityAttributes` — jede
/// weitere Extension kostete eine weitere App-ID, und das freie Personal
/// Team erlaubt zehn je sieben Tage (#71).
@main
struct LiveActivityBundle: WidgetBundle {
    var body: some Widget {
        EssenLiveActivity()
    }
}
