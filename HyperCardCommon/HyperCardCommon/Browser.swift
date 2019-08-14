//
//  Browser.swift
//  HyperCard
//
//  Created by Pierre Lorenzi on 03/03/2017.
//  Copyright © 2017 Pierre Lorenzi. All rights reserved.
//



private let trueHiliteContent = "1"


/// Browses through a stack: maintains a current card and current background and draws them.
public class Browser {
    
    /// The stack being browsed
    public let hyperCardFile: HyperCardFile
    public var stack: Stack {
        return self.hyperCardFile.stack
    }
    
    /// The index of the current card. Set it to browse.
    public var cardIndex: Int {
        get { return cardIndexProperty.value }
        set { if (newValue != cardIndexProperty.value) { cardIndexProperty.value = newValue } }
    }
    public var cardIndexProperty: Property<Int>
    
    /// Activate this flag for the background view: only the background is drawn
    public var displayOnlyBackground: Bool {
        get { return displayOnlyBackgroundProperty.value }
        set { displayOnlyBackgroundProperty.value = newValue }
    }
    public var displayOnlyBackgroundProperty = Property<Bool>(false)
    
    private let drawing: Drawing
    
    private let resources: ResourceSystem
    private let fontManager: FontManager
    
    /// The image of the current card with its background
    public var image: Image {
        return drawing.image
    }
    
    /// The current card
    public var currentCard: Card {
        return self.stack.cards[cardIndex]
    }
    
    /// The current background
    public var currentBackground: Background {
        return self.currentCard.background
    }
    
    private var viewRecords: [ViewRecord] = []
    
    public var needsDisplay: Bool {
        get { return needsDisplayProperty.value }
        set { needsDisplayProperty.value = newValue }
    }
    public var needsDisplayProperty = Property<Bool>(false)
    
    /// the background before changing card
    private var backgroundBefore: Background? = nil
    
    /// the view used to draw a white background on the window
    private var whiteView: WhiteView
    
    /// if the white view is in the view stack
    private var isShowingWhiteView = false
    
    private let cgdata: UnsafeMutableRawPointer
    private let cgcontext: CGContext
    
    private let areThereColors: Bool
    
    private struct ViewRecord {
        
        /// the view
        public let view: View
        
        /// if the view is marked for refresh
        public var willRefresh: Bool
        
        /// if the views behind have been updateed when the view was marked for refresh
        public var didUpdateBehind: Bool
        
        /// if the view accepts to draw sub-rectangles, the rectangles to draw.
        public var rectanglesToRefresh: [Rectangle]?
    }
    
    /// Builds a new browser from the given stack. A starting card index can be given.
    public init(hyperCardFile: HyperCardFile, cardIndex: Int = 0) {
        self.hyperCardFile = hyperCardFile
        let stack = hyperCardFile.stack
        drawing = Drawing(width: stack.size.width, height: stack.size.height)
        
        var resources = ResourceSystem()
        if let stackResources = hyperCardFile.resources {
            resources.repositories.append(stackResources)
        }
        resources.repositories.append(ResourceRepository.mainRepository)
        self.resources = resources
        
        self.fontManager = FontManager(resources: resources, fontNameReferences: stack.fontNameReferences)
        
        self.cardIndexProperty = Property<Int>(cardIndex)
        
        let width = stack.size.width
        let height = stack.size.height
        let cgdata = RgbConverter.createRgbData(width: width, height: height)
        self.cgdata = cgdata
        self.cgcontext = RgbConverter.createContext(forRgbData: cgdata, width: width, height: height)
        self.whiteView = WhiteView(cardRectangle: Rectangle(x: 0, y: 0, width: width, height: height))
        
        self.areThereColors = Browser.areThereColors(inFile: hyperCardFile)
        
        /* Flip the contect */
        cgcontext.translateBy(x: 0, y: CGFloat(height))
        cgcontext.scaleBy(x: 1, y: -1)
        
        /* Add a background view */
        self.appendView(self.whiteView)
        
        /* Build the views for the current card */
        self.rebuildViews()
        
        self.cardIndexProperty.startNotifications(for: self, by: { [unowned self] in self.rebuildViews() })
        self.displayOnlyBackgroundProperty.startNotifications(for: self, by: { [unowned self] in self.rebuildViews() })
    }
    
    private static func areThereColors(inFile hyperCardFile: HyperCardFile) -> Bool {
        
        guard let repository = hyperCardFile.resources else {
            return false
        }
        
        return !repository.cardColors.isEmpty || !repository.backgroundColors.isEmpty
    }
    
    private func rebuildViews() {
        
        /* If we haven't changed background, keep the background parts */
        if currentBackground === backgroundBefore {
            
            /* Remove all the views except the background views, there are one view per part,
             plus one for the image, plus one for the white view */
            let backgroundViewCount = 1 + currentBackground.parts.count + (isShowingWhiteView ? 1 : 0)
            removeLastViews(count: self.viewRecords.count - backgroundViewCount)
            
            /* Set the scrolls of the background fields to zero, to avoid having a field
             with a scroll higher than maximum */
            for field in currentBackground.fields {
                if field.style == .scrolling {
                    field.scroll = 0
                }
            }
        }
        else {
            
            /* Remove all the views except the window background */
            self.viewRecords.removeAll()
            
            /* If the background doesn't draw a white background, add the white view */
            isShowingWhiteView = !doesBackgroundHaveWhiteMask(self.currentBackground)
            if isShowingWhiteView {
                appendView(self.whiteView)
            }
            
            /* Append background views */
            appendLayerViews(self.currentBackground)
            
        }
        
        /* Update the state */
        backgroundBefore = currentBackground
        
        /* Append card views */
        if !displayOnlyBackground {
            appendLayerViews(self.currentCard)
        }
        
        /* We must refresh */
        self.needsDisplay = true
                
    }
    
    private func doesBackgroundHaveWhiteMask(_ background: Background) -> Bool {
        
        /* This function is a bad optimization, we should implement a opaque properties in views */
        
        /* Check if the background is visible */
        guard background.showPict else {
            return false
        }
        
        /* Check if the background have a rectangular white mask spanning on all the window */
        if let image = currentBackground.image {
            if case MaskedImage.Layer.rectangular(rectangle: let rectangle) = image.mask {
                if rectangle.right == self.image.width && rectangle.bottom == self.image.height {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func removeLastViews(count: Int) {
        
        /* Check if the views to remove are visible */
        let remainingViewCount = viewRecords.count - count
        let needsUpdate = viewRecords[remainingViewCount ..< viewRecords.count].map({$0.view.rectangle != nil}).reduce(false, { (b1: Bool, b2: Bool) -> Bool in
            return b1 || b2
        })
        
        /* Remove the views */
        self.viewRecords.removeLast(count)
        
        /* If the card was visible, refresh all the background views (don't loose time looping on all the card views) */
        if needsUpdate {
            for i in 0..<viewRecords.count {
                if !viewRecords[i].willRefresh {
                    markViewForRefresh(atIndex: i, redrawBehind: true)
                }
            }
        }
        
    }
    
    private func markViewForRefresh(atIndex index: Int, redrawBehind: Bool) {
        
        /* Get the view rectangle */
        guard let dirtyRectangle = viewRecords[index].view.rectangle else {
            return
        }
        
        /* Mask the view for refresh */
        viewRecords[index].willRefresh = true
        viewRecords[index].didUpdateBehind = redrawBehind
        
        /* Refresh all the views in front */
        for i in (index+1) ..< viewRecords.count {
            self.markViewForRefreshIfOverlapsRect(atIndex: i, dirtyRectangle: dirtyRectangle)
        }
        
        /* Refresh the views behind if requested */
        if redrawBehind {
            for i in 0 ..< index {
                self.markViewForRefreshIfOverlapsRect(atIndex: i, dirtyRectangle: dirtyRectangle)
            }
        }
        
        self.needsDisplay = true
    }
    
    private func markViewForRefreshIfOverlapsRect(atIndex index: Int, dirtyRectangle: Rectangle) {
        
        /* Get the view */
        let view = viewRecords[index].view
        
        /* Get the rectangle */
        guard let rectangle = view.rectangle else {
            return
        }
        
        /* The view must intersects the dirty rect */
        guard rectangle.intersects(dirtyRectangle) else {
            return
        }
        
        /* Check if it not already marked for refresh */
        guard !viewRecords[index].willRefresh else {
            return
        }
        
        /* If the view can draw sub-rectangles, mark the rectangle for refresh. Do not check the other
         views because the rectangle is already dirty */
        if view is ClipableView {
            
            let rectangleToRefresh = computeRectangleIntersection(dirtyRectangle, rectangle)
            var rectanglesToRefresh: [Rectangle] = viewRecords[index].rectanglesToRefresh ?? []
            rectanglesToRefresh.append(rectangleToRefresh)
            viewRecords[index].rectanglesToRefresh = rectanglesToRefresh
            return
        }
        
        /* Mask the view for refresh. Do not draw behind because it still has the same shape */
        self.markViewForRefresh(atIndex: index, redrawBehind: view.usesXorComposition)
        
    }
    
    public func refresh() {
        
        /* If there are colors, it is a separate process */
        guard !self.areThereColors else {
            
            self.refreshWithColors()
            return
        }
        
        /* Refresh the drawing */
        if let dirtyRectangle  = self.refreshDrawing() {
            
            /* Refresh the CGImage */
            RgbConverter.fillRgbData(self.cgdata, withImage: self.image, rectangle: dirtyRectangle)
        }
        
    }
    
    private func refreshWithColors() {
        
        /* Draw a white background */
        cgcontext.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0))
        cgcontext.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        /* Draw the colors */
        AddColorPainter.paintAddColor(ofFile: hyperCardFile, atCardIndex: cardIndex, excludeCardParts: self.displayOnlyBackground, onContext: cgcontext)
        
        /* Update data */
        cgcontext.flush()
        
        /* Update the black&white image */
        let _  = self.refreshDrawing()
        
        /* Draw the black&white image (only the black pixels, to keep the colors behind) */
        RgbConverter.fillRgbDataWithBlackPixels(self.cgdata, withImage: self.image)
        
    }
    
    private func refreshDrawing() -> Rectangle? {
        
        var index = -1
        var dirtyRectangle: Rectangle? = nil
        
        /* Draw the views */
        for viewRecord in viewRecords {
            
            let view = viewRecord.view
            index += 1
            
            /* The view may be not for refresh but have rectangles to draw */
            if let clipableView = view as? ClipableView,
                let rectanglesToRefresh = viewRecord.rectanglesToRefresh, !viewRecord.willRefresh {
                for rectangle in rectanglesToRefresh {
                    clipableView.draw(in: drawing, rectangle: rectangle)
                    dirtyRectangle = computeEnclosingRectangle(dirtyRectangle, rectangle)
                }
                view.refreshNeed = .none
                viewRecords[index].rectanglesToRefresh = nil
                viewRecords[index].didUpdateBehind = false
                continue
            }
            
            /* Check if the view is programmed for refresh */
            guard viewRecord.willRefresh else {
                continue
            }
            
            /* Draw the view */
            view.draw(in: drawing)
            view.refreshNeed = .none
            viewRecords[index].willRefresh = false
            viewRecords[index].didUpdateBehind = false
            viewRecords[index].rectanglesToRefresh = nil
            dirtyRectangle = computeEnclosingRectangle(dirtyRectangle, view.rectangle)
        }
        
        /* Restrain the rectangle to the card, in case there are parts outside the card rectangle */
        dirtyRectangle = (dirtyRectangle == nil) ? nil : computeRectangleIntersection(dirtyRectangle!, Rectangle(x: 0, y: 0, width: image.width, height: image.height))
        
        return dirtyRectangle
    }
    
    private func appendLayerViews(_ layer: Layer) {
        
        /* Image */
        let layerView = LayerView(layer: layer)
        appendView(layerView)
        
        /* Parts */
        for part in layer.parts {
            
            let partView = buildPartView(for: part)
            appendView(partView)
        }
        
    }
    
    private func appendView(_ view: View) {
        
        /* Listen to the view refresh needs */
        view.refreshNeedProperty.startNotifications(for: self, by: { [unowned self, unowned view] in
            
            /* Do not listen to updates with no effect */
            guard view.refreshNeed != .none && view.rectangle != nil else {
                return
            }
            
            /* Check if the view has changed shape, in that case the views behind must be refreshed */
            let hasChangedShape = (view.refreshNeed == .refreshWithNewShape)
            
            /* Find the record */
            let index = self.viewRecords.firstIndex(where: { $0.view === view })!
            let record = self.viewRecords[index]
            if (!hasChangedShape && record.willRefresh) || (hasChangedShape && record.didUpdateBehind) {
                return
            }
            
            /* Refresh */
            self.markViewForRefresh(atIndex: index, redrawBehind: hasChangedShape)
        })
        
        /* Build a view record. Do not mark it as refresh because we're just adding a view on top, just set willRefresh to true  */
        let viewRecord = ViewRecord(view: view, willRefresh: true, didUpdateBehind: false, rectanglesToRefresh: nil)
        self.viewRecords.append(viewRecord)
        self.needsDisplay = true
        
    }
    
    private func buildPartView(for part: LayerPart) -> View {
        
        switch part {
        case .field(let field):
            return buildFieldView(for: field)
        case .button(let button):
            return buildButtonView(for: button)
        }
        
    }
    
    private func buildFieldView(for field: Field) -> View {
        
        /* Content */
        let contentComputation = retrieveContent(of: field)
        
        let view = FieldView(field: field, contentComputation: contentComputation, fontManager: self.fontManager)
        
        return view
        
    }
    
    private func retrieveContent(of field: Field) -> Computation<PartContent> {
        
        /* Special case: bg buttons with not shared hilite */
        if !field.sharedText && isPartInBackground(field) {
            
            let computation = Computation<PartContent> {
                [unowned self, unowned field] () -> PartContent in
            
                /* If we're displaying the background, do not display the card contents */
                if self.displayOnlyBackground {
                    return PartContent.string("")
                }
                
                /* Get the content of the button in the card */
                if let content = self.findContentInCurrentCard(of: field) {
                    return content
                }
                
                return PartContent.string("")
                
            }
            
            /* Dependencies */
            computation.dependsOn(self.cardIndexProperty)
            computation.dependsOn(self.displayOnlyBackgroundProperty)
            
            return computation
            
        }
        
        /* Usual case: just return the content of the parent layer */
        let computation = Computation<PartContent> {
            [unowned field] () -> PartContent in
            return field.content
        }
        computation.dependsOn(field.contentProperty)
        
        return computation
    }
    
    private func buildButtonView(for button: Button) -> View {
        
        let hiliteComputation = retrieveHilite(of: button)
        
        return ButtonView(button: button, hiliteComputation: hiliteComputation, fontManager: fontManager, resources: resources)
    }
    
    private func retrieveHilite(of button: Button) -> Computation<Bool> {
        
        /* Special case: bg buttons with not shared hilite */
        if !button.sharedHilite && isPartInBackground(button) {
            
            let computation = Computation<Bool> {
                [unowned self, unowned button] () -> Bool in
            
                /* If we're displaying the background, do not display the card contents */
                if self.displayOnlyBackground {
                    return false
                }
                
                /* Get the content of the button in the card */
                guard let content = self.findContentInCurrentCard(of: button) else {
                    return false
                }
                
                /* If the card content is equal to "1", the button is hilited */
                guard case PartContent.string(let textContent) = content, textContent == trueHiliteContent  else {
                    return false
                }
            
                return true
            }
            
            /* Dependencies */
            computation.dependsOn(self.cardIndexProperty)
            computation.dependsOn(self.displayOnlyBackgroundProperty)
            
            return computation
        }
        
        /* Usual case: just return hilite */
        let computation = Computation<Bool> {
            [unowned button] () -> Bool in
            return button.hilite
        }
        computation.dependsOn(button.hiliteProperty)
        
        return computation
    }
    
    private func isPartInBackground(_ part: Part) -> Bool {
        
        return self.currentBackground.parts.contains(where: {$0.part === part})
    }
    
    private func findContentInCurrentCard(of part: Part) -> PartContent? {
        
        let contents = self.currentCard.backgroundPartContents
        
        /* Find the content of the part */
        guard let content = contents.first(where: { $0.partIdentifier == part.identifier }) else {
            return nil
        }
        
        return content.partContent
    }
    
    public func buildImage() -> CGImage {
        
        return RgbConverter.createImage(forRgbData: cgdata, isOwner: false, width: self.image.width, height: self.image.height)
    }
    
    public func findViewRespondingToMouseEvent(at position: Point) -> MouseResponder? {
        
        /* Ask to the views, from the foremost to the outmost */
        for viewRecord in viewRecords.reversed() {
            
            let view = viewRecord.view
            
            /* Check if the view responds to the mouse */
            guard let responder = view as? MouseResponder else {
                continue
            }
            
            /* Check if the view responds to that mouse event */
            guard responder.doesRespondToMouseEvent(at: position) else {
                continue
            }
            
            return responder
        }
        
        return nil
    }
    
}
