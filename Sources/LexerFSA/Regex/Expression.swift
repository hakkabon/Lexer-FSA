//
//  Expression.swift
//  lexer-fsa
//
//  Created by Ulf Akerstedt-Inoue on 2021/06/08.
//  Copyright © 2021 hakkabon software. All rights reserved.
//

import Foundation

/// Regex internal structure.
public indirect enum Expression: Hashable {
    case union(Expression,Expression)
    case concatenation(Expression,Expression)
//    case intersection(Expression,Expression)
    case optional(Expression)
    case `repeat`(Expression)
    case repeatMin(Expression,Int)
    case repeatMinMax(Expression,Int,Int)
//    case negatedCharClasses([Expression]))
    case charRange(Character,Character)
    case char(Character)
    case anyChar
    case string(String)
    case anyString
    case interval(Int,Int,Int)
    case empty
    
    public var flattened: String {
        return flatten(self)
    }

    public var description: String {
        switch self {
        case .union(let e1, let e2): return "union(\(e1), \(e2))"
        case .concatenation(let e1, let e2): return "concat(\(e1), \(e2))"
        case .optional(let e): return "optional(\(e))"
        case .repeat(let e): return "repeat(\(e))"
        case .repeatMin(let e, let n): return "repeatMin(\(e), \(n) : \(n)"
        case .repeatMinMax(let e, let n, let m): return "repeatMinMax(\(e), \(n), \(m)"
        case .charRange(let ch1, let ch2): return "charRange(\(ch1), \(ch2)"
        case .char(let ch): return "char(\(ch))"
        case .anyChar: return "any char"
        case .string(let s): return "string(\(s))"
        case .anyString: return "any string"
        case .interval(let n, let m, let digits): return "interval(\(n),\(m),\(digits)"
        case .empty: return "empty"
        }
    }

    public func preorder(traversal visit: (Expression) -> Void) {
        switch self {
        case let .union(l,r): fallthrough
        case let .concatenation(l,r):
            visit(self)
            l.preorder(traversal: visit)
            r.preorder(traversal: visit)
        case let .optional(e): fallthrough
        case let .repeat(e): fallthrough
        case let .repeatMin(e,_): fallthrough
        case let .repeatMinMax(e,_,_):
            visit(self)
            e.preorder(traversal: visit)
        case .charRange(_,_): fallthrough
        case .char(_): fallthrough
        case .anyChar: fallthrough
        case .string(_): fallthrough
        case .anyString: fallthrough
        case .interval(_,_,_): fallthrough
        case .empty: visit(self)
        }
    }

    public func inorder(traversal visit: (Expression) -> Void) {
        switch self {
        case let .union(l,r): fallthrough
        case let .concatenation(l,r):
            l.preorder(traversal: visit)
            visit(self)
            r.preorder(traversal: visit)
        case let .optional(e): fallthrough
        case let .repeat(e): fallthrough
        case let .repeatMin(e,_): fallthrough
        case let .repeatMinMax(e,_,_):
            visit(self)
            e.preorder(traversal: visit)
        case .charRange(_,_): fallthrough
        case .char(_): fallthrough
        case .anyChar: fallthrough
        case .string(_): fallthrough
        case .anyString: fallthrough
        case .interval(_,_,_): fallthrough
        case .empty: visit(self)
        }
    }

    public func postorder(traversal visit: (Expression) -> Void) {
        switch self {
        case let .union(l,r): fallthrough
        case let .concatenation(l,r):
            l.preorder(traversal: visit)
            r.preorder(traversal: visit)
            visit(self)
        case let .optional(e): fallthrough
        case let .repeat(e): fallthrough
        case let .repeatMin(e,_): fallthrough
        case let .repeatMinMax(e,_,_):
            e.preorder(traversal: visit)
            visit(self)
        case .charRange(_,_): fallthrough
        case .char(_): fallthrough
        case .anyChar: fallthrough
        case .string(_): fallthrough
        case .anyString: fallthrough
        case .interval(_,_,_): fallthrough
        case .empty: visit(self)
        }
    }
}

func leaves(_ expression: Expression) -> [Expression] {
    switch expression {
    case let .union(l,r): return leaves(l) + leaves(r)
    case let .concatenation(l,r): return leaves(l) + leaves(r)
    case let .optional(e): return leaves(e)
    case let .repeat(e): return leaves(e)
    case let .repeatMin(e,_): return leaves(e)
    case let .repeatMinMax(e,_,_): return leaves(e)
    case let .charRange(ch1,ch2):
        return [ .charRange(ch1,ch2) ]
    case let .char(ch):
        return [ .char(ch) ]
    case .anyChar:
        return [ .anyChar ]
    case let .string(s):
        return [ .string(s) ]
    case .anyString:
        return [ .anyString ]
    case let .interval(min,max,digits):
        return [.interval(min,max,digits) ]
    case .empty:
        return [.empty]
    }
}

func countleaves(_ expression: Expression) -> Int {
    switch expression {
    case let .union(l,r): fallthrough
    case let .concatenation(l,r): return countleaves(l) + countleaves(r)
    case let .optional(e): fallthrough
    case let .repeat(e): fallthrough
    case let .repeatMin(e,_): fallthrough
    case let .repeatMinMax(e,_,_): return countleaves(e)
    case .charRange(_,_): fallthrough
    case .char(_): fallthrough
    case .anyChar: fallthrough
    case .string(_): fallthrough
    case .anyString: fallthrough
    case .interval(_,_,_): fallthrough
    case .empty: return 1
    }
}

func flatten(_ expression: Expression) -> String {
    switch expression {
    case let .union(e1,e2):             return "union(\(flatten(e1)),\(flatten(e2)))"
    case let .concatenation(e1,e2):     return "concatenation(\(flatten(e1)),\(flatten(e2)))"
    case let .optional(e):              return "optional(\(flatten(e)))"
    case let .repeat(e):                return "repeat(\(flatten(e)))"
    case let .repeatMin(e,n):           return "repeatMin(\(flatten(e)),\(n))"
    case let .repeatMinMax(e,n,m):      return "repeatMinMax(\(flatten(e)),\(n),\(m))"
    case let .charRange(ch1,ch2):       return "\(Expression.charRange(ch1,ch2))"
    case let .char(ch):                 return "\(Expression.char(ch))"
    case .anyChar:                      return "\(Expression.anyChar)"
    case let .string(s):                return "\(Expression.string(s))"
    case .anyString:                    return "\(Expression.anyString)"
    case let .interval(n,m,digits):     return "\(Expression.interval(n,m,digits))"
    case .empty:                        return "\(Expression.empty)"
    }
}

func unparse(_ expression: Expression, _ string: inout String) {
    switch expression {
    case let .union(e1,e2):
        string.append("(")
        unparse(e1,&string)
        string.append("|")
        unparse(e2,&string)
        string.append(")")
    case let .concatenation(e1,e2):
        unparse(e1,&string)
        unparse(e2,&string)
    case let .optional(e):
        string.append("(")
        unparse(e,&string)
        string.append(")?")
    case let .repeat(e):
        string.append("(")
        unparse(e,&string)
        string.append(")*")
    case let .repeatMin(e,n):
        string.append("(")
        unparse(e,&string)
        string.append("){\(n),}")
    case let .repeatMinMax(e,n,m):
        string.append("(")
        unparse(e,&string)
        string.append("){\(n),\(m)}")
    case let .charRange(from,to): string.append("[\(from)-\(to)]")
    case let .char(ch): string.append(String(ch))
    case .anyChar: string.append(".")
    case let .string(s): string.append((s))
    case .anyString: string.append("@")
    case let .interval(min,max,digits):
        let s1 = String(min)
        let s2 = String(max)
        string.append("<")
        if digits > 0 {
            for _ in s1.count ..< digits { string.append("0") }
        }
        string.append(s1+"-")
        if digits > 0 {
            for _ in s2.count ..< digits { string.append("0") }
        }
        string.append(s2+">")
    case .empty: string.append("#")
    }
}
