import Foundation

struct SetupGuidanceService {
    func calibreInstallGuidance() -> String {
        """
        Install Calibre on macOS (Homebrew recommended):

        brew install --cask calibre

        Or download from https://calibre-ebook.com/download_osx

        PageForge looks for ebook-convert, ebook-meta, and ebook-polish in:
        - environment overrides
        - PATH
        - /Applications/calibre.app/Contents/MacOS
        - Homebrew bin paths
        """
    }

    func appUpdateGuidance() -> String {
        """
        Update PageForge from the distributed macOS app release channel for this project.
        App updates are separate from Calibre updates.
        """
    }

    func calibreUpdateGuidance() -> String {
        """
        Update Calibre separately, for example:

        brew upgrade --cask calibre

        PageForge does not auto-upgrade Calibre.
        """
    }

    func missingToolsMessage(_ status: DependencyStatus) -> String {
        if status.isReady {
            return "All Calibre tools are available."
        }
        let missing = status.missingTools.joined(separator: ", ")
        return "Missing Calibre tools: \(missing). \(calibreInstallGuidance())"
    }
}
