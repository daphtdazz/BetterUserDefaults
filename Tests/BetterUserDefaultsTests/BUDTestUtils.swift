//
//  BUDTestUtils.swift
//  BetterUserDefaults
//
//  Created by David Park on 20/10/2026.
//
import Foundation

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport

import BetterUserDefaults
import BetterUserDefaultsMacros


private let testMacros: [String: Macro.Type] = [
    "BetterUserDefaults": BetterUserDefaultsMacro.self,
    "BetterUserDefaultsAttr": BetterUserDefaultsAttr.self,
    "BetterUserDefaultsIgnore": BetterUserDefaultsIgnore.self,
]

fileprivate extension String {
    func indent() -> String {
        self
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.count == 0 ? "\n" : "    \($0)\n" }
            .joined(separator: "")
    }
}

func assertBetterUserDefaultsMacroEffect(
    _ input: String,
    _ output: String,
    diagnostics: [DiagnosticSpec] = [],
) {
    assertMacroExpansion(
        """
        @BetterUserDefaults
        class MyClass {
        \(input.indent())
        }
        """,
        expandedSource:
            """
            class MyClass {
            \(output.indent())
            }
            """
        ,
        diagnostics: diagnostics,
        macros: testMacros
    )
}

func assertBetterUserDefaultsMacroNoEffect(_ unchangedInput: String) {
    assertBetterUserDefaultsMacroEffect(unchangedInput, unchangedInput)
}

func assertBetterUserDefaultsMacroDiagnostics(_ input: String, _ diagnostics: [DiagnosticSpec]) {
    assertBetterUserDefaultsMacroEffect(
        input,
        input,
        diagnostics: diagnostics
    )
}

extension UserDefaults {
    static func cleanUDForTests() -> UserDefaults {
        let ud = UserDefaults(suiteName: #file)!
        ud.removePersistentDomain(forName: #file)
        return ud
    }
}
