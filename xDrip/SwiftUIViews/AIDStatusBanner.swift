//
//  AIDStatusBanner.swift
//  xdrip
//
//  Created by Paul Plant on 24/8/26.
//  Copyright © 2026 Johan Degraeve. All rights reserved.
//

import SwiftUI

/// Keeps the provider identity and status together when they fit, then moves the status to a
/// trailing second row rather than allowing either title to wrap on narrower screens.
private struct AdaptiveAIDStatusBannerLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat
    let layoutDirection: LayoutDirection

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        guard subviews.count == 2 else { return .zero }

        let identitySize = subviews[0].sizeThatFits(.unspecified)
        let statusSize = subviews[1].sizeThatFits(.unspecified)
        let combinedWidth = identitySize.width + horizontalSpacing + statusSize.width
        let availableWidth = finiteWidth(proposal.width) ?? combinedWidth

        if combinedWidth <= availableWidth {
            return CGSize(width: availableWidth, height: max(identitySize.height, statusSize.height))
        }

        let constrainedProposal = ProposedViewSize(width: availableWidth, height: nil)
        let constrainedIdentitySize = subviews[0].sizeThatFits(constrainedProposal)
        let constrainedStatusSize = subviews[1].sizeThatFits(constrainedProposal)

        return CGSize(
            width: availableWidth,
            height: constrainedIdentitySize.height + verticalSpacing + constrainedStatusSize.height
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        guard subviews.count == 2 else { return }

        let identitySize = subviews[0].sizeThatFits(.unspecified)
        let statusSize = subviews[1].sizeThatFits(.unspecified)
        let combinedWidth = identitySize.width + horizontalSpacing + statusSize.width

        if combinedWidth <= bounds.width {
            placeHorizontalSubviews(in: bounds, subviews: subviews)
            return
        }

        placeVerticalSubviews(in: bounds, subviews: subviews)
    }

    private func placeHorizontalSubviews(in bounds: CGRect, subviews: Subviews) {
        if layoutDirection == .leftToRight {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY),
                anchor: .leading,
                proposal: .unspecified
            )
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.midY),
                anchor: .trailing,
                proposal: .unspecified
            )
        } else {
            subviews[0].place(
                at: CGPoint(x: bounds.maxX, y: bounds.midY),
                anchor: .trailing,
                proposal: .unspecified
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.midY),
                anchor: .leading,
                proposal: .unspecified
            )
        }
    }

    private func placeVerticalSubviews(in bounds: CGRect, subviews: Subviews) {
        let constrainedProposal = ProposedViewSize(width: bounds.width, height: nil)
        let identitySize = subviews[0].sizeThatFits(constrainedProposal)

        if layoutDirection == .leftToRight {
            subviews[0].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY),
                anchor: .topLeading,
                proposal: constrainedProposal
            )
            subviews[1].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY + identitySize.height + verticalSpacing),
                anchor: .topTrailing,
                proposal: constrainedProposal
            )
        } else {
            subviews[0].place(
                at: CGPoint(x: bounds.maxX, y: bounds.minY),
                anchor: .topTrailing,
                proposal: constrainedProposal
            )
            subviews[1].place(
                at: CGPoint(x: bounds.minX, y: bounds.minY + identitySize.height + verticalSpacing),
                anchor: .topLeading,
                proposal: constrainedProposal
            )
        }
    }

    private func finiteWidth(_ width: CGFloat?) -> CGFloat? {
        guard let width, width.isFinite else { return nil }
        return width
    }
}

struct AIDStatusBanner<IdentityIcon: View, StatusIcon: View>: View {
    @Environment(\.layoutDirection) private var layoutDirection

    let systemName: String
    let detail: String?
    let statusTitle: String
    let statusColor: Color
    let backgroundColor: Color

    private let identityIcon: IdentityIcon
    private let statusIcon: StatusIcon

    init(
        systemName: String,
        detail: String?,
        statusTitle: String,
        statusColor: Color,
        backgroundColor: Color,
        @ViewBuilder identityIcon: () -> IdentityIcon,
        @ViewBuilder statusIcon: () -> StatusIcon
    ) {
        self.systemName = systemName
        self.detail = detail
        self.statusTitle = statusTitle
        self.statusColor = statusColor
        self.backgroundColor = backgroundColor
        self.identityIcon = identityIcon()
        self.statusIcon = statusIcon()
    }

    var body: some View {
        AdaptiveAIDStatusBannerLayout(
            horizontalSpacing: 12,
            verticalSpacing: 8,
            layoutDirection: layoutDirection
        ) {
            HStack(spacing: 8) {
                identityIcon

                VStack(alignment: .leading, spacing: 1) {
                    Text(systemName)
                        .font(.title2.bold())
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .allowsTightening(true)

                    if let detail, !detail.isEmpty {
                        Text(detail)
                            .font(.callout.bold())
                            .foregroundStyle(ConstantsAppColors.secondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)
                            .allowsTightening(true)
                    }
                }
            }

            HStack(spacing: 8) {
                statusIcon
                    .font(.title3.bold())
                    .foregroundStyle(statusColor)

                Text(statusTitle)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .allowsTightening(true)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: ConstantsHomeView.standardCornerRadius))
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }
}
