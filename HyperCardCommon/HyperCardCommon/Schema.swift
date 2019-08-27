//
//  Matching.swift
//  HyperCardCommon
//
//  Created by Pierre Lorenzi on 26/08/2019.
//  Copyright © 2019 Pierre Lorenzi. All rights reserved.
//


public final class Schema<T> {
    
    public var branches: [Branch] = []
    public var initialValue: T? = nil
    public var initFields: (() -> ())? = nil
    
    public init() {}
    
    public struct Branch {
        public var subSchemas: [SubSchema]
        
        public init(subSchemas: [SubSchema]) {
            self.subSchemas = subSchemas
        }
    }
    
    public enum MatchingStatus {
        
        case canContinue
        case mustStop
    }
    
    public class SubMatcher {
        
        var isMatching: Bool {
            fatalError()
        }
        
        var currentUpdate: ((inout T) -> ())? {
            fatalError()
        }
        
        func matchNextCharacter(_ character: HChar) -> MatchingStatus {
            fatalError()
        }
    }
    
    public class SubSchema {
        
        public var minCount: Int
        public var maxCount: Int?
        
        public init(minCount: Int, maxCount: Int?) {
            self.minCount = minCount
            self.maxCount = maxCount
        }
        
        func buildSubMatcher() -> SubMatcher {
            fatalError() // abstract
        }
        
        func matchesEmpty() -> Bool {
            fatalError()
        }
        
        func matchesNotEmpty() -> Bool {
            fatalError()
        }
    }
    
    public class TypedSubSchema<U>: SubSchema {
        
        public var schema: Schema<U>
        public var update: (inout T,U) -> ()
        
        public init(schema: Schema<U>, minCount: Int, maxCount: Int?, update: @escaping (inout T,U) -> ()) {
            
            self.schema = schema
            self.update = update
            
            super.init(minCount: minCount, maxCount: maxCount)
        }
        
        override func buildSubMatcher() -> SubMatcher {
            
            return TypedSubMatcher(schema: self.schema, update: self.update)
        }
        
        override func matchesEmpty() -> Bool {
            
            /* It matches empty if one of the branch matches empty */
            for branch in self.schema.branches {
                
                let matchesEmpty = branch.subSchemas.allSatisfy({ $0.minCount == 0 || $0.matchesEmpty() })
                if matchesEmpty {
                    return true
                }
            }
            
            return false
        }
        
        override func matchesNotEmpty() -> Bool {
            
            /* It matches not empty if one of the branch matches not empty */
            for branch in self.schema.branches {
                
                let matchesNotEmpty = branch.subSchemas.first(where: { $0.minCount > 0 && !$0.matchesEmpty() }) != nil
                if matchesNotEmpty {
                    return true
                }
            }
            
            return false
        }
        
        private class TypedSubMatcher: SubMatcher {
            
            private let matcher: Schema<U>.Matcher
            private let update: (inout T,U) -> ()
            
            init(schema: Schema<U>, update: @escaping (inout T,U) -> ()) {
                
                self.matcher = schema.buildMatcher()
                self.update = update
            }
            
            override var isMatching: Bool {
                return matcher.isMatching
            }
            
            override var currentUpdate: ((inout T) -> ())? {
                
                guard let currentValue = self.matcher.currentValue else {
                    return nil
                }
                
                let update = self.update
                
                return { (parentValue: inout T) in
                    update(&parentValue, currentValue)
                }
            }
            
            override func matchNextCharacter(_ character: HChar) -> MatchingStatus {
                
                let status = self.matcher.matchNextCharacter(character)
                
                /* We have to convert the status from Schema<U>.MatchingStatus to Schema<T>.MatchingStatus */
                switch status {
                    
                case .canContinue:
                    return Schema<T>.MatchingStatus.canContinue
                    
                case .mustStop:
                    return Schema<T>.MatchingStatus.mustStop
                }
            }
        }
    }
    
    public class StringSubSchema: SubSchema {
        
        public var string: HString
        public var update: (inout T, HString) -> ()
        
        public init(string: HString, minCount: Int, maxCount: Int?, update: @escaping (inout T, HString) -> ()) {
            
            self.string = string
            self.update = update
            
            super.init(minCount: minCount, maxCount: maxCount)
        }
        
        override func buildSubMatcher() -> SubMatcher {
            
            return StringSubMatcher(string: self.string, update: self.update)
        }
        
        override func matchesEmpty() -> Bool {
            return self.string.length == 0
        }
        
        override func matchesNotEmpty() -> Bool {
            return self.string.length > 0
        }
        
        class StringSubMatcher: SubMatcher {
            
            private let string: HString
            private let update: (inout T, HString) -> ()
            private var currentIndex = 0
            
            init(string: HString, update: @escaping (inout T, HString) -> ()) {
                
                self.string = string
                self.update = update
            }
            
            override var isMatching: Bool {
                
                return self.currentIndex == string.length
            }
            
            override var currentUpdate: ((inout T) -> ())? {
                
                guard self.isMatching else {
                    return nil
                }
                
                let update = self.update
                let string = self.string
                
                return {(parentValue: inout T) in
                    update(&parentValue, string)
                }
            }
            
            override func matchNextCharacter(_ character: HChar) -> MatchingStatus {
                
                /* If the character is wrong, there is no value */
                guard character == self.string[self.currentIndex] else {
                    
                    return MatchingStatus.mustStop
                }
                
                self.currentIndex += 1
                
                guard self.currentIndex < string.length else {
                    
                    /* Parsing is finished */
                    return MatchingStatus.mustStop
                }
                
                return MatchingStatus.canContinue
            }
        }
    }
    
    public func parse(_ string: HString) -> T? {
        
        /* Lazy init */
        if let action = self.initFields {
            action()
            self.initFields = nil
        }
        
        let matcher = self.buildMatcher()
        var status = MatchingStatus.canContinue
        
        for i in 0..<string.length {
            
            guard status == MatchingStatus.canContinue else {
                return nil
            }
            
            let character = string[i]
            status = matcher.matchNextCharacter(character)
        }
        
        return matcher.currentValue
    }
    
    private func buildMatcher() -> Matcher {
        
        return Matcher(branches: self.branches, initialValue: self.initialValue)
    }
    
    private class Matcher {
        
        private let branches: [Branch]
        
        /* The branches are sorted from best to worst */
        private var branchMatchers: [BranchMatcher]
        
        var isMatching: Bool
        private var bestValue: T? = nil
        
        private struct BranchMatcher {
            
            let value: T?
            let subMatcher: SubMatcher
            let branchIndex: Int
            let subSchemaIndex: Int
            let occurrenceIndex: Int
        }
        
        init(branches: [Branch], initialValue: T?) {
            
            self.branches = branches
            self.branchMatchers = []
            self.isMatching = false
            
            /* Make the first branch matchers */
            for i in 0..<branches.count {
                
                self.addBranchMatchersAtSchema(branchIndex: i, schemaIndex: 0, insertionIndex: self.branchMatchers.count, value: initialValue)
            }
            
            /* Register the value as our if there are valid branches */
            if isThereNullableBranch() {
                self.isMatching = true
                self.bestValue = initialValue
            }
        }
        
        private func isThereNullableBranch() -> Bool {
            
            for branch in self.branches {
                
                /* Check that all min counts are 0 */
                let isNullable = branch.subSchemas.allSatisfy({ $0.minCount == 0 || $0.matchesEmpty() })
                if isNullable {
                    return true
                }
            }
            
            return false
        }
        
        var currentValue: T? {
            
            return self.bestValue
        }
        
        func matchNextCharacter(_ character: HChar) -> MatchingStatus {
            
            self.isMatching = false
            self.bestValue = nil
            
            /* Update the matchers in the reverse order so we can remove and add elements from the list */
            for i in (0 ..< self.branchMatchers.count).reversed() {
                
                let subMatcher = self.branchMatchers[i].subMatcher
                
                /* Feed the matcher */
                let status = subMatcher.matchNextCharacter(character)
                
                /* Check if the sub-matcher has a match, and so can update our value */
                if let update = subMatcher.currentUpdate {
                    
                    let newValue: T?
                    if let oldValue = self.branchMatchers[i].value {
                        var changingValue = oldValue
                        update(&changingValue)
                        newValue = changingValue
                    }
                    else {
                        newValue = nil
                    }
                    
                    /* Register this value, as ours if the branch is the best one */
                    if checkBranchMatcherIsValid(at: i) {
                        self.isMatching = true
                        self.bestValue = newValue
                    }
                    
                    /* As it returns an update, it has a match, so we can consider it ends here */
                    self.addSubBranchMatchers(branchingFrom: self.branchMatchers[i], index: i, value: newValue)
                }
                
                /* If the matcher is over, remove it */
                if status == MatchingStatus.mustStop {
                    
                    self.branchMatchers.remove(at: i)
                }
            }
            
            return self.branchMatchers.isEmpty ? MatchingStatus.mustStop : MatchingStatus.canContinue
        }
        
        private func checkBranchMatcherIsValid(at index: Int) -> Bool {
            
            /* Get the schema of the matcher */
            let branchMatcher = self.branchMatchers[index]
            let branchIndex = branchMatcher.branchIndex
            let subSchemaIndex = branchMatcher.subSchemaIndex
            let subSchemas = self.branches[branchIndex].subSchemas
            let subSchema = subSchemas[subSchemaIndex]
            
            /* Check the current matcher */
            guard branchMatcher.occurrenceIndex+1 >= subSchema.minCount else {
                return false
            }
            guard subSchema.maxCount == nil || branchMatcher.occurrenceIndex < subSchema.maxCount! else {
                return false
            }
            
            /* We assume the previous ones were good */
            
            /* Check if the following schemas can be absent */
            for i in (subSchemaIndex+1)..<subSchemas.count {
                
                let subSchema = subSchemas[i]
                
                guard subSchema.minCount == 0 || subSchema.matchesEmpty() else {
                    return false
                }
            }
            
            return true
        }
        
        private func addSubBranchMatchers(branchingFrom branchMatcher: BranchMatcher, index: Int, value: T?) {
            
            /* Get the schema of the matcher */
            let branchIndex = branchMatcher.branchIndex
            let subSchemaIndex = branchMatcher.subSchemaIndex
            let subSchema = self.branches[branchIndex].subSchemas[subSchemaIndex]
            
            var insertionIndex = index + 1
            
            /* Consider the same schema restarts */
            if subSchema.maxCount == nil || branchMatcher.occurrenceIndex + 1 < subSchema.maxCount! {
                
                let newSubMatcher = subSchema.buildSubMatcher()
                let newBranchMatcher = BranchMatcher(value: value, subMatcher: newSubMatcher, branchIndex: branchIndex, subSchemaIndex: subSchemaIndex, occurrenceIndex: branchMatcher.occurrenceIndex + 1)
                
                self.branchMatchers.insert(newBranchMatcher, at: insertionIndex)
                insertionIndex += 1
            }
            
            /* Consider the next schema starts */
            if subSchemaIndex + 1 < self.branches[branchIndex].subSchemas.count &&
               branchMatcher.occurrenceIndex+1 >= subSchema.minCount {
                
                self.addBranchMatchersAtSchema(branchIndex: branchIndex, schemaIndex: subSchemaIndex+1, insertionIndex: insertionIndex, value: value)
            }
        }
        
        private func addBranchMatchersAtSchema(branchIndex: Int, schemaIndex: Int, insertionIndex: Int, value: T?) {
            
            let subSchemas = self.branches[branchIndex].subSchemas
            var currentInsertionIndex = insertionIndex
            
            for i in schemaIndex..<subSchemas.count {
                
                let subSchema = subSchemas[i]
                
                /* If it doesn't match anything, skip it */
                if !subSchema.matchesNotEmpty() {
                    
                    guard subSchema.matchesEmpty() else {
                        break
                    }
                    
                    continue
                }
                
                /* Very small precaution */
                guard subSchema.maxCount == nil || subSchema.maxCount! > 0 else {
                    continue
                }
                
                /* Create a matcher starting that sub-schema */
                let subMatcher = subSchema.buildSubMatcher()
                let branchMatcher = BranchMatcher(value: value, subMatcher: subMatcher, branchIndex: branchIndex, subSchemaIndex: i, occurrenceIndex: 0)
                
                /* Insert */
                self.branchMatchers.insert(branchMatcher, at: currentInsertionIndex)
                currentInsertionIndex += 1
                
                /* If the minCount is 0, we must consider the next schema starts */
                guard subSchema.minCount == 0 || subSchema.matchesEmpty() else {
                    break
                }
            }
        }
    }
    
}


