//
//  FileResourceRepository.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 05/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


public extension ResourceRepository {
    
    private static let mapHeaderLength = 30
    private static let mapTypeLength = 8
    private static let mapReferenceLength = 12
    
    private struct ResourceReference {
        
        /// Type of the resource
        public var type: Int
        
        /// ID of the resource
        public var identifier: Int
        
        /// Name of the resource
        public var name: HString
        
        /// Offset of the resource in the data section of the resource fork
        public var dataOffset: Int
    }
    
    /// Loads a resource repository from the content of a resource fork
    init(loadFromData resourceData: Data) {
        
        let data = DataRange(wholeData: resourceData)
        
        /* Extract the resource map */
        let mapOffset: Int = data.readUInt32(at: 0x4)
        let mapLength: Int = data.readUInt32(at: 0xC)
        let mapData = DataRange(fromData: data, offset: mapOffset, length: mapLength)
        
        /* List the resource references */
        let references = ResourceRepository.readReferences(in: mapData)
        
        /* Load the offset of the resource data table */
        let globalDataOffset: Int = data.readUInt32(at: 0x0)
        
        /* List the resources */
        let resources: [Resource] = references.map({
            ResourceRepository.buildReferencedResource($0, data: data, globalDataOffset: globalDataOffset)
        })
        
        /* Init */
        self.init(resources: resources)
    }
    
    private static func readReferences(in data: DataRange) -> [ResourceReference] {
        
        /* Define the list to return */
        var references = [ResourceReference]()
        
        /* Define the offset in the type list */
        var typeOffset = ResourceRepository.mapHeaderLength
        
        let typeCount = 1 + data.readSInt16(at: 0x1C)
        let nameListOffset: Int = data.readUInt16(at: 0x1A)
        
        /* Loop on the types */
        for _ in 0..<typeCount {
            
            /* Read the type */
            let type: Int = data.readUInt32(at: typeOffset)
            let referenceCountMinusOne: Int = data.readUInt16(at: typeOffset+0x4)
            let referenceListOffset: Int = data.readUInt16(at: typeOffset+0x6)
            
            /* Define the offset in the reference list, to read the references for this type */
            var referenceOffset = referenceListOffset + ResourceRepository.mapHeaderLength - 2
            
            /* Read the references */
            for _ in 0...referenceCountMinusOne {
                
                /* Read the reference */
                let identifier: Int = data.readSInt16(at: referenceOffset)
                let nameOffsetInList: Int = data.readSInt16(at: referenceOffset + 0x2)
                let dataOffsetWithFlags: Int = data.readUInt32(at: referenceOffset + 0x4)
                let dataOffset = dataOffsetWithFlags & 0xFF_FFFF
                
                /* Read the name */
                let name = (nameOffsetInList == -1) ? "" : readName(data: data, nameListOffset: nameListOffset, nameOffsetInList: nameOffsetInList)
                
                /* Build the reference */
                let reference = ResourceReference(type: type, identifier: identifier, name: name, dataOffset: dataOffset)
                references.append(reference)
                
                /* Increment */
                referenceOffset += ResourceRepository.mapReferenceLength
                
            }
            
            /* Increment the type */
            typeOffset += ResourceRepository.mapTypeLength
            
        }
        
        return references
    }
    
    private static func readName(data: DataRange, nameListOffset: Int, nameOffsetInList: Int) -> HString {
        
        /* Locate the name */
        let offset = nameListOffset + nameOffsetInList
        
        /* Read the length */
        let length: Int = data.readUInt8(at: offset)
        
        /* Read the string */
        return data.readString(at: offset+1, length: length)
        
    }
    
    private static func buildReferencedResource(_ reference: ResourceReference, data: DataRange, globalDataOffset: Int) -> Resource {
        
        let resourceData = extractResourceData(at: reference.dataOffset, globalDataOffset: globalDataOffset, data: data)
        let typeIdentifier = reference.type
        
        return Resource(identifier: reference.identifier, name: reference.name, typeIdentifier: typeIdentifier, data: resourceData)
    }
    
    private static func extractResourceData(at dataOffset: Int, globalDataOffset: Int, data: DataRange) -> DataRange {
        
        let offset = dataOffset + globalDataOffset
        let length: Int = data.readUInt32(at: offset)
        return DataRange(fromData: data, offset: offset + 4, length: length)
    }
    
}

