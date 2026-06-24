import Foundation

/// Source input is either a command line argument or a file containing the input to be parsed.
enum Source {
    case arg(String)
    case url(URL)
    
    init(_ string: String) {
        if string.isEmpty {
            self = .arg(string)
        } else if FileManager.default.fileExists(atPath: string) {
            self = .url(URL(fileURLWithPath: string))
        } else {
            self = .arg(string)
        }
    }
}
