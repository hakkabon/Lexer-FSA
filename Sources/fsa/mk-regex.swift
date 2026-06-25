import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    struct MkRegex: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate Regex from any input string. Inspect internal representation or analyse string matching capabilities.")

        @Argument(help: "Regular Expression")
        var expression: String
        
        @Argument(help: "Sample string to match")
        var match: String = ""
        
        /// Regex construction method to be applied to input supplied by user.
        enum Construction: String, ExpressibleByArgument, CaseIterable, CustomStringConvertible {
            case thom, bese, anti
            public var description: String {
                switch self {
                case .anti: return "Antimirov"
                case .bese: return "Berry-Sethi"
                case .thom: return "Thompson"
                }
            }
        }
        
        @Option(name: [.short, .long], help: "construction method") var construction: Construction = .thom
        @Flag(name: [.short, .long], help: "epsilon free internal representation") var free: Bool = false
        @Flag(name: [.short, .long], help: "determinize the internal representation") var det: Bool = false
//        @Flag(name: [.short, .long], help: "minimizes the internal representation") var min: Bool = false
        @Flag(name: [.short, .long], help: "regex as a linearized (flattened) AST") var ast: Bool = false
        @Flag(name: [.short, .long], help: "internal representation") var `internal`: Bool = false
        @Flag(name: [.short, .long], help: "graph of Finite State Automaton") var graph: Bool = false
        
        mutating func run() throws {
            do {
                guard expression.count > 0 else {
                    print("please submit a regular expression")
                    return
                }
                var regex: Regex = try {
                    switch construction {
                    case .anti: return try Regex(expression, method: .derivative)
                    case .bese: return try Regex(expression, method: .berrySethi)
                    case .thom: return try Regex(expression, method: .thompson)
                    }
                }()
                
                if free { regex.epsilonFree = true }
                if det { regex.isDeterministic = true }
//                if det && min { regex.brzozowskiMinimize() }
                if match.count > 0 {
                    let result = regex.recognize(string: match)
                    print("regular expression '\(regex)' is accepting '\(match)': \(result)")
                }
                
                if ast { print(regex.flattenExpressionTree) }
                if `internal` { regex.printGraph() }
                
                if graph {
                    let graphViz = regex.graphviz
                    
                    // When things go wrong ... use this.
                    print(DOTEncoder().encode(graphViz))
                    
                    let dotfile = DOTEncoder().encode(graphViz)
                    try shellOut(to: ["echo '\(dotfile)' | dot -Tpdf > parse-tree.pdf", "open parse-tree.pdf"])
                }
            } catch let error {
                print("regex failed execution for reason: \(error.localizedDescription)")
            }
        }
    }
}
