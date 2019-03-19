//
//  NumericName.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 22/03/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//


/// A 4-byte identifier, printed as a 4-char string. It was commonly used in old Mac OS.
public struct NumericName: Hashable, CustomStringConvertible {
    public let value: OSType
    
    public init(value: OSType) {
        self.value = value
    }
    
    public init?(string: String) {
        let aVal = UTGetOSTypeFromString(string as NSString)
        if aVal == 0 /*&& true // check for a string with zero length? */ {
            return nil
        }
        self.value = aVal
    }
    
    public var description: String {
        return UTCreateStringForOSType(value).takeRetainedValue() as String
    }
    
    public static func ==(i1: NumericName, i2: NumericName) -> Bool {
        return i1.value == i2.value
    }

    public func hash(into hasher: inout Hasher) {
        value.hash(into: &hasher)
    }

}
