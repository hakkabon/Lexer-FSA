import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    ///  Parses any input dictionary of words and builds a Acyclic Graph form all the entries.
    ///  It renders the result as a DAWG tree, or a DOT parse-tree diagram.
    struct MkDAWG: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate DAWG tree of any input dictionary of words.")

        @Argument(help: "Input to be parsed constructing the DAWG.", transform: Source.init)
        var input: Source = Source("")
        
        @Flag(name: [.short, .long], help: "Generate graph representation") var graph: Bool = false
        
        mutating func run() throws {
            
            let lines: [String] = switch input {
            case .arg(let content):
                content.split(separator: ",").map(String.init)
                
            case .url(let url):
                try String(contentsOf: url, encoding: .utf8)
                    .split(whereSeparator: \.isNewline)
                    .map(String.init)
            }
            
            let automaton = DFSA.stringUnion(words: lines)
            if graph {
                let graphViz = automaton.graphviz
                
                // When things go wrong ... use this.
                print(DOTEncoder().encode(graphViz))
                
                let dotfile = DOTEncoder().encode(graphViz)
                try shellOut(to: ["echo '\(dotfile)' | dot -Tpdf > parse-tree.pdf", "open parse-tree.pdf"])
            }
        }
    }
}
