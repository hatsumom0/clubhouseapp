import WidgetKit
import SwiftUI

@main
struct BAYCClubhouseWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widget
        BAYCClubhouseWidget()

        // Live Activities
        ValetLiveActivity()
        ArrivalLiveActivity()
        ClubhouseLiveActivity()
        EventLiveActivity()
        ReservationLiveActivity()
        LockerLiveActivity()
    }
}
