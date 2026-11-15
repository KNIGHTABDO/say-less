import SwiftUI
import UIKit
import SayLessEngine

@main
struct SayLessApp: App {
    @State private var model = AppModel()
    @State private var updates = Updates()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .environment(updates)
                .preferredColorScheme(model.appearance == 1 ? .light : model.appearance == 2 ? .dark : nil)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)) { _ in
                    model.memoryWarning()
                }
                .task { await updates.checkIfDue() }
        }
    }
}

/// The linen table, with either the first postcard or the conversation on it.
struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(Updates.self) private var updates
    @Environment(\.openURL) private var openURL

    var body: some View {
        @Bindable var model = model
        ZStack {
            LinenTable().ignoresSafeArea()
            if model.onboarded {
                ConversationView()
                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            } else {
                OnboardingView()
                    .transition(.asymmetric(insertion: .opacity, removal: .move(edge: .top).combined(with: .opacity)))
            }
        }
        .animation(.settle, value: model.onboarded)
        .alert("Sorry about that", isPresented: Binding(get: { model.crashNote != nil }, set: { if !$0 { model.crashNote = nil } })) {
            Button("OK") { model.crashNote = nil }
        } message: {
            Text(model.crashNote ?? "")
        }
        .overlay(alignment: .top) {
            if model.onboarded, updates.isNewer, let tag = updates.latest?.tag_name, !dismissedUpdate {
                Button {
                    if let url = updates.installURL { openURL(url) }
                } label: {
                    Label("Say Less \(tag) is out", systemImage: "arrow.down.circle.fill")
                        .font(Fonts.label(14))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.glass)
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
                .task {
                    try? await Task.sleep(for: .seconds(8))
                    withAnimation { dismissedUpdate = true }
                }
            }
        }
    }

    @State private var dismissedUpdate = false
}
