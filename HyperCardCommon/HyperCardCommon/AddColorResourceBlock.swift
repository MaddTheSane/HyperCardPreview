//
//  AddColorResourceBlock.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 26/08/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//


public struct AddColor {
    public var red: Double
    public var green: Double
    public var blue: Double
}

/// The elements are displayed in the order of the resource, not the order of the HyperCard object
public enum AddColorElement {
    
    case button(AddColorButton)
    case field(AddColorField)
    case rectangle(AddColorRectangle)
    case pictureResource(AddColorPictureResource)
    case pictureFile(AddColorPictureFile)
}

public struct AddColorButton {
    
    public var buttonIdentifier: Int
    public var bevel: Int
    public var color: AddColor
    public var enabled: Bool
}

public struct AddColorField {
    
    public var fieldIdentifier: Int
    public var bevel: Int
    public var color: AddColor
    public var enabled: Bool
}

public struct AddColorRectangle {
    
    public var rectangle: Rectangle
    public var bevel: Int
    public var color: AddColor
    public var enabled: Bool
}

public struct AddColorPictureResource {
    
    public var rectangle: Rectangle
    
    /// Transparent means that the white pixels of the image are drawn transparent
    public var transparent: Bool
    public var resourceName: HString
    public var enabled: Bool
}

public struct AddColorPictureFile {
    
    public var rectangle: Rectangle
    
    /// Transparent means that the white pixels of the image are drawn transparent
    public var transparent: Bool
    
    /// The file name is just the name of the file, not the path. The file is supposed to be in the same folder
    ///  as the HyperCard application, the Home stack or the current stack
    public var fileName: HString
    public var enabled: Bool
}



public class AddColorResourceBlock: ResourceBlock {
    
    public var elements: [AddColorElement] {
        
        var offset = 0
        var elements: [AddColorElement] = []
        
        while offset < data.length {
            
            let element = self.readElement(at: &offset)
            elements.append(element)
        }
        
        return elements
    }
    
    private func readElement(at offset: inout Int) -> AddColorElement {
        
        let typeAndFlags: Int = data.readUInt8(at: offset)
        let type = typeAndFlags & 0x7F
        let enabled = ((typeAndFlags >> 7) & 1) == 0
        
        switch type {
        
        case 1: // button
            let identifier: Int = data.readUInt16(at: offset + 0x1)
            let bevel: Int = data.readUInt16(at: offset + 0x3)
            let color = self.readColor(at: offset + 0x5)
            offset += 11
            let element = AddColorButton(buttonIdentifier: identifier, bevel: bevel, color: color, enabled: enabled)
            return AddColorElement.button(element)
            
        case 2: // field
            let identifier: Int = data.readUInt16(at: offset + 0x1)
            let bevel: Int = data.readUInt16(at: offset + 0x3)
            let color = self.readColor(at: offset + 0x5)
            offset += 11
            let element = AddColorField(fieldIdentifier: identifier, bevel: bevel, color: color, enabled: enabled)
            return AddColorElement.field(element)
            
        case 3: // rectangle
            let rectangle = data.readRectangle(at: offset + 0x1)
            let bevel: Int = data.readUInt16(at: offset + 0x9)
            let color = self.readColor(at: offset + 0xB)
            offset += 17
            let element = AddColorRectangle(rectangle: rectangle, bevel: bevel, color: color, enabled: enabled)
            return AddColorElement.rectangle(element)
            
        case 4: // picture resource
            let rectangle = data.readRectangle(at: offset + 0x1)
            let transparentValue: Int = data.readUInt8(at: offset + 0x9)
            let nameLength: Int = data.readUInt8(at: offset + 0xA)
            let name = data.readString(at: offset + 0xB, length: nameLength)
            offset += 11 + name.length
            
            let transparent = (transparentValue != 0)
            let element = AddColorPictureResource(rectangle: rectangle, transparent: transparent, resourceName: name, enabled: enabled)
            return AddColorElement.pictureResource(element)
            
        case 5:  // picture file
            let rectangle = data.readRectangle(at: offset + 0x1)
            let transparentValue: Int = data.readUInt8(at: offset + 0x9)
            let nameLength: Int = data.readUInt8(at: offset + 0xA)
            let name = data.readString(at: offset + 0xB, length: nameLength)
            offset += 11 + name.length
            
            let transparent = (transparentValue != 0)
            let element = AddColorPictureFile(rectangle: rectangle, transparent: transparent, fileName: name, enabled: enabled)
            return AddColorElement.pictureFile(element)
            
        default:
            fatalError()
        }
        
    }
    
    private func readColor(at offset: Int) -> AddColor {
        
        /* Read the values */
        let red16Bits: UInt16 = data.readUInt16(at: offset)
        let green16Bits: UInt16 = data.readUInt16(at: offset + 2)
        let blue16Bits: UInt16 = data.readUInt16(at: offset + 4)
        
        /* Convert to double */
        let factor = Double(UInt16.max)
        let red = Double(red16Bits) / factor
        let green = Double(green16Bits) / factor
        let blue = Double(blue16Bits) / factor
        
        return AddColor(red: red, green: green, blue: blue)
    }
    
}

public class AddColorResourceBlockCard: AddColorResourceBlock {
    
    public override class var Name: NumericName {
        return NumericName(string: "HCcd")!
    }
    
}

public class AddColorResourceBlockBackground: AddColorResourceBlock {
    
    public override class var Name: NumericName {
        return NumericName(string: "HCbg")!
    }
    
}

