//
//  AutomatonProtocol.swift
//  Automaton
//
//  Created by Ulf Akerstedt-Inoue on 2019/01/16.
//  Copyright © 2019 hakkabon software. All rights reserved.
//

import Foundation

// The previous `AutomataOperation` protocol has been removed. Its only
// conformer was `Automaton<DFSA>`, and the three operations it declared
// (`union(a:b:)`, `union(list:)`, `stringUnion(words:)`) are now plain
// static methods on `Automaton<DFSA>` and `Automaton<NFSA>` defined in
// `Operations.swift`. See §4 of the code-review notes.
