import Foundation

struct BookMetadata: Equatable, Sendable {
    var path: URL
    var raw: String
    var fields: [String: String]

    var title: String {
        fields["Title"] ?? fields["title"] ?? ""
    }

    var author: String {
        fields["Author(s)"] ?? fields["Authors"] ?? fields["author"] ?? ""
    }
}
