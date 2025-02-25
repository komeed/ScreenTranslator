//
//  TranslatorView.swift
//  ScreenTranslator
//
//  Created by Omeed on 2/6/25.
//

import Foundation
import SwiftUI
import Translation

struct TranslatorView: View{
    @ObservedObject var broadcaster: MessageBroadcaster
    
    var sourceText: String
    @State private var targetText = ""
    var sourceLanguage: Locale.Language
    var targetLanguage = Locale.Language(identifier: "en")
    var pronounciation: String
    @State private var showTranslator = true

    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                if let output = broadcaster.outputText {
                    Color.clear
                        .onAppear(){
                            self.targetText = output
                            broadcaster.outputText = nil // this if statement goes on for one frame
                        }
                }
                ScrollView {
                    Text(sourceText)
                        .padding()
                        .font(.title)
                    Text(pronounciation)
                        .padding()
                        .font(.title)
                    Text(self.targetText)
                        .padding()
                        .font(.title)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

