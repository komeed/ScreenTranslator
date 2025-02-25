/*
 Why do I need a broadcaster object?
 The Translation framework must be a global object: if you remove the view that contains the translation framework, it errors bcs the previous view holding it is gone, therefore I cannot hold the translation framework in the popup window
Unfortunately, my nsviewcontroller isn't a swiftui view, and translation framework only works on an SwiftUI View
 So, I have to add a swiftui clear view and hold the translation framework in there, and communicate between that swiftui and the swiftui for the popup window using a broadcaster to send the data between each view.
 */

import Cocoa
import SwiftUI
import Foundation
import NaturalLanguage
import Combine
//Window that holds the frame stuff
class OverlayWindowController: NSWindowController {
    //private var contentVC: ImageOverlayController?
    private var image: NSImage?
    private var screen: NSScreen?
    convenience init(image: NSImage) { // convenience init calls designated init (self.init) but requires less parameters
        var window: NSWindow
        var s: NSScreen?
        if let screen = NSScreen.main {
            s = screen
            window = NSWindow(
                contentRect: screen.frame,
                styleMask: [.borderless, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        else{
            window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 500),
                styleMask: [.closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
        }
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = NSColor.clear
        //window.center()
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.level = .mainMenu
        self.init(window: window)
        if let screen = s {
            self.screen = screen
        }
        self.image = image
        //contentVC = ImageOverlayController(image: image)
        //self.contentViewController = contentVC
    }
    func runProcessing(){
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = self.image else { return }
            let vp = VisionProcessor(ns: image, language: "EN")
            vp.detectText() { data in
                DispatchQueue.main.async {
                    if let d = data {
                        guard let screen = self.screen else { return }
                        let contentVC = ImageOverlayController(image: image, data: d, screen: screen)
                        self.contentViewController = contentVC
                    }
                }
            }
        }
    }
}

class ImageOverlayController: NSViewController {
    //message broadcasters (using Combine)
    var broadcaster = MessageBroadcaster()
    var cancellable: AnyCancellable?
    
    //UI Views (image, close button, popover windows)
    private var openSS = false
    private var rectangleView: changingRectangleView!
    private let imageView = NSImageView()
    private let closeButton = NSButton()
    private var popover = NSPopover()
    
    //Button on screen
    private var buttons: [YellowButton : (Int, Int)] = [:] // hash table for detecting which button clicked and return both char and line index
    
    //background stuff
    private var swiftUIWindow: NSWindow? // parent window
    private var data: EncryptData? // data returned from vision processor
    private var screen: NSScreen // screen from window

    private var selectByCharacter = true
    
    private let rectSize = NSSize(width: 300, height: 200) // initialize popup window size
    
    init(image: NSImage, data: EncryptData, screen: NSScreen) {
        self.data = data
        self.screen = screen
        super.init(nibName: nil, bundle: nil)
        imageView.image = image
        imageView.frame = screen.frame
        imageView.imageScaling = .scaleAxesIndependently
        
        view = KeyDetectingView(frame: screen.frame) // failiure to use keydetection :(
        view.addSubview(imageView) // add image
        
        //process all buttons
        for (index, rect) in data.rects.enumerated() {
            let b = YellowButton()
            b.title = ""
            let updatedRect = NSRect(x:rect.minX, y: screen.frame.maxY - rect.height - rect.minY, width: rect.width, height: rect.height)
            self.data?.rects[index] = updatedRect
            b.frame = updatedRect
            b.target = self
            b.action = #selector(openStuff(_:))
            buttons[b] = data.map[index]
            if(!selectByCharacter){
                b.isHidden = true
            }
            view.addSubview(b)
        }
        
        // button black ui element
        let bottomRect = NSRect(x: 0,y: 0, width: screen.frame.width, height: 50)
        let mySubview = NSView(frame: bottomRect)
        mySubview.wantsLayer = true
        mySubview.layer?.backgroundColor = NSColor.black.cgColor
        view.addSubview(mySubview)
        
        //toggle for toggling character vs line
        let cLabel = NSTextField(labelWithString: "By Character"), lLabel = NSTextField(labelWithString: "By Line")
        let toggleSelect = NSSwitch(frame: CGRect(x: 100, y: 0, width: 100, height: 50))
        let hStack = NSStackView(views: [closeButton, cLabel, toggleSelect, lLabel])
        hStack.orientation = .horizontal
        hStack.alignment = .centerY
        hStack.distribution = .equalSpacing
        hStack.frame = NSRect(x: 0, y: 0, width: screen.frame.width, height: screen.frame.height)
        
        //close button
        closeButton.title = "close"
        closeButton.frame = CGRect(x: 0, y: 0, width: 100, height: 50)
        closeButton.target = self
        closeButton.action = #selector(closeWindow)
        
        toggleSelect.state = .off
        toggleSelect.target = self
        toggleSelect.action = #selector(toggleSelectChanged(_:))
        
        view.addSubview(hStack)
        
        let translator = Translator(broadcaster: broadcaster) // adding the background translation swiftui view
        let hostingView = NSHostingView(rootView: translator)
        view.addSubview(hostingView)
        
        /*
         detect once its done finishing processing
         In translation framework, if it cannot detect the language it asks the user what language to choose through apple's own popup window. However, since I have the popover behavior to transient (so I can close it with a click outside), it automatically closes the popover window. So, only when the translator finishes the processing can I set it back to transient.
         */
        cancellable = broadcaster.$finishedProcessing.sink { [weak self] finishedProcessing in
            if finishedProcessing {
                self?.popover.behavior = .transient
                self?.broadcaster.finishedProcessing = false
            }
        }
    }
    
    @objc private func toggleSelectChanged(_ sender: NSSwitch){
        if sender.state == .on {
            selectByCharacter = false
        } else {
            selectByCharacter = true
        }
    }
    
    @objc private func openStuff(_ sender: YellowButton) {
        if let indecies = buttons[sender], let data = self.data {
            let text = selectByCharacter ? data.texts[indecies.0] : data.lines[indecies.1] // tuple: 1st = charindex, 2nd = lineindex
            let recognizer = NLLanguageRecognizer()
            recognizer.languageConstraints = [.english, .simplifiedChinese,
                                              .traditionalChinese]
            recognizer.processString(text)
            guard let language = recognizer.dominantLanguage else {
                print("Language not recognized")
                return
            }
            let mysql = MySequel()
            guard let chineseData = mysql.access(word: text, language: language.rawValue) else {
                print("mysql error")
                return }
            broadcaster.inputText = text
            let contentView = TranslatorView(broadcaster: broadcaster, sourceText: text, sourceLanguage: Locale.Language(identifier: language.rawValue), pronounciation: chineseData.pinyin)
            let hostingController = NSHostingController(rootView: contentView)
            
            popover.contentViewController = hostingController
            popover.behavior = .applicationDefined // intially make it non-closable until translation popup closes
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    //failed attempt at making key controls
    override func keyDown(with event: NSEvent) {
        if let characters = event.characters {
            print("Key pressed: \(characters)")
            if characters.lowercased() == "c" {
                print("You pressed 'C'!")
            }
        }
    }
    
    @objc private func closeWindow() {
        //self.view.window?.contentViewController = nil
        view.window?.close()
        self.view.window?.contentViewController = nil
    }
    @IBAction func showOverlay(_ sender: Any) {
        //let overlayVC = InfoOverlay()
        //presentAsModalWindow(overlayVC)
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(view)  // Ensure key events are captured
    }
}

class InfoOverlay: NSViewController {
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class YellowButton: NSButton {

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        NSColor.yellow.withAlphaComponent(0.5).setFill()
        
        bounds.fill() // Fill the button's area
    }
}

class changingRectangleView: NSView {
    private var rectSize: CGSize = .zero
    override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)
            
            NSColor.systemBlue.setFill()
            let rect = NSRect(origin: .zero, size: rectSize)
            rect.fill()
        }
        
        func updateSize(to newSize: CGSize) {
            rectSize = newSize
            needsDisplay = true
        }
}

struct RectData {
    var rect: CGRect
    var word: String
    init(rect: CGRect, word: String){
        self.rect = rect
        self.word = word
    }
}

class KeyDetectingView: NSView {
    override func keyDown(with event: NSEvent) {
        super.keyDown(with: event)
        print("Key pressed: \(event.keyCode)")
        // Handle the key press here
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
}
