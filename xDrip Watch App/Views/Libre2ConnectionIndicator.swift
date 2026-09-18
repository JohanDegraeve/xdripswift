import SwiftUI

/// Radio connection status is independent of the age of the displayed glucose value.
struct Libre2ConnectionIndicator: View {
    @ObservedObject private var connection = Libre2WatchConnection.shared
    let relayColor: Color

    var body: some View {
        Image(systemName: connection.direct ? "antenna.radiowaves.left.and.right" : ConstantsAppleWatch.requestingDataIconSFSymbolName)
            .font(connection.direct
                  ? .system(size: ConstantsAppleWatch.isSmallScreen() ? 14 : 16)
                  : .system(size: ConstantsAppleWatch.requestingDataIconFontSize, weight: .heavy))
            .padding(.top, connection.direct ? 0 : 4)
            .foregroundStyle(connection.direct ? (connection.connected ? Color.green : Color.orange) : relayColor)
            .accessibilityLabel(connection.direct ? connection.status : "Phone update")
    }
}
