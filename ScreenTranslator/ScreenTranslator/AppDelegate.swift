/*
 The NSApplication Delegate is used to have a icon show up in the top right corner of your mac menu bar. This allows for the app to run in the background and easily be controlled through the upper menu indicator.
 */

import Cocoa
import SwiftUI
import CoreGraphics
import Foundation
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var nsImage: NSImage? = nil
    var openContentView = false
    var window: NSWindow?
    var screenCapture: ScreenCapture?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create menu bar icon
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "wifi", accessibilityDescription: "Menu Bar App")
        }
        
        // Create a dropdown menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        menu.addItem(NSMenuItem(title: "Capture Screen", action: #selector(CaptureScreen), keyEquivalent: "`")) // hotkeys temporarily don't work
        menu.addItem(NSMenuItem(title: "Close Window", action: #selector(closeWindow), keyEquivalent: ""))

        statusItem?.menu = menu
    }

    @objc func CaptureScreen(){
        screenCapture = ScreenCapture()
        screenCapture?.CaptureScreen() { image in
            if let image = image {
                DispatchQueue.main.async {
                    self.openNSWindow(image: image)
                }
            }
        }
    }
    
    @objc func openNSWindow(image: NSImage){
        let overlay = OverlayWindowController(image: image)
        overlay.showWindow(nil)
        overlay.runProcessing()
    }
    @objc func closeWindow(){
        window?.close()
    }
    @objc func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}

/*
 side note: Before macOS 15 this process was shortened down to 5 lines of code and was extremely high res. Unfortunately, they made it so you must now use the screen recording system in order to capture a screenshot, but because its a screen recording the resolution is terrible.
 
 How it works: you start the screen recording and pause it the second it retrieves any image. The image is encrypted in a CMSampleBuffer, which you then convert to a CIImage, an NSCIImageRep, and from there an NSImage.
 */
class ScreenCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private var completion: ((NSImage?) -> Void)?

    @objc func CaptureScreen(completion: @escaping (NSImage?) -> Void) {
        self.completion = completion
        Task { // capturing screen using the ScreenCapture Kit is async (hence the await), so we need to use Task to stop until completion
            do {
                let availableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard let display = availableContent.displays.first else {
                    print("No display found")
                    return
                }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                let config = SCStreamConfiguration()
                config.width = display.width
                config.height = display.height
                config.minimumFrameInterval = CMTime(value: 1, timescale: 30) // 30 FPS (pretty useless tho bcs we're only retrieving 1 image)
                config.showsCursor = false
                
                stream = SCStream(filter: filter, configuration: config, delegate: nil)
                
                try stream?.addStreamOutput(self, type: .screen, sampleHandlerQueue: DispatchQueue.global())

                try await stream?.startCapture()
                print("Screen capture started")

            } catch {
                print("Screen capture failed: \(error)")
                completion(nil)
            }
        }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else {
            print("Invalid sample buffer")
            return
        }
        guard let imageBuffer = sampleBuffer.imageBuffer else { return } // retrieve imageBuffer from samplebuffer
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let rep = NSCIImageRep(ciImage: ciImage)
        let nsImage = NSImage(size: rep.size)
        nsImage.addRepresentation(rep)
        stopCapture() //end stream
        completion?(nsImage) //exit screencapture class with completion
    }

    func stopCapture() {
        stream?.stopCapture()
        print("Screen capture stopped")
    }
}

