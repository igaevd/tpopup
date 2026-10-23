import AppKit
import Combine
import SwiftUI

/// One status line for the Settings window footer: the model editor publishes the state
/// of a connectivity test here, and `StatusFooterView` renders it next to the OK button,
/// where there is room for a long message plus copy / details controls.
@MainActor
final class StatusCenter: ObservableObject {
    enum Kind { case running, success, failure }

    struct Message: Equatable {
        let kind: Kind
        let text: String
    }

    @Published var message: Message?

    var isRunning: Bool { message?.kind == .running }

    func clearUnlessRunning() {
        if !isRunning { message = nil }
    }
}

struct StatusFooterView: View {
    @EnvironmentObject private var status: StatusCenter
    @State private var showingDetails = false

    var body: some View {
        if let message = status.message {
            HStack(alignment: .center, spacing: 8) {
                icon(for: message.kind)

                Text(message.text)
                    .font(.system(size: 11))
                    .foregroundStyle(color(for: message.kind))
                    .lineLimit(2)
                    .truncationMode(.tail)
                    .fixedSize(horizontal: false, vertical: true)
                    .contentShape(Rectangle())
                    .onTapGesture { showingDetails = true }
                    .help(message.kind == .running ? "" : "Click to see the full text")

                if message.kind != .running {
                    Button {
                        Clipboard.write(message.text)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.borderless)
                    .help("Copy the full message")

                    Button {
                        showingDetails = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Show the full message")
                    .popover(isPresented: $showingDetails, arrowEdge: .top) {
                        details(message)
                    }
                }
            }
        }
    }

    private func details(_ message: Message) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ScrollView {
                Text(message.text)
                    .font(.system(size: 12))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: 220)

            HStack {
                Spacer()
                Button {
                    Clipboard.write(message.text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 440)
    }

    private typealias Message = StatusCenter.Message

    @ViewBuilder
    private func icon(for kind: StatusCenter.Kind) -> some View {
        switch kind {
        case .running:
            ProgressView().controlSize(.small)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure:
            Image(systemName: "xmark.octagon.fill").foregroundStyle(.red)
        }
    }

    private func color(for kind: StatusCenter.Kind) -> Color {
        switch kind {
        case .running: return .secondary
        case .success: return .green
        case .failure: return .red
        }
    }
}
