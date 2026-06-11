# Automaton

A Finite State Automata implementation that uses the Swift programming language. It has limited Unicode alphabet support for the standard regular expression operations concatenation, union, and Kleene star. There is currently no support for complement and intersection set operations. 

The intended use for this FSA implementation has always been in connection with parsing, parser generators, or interpreters of serveral language classes, such as LL(1), LL(*), SLR, LALR, LR(1), GLR, Earley. The grammar definition is managed by the `Grammar` submodule that in turn uses the `Automaton` to facilitate regular expressions that are used to express tokens that are used in the grammar definition. The grammar is parsed by the `BNF-Parser` which in turn uses the `Tokenizer` to read the text from the grammar files.    

This implementation has taken strong inspiration from the dk.brics.automaton by Anders Møller at Aarhus University. 

Regular expression spoiler alert:
• There is no support for capturing groups.
• Some symbols, like ^ and $, may mean something else than you expect.

A more user (programmer) end oriented `Regex` implemention would be more suitable for capturing groups and extracting substrings from matched tokens.

## License
MIT
