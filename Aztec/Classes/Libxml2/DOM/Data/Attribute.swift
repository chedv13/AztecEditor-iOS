import Foundation

/// Represents a basic attribute with no value.  This is also the base class for all other
/// attributes.
///
class Attribute: NSObject, CustomReflectable, NSCoding {

    // MARK: - Attribute Definition Properties

    let name: String
    var value: Value

    // MARK: - CSS Support

    let cssAttributeName = "style"

    // MARK: - Initializers
    
    init(name: String, value: Value = .none) {
        self.name = name
        self.value = value
    }

/*
    init(name: String, string: String?) {
        self.name = name

        guard let string = string, !string.isEmpty else {
            self.value = .none
            return
        }

        guard name.lowercased() == cssAttributeName else {
            self.value = .string(string)
            return
        }

        self.value = Value(withCSSString: string)
    }
*/
    // MARK: - CSS Parsing




    // MARK: - CustomReflectable

    public var customMirror: Mirror {
        get {
            return Mirror(self, children: ["name": name, "value": value])
        }
    }

    // MARK - Hashable

    override var hashValue: Int {
        return name.hashValue ^ value.hashValue
    }

    // MARK: - NSCoding

    struct Keys {
        static let name = "name"
        static let value = "value"
    }

    public required convenience init?(coder aDecoder: NSCoder) {

        guard let name = aDecoder.decodeObject(forKey: Keys.name) as? String,
            let valueCoding = aDecoder.decodeObject(forKey: Keys.value) as? Value.Coding
        else {
            assertionFailure("Review the logic.")
            return nil
        }

        self.init(name: name, value: valueCoding.value)
    }

    open func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: Keys.name)
        aCoder.encode(value.encode(), forKey: Keys.value)
    }

    // MARK: - Equatable

    override func isEqual(_ object: Any?) -> Bool {
        guard let rhs = object as? Attribute else {
            return false
        }

        return name == rhs.name && value == rhs.value
    }

    // MARK: - String Representation

    func toString() -> String {
        var result = name

        if let stringValue = value.toString() {
            result += "=\"" + stringValue + "\""
        }

        return result
    }
}


// MARK: - Attribute.Value

extension Attribute {

    /// Allowed attribute values
    ///
    enum Value: Equatable, Hashable {
        case none
        case string(String)
        case inlineCss([CSSAttribute])

        // MARK: - Initializers

        init(withCSSString cssString: String) {

            let components = cssString.components(separatedBy: CSSParser.attributeSeparator)

            guard !components.isEmpty else {
                self = .none
                return
            }

            let properties = components.flatMap { CSSAttribute(for: $0) }

            guard !properties.isEmpty else {
                self = .string(cssString)
                return
            }

            self = .inlineCss(properties)
        }

        // MARK: - NSCoding pseudo-support

        func encode() -> Coding {
            return Coding(self)
        }

        // MARK: - Hashable

        var hashValue: Int {
            switch(self) {
            case .none:
                return 0
            case .string(let string):
                return string.hashValue
            case .inlineCss(let cssAttributes):
                return cssAttributes.reduce(0, { (previous, cssAttribute) -> Int in
                    return previous ^ cssAttribute.hashValue
                })
            }
        }


        // MARK: - Equatable

        static func ==(lValue: Value, rValue: Value) -> Bool {
            switch(lValue) {
            case .none:
                return true
            case .string(let string):
                return string == rValue
            case .inlineCss(let cssProperties):
                return cssProperties == rValue
            }
        }

        static func ==(lValue: Value, rString: String) -> Bool {
            return rString == lValue
        }

        static func ==(lString: String, rValue: Value) -> Bool {
            switch(rValue) {
            case .string(let rString):
                return lString == rString
            default:
                return false
            }
        }

        static func ==(lValue: Value, rProperties: [CSSAttribute]) -> Bool {
            return rProperties == lValue
        }

        static func ==(lProperties: [CSSAttribute], rValue: Value) -> Bool {
            switch(rValue) {
            case .inlineCss(let rProperties):
                return lProperties == rProperties
            default:
                return false
            }
        }


        // MARK: - String Representation

        func toString() -> String? {
            switch(self) {
            case .none:
                return nil
            case .string(let string):
                return string
            case .inlineCss(let properties):
                var result = ""

                for (index, property) in properties.enumerated() {
                    result += property.toString()

                    if index < properties.count - 1 {
                        result += CSSParser.attributeSeparator + " "
                    }
                }
                
                return result
            }
        }

        // MARK: - NSCoding support

        /// Offers NSCoding support for our enum, without having to change our arquitecture for it.
        ///
        class Coding: NSObject, NSCoding {

            enum ValueType: String {
                case none = "none"
                case string = "string"
                case inlineCss = "inlineCss"
            }

            let valueDataKey = "valueData"
            let valueTypeKey = "valueType"

            let value: Value

            // MARK: - Initializing with value

            init(_ value: Value) {
                self.value = value
            }

            // MARK: - NSCoding support

            required init?(coder: NSCoder) {
                guard let valueTypeRaw = coder.decodeObject(forKey: valueTypeKey) as? String,
                    let valueType = ValueType(rawValue: valueTypeRaw) else {
                        return nil
                }

                switch valueType {
                case .none:
                    value = .none
                case .string:
                    let string = coder.decodeObject(forKey: valueDataKey) as? String ?? ""

                    value = .string(string)
                case .inlineCss:
                    let cssAttributes = coder.decodeObject(forKey: valueDataKey) as? [CSSAttribute] ?? []

                    value = .inlineCss(cssAttributes)
                }
            }

            func encode(with aCoder: NSCoder) {

                let valueData: Any?
                let valueType: ValueType

                switch value {
                case .none:
                    valueData = nil
                    valueType = .none
                case .string(let string):
                    valueData = string
                    valueType = .string
                case .inlineCss(let attributes):
                    valueData = attributes
                    valueType = .inlineCss
                }

                aCoder.encode(valueData, forKey: valueDataKey)
                aCoder.encode(valueType.rawValue, forKey: valueTypeKey)
            }
        }
    }
}
