import Foundation
import SwiftUI
import Vision
import AppKit
import ImageIO
import NaturalLanguage

struct VisionProcessor {
    var image: NSImage
    var language: String
    
    init(ns: NSImage, language: String) {
        self.image = ns
        self.language = language
    }
    
    private func cgImage(from nsImage: NSImage) -> CGImage? {
        guard let tiffData = nsImage.tiffRepresentation,
              let imageSource = CGImageSourceCreateWithData(tiffData as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(imageSource, 0, nil)
    }
    
    func detectText(completion: @escaping (EncryptData?) -> Void) {
        guard let cgImage = cgImage(from: image) else {
            completion(nil)
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                completion(nil)
                return
            }
            
            let imageWidth = image.size.width
            let imageHeight = image.size.height
            
            var boundingRects: [CGRect] = []
            //var lineBoundingRects: [CGRect] = []
            var texts: [String] = []
            var lines: [String] = []
            var storeIndecies: [(Int, Int)] = [] // 1st Int: store char index, 2nd Int: store line index
            var wordIndex: Int = 0
            var charIndex: Int = 0
            
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else {
                    continue
                }
                let words = candidate.string.split(separator: " ")
                var currentIndex = candidate.string.startIndex
                for word in words {
                    var charRects: [CGRect] = []
                    for char in word {
                        if let range = candidate.string.range(of: String(char), range: currentIndex..<candidate.string.endIndex) {
                            if let charBox = try? candidate.boundingBox(for: range) {
                                let normalizedBox = charBox.boundingBox
                                let rect = CGRect(
                                    x: normalizedBox.origin.x * imageWidth,
                                    y: (1 - normalizedBox.origin.y - normalizedBox.height) * imageHeight,
                                    width: normalizedBox.width * imageWidth,
                                    height: normalizedBox.height * imageHeight
                                )
                                charRects.append(rect)
                            }
                            currentIndex = range.upperBound
                        }
                        texts.append(String(char))
                        storeIndecies.append((charIndex, wordIndex))
                        print((charIndex, wordIndex))
                        charIndex += 1
                    }
                    boundingRects.append(contentsOf: charRects)
                    lines.append(String(word))
                    let giantRect = CGRect.findBoundingRect(charRects)
                    //lineBoundingRects.append(giantRect)
                    wordIndex += 1
                }
            }
            completion(EncryptData(rects: boundingRects, texts: texts, lines: lines, map: storeIndecies))
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("Error performing text detection: \(error)")
                completion(nil)
            }
        }
    }
}

struct EncryptData {
    var rects: [CGRect] = []
    var texts: [String] = []
    var lines: [String] = []
    var lineRects: [CGRect] = []
    var map: [(Int, Int)] = []
    
    init(rects: [CGRect], texts: [String], lines: [String], map: [(Int, Int)]) {
        self.rects = rects
        self.texts = texts
        self.lines = lines
        //self.lineRects = lineRects
        self.map = map
    }
}
