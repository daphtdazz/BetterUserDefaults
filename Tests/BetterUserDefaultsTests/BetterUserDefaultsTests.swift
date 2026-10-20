import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import BetterUserDefaults
import BetterUserDefaultsMacros

let justBetterUserDefaults: [String: Macro.Type] = [
    "BetterUserDefaults": BetterUserDefaultsMacro.self
]

final class BetterUserDefaultsTests: XCTestCase {

    func testBetterUserDefaultsMacroDefaultExpansion() throws {
        assertBetterUserDefaultsMacroEffect(
            """
            var lastLocation: URL = URL(string: "https://gps.com")!
            """,
            """
            var lastLocation: URL {
                get {
                    let optVal = URL(string: _dict["lastLocation"] as? String ?? "")
                    let udVal = optVal ?? URL(string: "https://gps.com")!
                    return udVal
                }
                set {
                    save(value: newValue.absoluteString, forKey: "lastLocation")
                }
            }

            override open func dataRepresentation() -> UDDictType {
                var repr: UDDictType = [:]
                repr["lastLocation"] = lastLocation.absoluteString as Any
                return repr
            }
            """
        )
    }
    func testBetterUserDefaultsMacroOptionalExpansion() throws {
        assertBetterUserDefaultsMacroEffect(
            """
            var maybeString: String?
            """,
            """
            var maybeString: String? {
                get {
                    let optVal = _dict["maybeString"] as? String
                    let udVal = optVal
                    return udVal
                }
                set {
                    save(value: newValue, forKey: "maybeString")
                }
            }

            override open func dataRepresentation() -> UDDictType {
                var repr: UDDictType = [:]
                if let _local_maybeString = maybeString {
                    repr["maybeString"] = _local_maybeString as Any
                }
                return repr
            }
            """
        )
    }
    func testBetterUserDefaultsMacroOptionalArrayChild() throws {
        assertBetterUserDefaultsMacroEffect(
            """
            var children: BetterUserDefaultsArray<AnotherBetterUserDefaults>?
            """,
            """
            var children: BetterUserDefaultsArray<AnotherBetterUserDefaults>? {
                get {
                    _childrenBackingArray
                }
                set {
                    if let existingArray = _childrenBackingArray {
                        _removeChildLinks(existingArray)
                    }
                    _childrenBackingArray = newValue
                    if let newValueHard = newValue {
                        _addChildLinks(newValueHard, forKey: "children")
                    }
                }
            }

            private var _childrenBackingArray: BetterUserDefaultsArray<AnotherBetterUserDefaults>? = nil

            override func buildChildren() {
                if let _local_children = _dict["children"] as? UDArrayType {
                    _childrenBackingArray = BetterUserDefaultsArray<AnotherBetterUserDefaults>(
                        parent: self, initial: _local_children
                    )
                    _addChildLinks(_childrenBackingArray!, forKey: "children")
                }
            }
            """,
        )
    }
    func testBetterUserDefaultsMacroArrayChild() throws {
        assertBetterUserDefaultsMacroEffect(
            """
            var children: BetterUserDefaultsArray<AnotherBetterUserDefaults>

            let childrenDefault: UDArrayType = []
            """,
            """
            var children: BetterUserDefaultsArray<AnotherBetterUserDefaults> {
                get {
                    if let value = _childrenBackingArray {
                        return value
                    }
                    let defaultValue = BetterUserDefaultsArray<AnotherBetterUserDefaults>(parent: self, initial: childrenDefault)!
                    self.children = defaultValue
                    return defaultValue
                }
                set {
                    if let existingArray = _childrenBackingArray {
                        _removeChildLinks(existingArray)
                    }
                    _childrenBackingArray = newValue
                    _addChildLinks(newValue, forKey: "children")
                }
            }

            private var _childrenBackingArray: BetterUserDefaultsArray<AnotherBetterUserDefaults>? = nil

            let childrenDefault: UDArrayType = []

            override func buildChildren() {
                if let _local_children = _dict["children"] as? UDArrayType {
                    _childrenBackingArray = BetterUserDefaultsArray<AnotherBetterUserDefaults>(
                        parent: self, initial: _local_children
                    )
                    _addChildLinks(_childrenBackingArray!, forKey: "children")
                }
            }
            """,
        )
    }

    func testBetterUserDefaultsMacroIgnoresAlreadyComputed() throws {
        assertBetterUserDefaultsMacroNoEffect(
            """
            var alreadyAccessed {
                get { "testvalue" }
            }
            """
        )
    }

    func testBetterUserDefaultsMacroIgnoresFunction() throws {
        assertBetterUserDefaultsMacroNoEffect(
            """
            func someFunc() {
                // unaffected
            }
            """
        )
    }

    func testBetterUserDefaultsMacroIgnoresIgnored() throws {
        assertBetterUserDefaultsMacroEffect(
            """
            @BetterUserDefaultsIgnore
            var toBeIgnored: String? = nil
            """,
            """
            var toBeIgnored: String? = nil
            """
        )
    }

    func testBetterUserDefaultsUnrecognisedType() throws {
        assertBetterUserDefaultsMacroDiagnostics(
            "var someType: SomeType?",
            [
                DiagnosticSpec(
                    message: "Unusable type \"SomeType?\" for BetterUserDefaults",
                    line: 3,
                    column: 19
                )
            ]
        )
    }
    func testBetterUserDefaultsUnrecognisedArrayType() throws {
        assertBetterUserDefaultsMacroDiagnostics(
            "var someType: [SomeType]",
            [
                DiagnosticSpec(
                    message: "Unusable type \"[SomeType]\" for BetterUserDefaults",
                    line: 3,
                    column: 19
                )
            ]
        )
    }

    func testBetterUserDefaultsMacroDiagnostics() throws {
        assertMacroExpansion(
            // deliberate indent to check diagnostc column matches
            """
              @BetterUserDefaults
            enum MyClass {
                var lastLocation: URL
            }
            """,
            expandedSource: """
                enum MyClass {
                    var lastLocation: URL
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@BetterUserDefaultsMacro can only be applied to a class",
                    line: 1,
                    column: 3
                )
            ],
            macros: justBetterUserDefaults
        )
    }

    func testBetterUserDefaultsMissingInitializer() throws {
        assertBetterUserDefaultsMacroDiagnostics(
            "var someString: String",
            [
                DiagnosticSpec(
                    message: "Non-optional @BetterUserDefaultsAttr property needs an initializer",
                    line: 3,
                    column: 5
                )
            ]
        )
    }
}

@BetterUserDefaults
class ChildBetterUserDefaults: BetterUserDefaults {
    public var someChildValue: String?
    public var someUrl: URL? = nil

    override class var upgrades: BetterUserDefaults.BetterUserDefaultsUpgraderSet {
        [
            1: [
                {
                    dict in
                    if let someChildValue = dict["someChildValue"] as? String {
                        dict["someChildValue"] = "\(someChildValue) - upgraded"
                    } else {
                        dict.removeValue(forKey: "someChildValue")
                    }
                }
            ],
            2: [
                {
                    dict in
                    if let someCV = dict["someChildValue"] as? String {
                        dict["someUrl"] = someCV
                    }
                }
            ],
        ]
    }
}

@BetterUserDefaults
class ExampleBetterUserDefaults: BetterUserDefaults {
    var someNumber: Int = 2

    var children: BetterUserDefaultsArray<ChildBetterUserDefaults>?
    var childrenWithDefault: BetterUserDefaultsArray<ChildBetterUserDefaults>

    let childrenWithDefaultDefault: UDArrayType = [
        ["someChildValue": "hello, bob"],
        ["someChildValue": "hello, caro"],
    ]

    override class var upgrades: BetterUserDefaults.BetterUserDefaultsUpgraderSet {
        [
            1: [
                {
                    dict in
                    if let someNum = dict["someNumber"] as? Int {
                        dict["someNumber"] = (someNum * 2) as Any
                    } else {
                        dict.removeValue(forKey: "someNumber")
                    }
                }
            ]
        ]
    }
}

final class BetterUserDefaultsChildManagerTest: XCTestCase {
    func testChildManager() throws {
        let epm = ExampleBetterUserDefaults(defaults: UserDefaults.cleanUDForTests())

        XCTAssertNil(epm.children)

        epm.children = BetterUserDefaultsArray<ChildBetterUserDefaults>(array: [], parent: epm)

        let child = try epm.children!.newItem(initial: [:])
        child.someChildValue = "hello world"

        let epm2 = ExampleBetterUserDefaults(defaults: epm.userDefaults!)

        XCTAssertEqual(epm2.children?[0].someChildValue, "hello world")
    }

    func testChildOptionalArray() throws {
        let epm = ExampleBetterUserDefaults(defaults: UserDefaults.cleanUDForTests())

        XCTAssertNotNil(epm.childrenWithDefaultDefault)
        XCTAssertEqual(epm.childrenWithDefault.count, 2)
        XCTAssertEqual(epm.childrenWithDefault[0].someChildValue, "hello, bob")
    }

    func testMoveDefaultArrayEntry() throws {
        let epm = ExampleBetterUserDefaults(defaults: UserDefaults.cleanUDForTests())

        epm.childrenWithDefault.move(from: 1, to: 0)

        let epm2 = ExampleBetterUserDefaults(defaults: epm.userDefaults!)
        XCTAssertEqual(epm2.childrenWithDefault[0].someChildValue, "hello, caro")
    }
}

final class BetterUserDefaultsUpgradeTests: XCTestCase {
    func testBetterUserDefaultsUpgradesIgnoresDefaults() throws {
        let epm = ExampleBetterUserDefaults(defaults: UserDefaults.cleanUDForTests())
        XCTAssertEqual(epm.someNumber, 2)

        epm.upgrade()
        // not changed because someNumber was never set, so the default is used
        XCTAssertEqual(epm.someNumber, 2)
    }
    func testBetterUserDefaultsUpgrades() throws {
        let ud = UserDefaults.cleanUDForTests()
        ud.set([], forKey: "children")
        let epm = ExampleBetterUserDefaults(defaults: ud)
        XCTAssertEqual(epm.userDefaults!.integer(forKey: "_prefVersion"), 0)

        epm.someNumber = 2
        let child = try epm.children!.newItem(initial: ["someUrl": "about:blank"])
        child.someChildValue = "hello"

        epm.upgrade()
        XCTAssertEqual(epm.someNumber, 4)
        XCTAssertEqual(epm.userDefaults!.integer(forKey: "_prefVersion"), 1)
        XCTAssertEqual(
            (epm.userDefaults!.array(forKey: "children")! as! [[String: Any]])[0]["someChildValue"]!
                as! String,
            "hello - upgraded"
        )
        XCTAssertEqual(
            epm.children![0].someUrl?.absoluteString,
            "hello%20-%20upgraded"
        )

        // Another upgrade is no-op
        epm.upgrade()
        XCTAssertEqual(epm.someNumber, 4)
    }
}
