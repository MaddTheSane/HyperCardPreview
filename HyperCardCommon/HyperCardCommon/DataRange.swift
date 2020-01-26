//
//  DataObject.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 12/02/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//

import Foundation


/// An reference to a section of a data
public struct DataRange {
    
    /// The data pointed by by the object
    public let sharedData: Data
    
    /// The start of the pointed section
    public let offset: Int
    
    /// The length of the pointed section
    public let length: Int
    
    /// Main constructor, declared to be public
    public init(sharedData: Data, offset: Int, length: Int) {
        self.sharedData = sharedData
        self.offset = offset
        self.length = length
    }
    
    /// Reads a unsigned byte in the pointed data
    public func readUInt8(at offset: Int) -> Int {
        return self.sharedData.readUInt8(at: self.offset + offset)
    }
    
    /// Reads a signed byte in the pointed data
    public func readSInt8(at offset: Int) -> Int {
        return self.sharedData.readSInt8(at: self.offset + offset)
    }
    
    /// Reads a big-endian unsigned 2-byte integer in the pointed data
    public func readUInt16(at offset: Int) -> Int {
        return self.sharedData.readUInt16(at: self.offset + offset)
    }
    
    /// Reads a big-endian signed 2-byte integer in the pointed data
    public func readSInt16(at offset: Int) -> Int {
        return self.sharedData.readSInt16(at: self.offset + offset)
    }
    
    /// Reads a big-endian unsigned 4-byte integer in the pointed data
    public func readUInt32(at offset: Int) -> Int {
        return self.sharedData.readUInt32(at: self.offset + offset)
    }
    
    /// Reads a big-endian signed 4-byte integer in the pointed data
    public func readSInt32(at offset: Int) -> Int {
        return self.sharedData.readSInt32(at: self.offset + offset)
    }
    
    /// Reads a unsigned byte in the pointed data
    public func readUInt8(at offset: Int) -> UInt8 {
        return self.sharedData.readUInt8(at: self.offset + offset)
    }
    
    /// Reads a signed byte in the pointed data
    public func readSInt8(at offset: Int) -> Int8 {
        return self.sharedData.readSInt8(at: self.offset + offset)
    }
    
    /// Reads a big-endian unsigned 2-byte integer in the pointed data
    public func readUInt16(at offset: Int) -> UInt16 {
        return self.sharedData.readUInt16(at: self.offset + offset)
    }
    
    /// Reads a big-endian signed 2-byte integer in the pointed data
    public func readSInt16(at offset: Int) -> Int16 {
        return self.sharedData.readSInt16(at: self.offset + offset)
    }
    
    /// Reads a big-endian unsigned 4-byte integer in the pointed data
    public func readUInt32(at offset: Int) -> UInt32 {
        return self.sharedData.readUInt32(at: self.offset + offset)
    }
    
    /// Reads a big-endian signed 4-byte integer in the pointed data
    public func readSInt32(at offset: Int) -> Int32 {
        return self.sharedData.readSInt32(at: self.offset + offset)
    }
}

public extension DataRange {
    
    init(wholeData data: Data) {
        
        self.sharedData = data
        self.offset = 0
        self.length = data.count
    }
    
    init(fromData data: DataRange, offset: Int, length: Int) {
        
        self.sharedData = data.sharedData
        self.offset = data.offset + offset
        self.length = length
    }
    
    init(fromData data: DataRange, offset: Int) {
        
        self.sharedData = data.sharedData
        self.offset = data.offset + offset
        self.length = data.length - offset
    }
}


public extension DataRange {
    
    /// Reads a bit inside a big-endian 2-byte integer in the pointed data
    func readFlag(at offset: Int, bitOffset: Int) -> Bool {
        
        let flags: UInt16 = readUInt16(at: offset)
        return (flags & (1 << bitOffset)) != 0
    }
    
    /// Reads a 2D rectangle in the pointed data
    func readRectangle(at offset: Int) -> Rectangle {
        /* Sometimes a flag is added to top bit, so remove it */
        let top = self.readCoordinate(at: offset)
        let left = self.readCoordinate(at: offset + 2)
        let bottom = self.readCoordinate(at: offset + 4)
        let right = self.readCoordinate(at: offset + 6)
        return Rectangle(top: top, left: left, bottom: bottom, right: right)
    }
    
    private func readCoordinate(at offset: Int) -> Int {
        
        let value: Int = self.readUInt16(at: offset)
        
        let topBits = value >> 14
        
        /* Correction if there is a flag on top bit (it happened on a window rectangle) */
        if topBits == 0b10 {
            return value & 0x7FFF
        }
        
        /* Correction if the value is negative */
        if topBits == 0b11 {
            return Int(Int16(bitPattern: UInt16(truncatingIfNeeded: value)))
        }
        
        return value
    }
    
    /// Reads a null-terminated Mac OS Roman string in the pointed data
    func readString(at offset: Int) -> HString {
        return HString(copyNullTerminatedFrom: sharedData, at: self.offset + offset)
    }
    
    /// Reads a Mac OS Roman string in the pointed data
    func readString(at offset: Int, length: Int) -> HString {
        return HString(copyFrom: sharedData, at: self.offset + offset, length: length)
    }
    
}

public extension Data {
    
    /// Reads a unsigned byte
    func readUInt8(at offset: Int) -> Int {
        let value: UInt8 = readUInt8(at: offset)
        return Int(value)
    }
    
    /// Reads a unsigned byte
    func readUInt8(at offset: Int) -> UInt8 {
        return self[offset]
    }
    
    /// Reads a signed byte
    func readSInt8(at offset: Int) -> Int8 {
        let value: UInt8 = readUInt8(at: offset)
        return Int8(bitPattern: value)
    }
    
    /// Reads a signed byte
    func readSInt8(at offset: Int) -> Int {
        let value: Int8 = readSInt8(at: offset)
        return Int(value)
    }
    
    /// Reads a big-endian unsigned 2-byte integer
    func readUInt16(at offset: Int) -> Int {
        let value: UInt16 = readUInt16(at: offset)
        return Int(value)
    }
    
    /// Reads a big-endian unsigned 2-byte integer
    func readUInt16(at offset: Int) -> UInt16 {
        return UInt16(self[offset]) << 8 | UInt16(self[offset+1])
    }
    
    /// Reads a big-endian signed 2-byte integer
    func readSInt16(at offset: Int) -> Int {
        let value: Int16 = readSInt16(at: offset)
        return Int(value)
    }
    
    /// Reads a big-endian signed 2-byte integer
    func readSInt16(at offset: Int) -> Int16 {
        let value: UInt16 = readUInt16(at: offset)
        return Int16(bitPattern: value)
    }
    
    /// Reads a big-endian unsigned 4-byte integer
    func readUInt32(at offset: Int) -> Int {
        let value: UInt32 = readUInt32(at: offset)
        return Int(value)
    }
    
    /// Reads a big-endian unsigned 4-byte integer
    func readUInt32(at offset: Int) -> UInt32 {
        /* If use multiplications because Swift tells "Expression too complex" when I use bit shifts */
        return UInt32(self[offset])*16777216 | UInt32(self[offset+1])*65536 | UInt32(self[offset+2])*256 | UInt32(self[offset+3])
    }
    
    /// Reads a big-endian signed 4-byte integer
    func readSInt32(at offset: Int) -> Int32 {
        let value: UInt32 = readUInt32(at: offset)
        return Int32(bitPattern: value)
    }
    
    /// Reads a big-endian signed 4-byte integer
    func readSInt32(at offset: Int) -> Int {
        let value: Int32 = readSInt32(at: offset)
        return Int(value)
    }
    
}

public extension Image {
    
    /// Reads an uncompressed 1-bit image in a data
    init(data: Data, offset: Int, width: Int, height: Int) {
        
        /* Create the image */
        self.init(width: width, height: height)
        
        /* Fill the rows */
        let rowSize = width / 8
        var integerIndex = 0
        var shift = Image.Integer(Image.Integer.bitWidth - 8)
        var i = offset
        for _ in 0..<height {
            for _ in 0..<rowSize {
                let byte = data[i]
                i += 1
                self.data[integerIndex] |= Image.Integer(byte) << shift
                if shift == 0 {
                    shift = Image.Integer(Image.Integer.bitWidth - 8)
                    integerIndex += 1
                }
                else {
                    shift -= 8
                }
            }
            if shift != Image.Integer(Image.Integer.bitWidth - 8) {
                integerIndex += 1
                shift = Image.Integer(Image.Integer.bitWidth - 8)
            }
        }
        
    }
    
}

public extension HString {
    
    /// Init with null-terminated data
    init(copyNullTerminatedFrom data: Data, at offset: Int) {
        
        /* Find the null termination */
        let dataFromOffset = data.suffix(from: offset)
        let nullIndex = dataFromOffset.firstIndex(of: UInt8(0))!
        
        /* Extract the data for the string */
        let stringSlice = data[offset..<nullIndex]
        let stringData = Data(stringSlice)
        
        self.init(data: stringData)
    }
    
    /// Init with data
    init(copyFrom data: Data, at offset: Int, length: Int) {
        
        /* Extract the data for the string */
        let stringSlice = data[offset..<offset + length]
        let stringData = Data(stringSlice)
        
        self.init(data: stringData)
    }
    
}
