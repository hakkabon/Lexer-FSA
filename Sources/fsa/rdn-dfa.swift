import Foundation
import ArgumentParser
import LexerFSA
import GraphViz
import ShellOut

extension FSATool {
    
    struct RndDFA: ParsableCommand {
        static var configuration = CommandConfiguration(abstract: "Generate a random Deterministic Finite State Automaton (DFA) form given options.")

        @Option(name: [.short, .long], help: "Number of states") var states: Int = 10
        @Option(name: [.short, .long], help: "Number of final states") var finals: Int = 2
        @Option(name: [.short, .long], help: "Number of transition symbols") var alphabet: Int = 2
        @Option(name: [.short, .long], help: "Connectivity ratio in % w.r.t. full connectivity") var density: Float = 2
        @Flag(name: [.short, .long], help: "Generate graph of DFA") var graph: Bool = false
        
        mutating func run() throws {
            var options = GenerateOptions()
            options.states = states
            options.finals = finals
            options.symbols = alphabet
            options.density = Float(density)
            
            let automaton = DFSA.generate(with: options)
            
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
