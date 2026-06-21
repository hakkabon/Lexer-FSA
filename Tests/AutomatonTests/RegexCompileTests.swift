import Testing
@testable import LexerFSA

// dk.bricks.automaton has a bunch of regexp tests!

@Test
func testUnion() async throws {
    let r = try Regex("a|b")
    #expect(r.description == "(a|b)")
}

@Test
func testUnion2() async throws {
    let r = try Regex("ab|a")
    #expect("\(r)" == "(ab|a)")
}

@Test
func testUnion3() async throws {
    let r = try Regex("ab|ab")
    #expect("\(r)" == "(ab|ab)")
}

@Test
func testConcatenation() async throws {
    let r = try Regex("ab")
    #expect("\(r)" == "ab")
}

@Test
func testConcatenation2() async throws {
    let r = try Regex("abc")
    #expect("\(r)" == "abc")
}

@Test
func testConcatenation3() async throws {
    let r = try Regex("(a|b)c")
    #expect("\(r)" == "(a|b)c")
}

@Test
func testConcatenation4() async throws {
    let r = try Regex("(a|b)cdefgh")
    #expect("\(r)" == "(a|b)cdefgh")
}

@Test
func testDragonBook() async throws {
    let r = try Regex("(a|b)*abb")
    print(r)
    #expect("\(r)" == "((a|b))*abb")
}

@Test
func testSomething() async throws {
    let r = try Regex("[0-9]+")
    #expect("\(r)" == "([0-9]){1,}")
}

@Test
func testSomething2() async throws {
    let r = try Regex("<1-100>")
    #expect("\(r)" == "<1-100>")
}

@Test
func testSomething3() async throws {
    let r = try Regex("a{1,}")
    #expect("\(r)" == "(a){1,}")
}

@Test
func testSomething4() async throws {
    let r = try Regex("a{1,5}")
    #expect("\(r)" == "(a){1,5}")
}

@Test
func testSomething5() async throws {
    do {
        let r = try Regex("a{5,5}")
        print("\(r)")
    } catch {
        print(error)
    }
}

@Test
func testSomething6() async throws {
    do {
        let r = try Regex("a{5,1}")
        print("\(r)")
    } catch {
        print(error)
    }
}
