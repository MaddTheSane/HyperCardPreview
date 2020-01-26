//
//  Tokenizer.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 10/06/2018.
//  Copyright © 2018 Pierre Lorenzi. All rights reserved.
//


public class TokenSequence: Sequence {
    
    public typealias Element = Token
    public typealias Iterator = TokenIterator
    
    private let string: HString
    
    public init(_ string: HString) {
        self.string = string
    }
    
    public func makeIterator() -> TokenIterator {
        
        return TokenIterator(string: self.string)
    }
    
    public struct TokenIterator: IteratorProtocol {
        
        public typealias Element = Token
        
        private let string: HString
        private var index: Int
        
        private static let twoCharacterOperators: [HString] = ["<>", "<=", ">=", "&&"]
        
        private static let commentPrefix: HString = "--"
        
        public init(string: HString) {
            
            self.string = string
            self.index = 0
        }
        
        public mutating func next() -> Token? {
            
            /* Skip spaces */
            while index < string.length && string[index].isWhiteSpace() {
                index += 1
            }
            
            /* Check if we have reached the end */
            guard index < string.length else {
                return nil
            }
            
            /* Read the next character */
            let nextCharacter = string[index]
            
            /* Check if it is the start of a comment (must be checked before symbol) */
            if nextCharacter == TokenIterator.commentPrefix[0] && index < string.length-1 && string[index+1] == TokenIterator.commentPrefix[1] {
                self.skipToNextLine()
                if self.index == self.string.length && self.string[self.index - 1] != HChar.carriageReturn {
                    return nil
                }
                else {
                    return Token.lineSeparation
                }
            }
                
                /* If it is a symbol, it is a single token */
            else if nextCharacter.isSymbol() {
                let symbol = self.readSymbol()
                return Token.symbol(symbol)
            }
                
                /* If it is a return, it is a single token */
            else if nextCharacter == HChar.carriageReturn {
                self.index += 1
                return Token.lineSeparation
            }
                
                /* If it is a digit, include all the remaining digits */
            else if nextCharacter.isDigit() {
                return self.readNumber()
            }
                
                /* If it is a letter, include the following word */
            else if nextCharacter.isLetter() {
                let word = self.readWord()
                return Token.word(word)
            }
                
                /* If it is a quote, extract the quoted string */
            else if nextCharacter == HChar.quote {
                let quotedString = self.readQuotedString()
                return Token.quotedString(quotedString)
            }
                
                /* If it is ¬, continue to next line */
            else if nextCharacter == HChar.lineContinuation {
                self.index += 1
                self.skipToNextLine()
                return self.next()
            }
                
                /* If it is a normal character, it is considered a one-character word */
            else {
                self.index += 1
                var word: HString = " "
                word[0] = nextCharacter
                return Token.word(word)
            }
            
        }
        
        private mutating func readSymbol() -> HString {
            
            /* Check if the symbol is the start of a symbol with two characters */
            if self.index < self.string.length - 1 {
                let twoCharacterSymbol = self.string[self.index...(self.index + 1)]
                if TokenIterator.twoCharacterOperators.contains(where: { (twoCharacterOperator: HString) -> Bool in
                    return compare(twoCharacterSymbol, twoCharacterOperator) == .orderedSame
                }) {
                    self.index += 2
                    return twoCharacterSymbol
                }
            }
            
            /* The symbol is only one character long */
            var symbol: HString = " "
            symbol[0] = self.string[self.index]
            self.index += 1
            return symbol
            
        }
        
        private mutating func readNumber() -> Token {
            
            /* Read the following digits */
            let integer = self.readInteger()
            
            /* Check if there is a fractional part */
            if index < string.length && string[index] == HChar.point {
                
                index += 1
                let fractional = self.readFractional()
                let number = Double(integer) + fractional
                return Token.realNumber(number)
            }
            
            /* If there is no fractional part, the number is an integer */
            return Token.integer(integer)
        }
        
        private mutating func readInteger() -> Int {
            
            var integer = 0
            
            while index < string.length && string[index].isDigit() {
                
                /* Read the character as a digit */
                let character = string[index]
                let digitValue = character.digitValue()
                
                /* Update number */
                integer *= 10
                integer += digitValue
                
                index += 1
            }
            
            return integer
        }
        
        private mutating func readFractional() -> Double {
            
            let startIndex = self.index
            let integer = self.readInteger()
            
            let digitCount = self.index - startIndex
            let fractional = Double(integer) / pow(10.0, Double(digitCount))
            
            return fractional
        }
        
        private mutating func readQuotedString() -> HString {
            
            /* Read the first quote */
            let firstQuoteIndex = self.index
            self.index += 1
            
            /* Move to the next quote */
            while index < string.length && string[index] != HChar.quote && string[index] != HChar.carriageReturn {
                self.index += 1
            }
            
            /* If we have reached the end of the line without quote, return the entire string
             including the first quote. That's how HyperCard does. */
            if index == string.length || string[index] == HChar.carriageReturn {
                return self.string[firstQuoteIndex..<self.index]
            }
            
            /* Build the string */
            let quotedString = self.string[(firstQuoteIndex + 1) ..< self.index]
            
            /* Move after the final quote */
            self.index += 1
            
            return quotedString
        }
        
        private mutating func skipToNextLine() {
            
            while index < string.length && string[index] != HChar.carriageReturn {
                index += 1
            }
            
            /* Skip the newline character */
            if index < string.length {
                index += 1
            }
        }
        
        private mutating func readWord() -> HString {
            
            let startIndex = self.index
            
            /* Skip alphanumeric characters */
            while index < string.length && string[index].isAlphaNumeric() {
                
                index += 1
            }
            
            /* Build the word */
            let word = self.string[startIndex ..< self.index]
            return word
        }
    }
    
    
    
}
