//
//  FontBlockReader.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 03/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


/// Reads inside a Font Block (FTBL) data, which contains the names of the fonts
/// used in the stack
/// <p>
/// This data block was necessary because the font identifiers were not always
/// consistent across the installations.
public struct FontBlockReader {
    
    private let data: DataRange
    
    public init(data: DataRange) {
        self.data = data
    }
    
    /// Identifier
    public func readIdentifier() -> Int {
        return data.readUInt32(at: 0x8)
    }
    
    /// Number of font names
    public func readFontCount() -> Int {
        return data.readUInt32(at: 0x10)
    }
    
    /// The font names
    public func readFontReferences() -> [FontNameReference] {
        let count = self.readFontCount()
        var offset = 0x18
        var fonts: [FontNameReference] = []
        for _ in 0..<count {
            let identifier: Int = data.readUInt16(at: offset)
            let name = data.readString(at: offset + 0x2)
            fonts.append(FontNameReference(identifier: identifier, name: name))
            
            /* Advance after the name, 16-bit aligned */
            offset += 2
            while data.readUInt8(at: offset) != 0 {
                offset += 1
            }
            offset += 1
            if offset & 1 != 0 {
                offset += 1
            }
        }
        return fonts
    }
}
