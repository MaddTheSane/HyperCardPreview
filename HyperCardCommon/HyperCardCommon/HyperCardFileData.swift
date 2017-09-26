//
//  HyperCardFileContent.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 22/03/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//



/// The parsed data blocks in a stack file
public class HyperCardFileData: DataBlock {
    
    public let decodedHeader: Data?
    
    public init(data: DataRange, decodedHeader: Data? = nil) {
        self.decodedHeader = decodedHeader
        
        super.init(data: data)
    }
    
    /// The stack block
    public var stack: StackBlock {
        let length: Int = data.readUInt32(at: 0x0)
        let dataRange = DataRange(sharedData: data.sharedData, offset: data.offset, length: length)
        return StackBlock(data: dataRange, decodedHeader: decodedHeader)
    }
    
    /// The master block
    public var master: MasterBlock {
        let stackLength: Int = data.readUInt32(at: 0x0)
        
        /* In the "Stack Templates" stack in 2.4.1, there is a flag in the 2nd higher bit */
        let masterLength = data.readUInt32(at: stackLength) & 0x0FFF_FFFF
        let dataRange = DataRange(sharedData: data.sharedData, offset: data.offset + stackLength, length: masterLength)
        return MasterBlock(data: dataRange)
    }
    
    
    /// The list block
    public var list: ListBlock {
        let identifier = self.stack.listIdentifier
        return self.loadBlock(identifier: identifier, initializer: ListBlock.init)
    }
    
    /// The Style Block
    public var styleBlock: StyleBlock? {
        guard let identifier = self.stack.styleBlockIdentifier else {
            return nil
        }
        return self.loadBlock(identifier: identifier, initializer: StyleBlock.init)
    }
    
    /// The Font Block
    public var fontBlock: FontBlock? {
        guard let identifier = self.stack.fontBlockIdentifier else {
            return nil
        }
        return self.loadBlock(identifier: identifier, initializer: FontBlock.init)
    }
    
    /// The page blocks (PAGE), containing sections of the card list
    public var pages: [PageBlock] {
        
        var pages = [PageBlock]()
        
        /* Get the identifier list from the list */
        let pageReferences = self.list.pageReferences
        
        /* Get info shared among the pages */
        let cardReferenceSize = list.cardReferenceSize
        let hashValueCount = list.hashValueCount
        
        /* Add all the pages */
        for pageReference in pageReferences {
            
            /* Build the page (the page must have some info in order to work) */
            let initializer: (DataRange) -> PageBlock = {
                (data: DataRange) in
                return PageBlock(data: data,
                                 cardCount: pageReference.cardCount,
                                 cardReferenceSize: cardReferenceSize,
                                 hashValueCount: hashValueCount)
            }
            let page = self.loadBlock(identifier: pageReference.identifier, initializer: initializer)
            
            pages.append(page)
        }
        
        return pages
    }
    
    /// The card blocks (CARD), contaning the data about the cards. They are in the order of the cards.
    public var cards: [CardBlock] {
        
        var cards = [CardBlock]()

        /* Loop on the pages, that are the sections of the card list */
        for page in pages {
            
            /* Every page has card references */
            for reference in page.cardReferences {
                
                /* Build the card */
                let initializer = { (data: DataRange) -> CardBlock in
                    return CardBlock(data: data,
                                     marked: reference.marked,
                                     hasTextContent: reference.hasTextContent,
                                     isStartOfBackground: reference.isStartOfBackground,
                                     hasName: reference.hasName,
                                     searchHash: reference.searchHash)
                }
                let card = self.loadBlock(identifier: reference.identifier, initializer: initializer)
                
                cards.append(card)
            }
            
        }
        
        return cards
    }
    
    /// The background blocks (BKGD), they are in the expected order of the backgrounds */
    public var backgrounds: [BackgroundBlock] {
        
        let identifier0 = self.stack.firstBackgroundIdentifier
        
        var backgrounds: [BackgroundBlock] = []
        var identifier = identifier0
        
        /* Load the background blocks in the right order, using the nextBackgroundIdentifier property */
        repeat {
            
            /* Load the background */
            let background = self.loadBlock(identifier: identifier, initializer: BackgroundBlock.init)
            backgrounds.append(background)
            
            /* Move to the next */
            identifier = background.nextBackgroundIdentifier
            
        } while (identifier != identifier0)
        
        return backgrounds
    }
    
    /// The bitmap blocks (BMAP), containing the images of the cards and backgrounds. They are not ordered.
    public var bitmaps: [BitmapBlock] {
        return self.buildElementList(BitmapBlock.init)
    }
    
    /// Cache of the block offsets in the file
    private lazy var masterEntries: [MasterBlock.Entry] = {
        [unowned self] in
        return self.master.entries
        }()
    
    /// List the data blocks of a certain kind in the file, in the order where they appear in the data.
    public func buildElementList<T: HyperCardFileBlock>(_ initializer: (DataRange) -> T) -> [T] {
        
        var elements = [T]()
        
        /* Find a corresponding entry */
        for entry in masterEntries {
            
            /* Ignore invalid entries */
            guard entry.offset > 0 && entry.offset < data.length else {
                continue
            }
            
            /* Check the name */
            let entryNameValue: Int = data.readUInt32(at: entry.offset + 4)
            guard entryNameValue == T.Name.value else {
                continue
            }
            
            /* Build the element */
            let length: Int = data.readUInt32(at: entry.offset)
            let dataRange = DataRange(sharedData: data.sharedData, offset: data.offset + entry.offset, length: length)
            let element = initializer(dataRange)
            
            elements.append(element)
        }
        
        return elements
    }
    
    func loadBlock<T: HyperCardFileBlock>(identifier: Int, initializer: (DataRange) -> T) -> T {
        
        /* Find the data element */
        let offset = findBlockOffset(name: Int(T.Name.value), identifier: identifier)!
        
        /* Build the object */
        let length: Int = data.readUInt32(at: offset)
        let dataRange = DataRange(sharedData: data.sharedData, offset: data.offset + offset, length: length)
        let element = initializer(dataRange)
        return element
        
    }
    
    private func findBlockOffset(name: Int, identifier: Int) -> Int? {
        
        let identifierLastByte = identifier & 0xFF
        
        /* Find a corresponding entry */
        for entry in masterEntries {
            
            /* Ignore invalid entries */
            guard entry.offset > 0 && entry.offset < data.length else {
                continue
            }
            
            /* Check the identifier */
            guard entry.identifierLastByte == identifierLastByte else {
                continue
            }
            
            /* Check the full name */
            let entryName: Int = data.readUInt32(at: entry.offset + 4)
            guard entryName == name else {
                continue
            }
            
            /* Check the full identifier */
            let entryIdentifier: Int = data.readUInt32(at: entry.offset + 8)
            guard entryIdentifier == identifier else {
                continue
            }
            
            return entry.offset
        }
        
        return nil
        
    }
    
}
