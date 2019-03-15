//
//  CommonTypes.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 26/02/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//

/// 2D geometric position, in pixels
///<p>
/// x is left to right, y top to bottom
public struct Point: Equatable {
    public var x: Int
    public var y: Int
    
    public init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }
    
    public static func ==(p1: Point, p2: Point) -> Bool {
        return p1.x == p2.x && p1.y == p2.y
    }
}


/// 2D geometric size, in pixels
public struct Size: Equatable {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public static func ==(s1: Size, s2: Size) -> Bool {
        return s1.width == s2.width && s1.height == s2.height
    }
}

/// 2D geometric retangle, in pixels
/// <p>
/// It includes the pixels respecting the inequalities left&lt;=x&lt;right and top&lt;=y&lt;bottom
public struct Rectangle: Equatable {
    public var top: Int
    public var left: Int
    public var bottom: Int
    public var right: Int
    
    /* x-y w-h coordinates */
    public var x: Int {
        return left
    }
    public var y: Int {
        return top
    }
    public var width: Int {
        return right - left
    }
    public var height: Int {
        return bottom - top
    }
    
    public init(top: Int, left: Int, bottom: Int, right: Int) {
        self.top = top
        self.left = left
        self.bottom = bottom
        self.right = right
    }
    
    public init(x: Int, y: Int, width: Int, height: Int) {
        self.top = y
        self.left = x
        self.bottom = y + height
        self.right = x + width
    }
    
    public func containsPosition(_ position: Point) -> Bool {
        return position.x >= left && position.x < right && position.y >= top && position.y < bottom
    }
    
    public func intersects(_ rectangle: Rectangle) -> Bool {
        let intersection = computeRectangleIntersection(self, rectangle)
        return intersection.width > 0 && intersection.height > 0
    }
}

public func ==(r1: Rectangle, r2: Rectangle) -> Bool {
    return r1.top == r2.top && r1.left == r2.left && r1.bottom == r2.bottom && r1.right == r2.right
}

/// Computes the intersection rectangle of two rectangles.
///<p>
/// If the intersection is empty, returns an empty rectangle with zero or negative width and height
public func computeRectangleIntersection(_ r1: Rectangle, _ r2: Rectangle) -> Rectangle {
    return Rectangle(top: max(r1.top, r2.top), left: max(r1.left, r2.left), bottom: min(r1.bottom, r2.bottom), right: min(r1.right, r2.right))
}

/// Computes the rectangle directly enclosing two rectangles. Any of the rectangle can be absent
public func computeEnclosingRectangle(_ rectangle1: Rectangle?, _ rectangle2: Rectangle?) -> Rectangle? {
    
    switch (rectangle1, rectangle2) {
        
    case (.some(let r1), .some(let r2)):
        return Rectangle(top: min(r1.top, r2.top), left: min(r1.left, r2.left), bottom: max(r1.bottom, r2.bottom), right: max(r1.right, r2.right))
        
    case (.some(let rectangle), nil):
        return rectangle
        
    case (nil, .some(let rectangle)):
        return rectangle
        
    case (nil, nil):
        return nil
        
    }
}

/// The possible user levels in HyperCard, that is, the protection level against edition
public enum UserLevel: Int {
    
    /// Open, close, and browse through stacks, search for text, click buttons, move between stacks, save copies of stacks, and print the information in stacks
    case browse = 1
    /// In addition to all of the things you can do at the Browsing level, you can type, edit, and add styles to text in existing fields, set the Arrow Keys in Text option on the Preferences card (explained in the “Arrow Keys in Text Option” later in this chapter), add and delete cards, and compact stacks
    case type
    /// In addition to all of the things you can do at the Typing level, you can set stack protection, edit icons from the Edit menu, delete stacks, create graphics with the Paint tools in the Tools menu, edit graphics and patterns using the Paint and Options menus (which appear when a Paint tool is selected), move between the background layer and the card layer, and use the Power Keys (explained in “Power Keys Option” later in this chapter).
    case paint
    /// In addition to all of the things you can do at the Painting level, you can create, modify, and delete buttons, links, fields, cards, backgrounds, and stacks using the Button tool, the Field tool, and commands in the Objects menu
    case author
    /// In addition to all of the things you can do at the Authoring level, you can write, edit, and debug scripts, and use the Blind Typing option (explained in “Blind Typing Option” later in this chapter)
    case script
}

/// All the variants that can be applied to a font
public struct TextStyle: Equatable, CustomStringConvertible, OptionSet, Hashable {
    public var rawValue: UInt8
    public init(rawValue: UInt8) {
        self.rawValue = rawValue
    }
    
    /// Characters are drawn thicker
    public static var bold: TextStyle {
        return TextStyle(rawValue: 1 << 0)
    }
    
    /// Characters are drawn slanted
    public static var italic: TextStyle {
        return TextStyle(rawValue: 1 << 1)
    }

    /// Characters are drawn with an under-line
    public static var underline: TextStyle {
        return TextStyle(rawValue: 1 << 2)
    }

    /// The borders of the characters are drawn in black and the interiors in white
    public static var outline: TextStyle {
        return TextStyle(rawValue: 1 << 3)
    }

    /// Characters are drawn with an under-line
    public static var shadow: TextStyle {
        return TextStyle(rawValue: 1 << 4)
    }
    
    /// Characters are drawn closer to each other
    public static var condense: TextStyle {
        return TextStyle(rawValue: 1 << 5)
    }

    /// Characters are drawn further from each other
    public static var extend: TextStyle {
        return TextStyle(rawValue: 1 << 6)
    }

    /// Specific HyperCard type used to mark the hyperlinks
    public static var group: TextStyle {
        return TextStyle(rawValue: 1 << 7)
    }
	
    /// Characters are drawn thicker
    public var bold: Bool {
        get {
            return self.contains(TextStyle.bold)
        }
        set {
            if newValue {
                self.insert(TextStyle.bold)
            } else {
                self.remove(TextStyle.bold)
            }
        }
    }
	
    /// Characters are drawn slanted
    public var italic: Bool {
        get {
            return self.contains(TextStyle.italic)
        }
        set {
            if newValue {
                self.insert(TextStyle.italic)
            } else {
                self.remove(TextStyle.italic)
            }
        }
    }
	
    /// Characters are drawn with an under-line
    public var underline: Bool {
        get {
            return self.contains(TextStyle.underline)
        }
        set {
            if newValue {
                self.insert(TextStyle.underline)
            } else {
                self.remove(TextStyle.underline)
            }
        }
    }
	
    /// The borders of the characters are drawn in black and the interiors in white
    public var outline: Bool {
        get {
            return self.contains(TextStyle.outline)
        }
        set {
            if newValue {
                self.insert(TextStyle.outline)
            } else {
                self.remove(TextStyle.outline)
            }
        }
    }
	
    /// Characters are drawn outlined and with a shadow
    public var shadow: Bool {
        get {
            return self.contains(TextStyle.shadow)
        }
        set {
            if newValue {
                self.insert(TextStyle.shadow)
            } else {
                self.remove(TextStyle.shadow)
            }
        }
    }
	
    /// Characters are drawn closer to each other
    public var condense: Bool {
        get {
            return self.contains(TextStyle.condense)
        }
        set {
            if newValue {
                self.insert(TextStyle.condense)
            } else {
                self.remove(TextStyle.condense)
            }
        }
    }
	
    /// Characters are drawn further from each other
    public var extend: Bool {
        get {
            return self.contains(TextStyle.extend)
        }
        set {
            if newValue {
                self.insert(TextStyle.extend)
            } else {
                self.remove(TextStyle.extend)
            }
        }
    }
	
    /// Specific HyperCard type used to mark the hyperlinks
    public var group: Bool {
        get {
            return self.contains(TextStyle.group)
        }
        set {
            if newValue {
                self.insert(TextStyle.group)
            } else {
                self.remove(TextStyle.group)
            }
        }
    }
	
    public init(bold: Bool = false, italic: Bool = false, underline: Bool = false, outline: Bool = false, shadow: Bool = false, condense: Bool = false, extend: Bool = false, group: Bool = false) {
        rawValue = 0
        self.bold = bold
        self.italic = italic
        self.underline = underline
        self.outline = outline
        self.shadow = shadow
        self.condense = condense
        self.extend = extend
        self.group = group
    }
    
    public var description: String {
        var s = ""
        if bold {
            s += "b"
        }
        if italic {
            s += "i"
        }
        if underline {
            s += "u"
        }
        if outline {
            s += "o"
        }
        if shadow {
            s += "s"
        }
        if condense {
            s += "c"
        }
        if extend {
            s += "e"
        }
        if group {
            s += "g"
        }
        if s == "" {
            s = "p"
        }
        return s
    }
    
}

public let PlainTextStyle = TextStyle()

public extension TextStyle {
    
    /// Init a text style from a 8 bit flag
    public init(flags: UInt8) {
        self.init(rawValue: flags)
        
    }
    
    /// Init a text style from a 8 bit flag
    public init(flags: Int) {
		rawValue = 0
        bold = (flags & (1 << 0)) != 0
        italic = (flags & (1 << 1)) != 0
        underline = (flags & (1 << 2)) != 0
        outline = (flags & (1 << 3)) != 0
        shadow = (flags & (1 << 4)) != 0
        condense = (flags & (1 << 5)) != 0
        extend = (flags & (1 << 6)) != 0
        group = (flags & (1 << 7)) != 0
    }
    
}

/// Text alignment
public enum TextAlign {
    case left
    case center
    case right
}

/// A text is a string with drawing attributes
public struct Text {
    
    /// The raw string
    public var string: HString
    
    /// The text styles and their starting character index. They are ordered by index.
    public var attributes: [FormattingAssociation]
    
    public struct FormattingAssociation {
        public var offset: Int
        public var formatting: TextFormatting
    }
}

/// Text drawing attributes
public struct TextFormatting {
    
    /// Identifier of the font (in the old Macintosh convention)
    /// <p>
    /// If nil, the value must be set to the default value of the part containing the text
    public var fontFamilyIdentifier: Int?
    
    /// Size of the text in pixels
    /// <p>
    /// If nil, the value must be set to the default value of the part containing the text
    public var size: Int?
    
    /// Style of the text
    /// <p>
    /// If nil, the value must be set to the default value of the part containing the text
    public var style: TextStyle?
}

public enum PartContent {
    case string(HString)
    case formattedString(Text)
    
    public var string: HString {
        switch self {
        case .string(let string):
            return string
        case .formattedString(let text):
            return text.string
        }
    }
}

/// A layer can be either a card or a background
public enum LayerType {
    case card
    case background
}

/// Type of a card or background part
public enum PartType {
    case field
    case button
}

/// Visual style of a part
///<p>
/// The styles of buttons and fields are all mixed
public enum PartStyle {
    
    /// The part has no frame, only a title
    ///<p>
    /// Available for buttons and fields
    case transparent
    
    /// The part has a rectangular background
    ///<p>
    /// Available for buttons and fields
    case opaque
    
    /// The part is rectangular, with a background and a border
    ///<p>
    /// Available for buttons and fields
    case rectangle
    
    /// The part is rectangular with rounded corners, with a background and a border
    ///<p>
    /// Available for buttons only
    case roundRect
    
    /// The part is rectangular, with a background, a border and a shadow
    ///<p>
    /// Available for buttons and fields
    case shadow
    
    /// The part is drawn as a check-box button
    ///<p>
    /// Available for buttons only
    case checkBox
    
    /// The part is drawn as a radio button
    ///<p>
    /// Available for buttons only
    case radio
    
    /// The part is drawn as text editor with a scroll
    ///<p>
    /// Available for fields only
    case scrolling
    
    /// The part is drawn as a System 7 button
    ///<p>
    /// Available for buttons only
    case standard
    
    /// The part is drawn as a System 7 default button, with an external border to show it is triggered by taping enter key
    ///<p>
    /// Available for buttons only
    case `default`
    
    /// The part is drawn with no frame but its background is round
    ///<p>
    /// Available for buttons only
    case oval
    
    /// The button is drawn as a popup button
    ///<p>
    /// Available for buttons only
    case popup
}





/// A software version as defined is classic Mac OS
///<p>
///Version Format: "major.minor1.minor2 state release". Major, minor1 and minor2 are the three version numbers.
///The state is the version status: alpha, beta, final...
///The release is used for alpha and beta versions, it is the release number for that status.
///<p>
///Examples: "2.4.1 final", "2.2 beta release 44"
public struct Version: CustomStringConvertible, Equatable {
    
    /// Major version
    public var major: UInt8
    
    /// Minor version
    public var minor1: UInt8 {
        get {
            return minor >> 4
        }
        set {
            minor &= 0x0F
            minor |= newValue << 4
        }
    }
    
    /// Second minor version
    public var minor2: UInt8 {
        get {
            return minor & 0x0F
        }
        set {
            minor &= 0xf0
            minor |= newValue & 0x0F
        }
    }
    
    /// Minor versions
    public var minor: UInt8
    
    /// Whether the version is alpha, beta, final...
    public var state: State
    
    /// The internal release number for alpha and beta versions
    public var release: UInt8
    
    public enum State: CustomStringConvertible {
        case final
        case beta
        case development
        case alpha
        
        public var description: String {
            switch self {
            case .final:
                return "final"
            case .beta:
                return "beta"
            case .development:
                return "development"
            case .alpha:
                return "alpha"
            }
        }
    }
    
    public init(major: UInt8, minor1: UInt8, minor2: UInt8, state: State, release: UInt8) {
        self.major = major
        self.minor = UInt8(minor1) << 4 | UInt8(minor2)
        self.state = state
        self.release = release
    }
    
    public init(major: UInt8, minor: UInt8, state: State, release: UInt8) {
        self.major = major
        self.minor = minor
        self.state = state
        self.release = release
    }
    
    public init(major: Int, minor1: Int, minor2: Int, state: State, release: Int) {
        self.major = UInt8(major)
        self.minor = UInt8(minor1) << 4 | UInt8(minor2)
        self.state = state
        self.release = UInt8(release)
    }
    
    public var description: String {
        return "\(major).\(minor1).\(minor2) \(writeStateDescription(state))\(writeReleaseDescription(release))"
    }
    
    private func writeStateDescription(_ state: State) -> String {
        switch state {
        case .final:
            return "final"
        case .beta:
            return "beta"
        case .development:
            return "development"
        case .alpha:
            return "alpha"
        }
    }
    
    private func writeReleaseDescription(_ release: UInt8) -> String {
        if release == 0 {
            return ""
        }
        
        /* In HyperTalk, the release is given in hexadecimal, so I stick to that */
        let releaseInHex = String(release, radix: 16, uppercase: true)
        let prefix = (releaseInHex.count == 1) ? "0" : ""
        return " release \(prefix)\(releaseInHex)"
    }
}

public extension Version {
    
    /// Init the version from its encoded form in the resources
    public init(code: Int) {
        self.major = UInt8(code >> 24)
        self.minor = UInt8((code >> 16) & 0xFF)
        self.release = UInt8(code & 0xFF)
        
        let stateNumber = (code >> 8) & 0xFF
        switch stateNumber {
        case 0x20:
            self.state = .development
        case 0x40:
            self.state = .alpha
        case 0x60:
            self.state = .beta
        case 0x80:
            self.state = .final
        default:
            self.state = .final
        }
    }
    
    /// Init the version from its encoded form in the resources
    public init(code: UInt32) {
        self.major = UInt8(code >> 24)
        self.minor = UInt8((code >> 16) & 0xFF)
        self.release = UInt8(code & 0xFF)
        
        let stateNumber = (code >> 8) & 0xFF
        switch stateNumber {
        case 0x20:
            self.state = .development
        case 0x40:
            self.state = .alpha
        case 0x60:
            self.state = .beta
        case 0x80:
            self.state = .final
        default:
            self.state = .final
        }
    }

    
}

public func ==(v1: Version, v2: Version) -> Bool {
    return v1.major == v2.major && v1.minor1 == v2.minor1 && v1.minor2 == v2.minor2 && v1.state == v2.state && v1.release == v2.release
}

/// Identifiers of some basic fonts of Classic Mac OS
public enum FontIdentifiers {
    public static let chicago = 0
    public static let newYork = 2
    public static let geneva = 3
    public static let monaco = 4
    public static let venice = 5
    public static let london = 6
    public static let athens = 7
    public static let sanFrancisco = 8
    public static let toronto = 9
    public static let cairo = 11
    public static let losAngeles = 12
    public static let palatino = 16
    public static let times = 20
    public static let helvetica = 21
    public static let courier = 22
    public static let symbol = 23
    public static let taliesin = 24
    public static let charcoal = 2002
}

/// Properties of the text styles in font families
public struct FontStyleProperties {
    public var plainExtraWidth: Double
    public var boldExtraWidth: Double
    public var italicExtraWidth: Double
    public var underlineExtraWidth: Double
    public var outlineExtraWidth: Double
    public var shadowExtraWidth: Double
    public var condensedExtraWidth: Double
    public var extendedExtraWidth: Double
}

/// A record of a font name
public struct FontNameReference {
    
    /// ID of the font
    public var identifier: Int
    
    /// Name of the font
    public var name: HString
}

/// The version of a HyperCard file
public enum FileVersion {
    case v1
    case v2
    
    public func isTwo() -> Bool {
        return self == FileVersion.v2
    }
}

