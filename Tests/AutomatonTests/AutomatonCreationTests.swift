import XCTest
@testable import LexerFSA

class AutomatonCreationTests: XCTestCase {

    func testEmptyNondeterministicFiniteState() throws {
        let nfa = NFSA(initial: 0, finals: Set<Int>(), transitions: Set<Transition>())
        let a = Automaton(nfa)
        XCTAssertNotNil(nfa)
        XCTAssertNotNil(a)
    }
    
    func testEmptyDeterministicFiniteState() throws {
        let dfa = DFSA(initial: 0, finals: Set<Int>(), transitions: Set<Transition>())
        let a = Automaton(dfa)
        XCTAssertNotNil(dfa)
        XCTAssertNotNil(a)
    }
    
    func testSimpleNondeterministicFiniteState() throws {
        let finals = Set<Int>([2,3])
        var transitions = Set<Transition>()
        transitions.insert(Transition(from: 0, AlphabetRange.char("a"), to: 1))
        transitions.insert(Transition(from: 0, AlphabetRange.char("b"), to: 2))
        transitions.insert(Transition(from: 1, AlphabetRange.char("b"), to: 3))
        let nfa = NFSA(initial: 0, finals: finals, transitions: transitions)
        let a = Automaton(nfa)
        XCTAssertNotNil(nfa)
        XCTAssertNotNil(a)
    }
    
    func testSimpleRepeat4() throws {
        let finals = Set<Int>([4])
        var transitions = Set<Transition>()
        transitions.insert(Transition(from: 0, AlphabetRange.char("a"), to: 1))
        transitions.insert(Transition(from: 0, AlphabetRange.char("b"), to: 2))
        transitions.insert(Transition(from: 1, AlphabetRange.char("b"), to: 3))
        transitions.insert(Transition(from: 1, AlphabetRange.char("a"), to: 4))
        let dfa = DFSA(initial: 0, finals: finals, transitions: transitions)
        let a = Automaton(dfa)
        XCTAssertNotNil(dfa)
        XCTAssertNotNil(a)
    }
    
    
//    func testSimpleRepeat5() throws {
//        var r = try Regex("(ab)*(ba)*")
//        XCTAssertTrue(r.recognize(string: "ababbababa"), "'(ab)*(ba)*' accepts `ababbababa`")
//        let a = Automaton(r)
//        XCTAssertTrue(a.recognize(string: "ababbababa"), "'(ab)*(ba)*' accepts `ababbababa`")
//        r.deterministic = true
//        let dfa = Automaton(r)
//        XCTAssertTrue(dfa.finiteState.recognize(string: "ababbababa"), "'(ab)*(ba)*' accepts `ababbababa`")
//    }
}
