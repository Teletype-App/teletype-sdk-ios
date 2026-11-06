import UIKit

public enum ChatBackgroundImages {
    public static func image(_ id: ChatBackground) -> UIImage? {
        TeletypeAssets.background(id)
    }

    public static func thumb(_ id: ChatBackground) -> UIImage? {
        TeletypeAssets.backgroundThumb(id)
    }
}
