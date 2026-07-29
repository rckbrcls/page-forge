import Foundation

extension Character {
    var isControl: Bool {
        unicodeScalars.allSatisfy { CharacterSet.controlCharacters.contains($0) }
    }
}
