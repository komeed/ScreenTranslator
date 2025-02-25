/*
 I need two different translation views, one for the popupview and another for the global translation view because of the phenomenon described in my NSWindow class
 */

import Foundation
import SwiftUI
import Translation
import Combine

struct Translator: View {
    @ObservedObject var broadcaster: MessageBroadcaster
    @State private var configuration: TranslationSession.Configuration?
    @State private var input: String? = nil
    var body: some View {
        if let inp = broadcaster.inputText {
            Color.clear
                .onAppear(){
                    self.input = inp
                    triggerTranslation()
                }
        }
        Color.clear
            .translationTask(configuration) { session in
                do {
                    // Use the session the task provides to translate the text
                    let response = try await session.translate(self.input ?? "")
                    broadcaster.inputText = nil
                    broadcaster.outputText = response.targetText
                    broadcaster.finishedProcessing = true
                } catch {
                    print("Translating Error: " + String(describing: error))
                    broadcaster.outputText = nil
                    broadcaster.inputText = nil
                    broadcaster.finishedProcessing = true
                }
            }
    }
    private func triggerTranslation() {
        guard configuration == nil else {
            configuration?.invalidate()
            return
        }
        
        // Let the framework automatically determine the language pairing
        configuration = .init()
    }
}
class MessageBroadcaster: ObservableObject {
    @Published var inputText: String? = nil
    @Published var outputText: String? = nil
    @Published var finishedProcessing: Bool = false
}


