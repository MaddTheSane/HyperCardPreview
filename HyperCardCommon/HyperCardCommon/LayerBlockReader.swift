//
//  LayerBlockReader.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 03/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


/// Super-protocol for card and background blocks. They share a lot of fields.
public protocol LayerBlockReader {
    
    /// Identifier
    func readIdentifier() -> Int
    
    /// ID of bitmap block storing the picture of the layer. Nil if there is no picture.
    func readBitmapIdentifier() -> Int?
    
    /// Can't Delete
    func readCantDelete() -> Bool
    
    /// Show Picture
    func readShowPict() -> Bool
    
    /// Don't Search
    func readDontSearch() -> Bool
    
    /// Number of parts
    func readPartCount() -> Int
    
    /// ID to give to a new part
    func readNextAvailableIdentifier() -> Int
    
    /// Total size of the part list, in bytes
    func readPartSize() -> Int
    
    /// Number of part contents
    func readContentCount() -> Int
    
    /// Total size of the part content list, in bytes
    func readContentSize() -> Int
    
    /// The parts in the layer
    func extractPartBlocks() -> [DataRange]
    
    /// The part contents in the layer
    func extractContentBlocks() -> [DataRange]
    
    /// Name
    func readName() -> HString
    
    /// Script
    func readScript() -> HString
    
}
