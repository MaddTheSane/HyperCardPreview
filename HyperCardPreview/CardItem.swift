//
//  CardItem.swift
//  HyperCardPreview
//
//  Created by Pierre Lorenzi on 30/08/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//

import Cocoa

class CardItem: NSCollectionViewItem {
    
    override var isSelected: Bool {
        didSet {
            (self.view as! CardItemView).displaySelected(super.isSelected)
        }
    }
    
}
