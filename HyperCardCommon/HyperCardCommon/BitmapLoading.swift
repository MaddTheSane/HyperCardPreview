//
//  BitmapLoading.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 25/08/2019.
//  Copyright © 2019 Pierre Lorenzi. All rights reserved.
//


public extension MaskedImage {
    
    /// Reads inside a bitmap (BMAP) data block, which contains the picture of a card
    /// or of a background.
    /// <p>
    /// It is a proprietary image format designed by Bill Atkinson, and retro-engineered
    /// with great pain by Rebecca Bettencourt, who called it Wrath of Bill Atkinson, or
    /// WOBA, for its tortuous complexity
    /// <p>
    /// It has two layers with one bit per pixel: an image, to tell where the black pixels are,
    /// and a mask, to tell where the white pixels are. This is not the classical notion of mask:
    /// the mask is not about transparency, it just tells where the blank pixels are. If a pixel
    /// is activated in the image and not in the mask, it is black. It it is activated only in the
    /// mask, it is blank. If it is activated in both, it is black. The pixels neither activated
    /// in the image and in the mask are transparent.
    /// <p>
    /// The mask and the image both have rectangles where they are enclosed, relative to the card
    /// coordinates. Outside the rectangles, the pixels are transparent. The mask and image
    /// rectangles are not necessarily in the same place.
    init(hyperCardBitmap data: DataRange, fileVersion: FileVersion) {
        
        /* Get the rectangles */
        let versionOffset = fileVersion.isTwo() ? 0 : -4
        let cardRectangle = data.readRectangle(at: 0x18 + versionOffset)
        let maskRectangle = data.readRectangle(at: 0x20 + versionOffset)
        let imageRectangle = data.readRectangle(at: 0x28 + versionOffset)
        let maskLength: Int = data.readUInt32(at: 0x38 + versionOffset)
        let imageLength: Int = data.readUInt32(at: 0x3C + versionOffset)
        let dataOffset = 0x40 + versionOffset
        
        /* Check if there is data */
        guard data.length > dataOffset else {
            
            self.init(width: cardRectangle.width, height: cardRectangle.height, image: .rectangular(rectangle: imageRectangle), mask: .rectangular(rectangle: maskRectangle))
            return
        }
        
        /* The data rectangle is 32-bit aligned */
        let maskRectangle32 = MaskedImage.aligned32Bits(maskRectangle)
        let imageRectangle32 = MaskedImage.aligned32Bits(imageRectangle)
        
        /* Decode mask */
        var mask: Image? = nil
        if maskLength > 0 {
            mask = Image(width: maskRectangle32.width, height: maskRectangle32.height)
            MaskedImage.decodeLayer(data, dataOffset: dataOffset, dataLength: maskLength, pixels: &mask!.data, rectangle: maskRectangle32)
        }
        
        /* Decode image */
        var image: Image? = nil
        if imageLength > 0 {
            image = Image(width: imageRectangle32.width, height: imageRectangle32.height)
            MaskedImage.decodeLayer(data, dataOffset: dataOffset + maskLength, dataLength: imageLength, pixels: &image!.data, rectangle: imageRectangle32)
        }
        
        /* Create the masked image */
        let maskLayer = MaskedImage.buildImageLayer(mask, rectangle: maskRectangle, rectangle32: maskRectangle32)
        let imageLayer = MaskedImage.buildImageLayer(image, rectangle: imageRectangle, rectangle32: imageRectangle32)
        self.init(width: cardRectangle.width, height: cardRectangle.height, image: imageLayer, mask: maskLayer)
        
    }
    
    private static let ZeroRectangle = Rectangle(top: 0, left: 0, bottom: 0, right: 0)
    private static let version1Offset = -4
    private static let blackPixelInteger: UInt = 0xFFFF_FFFF_FFFF_FFFF
    private static let blackPixel = Image.Integer(truncatingIfNeeded: blackPixelInteger)
    
    private static func buildImageLayer(_ data: Image?, rectangle _rectangle: Rectangle, rectangle32: Rectangle) -> MaskedImage.Layer {
        
        /* The rectangle is nil if it is zero */
        let rectangle: Rectangle? = (_rectangle == MaskedImage.ZeroRectangle) ? nil : _rectangle
        
        /* If we have a bitmap, it is a bitmap */
        if let data = data, let rectangle = rectangle {
            let realRectangleInImage = Rectangle(x: rectangle.x - rectangle32.x, y: rectangle.y - rectangle32.y, width: rectangle.width, height: rectangle.height)
            return .bitmap(image: data, imageRectangle: rectangle32, realRectangleInImage: realRectangleInImage)
        }
        
        /* If we have only a rectangle, it is a rectangle */
        if let rectangle = rectangle {
            return .rectangular(rectangle: rectangle)
        }
        
        return .clear
        
    }
    
    private static func aligned32Bits(_ rectangle: Rectangle) -> Rectangle {
        return Rectangle(top: rectangle.top, left: downToMultiple(rectangle.left, 32), bottom: rectangle.bottom, right: upToMultiple(rectangle.right, 32))
    }
    
    private static func decodeLayer(_ data: DataRange, dataOffset: Int, dataLength: Int, pixels: inout [Image.Integer], rectangle: Rectangle) {
        
        var pixelIndex = 0
        let integerLengthImage = upToMultiple(rectangle.width, Image.Integer.bitWidth) / Image.Integer.bitWidth
        let integerLength32 = rectangle.width / 32
        let rowWidth32 = integerLength32 * 32
        
        var offset = dataOffset
        var dx = 0
        var dy = 0
        
        var repeatedBytes = [0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55, 0xAA, 0x55]
        
        var y = rectangle.top
        
        rowLoop: while y < rectangle.bottom {
            
            var x = 0
            var repeatCount = 1
            
            /* Read the opcodes */
            while x < rowWidth32 {
                
                /* Read the opcode */
                let opcode: Int = data.readUInt8(at: offset)
                offset += 1
                
                /* Execute opcode */
                switch opcode {
                    
                case 0x00...0x7F:
                    /* z zero bytes followed by d data bytes */
                    let zeroLength = opcode & 0xF
                    let dataLength = opcode >> 4
                    let totalLength = zeroLength + dataLength
                    for i in 0..<dataLength {
                        let value: Int = data.readUInt8(at: offset)
                        offset += 1
                        for r in 0..<repeatCount {
                            writeByteInRow(value, row: &pixels, rowPixelIndex: pixelIndex, x: x + (zeroLength + i + r * totalLength) * 8)
                        }
                    }
                    x += totalLength * repeatCount * 8
                    repeatCount = 1
                    
                case 0x80:
                    /* One row of uncompressed data */
                    for i in 0..<integerLength32 {
                        let value: Int = data.readUInt32(at: offset + i*4)
                        for r in 0..<repeatCount {
                            writeInt32InRow(value, row: &pixels, rowPixelIndex: pixelIndex + r * integerLengthImage, x: i * 32)
                        }
                    }
                    offset += integerLength32 * 4
                    pixelIndex += repeatCount * integerLengthImage
                    y += repeatCount
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x81:
                    /* One white row */
                    pixelIndex += repeatCount * integerLengthImage
                    y += repeatCount
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x82:
                    /* One black row */
                    for _ in 0..<repeatCount {
                        for i in 0..<integerLengthImage {
                            pixels[i + pixelIndex] = MaskedImage.blackPixel
                        }
                        pixelIndex += integerLengthImage
                        y += 1
                    }
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x83:
                    /* One row of a repeated byte of data */
                    let v: Int = data.readUInt8(at: offset)
                    offset += 1
                    var integer: Image.Integer = 0
                    for _ in stride(from: 0, to: Image.Integer.bitWidth, by: 8) {
                        integer <<= 8
                        integer |= Image.Integer(v)
                    }
                    repeatedBytes[y % 8] = v
                    for _ in 0..<repeatCount {
                        for i in 0..<integerLengthImage {
                            pixels[i + pixelIndex] = integer
                        }
                        pixelIndex += integerLengthImage
                        y += 1
                    }
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x84:
                    /* One row of a repeated byte of data previously used */
                    for _ in 0..<repeatCount {
                        let v = repeatedBytes[y % 8]
                        var integer: Image.Integer = 0
                        for _ in stride(from: 0, to: Image.Integer.bitWidth, by: 8) {
                            integer <<= 8
                            integer |= Image.Integer(v)
                        }
                        for i in 0..<integerLengthImage {
                            pixels[i + pixelIndex] = integer
                        }
                        pixelIndex += integerLengthImage
                        y += 1
                    }
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x85:
                    /* Copy the previous row */
                    for _ in 0..<repeatCount {
                        for i in 0..<integerLengthImage {
                            pixels[i + pixelIndex] = pixels[i + pixelIndex - integerLengthImage]
                        }
                        pixelIndex += integerLengthImage
                        y += 1
                    }
                    repeatCount = 1
                    continue rowLoop
                    
                case 0x86:
                    /* Copy the row before the previous row */
                    for _ in 0..<repeatCount {
                        for i in 0..<integerLengthImage {
                            pixels[i + pixelIndex] = pixels[i + pixelIndex - 2 * integerLengthImage]
                        }
                        pixelIndex += integerLengthImage
                        y += 1
                    }
                    repeatCount = 1
                    continue rowLoop
                    
                    /* dx, dy */
                case 0x88:
                    dx = 16
                    dy = 0
                case 0x89:
                    dx = 0
                    dy = 0
                case 0x8A:
                    dx = 0
                    dy = 1
                case 0x8B:
                    dx = 0
                    dy = 2
                case 0x8C:
                    dx = 1
                    dy = 0
                case 0x8D:
                    dx = 1
                    dy = 1
                case 0x8E:
                    dx = 2
                    dy = 2
                case 0x8F:
                    dx = 8
                    dy = 0
                    
                case 0xA0...0xBF:
                    /* Repeat */
                    repeatCount = opcode & 0b11111
                    
                case 0xC0...0xDF:
                    /* Bytes of data */
                    let dataLength = (opcode & 0b11111) * 8
                    for i in 0..<dataLength {
                        let value: Int = data.readUInt8(at: offset)
                        offset += 1
                        for j in 0..<repeatCount {
                            writeByteInRow(value, row: &pixels, rowPixelIndex: pixelIndex, x: x + (i + j * dataLength) * 8)
                        }
                    }
                    x += dataLength * repeatCount * 8
                    repeatCount = 1
                    
                case 0xE0...0xFF:
                    /* Zeros */
                    let zeroCount = (opcode & 0b11111) * 128
                    x += zeroCount * repeatCount
                    repeatCount = 1
                    
                default:
                    /* If the instruction is unknown, that means the data is over */
                    break rowLoop
                    
                }
            }
            
            /* If we get here, we must apply the transformations to the row */
            if dx != 0 {
                applyDx(dx, row: &pixels, rowPixelIndex: pixelIndex, integerLength: integerLengthImage)
            }
            if dy != 0 && dy <= y - rectangle.top {
                for i in 0..<integerLengthImage {
                    pixels[i + pixelIndex] ^= pixels[i + pixelIndex - dy * integerLengthImage]
                }
            }
            pixelIndex += integerLengthImage
            y += 1
            
        }
        
    }
    
    private static func applyDx(_ dx: Int, row: inout [Image.Integer], rowPixelIndex: Int, integerLength: Int) {
        
        /* dx can only be 1, 2, 4, 8, 16, 32 */
        
        var previousResult: Image.Integer = 0
        var previousXorLeft: Image.Integer = 0
        
        for i in 0..<integerLength {
            
            let value = row[i + rowPixelIndex]
            
            var xorLeft: Image.Integer = value
            var xorRight: Image.Integer = 0
            
            /* Apply dx on that window */
            for i in 0..<(Image.Integer.bitWidth / dx) {
                xorLeft ^= (value << Image.Integer(dx * i))
                xorRight ^= (value >> Image.Integer(dx * i))
            }
            
            let result = previousResult ^ previousXorLeft ^ xorRight
            row[i + rowPixelIndex] = result
            
            /* Update the state */
            previousResult = result
            previousXorLeft = xorLeft
            
        }
    }
    
    private static func writeByteInRow(_ byte: Int, row: inout [Image.Integer], rowPixelIndex: Int, x: Int) {
        
        row[rowPixelIndex + x / Image.Integer.bitWidth] |= (Image.Integer(byte) << (Image.Integer.bitWidth - 8 - x % Image.Integer.bitWidth))
    }
    
    private static func writeInt32InRow(_ int32: Int, row: inout [Image.Integer], rowPixelIndex: Int, x: Int) {
        
        row[rowPixelIndex + x / Image.Integer.bitWidth] |= (Image.Integer(int32) << (Image.Integer.bitWidth - 32 - x % Image.Integer.bitWidth))
    }
    
    private func writeInt32InRow(_ int32: UInt32, row: inout [Image.Integer], rowPixelIndex: Int, x: Int) {
        
        row[rowPixelIndex + x / Image.Integer.bitWidth] |= (Image.Integer(int32) << (Image.Integer.bitWidth - 32 - x % Image.Integer.bitWidth))
    }
}
