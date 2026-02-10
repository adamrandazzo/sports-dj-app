import UIKit

/// Size options for event buttons in the DJ grid
public enum EventButtonSize: Int, CaseIterable {
    case small = 0
    case medium = 1
    case large = 2

    public var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    /// Minimum column width for the grid
    public var minColumnWidth: CGFloat {
        let isIPad = UIDevice.current.userInterfaceIdiom == .pad
        switch self {
        case .small: return isIPad ? 120 : 100
        case .medium: return isIPad ? 150 : 120
        case .large: return isIPad ? 200 : 150
        }
    }

    /// Button height
    public var buttonHeight: CGFloat {
        switch self {
        case .small: return 80
        case .medium: return 100
        case .large: return 130
        }
    }

    /// Icon font size
    public var iconSize: CGFloat {
        switch self {
        case .small: return 24
        case .medium: return 32
        case .large: return 44
        }
    }

    /// Pause button overlay size
    public var pauseButtonSize: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 44
        case .large: return 56
        }
    }

    /// Pause icon size
    public var pauseIconSize: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 18
        case .large: return 24
        }
    }
}
