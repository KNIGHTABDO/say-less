import SwiftUI
import UIKit
import SayLessEngine

/// Every card from past conversations, grouped by day. Only on this phone.
struct ShoeboxView: View {
    @Environment(AppModel.self) private var model
    @State private var query = ""
    @State private var open: Card?

    private var days: [(day: Date, cards: [Card])] {
        let q = query.trimmingCharacters(in: .whitespaces)
        let list = model.history.cards.reversed().filter {
            q.isEmpty || $0.original.localizedCaseInsensitiveContains(q) || $0.translated.localizedCaseInsensitiveContains(q)
        }
        let groups = Dictionary(grouping: list) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted(by: >).map { ($0, groups[$0] ?? []) }
    }

    var body: some View {
        List {
            if model.history.cards.isEmpty {
                ContentUnavailableView("The shoebox is empty", systemImage: "tray",
                                       description: Text("Cards from your conversations land here."))
                    .listRowBackground(Color.clear)
            }
            ForEach(days, id: \.day) { group in
                Section(group.day.formatted(.dateTime.weekday(.wide).day().month(.wide))) {
                    ForEach(group.cards) { card in
                        Button { open = card } label: { row(card) }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) { model.history.delete(card) }
                                Button("Copy", systemImage: "doc.on.doc") { UIPasteboard.general.string = card.translated }
                                    .tint(Palette.sea)
                            }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background { LinenTable().ignoresSafeArea() }
        .searchable(text: $query, prompt: "Search your cards")
        .navigationTitle("Shoebox")
        .sheet(item: $open) { card in
            ShoeboxCard(card: card)
                .presentationDetents([.medium])
                .presentationBackground { LinenTable() }
        }
    }

    private func row(_ card: Card) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StampView(language: card.fromLanguage, size: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(card.translated).font(Fonts.card(17)).foregroundStyle(Palette.ink).lineLimit(3)
                Text(card.original).font(.footnote.italic()).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 0)
            Text(card.date, format: .dateTime.hour().minute())
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

/// One card out of the shoebox; long-press flips it like on the table.
private struct ShoeboxCard: View {
    @Environment(AppModel.self) private var model
    let card: Card
    @State private var flipped = false

    var body: some View {
        PostcardView(card: card, flipped: flipped, lifted: true, scale: model.cardTextScale) { slower in
            model.replay(card, slower: slower)
        }
        .padding(24)
        .rotationEffect(.degrees(card.tilt))
        .onLongPressGesture(minimumDuration: 0.3) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { flipped.toggle() }
            Haptics.move()
        }
    }
}
