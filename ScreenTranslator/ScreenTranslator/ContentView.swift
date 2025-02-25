import SwiftUI
import Translation

struct ContentView: View {
    var nsImage: NSImage
    
    
    var body: some View {
        GeometryReader { geometry in
            VStack {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .onAppear() {
                        print(geometry.size)
                    }
            }
            //.frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
