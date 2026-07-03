import SwiftUI
import AppKit

struct ContentView: View {

    @State private var selectedFile = "No file selected"

    var body: some View {

        VStack(spacing: 20) {

            Text("K1 Atlas")
                .font(.largeTitle)
                .bold()

            Text("Modern Patch Librarian")
                .foregroundStyle(.secondary)

            RoundedRectangle(cornerRadius: 12)
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .frame(width: 400, height: 180)
                .overlay {

                    VStack(spacing: 12) {

                        Image(systemName: "square.and.arrow.down")
                            .font(.system(size: 40))

                        Text("Drop .syx files here")

                        Button("Open File") {
                            openFile()
                        }
                    }
                }

            Divider()

            Text(selectedFile)
                .font(.headline)

            Spacer()

        }
        .padding(40)
        .frame(minWidth: 700, minHeight: 500)

    }

    func openFile() {

        let panel = NSOpenPanel()

        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        if panel.runModal() == .OK {

            if let url = panel.url {

                selectedFile = url.lastPathComponent

            }

        }

    }

}

#Preview {
    ContentView()
}
