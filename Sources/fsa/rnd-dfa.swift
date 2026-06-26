import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    struct RndDFA: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate a random Deterministic Finite State Automaton (DFA) form given options.")

        /// Select a randomized construction method to build the DFA.
        enum Method: String, ExpressibleByArgument, CaseIterable {
            case standard, simple
            var conversion: DfaStrategy {
                switch self {
                case .standard: return DfaStrategy.bridged
                case .simple: return DfaStrategy.simple
                }
            }
        }

        @Option(name: [.short, .long], help: "construction method") var method: Method = .standard
        @Option(name: [.short, .long], help: "Number of states") var states: Int = 10
        @Option(name: [.short, .long], help: "Number of final states") var finals: Int = 2
        @Option(name: [.short, .long], help: "Number of transition symbols") var alphabet: Int = 2
        @Option(name: [.short, .long], help: "Connectivity ratio in % w.r.t. full connectivity") var density: Float = 2
        
        mutating func run() throws {
            var options = GenerateOptions()
            options.strategy = .dfaStrategy(method.conversion)
            options.states = states
            options.finals = finals
            options.symbols = alphabet
            options.density = Float(density)
            
            let automaton = DFSA.generate(with: options)
            
            let graphViz = automaton.graphviz
                
            // When things go wrong ... use this.
            // print(DOTEncoder().encode(graphViz))
                
            let dotfile = DOTEncoder().encode(graphViz)
            try shellOut(to: ["echo '\(dotfile)' | dot -Tpdf > parse-tree.pdf", "open parse-tree.pdf"])
        }
    }
}
