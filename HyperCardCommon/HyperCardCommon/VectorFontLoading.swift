//
//  VectorFontLoading.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 06/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


extension VectorFont: ResourceContent {
    
    /// Loads a vector font from the data of a sfnt resource
    public init(loadFromData dataRange: DataRange) {
        
        /* Copy the data */
        let slice = dataRange.sharedData[dataRange.offset..<dataRange.offset + dataRange.length]
        let nsdata = slice as NSData
        
        /* Build a data provider */
        let dataProvider = CGDataProvider(data: nsdata)
        
        let cgfont = CGFont(dataProvider!)!
        self.init(cgfont: cgfont)
    }
    
}
