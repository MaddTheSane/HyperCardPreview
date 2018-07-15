//
//  FontDecorator.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 18/02/2016.
//  Copyright © 2016 Pierre Lorenzi. All rights reserved.
//


/* Differences from original: underline extends too much around the characters, start offset of text can shift one pixel */


public extension BitmapFont {
    
    /// Applies a font variation to a bitmap font
    public convenience init(decorate baseFont: BitmapFont, with style: TextStyle, in possibleFamily: FontFamily?, size: Int) {
        
        /* Copy the font */
        self.init()
        self.maximumWidth = baseFont.maximumWidth
        self.maximumKerning = baseFont.maximumKerning
        self.fontRectangleWidth = baseFont.fontRectangleWidth
        self.fontRectangleHeight = baseFont.fontRectangleHeight
        self.maximumAscent = baseFont.maximumAscent
        self.maximumDescent = baseFont.maximumDescent
        self.leading = baseFont.leading
        
        /* Decorate the glyphs */
        self.glyphs = baseFont.glyphs.map({ Glyph(baseGlyph: $0, style: style, properties: possibleFamily?.styleProperties, size: size, maximumDescent: self.maximumDescent) })
        
        /* Adjust the metrics */
        self.adjustMeasures(for: style, properties: possibleFamily?.styleProperties, size: size)
        
    }
    
    private func adjustMeasures(for style: TextStyle, properties: FontStyleProperties?, size: Int) {
        
        if style.bold {
            self.maximumWidth += computeExtraWidth(byDefault: 1, property: properties?.boldExtraWidth, size: size)
            self.fontRectangleWidth += 1
        }
        
        if style.italic {
            self.maximumWidth += computeExtraWidth(byDefault: 0, property: properties?.italicExtraWidth, size: size)
            self.maximumKerning -= self.maximumDescent/2
            self.fontRectangleWidth += self.fontRectangleHeight/2
        }
        
        if style.underline {
            self.maximumWidth += computeExtraWidth(byDefault: 0, property: properties?.underlineExtraWidth, size: size)
            self.fontRectangleWidth += 2
            if self.maximumDescent < 2 {
                self.fontRectangleHeight += 2 - self.maximumDescent
                self.maximumDescent = 2
            }
        }
        
        if style.outline || style.shadow {
            self.maximumWidth += computeExtraWidth(byDefault: 1, property: properties?.outlineExtraWidth, size: size)
            self.maximumKerning -= 1
            self.fontRectangleWidth += 2
            self.fontRectangleHeight += 2
            self.maximumAscent += 1
            self.maximumDescent += 1
        }
        
        if style.shadow {
            let value = (style.outline ? 2 : 1)
            self.maximumWidth += value * computeExtraWidth(byDefault: 1, property: properties?.shadowExtraWidth, size: size)
            self.fontRectangleWidth += value
            self.maximumDescent += value
            self.fontRectangleHeight += value
        }
        
        if style.condense {
            self.maximumWidth += computeExtraWidth(byDefault: -1, property: properties?.condensedExtraWidth, size: size)
        }
        
        if style.extend {
            self.maximumWidth += computeExtraWidth(byDefault: 1, property: properties?.extendedExtraWidth, size: size)
        }
        
    }
    
}


private func computeExtraWidth(byDefault: Int, property: Double?, size: Int) -> Int {
    
    if let property = property {
        let value = property * Double(size)
        
        /* Ths rounding rule was not the same, it caused a glitch in a stack */
        if value - floor(value) == 0.5 {
            return Int(value)
        }
        return Int(round(value))
    }
    
    return byDefault
}


/// A glyph that lazily applies a font variation to a base glyph
private extension Glyph {
    
    convenience init(baseGlyph: Glyph, style: TextStyle, properties: FontStyleProperties?, size: Int, maximumDescent: Int) {
        
        self.init()
        
        /* Copy the measures of the base glyph */
        self.width = baseGlyph.width
        self.imageOffset = baseGlyph.imageOffset
        self.imageTop = baseGlyph.imageTop
        self.imageWidth = baseGlyph.imageWidth
        self.imageHeight = baseGlyph.imageHeight
        self.isThereImage = baseGlyph.isThereImage
        
        /* Change the measures for the style */
        self.readjustMeasures(baseGlyph: baseGlyph, style: style, properties: properties, size: size)
        
        self.imageProperty.lazyCompute { () -> MaskedImage? in
            return self.buildImage(baseGlyph: baseGlyph, style: style, maximumDescent: maximumDescent)
        }
    }
    
    private func readjustMeasures(baseGlyph: Glyph, style: TextStyle, properties: FontStyleProperties?, size: Int) {
        
        /* Underline: if there is no image, make an image of the line under */
        if style.underline && !baseGlyph.isThereImage {
            self.imageOffset = 0
            self.imageTop = -1
            self.imageWidth = baseGlyph.width
            self.imageHeight = 1
        }
        
        /* Bold (inferred by Outline and Shadow): add black pixel next to every black pixel */
        if style.bold {
            self.width += computeExtraWidth(byDefault: 1, property: properties?.boldExtraWidth, size: size)
            self.imageWidth += 1
        }
        
        /* Italic: slant with slope 2, and the glyph origin must be the same */
        if style.italic {
            self.width += computeExtraWidth(byDefault: 0, property: properties?.italicExtraWidth, size: size)
            self.imageWidth += self.imageHeight / 2
            self.imageOffset -= (self.imageHeight - self.imageTop) / 2
        }
        
        /* Underline: check that there is enough room for the line */
        if style.underline {
            
            /* Add pixels under if necessary */
            let descent = self.imageHeight - self.imageTop
            if descent < 2 {
                self.imageHeight += 2 - descent
            }
        }
        
        /* Outline: every black pixel becomes white and surrounded by four black pixels */
        if style.outline || style.shadow {
            self.imageOffset -= 1
            self.imageTop += 1
            self.width += computeExtraWidth(byDefault: 1, property: properties?.outlineExtraWidth, size: size)
            self.imageWidth += 2
            self.imageHeight += 2
        }
        
        if style.shadow {
            let value = style.outline ? 2 : 1
            self.width += value * computeExtraWidth(byDefault: 1, property: properties?.shadowExtraWidth, size: size)
            self.imageWidth += value
            self.imageHeight += value
        }
        
        if style.condense {
            self.width += computeExtraWidth(byDefault: -1, property: properties?.condensedExtraWidth, size: size)
        }
        
        if style.extend {
            self.width += computeExtraWidth(byDefault: 1, property: properties?.extendedExtraWidth, size: size)
        }
        
        /* Underline: add pixels on both sides, the line extends from 0 to width */
        if style.underline {
            if self.imageOffset > 0 {
                self.imageWidth += self.imageOffset
                self.imageOffset = 0
            }
            if self.imageOffset + self.imageWidth < self.width {
                self.imageWidth = self.width - self.imageOffset
            }
        }
        
    }
    
    private func buildImage(baseGlyph: Glyph, style: TextStyle, maximumDescent: Int) -> MaskedImage? {
        
        /* Check if there is an image in the base glyph */
        guard self.imageWidth > 0 && self.imageHeight > 0 else {
            return nil
        }
        
        /* Build the image */
        let drawing = Drawing(width: self.imageWidth, height: self.imageHeight)
        
        /* Draw the glyph on it */
        if let baseMaskedImage = baseGlyph.image {
            if case MaskedImage.Layer.bitmap(image: let baseImage, imageRectangle: _, realRectangleInImage: _) = baseMaskedImage.image {
                
                drawing.drawImage(baseImage, position: Point(x: baseGlyph.imageOffset - self.imageOffset, y: self.imageTop - baseGlyph.imageTop))
            }
        }
        
        var mask: MaskedImage.Layer = .clear
        
        /* Bold: add a black pixel on the right of every black pixel */
        if style.bold {
            
            /* Loop on the rows */
            for y in 0..<drawing.height {
                
                /* Get the row */
                drawing.fillRowWithImage(drawing.image, position: Point(x: 0, y: y), length: drawing.width)
                
                /* Shift it right */
                drawing.shiftRowRight(1)
                
                /* Draw it on the image */
                drawing.applyRow(Point(x: 0, y: y), length: drawing.width)
                
            }
            
        }
        
        /* Italic: slant with slope 2 from baseline */
        if style.italic {
            
            /* Loop on the rows */
            for y in 0..<drawing.height {
                
                /* Get the row */
                drawing.fillRowWithImage(drawing.image, position: Point(x: 0, y: y), length: drawing.width)
                
                /* Shift it right */
                drawing.shiftRowRight( (imageTop - y + maximumDescent - 1) / 2 - maximumDescent / 2)
                
                /* Draw it on the image */
                drawing.applyRow(Point(x: 0, y: y), length: drawing.width, composition: {(a: inout Image.Integer, b: Image.Integer, integerIndex: Int, y: Int) in a = b})
                
            }
            
        }
        
        /* Underline: draw a line under every character */
        if style.underline {
            
            var lastDrawnX = -1
            let y = self.imageTop + 1
            
            for x in (-self.imageOffset)..<(-self.imageOffset + self.width) {
                
                /* The underline must stop if there is a black pixel nearby */
                if drawing[x, y] {
                    continue
                }
                if lastDrawnX != x-1 && x > 0 && drawing[x-1, y] {
                    continue
                }
                if x > 0 && y > 0 && drawing[x-1,y-1] {
                    continue
                }
                if y > 0 && drawing[x,y-1] {
                    continue
                }
                if y > 0 && x < drawing.width-1 && drawing[x+1, y-1] {
                    continue
                }
                if x < drawing.width-1 && drawing[x+1, y] {
                    continue
                }
                if x < drawing.width && y < drawing.height-1 && drawing[x+1, y+1] {
                    continue
                }
                if y < drawing.height-1 && drawing[x, y+1] {
                    continue
                }
                if y < drawing.height-1 && x > 0 && drawing[x-1, y+1] {
                    continue
                }
                
                lastDrawnX = x
                drawing[x, y] = true
            }
            
        }
        
        /* Outline & Shadow */
        if style.shadow || style.outline {
            let initialBitmap = drawing.image
            
            /* Outline */
            drawing.drawImage(initialBitmap, position: Point(x: -1, y: 0))
            drawing.drawImage(initialBitmap, position: Point(x: -1, y: -1))
            drawing.drawImage(initialBitmap, position: Point(x: 0, y: -1))
            drawing.drawImage(initialBitmap, position: Point(x: 1, y: -1))
            drawing.drawImage(initialBitmap, position: Point(x: 1, y: 0))
            drawing.drawImage(initialBitmap, position: Point(x: 1, y: 1))
            drawing.drawImage(initialBitmap, position: Point(x: 0, y: 1))
            drawing.drawImage(initialBitmap, position: Point(x: -1, y: 1))
            
            /* Keep a clean underline */
            var row: [Image.Integer] = []
            if style.underline {
                
                /* Remove the pixels around the underline that the outline has put */
                if style.underline {
                    let lineY = self.imageTop + 1
                    let leftPixelX = -self.imageOffset - 1
                    let rightPixelX = -self.imageOffset + self.width
                    if leftPixelX >= 0 && !initialBitmap[leftPixelX, lineY] {
                        drawing[leftPixelX, lineY] = false
                    }
                    if rightPixelX < drawing.width && !initialBitmap[rightPixelX, lineY] {
                        drawing[rightPixelX, lineY] = false
                    }
                }
                
                /* Save the state of the underline before applying the shadow */
                let newRow = drawing.image.data[drawing.image.integerCountInRow * (imageTop + 1) ..< drawing.image.integerCountInRow * (imageTop + 2)]
                row = [Image.Integer](newRow)
            }
            
            /* Shadow */
            if style.shadow {
                drawing.drawImage(initialBitmap, position: Point(x: 2, y: -1))
                drawing.drawImage(initialBitmap, position: Point(x: 2, y: 0))
                drawing.drawImage(initialBitmap, position: Point(x: 2, y: 1))
                drawing.drawImage(initialBitmap, position: Point(x: 2, y: 2))
                drawing.drawImage(initialBitmap, position: Point(x: 1, y: 2))
                drawing.drawImage(initialBitmap, position: Point(x: 0, y: 2))
                drawing.drawImage(initialBitmap, position: Point(x: -1, y: 2))
                
                /* If outline and shadow are both set, a second shadow is draw */
                if style.outline {
                    drawing.drawImage(initialBitmap, position: Point(x: 3, y: -1))
                    drawing.drawImage(initialBitmap, position: Point(x: 3, y: 0))
                    drawing.drawImage(initialBitmap, position: Point(x: 3, y: 1))
                    drawing.drawImage(initialBitmap, position: Point(x: 3, y: 2))
                    drawing.drawImage(initialBitmap, position: Point(x: 3, y: 3))
                    drawing.drawImage(initialBitmap, position: Point(x: 2, y: 3))
                    drawing.drawImage(initialBitmap, position: Point(x: 1, y: 3))
                    drawing.drawImage(initialBitmap, position: Point(x: 0, y: 3))
                    drawing.drawImage(initialBitmap, position: Point(x: -1, y: 3))
                }
            }
            
            /* Remove the shadow from the underline */
            if style.underline {
                let firstIntegerIndex = drawing.image.integerCountInRow * (imageTop + 1)
                
                for i in 0..<row.count {
                    drawing.image.data[firstIntegerIndex + i] = row[i]
                }
            }
            
            /* Make the original pixels white */
            drawing.drawImage(initialBitmap, position: Point(x: 0, y: 0), composition: Drawing.MaskComposition)
            let rectangle = Rectangle(top: 0, left: 0, bottom: drawing.height, right: drawing.width)
            mask = MaskedImage.Layer.bitmap(image: initialBitmap, imageRectangle: rectangle, realRectangleInImage: rectangle)
            
        }
        
        let rectangle = Rectangle(top: 0, left: 0, bottom: drawing.height, right: drawing.width)
        let maskedImageImage = MaskedImage.Layer.bitmap(image: drawing.image, imageRectangle: rectangle, realRectangleInImage: rectangle)
        return MaskedImage(width: drawing.width, height: drawing.height, image: maskedImageImage, mask: mask)
    }
    
    private func createUnderlineImage() -> MaskedImage {
        
        var image = Image(width: self.width, height: 1)
        
        /* Make the image black */
        for i in 0..<image.integerCountInRow {
            image.data[i] = Image.Integer.max
        }
        
        /* Create the masked image */
        let rectangle = Rectangle(top: 0, left: 0, bottom: image.height, right: image.width)
        return MaskedImage(width: image.width, height: image.height, image: .bitmap(image: image, imageRectangle: rectangle, realRectangleInImage: rectangle), mask: .clear)
    }
    
}
