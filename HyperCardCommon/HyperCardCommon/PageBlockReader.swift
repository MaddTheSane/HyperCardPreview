//
//  PageBlockReader.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 03/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


/// Reads inside a page (PAGE) data block, which contains a section of the card list.
public struct PageBlockReader {
    
    private let data: DataRange
    
    private let versionOffset: Int
    
    private let cardCount: Int
    
    private let cardReferenceSize: Int
    
    private let hashValueCount: Int
    
    private static let version1Offset = -4
    
    public init(data: DataRange, version: FileVersion, cardCount: Int, cardReferenceSize: Int, hashValueCount: Int) {
        self.data = data
        self.versionOffset = version.isTwo() ? 0 : PageBlockReader.version1Offset
        self.cardCount = cardCount
        self.cardReferenceSize = cardReferenceSize
        self.hashValueCount = hashValueCount
    }
    
    /// Identifier
    public func readIdentifier() -> Int {
        return data.readUInt32(at: 0x8)
    }
    
    /// ID of the list
    public func readListIdentifier() -> Int {
        return data.readUInt32(at: 0x10 + self.versionOffset)
    }
    
    /// Checksum of the PAGE block
    public func readChecksum() -> Int {
        return data.readUInt32(at: 0x14 + self.versionOffset)
    }
    
    
    /// Checks the checksum
    public func isChecksumValid() -> Bool {
        var c: UInt32 = 0
        let cardReferences: [CardReference] = self.readCardReferences()
        for r in cardReferences {
            c = rotateRight3Bits(c &+ UInt32(r.identifier))
        }
        let expectedChecksum: Int = self.readChecksum()
        return c == UInt32(expectedChecksum)
    }
    
    /// The records of the cards
    public func readCardReferences() -> [CardReference] {
        
        /* Read the references */
        var references = [CardReference]()
        var offset = 0x18
        for _ in 0..<self.cardCount {
            let identifier: Int = data.readSInt32(at: offset)
            let marked = data.readFlag(at: offset + 4, bitOffset: 12)
            let hasTextContent = data.readFlag(at: offset + 4, bitOffset: 13)
            let isStartOfBackground = data.readFlag(at: offset + 4, bitOffset: 14)
            let hasName = data.readFlag(at: offset + 4, bitOffset: 15)
            let searchHash = SearchHash(data: self.data.sharedData, offset: data.offset + offset + 4, length: self.cardReferenceSize-4, valueCount: self.hashValueCount)
            references.append(CardReference(identifier: identifier, marked: marked, hasTextContent: hasTextContent, isStartOfBackground: isStartOfBackground, hasName: hasName, searchHash: searchHash))
            offset += self.cardReferenceSize
        }
        
        return references
        
    }
    
}


private extension SearchHash {
    
    /// Builds a search hash from a binary data in a stack file
    init(data: Data, offset: Int, length: Int, valueCount: Int) {
        var ints = [UInt32]()
        let count = length / 4
        for i in 0..<count {
            ints.append(data.readUInt32(at: i*4))
        }
        self.init(ints: ints, valueCount: valueCount)
    }
    
}
