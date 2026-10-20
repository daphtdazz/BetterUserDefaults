//
//  verifyDecl.swift
//  BetterUserDefaults
//
//  Created by David Park on 20/10/2026.
//

import SwiftSyntax
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacros

// MARK: private helpers
package func isAllowedType(_ type: IdentifierTypeSyntax) -> Bool {
    switch type.name.text {
    case "URL", "Float", "Bool", "Int", "Double", "String", "Data", "BetterUserDefaultsArray", "UDArrayType":
        return true
    default: break
    }
    return false
}

package struct BetterUserDefaultsItemDeclInfo {
    let vdecl: VariableDeclSyntax
    let binding: PatternBindingSyntax
    let propertyName: String
    let defaultPropertyName: String
    let isOptional: Bool
    let typeIdentifier: IdentifierTypeSyntax
    let isBetterUserDefaultsArray: Bool

    var backingArrayToken: TokenSyntax {
        assert(isBetterUserDefaultsArray)
        return TokenSyntax.identifier("_\(propertyName)BackingArray")
    }
    var initializerExpr: ExprSyntax? {
        binding.initializer?.value
    }
    var propertyNameStringLiteral: StringLiteralExprSyntax {
        propertyName.makeLiteralSyntax()
    }
    var initializerIdentiferName: String? {
        initializerExpr?.as(DeclReferenceExprSyntax.self)?.baseName.identifier?.name
    }
    var typeName: String {
        typeIdentifier.name.text
    }
    func dataExpr(from baseExpr: ExprSyntax) -> ExprSyntax {
        switch(typeName) {
        case "URL":
            if isOptional {
                "\(baseExpr)?.absoluteString" as ExprSyntax
            } else {
                "\(baseExpr).absoluteString" as ExprSyntax
            }
        default:
            baseExpr
        }
    }
}

extension VariableDeclSyntax {
    func hasAny(attrs: [String]) -> Bool {
        return self.attributes.contains(where: {
            guard
                let attrName = $0.as(AttributeSyntax.self)?
                .attributeName.as(IdentifierTypeSyntax.self)?
                .name.text
                    else {
                return false
            }
            return attrs.contains(attrName)
        })
    }
    var firstDeclName: String? {
        self.bindings.first?.pattern.as(IdentifierPatternSyntax.self)?.identifier.text
    }
}

package func verifyDecl(
    _ decl: some DeclSyntaxProtocol,
    context: some MacroExpansionContext? = (nil as BasicMacroExpansionContext?)
) -> BetterUserDefaultsItemDeclInfo? {
    guard
        let vdecl = decl.as(VariableDeclSyntax.self),
        let binding = vdecl.bindings.first,
        let pat = binding.pattern.as(IdentifierPatternSyntax.self),
        binding.accessorBlock == nil,
        !vdecl.hasAny(attrs: ["BetterUserDefaultsIgnore"])
    else {
        return nil
    }
    guard let rawType = binding.typeAnnotation?.type else {
        context?.diagnose(BetterUserDefaultsDiagnosticMessage.diagNeedsExplicitType(binding))
        return nil
    }

    let typeIdentifier: IdentifierTypeSyntax
    let isOptional: Bool
    if let optType = rawType.as(OptionalTypeSyntax.self) {
        guard let _identifier = optType.wrappedType.as(IdentifierTypeSyntax.self) else {
            context?.diagnose(BetterUserDefaultsDiagnosticMessage.diagUnusableType(rawType))
            return nil
        }
        typeIdentifier = _identifier.trimmed
        isOptional = true
    } else {
        guard let _identifier = rawType.as(IdentifierTypeSyntax.self) else {
            context?.diagnose(BetterUserDefaultsDiagnosticMessage.diagUnusableType(rawType))
            return nil
        }
        typeIdentifier = _identifier.trimmed
        isOptional = false
    }

    guard isAllowedType(typeIdentifier) else {
        context?.diagnose(BetterUserDefaultsDiagnosticMessage.diagUnusableType(rawType))
        return nil
    }

    let declInfo = BetterUserDefaultsItemDeclInfo(
        vdecl: vdecl,
        binding: binding,
        propertyName: pat.identifier.text,
        defaultPropertyName: "\(pat.identifier.text)Default",
        isOptional: isOptional,
        typeIdentifier: typeIdentifier,
        isBetterUserDefaultsArray: typeIdentifier.name.text == "BetterUserDefaultsArray",
    )
    if !declInfo.isBetterUserDefaultsArray && declInfo.initializerExpr == nil && !declInfo.isOptional {
        context?.diagnose(
            BetterUserDefaultsDiagnosticMessage.diagMissingNonOptionalInitializer(decl)
        )
        return nil
    }

    return declInfo
}

