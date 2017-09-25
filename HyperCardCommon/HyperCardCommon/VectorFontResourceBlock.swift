//
//  VectorFont.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 18/02/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//

import Foundation


/// Parsed vector font resource
public class VectorFontResourceBlock: ResourceBlock {
    
    public override class var Name: NumericName {
        return NumericName(string: "sfnt")!
    }
    
    /// The resource contains a vector font file, that can be read with Core Graphics
    public var cgfont: CGFont {
        
        /* Copy the data */
        let slice = data.sharedData[data.offset..<data.offset + data.length]
        
        /* Build a data provider */
        let dataProvider = CGDataProvider(data: slice as NSData)!
        
        return CGFont(dataProvider)!
    }
    
}
