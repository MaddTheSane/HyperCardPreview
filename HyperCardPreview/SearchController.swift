//
//  SearchController.swift
//  HyperCardPreview
//
//  Created by Pierre Lorenzi on 12/09/2019.
//  Copyright © 2019 Pierre Lorenzi. All rights reserved.
//

import AppKit
import HyperCardCommon

class SearchController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    
    var currentRequest: HString = ""
    private var results: [Result] = []
    private let queue = OperationQueue()
    
    private struct Result {
        var cardIndex: Int
        var occurrenceCount: Int
        var extract: String
    }
    
    @IBOutlet weak var searchField: NSSearchField!
    @IBOutlet weak var resultTable: NSTableView!
    @IBOutlet weak var resultCountField: NSTextField!
    @IBOutlet weak var goToResultButton: NSSegmentedControl!
    @IBOutlet weak var cardOrderButton: NSButton!
    @IBOutlet weak var rankingOrderButton: NSButton!
    
    override var windowNibName: NSNib.Name? {
        return "Search"
    }
    
    override func windowTitle(forDocumentDisplayName displayName: String) -> String {
        return "Search"
    }
    
    var stackDocument: Document!
    
    @IBAction func search(_ sender: Any?) {
        
        /* Stop the current searches */
        self.queue.cancelAllOperations()
        
        let request = self.searchField.stringValue
        
        /* Stack a new search */
        let operation = BlockOperation()
        operation.addExecutionBlock {
            [unowned self, unowned operation] in
            
            self.performSearch(request: request, operation: operation)
        }
        
        self.queue.addOperation(operation)
    }
    
    private func performSearch(request: String, operation: Operation) {
        
        let results = self.executeRequest(request, operation: operation)
        
        guard !operation.isCancelled else {
            return
        }
        
        OperationQueue.main.addOperation {
            [unowned self] in
            
            self.currentRequest = HString(converting: request) ?? ""
            self.results = results
            if self.rankingOrderButton.state == .on {
                self.sortByCardRanking(nil)
            }
            else {
                self.resultTable.reloadData()
            }
            self.resultCountField.stringValue = self.writeResultCount()
            self.goToResultButton.isEnabled = !self.results.isEmpty
        }
    }
    
    private func executeRequest(_ request: String, operation: Operation) -> [Result] {
        
        guard !request.isEmpty else {
            return []
        }
        guard let string = HString(converting: request) else {
            return []
        }
        
        let pattern = HString.SearchPattern(string)
        let results = self.searchInStack(pattern, operation: operation)
        
        return results
    }
    
    private func searchInStack(_ pattern: HString.SearchPattern, operation: Operation) -> [Result] {
        
        var results: [Result] = []
        let stack = self.stackDocument.browser.stack
        
        for cardIndex in 0..<stack.cards.count {
            
            guard !operation.isCancelled else {
                return []
            }
            
            let card = stack.cards[cardIndex]
            
            let cardResult = self.countOccurrencesInCard(card, of: pattern)
            
            if cardResult.occurrenceCount > 0 {
                let extract = self.makeExtract(in: cardResult.bestContent!, around: pattern)
                let result = Result(cardIndex: cardIndex, occurrenceCount: cardResult.occurrenceCount, extract: extract)
                results.append(result)
            }
        }
        
        return results
    }
    
    private func makeExtract(in content: HString, around pattern: HString.SearchPattern) -> String {
     
        let length = 100
        let firstOccurrence = content.find(pattern, from: 0)!
        let startIndex = max(firstOccurrence - length/2, 0)
        let endIndex = min(firstOccurrence + length/2, content.length)
        
        var string = content[startIndex ..< endIndex]
        for i in 0..<string.length {
            if string[i] == HChar.carriageReturn {
                string[i] = HChar.space
            }
        }
        let extract = (startIndex != 0 ? "…" : "") + string.description + (endIndex < content.length ? "…" : "")
        
        return extract
    }
    
    private struct CardResult {
        var occurrenceCount: Int
        var bestContent: HString?
    }
    
    private func countOccurrencesInCard(_ card: Card, of pattern: HString.SearchPattern) -> CardResult {
        
        var occurrenceCount = 0
        var bestContent: HString? = nil
        
        /* Search in the background fields */
        for content in card.backgroundPartContents {
            
            let stringContent = content.partContent.string
            let contentOccurrenceCount = self.countOccurrencesInString(stringContent, of: pattern)
            occurrenceCount += contentOccurrenceCount
            
            if contentOccurrenceCount > 0 && stringContent.length > bestContent?.length ?? 0 {
                bestContent = stringContent
            }
        }
        
        /* Search in the card fields */
        for field in card.fields {
            
            let stringContent = field.content.string
            let contentOccurrenceCount = self.countOccurrencesInString(stringContent, of: pattern)
            occurrenceCount += contentOccurrenceCount
            
            if contentOccurrenceCount > 0 && stringContent.length > bestContent?.length ?? 0 {
                bestContent = stringContent
            }
        }
        
        return CardResult(occurrenceCount: occurrenceCount, bestContent: bestContent)
    }
    
    private func countOccurrencesInString(_ string: HString, of pattern: HString.SearchPattern) -> Int {
        
        var index = 0
        var count = 0
        
        while index < string.length, let occurrenceIndex = string.find(pattern, from: index) {
            
            count += 1
            index = occurrenceIndex + pattern.string.length
        }
        
        return count
    }
    
    private func writeResultCount() -> String {
        
        guard !self.searchField.stringValue.isEmpty else {
            return ""
        }
        
        let resultCount = self.results.map({ $0.occurrenceCount }).reduce(0,+)
        
        switch resultCount {
            
        case 0:
            return "0 result"
            
        case 1:
            return "1 result"
            
        default:
            return "\(resultCount) results"
        }
    }
    
    @IBAction func sortByCardOrder(_ sender: Any?) {
        self.rankingOrderButton.state = .off
        self.results.sort(by: { return $0.cardIndex < $1.cardIndex })
        self.resultTable.reloadData()
    }
    
    @IBAction func sortByCardRanking(_ sender: Any?) {
        self.cardOrderButton.state = .off
        self.results.sort(by: { return $0.occurrenceCount > $1.occurrenceCount })
        self.resultTable.reloadData()
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.results.count
    }
    
    @IBAction func goToResult(_ sender: Any?) {
        
        let cellIndex = self.goToResultButton.indexOfSelectedItem
        let findAction: NSFindPanelAction = (cellIndex == 0) ? .previous : .next
        
        self.sendFindAction(findAction)
    }
    
    private func sendFindAction(_ findAction: NSFindPanelAction) {
        
        /* Normally there should be one control per action but whatever, we change the tag
         to pretend */
        self.goToResultButton.tag = Int(findAction.rawValue)
        NSApp.sendAction(#selector(Document.performFindPanelAction(_:)), to: self.document, from: self.goToResultButton)
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let viewGeneric = self.resultTable.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "searchItem"), owner: self) ?? SearchItemView(frame: NSRect(x: 0, y: 0, width: 100, height: 100))
        let view = viewGeneric as! SearchItemView
        
        /* Load the view from the NIB */
        if !view.isSetup {
            let nib = NSNib(nibNamed: "SearchItem", bundle: nil)!
            nib.instantiate(withOwner: view, topLevelObjects: nil)
            view.setup()
        }
        
        let result = self.results[row]
        let name = self.writeCardName(index: result.cardIndex)
        view.showResult(cardName: name, occurrenceCount: result.occurrenceCount, extract: result.extract)
        
        return view
    }
    
    private func writeCardName(index: Int) -> String {
        
        let stack = self.stackDocument.browser.stack
        let card = stack.cards[index]
        
        guard card.name.length != 0 else {
            return "Card \(index+1)"
        }
        
        return card.name.description
    }
    
    func tableViewSelectionDidChange(_: Notification) {
        
        let resultIndex = self.resultTable.selectedRow
        let cardIndex = self.results[resultIndex].cardIndex
        self.stackDocument.goToCard(at: cardIndex, transition: Document.Transition.none)
        if let field = self.stackDocument.browser.selectedField {
            field.selectedRange = nil
        }
        self.sendFindAction(NSFindPanelAction.next)
    }
}

