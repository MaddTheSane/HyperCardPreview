//
//  StackPreviewer.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 06/03/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//

/// Class intended to be used by objective-c objects. It is just a wrapper of Browser.
public class StackPreviewer: NSObject {
    
    private let browser: Browser
    
    @objc public init(url: URL) throws {
        let file = try HyperCardFile(path: url.path)
        browser = Browser(stack: file.stack)
    }
    
    @objc public func moveToCard(_ index: Int) {
        browser.cardIndex = index
    }
    
    @objc public var cardCount: Int {
        return browser.stack.cards.count
    }
    
    @objc public var width: Int {
        return browser.image.width
    }
    
    @objc public var height: Int {
        return browser.image.height
    }
    
    @objc public var integerCountInRows: Int {
        return browser.image.integerCountInRow
    }
    
    @objc public var imageData: UnsafePointer<UInt32> {
        return UnsafePointer<UInt32>(browser.image.data)
    }

    
}

