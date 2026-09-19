import SwiftUI

/// Radio connection status is independent of the age of the displayed glucose value.
struct Libre2ConnectionIndicator: View {
    @ObservedObject private var connection = Libre2WatchConnection.shared
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let relayColor: Color

    private var connectionColor: Color {
        if connection.connected { return .green }
        return connection.activity == nil ? .gray : .orange
    }

    private var shouldBlink: Bool {
        connection.direct && !connection.connected && connection.activity == .scanning
            && scenePhase == .active && !isLuminanceReduced && !reduceMotion
    }

    var body: some View {
        Image(systemName: connection.direct ? "antenna.radiowaves.left.and.right" : ConstantsAppleWatch.requestingDataIconSFSymbolName)
            .font(connection.direct
                  ? .system(size: ConstantsAppleWatch.isSmallScreen() ? 14 : 16)
                  : .system(size: ConstantsAppleWatch.requestingDataIconFontSize, weight: .heavy))
            .padding(.top, connection.direct ? 0 : 4)
            .foregroundStyle(connection.direct ? connectionColor : relayColor)
            .symbolEffect(.pulse.wholeSymbol, options: .repeating, isActive: shouldBlink)
            .accessibilityLabel(connection.direct ? connection.status : "Phone update")
    }
}
