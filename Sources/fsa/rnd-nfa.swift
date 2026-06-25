import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    struct RndNFA: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate a random Non-Deterministic Finite State Automaton (NFA) form given options.")

        /// Select a randomized construction method to build the NFA.
        enum Method: String, ExpressibleByArgument, CaseIterable {
            case standard, simple
            var conversion: NfaStrategy {
                switch self {
                case .standard: return NfaStrategy.standard
                case .simple: return NfaStrategy.simple
                }
            }
        }

        @Option(name: [.short, .long], help: "construction method") var metod: Method = .standard
        @Option(name: [.short, .long], help: "Number of states") var states: Int = 8
        @Option(name: [.short, .long], help: "Number of final states") var finals: Int = 1
        @Option(name: [.short, .long], help: "Number of transition symbols") var alphabet: Int = 2
        @Option(name: [.short, .long], help: "Connectivity ratio in % w.r.t. full connectivity") var density: Float = 0.2
        
        mutating func run() throws {
            var options = GenerateOptions()
            options.strategy = .nfaStrategy(metod.conversion)
            options.states = states
            options.finals = finals
            options.symbols = alphabet
            options.density = Float(density)
            
            let automaton = NFSA.generate(with: options)
            
            let graphViz = automaton.graphviz
            
            // When things go wrong ... use this.
            // print(DOTEncoder().encode(graphViz))
            
            let dotfile = DOTEncoder().encode(graphViz)
            try shellOut(to: ["echo '\(dotfile)' | dot -Tpdf > parse-tree.pdf", "open parse-tree.pdf"])
        }
    }
}
