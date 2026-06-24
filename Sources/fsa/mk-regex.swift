import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    struct MkRegex: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate Regex from any input string.")

        @Argument(help: "Regular Expression")
        var expression: String
        
        @Argument(help: "Sample string to match")
//        @Option(name: [.short, .long], help: "Sample string to match")
        var match: String = ""
        
//        enum Method: EnumerableFlag {
//            case thompson
//            case berrySethi
//            static func name(for value: Method) -> NameSpecification {
//                switch value {
//                case .thompson: return [.short, .customLong("tho"), .long]
//                case .berrySethi: return [.short, .customLong("ber"), .long]
//                }
//            }
//        }

        /// Parsing method to be applied to input supplied by user.
        enum Construction: String, ExpressibleByArgument, CaseIterable {
            case thompson, berrySethi, antimirov
        }
        
        @Option(name: [.short, .long], help: "construction method") var construction: Construction = .thompson
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
                    case .berrySethi: return try Regex(expression, method: .berrySethi)
                    case .thompson: return try Regex(expression, method: .thompson)
                    case .antimirov: return try Regex(expression, method: .derivative)
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
