//
//  FSATool.swift
//  fsa
//
//  Created by Ulf Akerstedt-Inoue on 2024/03/16.
//  Copyright © 2024 hakkabon software. All rights reserved.
//

import Foundation
import ArgumentParser

@main
struct FSATool: ParsableCommand {
    
    static let configuration = CommandConfiguration(
        commandName: "gtool",
        abstract: "A utility for exploring Regular Expressions, NFA, DFA, and DAWG abstractions.",
        version: "0.0.1",
        subcommands: [
            MkDAWG.self,
            MkRegex.self,
            RndDFA.self,
            RndNFA.self,
        ],
        defaultSubcommand: MkRegex.self
    )
}
