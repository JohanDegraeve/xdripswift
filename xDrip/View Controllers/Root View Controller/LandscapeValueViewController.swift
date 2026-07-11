//
//  LandscapeValueViewController.swift
//  xdrip
//
//  Created by Johan Degraeve on 24/12/2024.
//  Copyright © 2024 Johan Degraeve. All rights reserved.
//

import UIKit
import SwiftUI

/// Temporary UIKit container for the SwiftUI landscape value screen.
///
/// RootViewController still owns rotation and child-controller presentation during this migration
/// phase. The landscape value UI itself is now SwiftUI so it can consume the same
/// RootHomeGlucoseState as the portrait Home view without copying through UIKit labels.
final class LandscapeValueViewController: UIViewController {

    // MARK: - Properties

    private let stateModel = LandscapeValueStateModel()
    private var hostingController: UIHostingController<LandscapeValueView>?

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        installLandscapeValueView()
    }

    // MARK: - Public Methods

    /// updates the landscape value screen from the same presentation state used by the SwiftUI
    /// portrait home view
    public func updateLabels(glucoseState: RootHomeGlucoseState) {
        stateModel.glucoseState = glucoseState
    }

    // MARK: - Private Methods

    private func installLandscapeValueView() {
        guard hostingController == nil else { return }

        let landscapeValueView = LandscapeValueView(stateModel: stateModel)
        let hostingController = UIHostingController(rootView: landscapeValueView)
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false

        addChild(hostingController)
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
        self.hostingController = hostingController
    }
}

private final class LandscapeValueStateModel: ObservableObject {
    @Published var glucoseState = RootHomeGlucoseState()
}

private struct LandscapeValueView: View {

    // MARK: - Properties

    @ObservedObject var stateModel: LandscapeValueStateModel
    @State private var currentDate = Date()

    private let clockTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private var showsClock: Bool { UserDefaults.standard.showClockWhenScreenIsLocked }

    // MARK: - Body

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if showsClock {
                    clockView(availableHeight: geometry.size.height)
                }

                glucoseContent(availableSize: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
        }
        .colorScheme(.dark)
        .onReceive(clockTimer) { date in
            guard showsClock else { return }

            currentDate = date
        }
    }

    // MARK: - Views

    private func clockView(availableHeight: CGFloat) -> some View {
        Text(currentDate.formatted(date: .omitted, time: .shortened))
            .font(.system(size: max(34, availableHeight * 0.16), weight: .heavy))
            .foregroundStyle(ConstantsAppColors.clockText)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.2)
            .frame(maxWidth: .infinity)
    }

    private func glucoseContent(availableSize: CGSize) -> some View {
        VStack(spacing: -10) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                minutesView
                    .frame(maxWidth: .infinity, alignment: .leading)

                deltaView
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.system(size: topRowFontSize(availableHeight: availableSize.height)))
            .lineLimit(1)
            .minimumScaleFactor(0.25)

            Text(stateModel.glucoseState.valueText)
                .font(.system(size: valueFontSize(availableSize: availableSize), weight: .regular))
                .foregroundStyle(stateModel.glucoseState.valueColor)
                .strikethrough(stateModel.glucoseState.valueHasStrikethrough, color: stateModel.glucoseState.valueColor)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.08)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var minutesView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(stateModel.glucoseState.minutesText)
                .foregroundStyle(stateModel.glucoseState.minutesColor)
                .monospacedDigit()

            Text(stateModel.glucoseState.minutesAgoText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    private var deltaView: some View {
        HStack(alignment: .firstTextBaseline, spacing: 3) {
            Text(stateModel.glucoseState.deltaText)
                .foregroundStyle(stateModel.glucoseState.deltaColor)
                .monospacedDigit()

            Text(stateModel.glucoseState.deltaUnitText)
                .foregroundStyle(ConstantsAppColors.secondaryText)
        }
    }

    // MARK: - Sizing

    private func topRowFontSize(availableHeight: CGFloat) -> CGFloat {
        showsClock ? max(22, availableHeight * 0.10) : max(28, availableHeight * 0.15)
    }

    private func valueFontSize(availableSize: CGSize) -> CGFloat {
        min(availableSize.height * (showsClock ? 0.72 : 0.82), availableSize.width * 0.46)
    }
}
