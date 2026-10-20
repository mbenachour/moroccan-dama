import SwiftUI
import DamaEngine

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @ObservedObject private var sound = SoundPlayer.shared
    @State private var showingRules = false
    @State private var confirmingNewGame = false
    @State private var pendingVariantSwitch: GameVariant?

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.93, blue: 0.84).ignoresSafeArea()

            VStack(spacing: 14) {
                header
                capturedRow
                modeRow
                BoardView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                statusPill
                calloutPill
                huffBanner
                pendingOptions
                controls
                Spacer(minLength: 0)
            }
            .padding(.top, 10)
        }
        .sheet(isPresented: $showingRules) { RulesView() }
        .confirmationDialog("Start a new game?", isPresented: $confirmingNewGame) {
            Button("New game", role: .destructive) { viewModel.newGame() }
            Button("Keep playing", role: .cancel) {}
        }
        .confirmationDialog(
            "Switch mode and start a new game?",
            isPresented: Binding(
                get: { pendingVariantSwitch != nil },
                set: { if !$0 { pendingVariantSwitch = nil } }
            )
        ) {
            Button("Switch to \(pendingVariantSwitch == .cafe ? "Café" : "Tournament")") {
                if let pendingVariantSwitch { viewModel.setVariant(pendingVariantSwitch) }
                pendingVariantSwitch = nil
            }
            Button("Keep playing", role: .cancel) { pendingVariantSwitch = nil }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Dama")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.11))
                Text("Moroccan Checkers")
                    .font(.subheadline)
                    .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.28))
            }
            Spacer()
            Button {
                sound.isMuted.toggle()
            } label: {
                Image(systemName: sound.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title3)
                    .foregroundStyle(Color(red: 0.48, green: 0.32, blue: 0.18))
            }
            .accessibilityLabel(sound.isMuted ? "Unmute sounds" : "Mute sounds")
            Button {
                showingRules = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
                    .foregroundStyle(Color(red: 0.48, green: 0.32, blue: 0.18))
            }
            .accessibilityLabel("How to play")
        }
        .padding(.horizontal, 16)
    }

    // MARK: Mode switch

    private var modeRow: some View {
        HStack(spacing: 0) {
            ForEach(GameVariant.allCases, id: \.self) { variant in
                Button {
                    requestVariant(variant)
                } label: {
                    Text(variant == .cafe ? "☕ Café" : "Tournament")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .foregroundStyle(viewModel.variant == variant
                                         ? Color.white
                                         : Color(red: 0.48, green: 0.32, blue: 0.18))
                        .background(
                            Capsule().fill(viewModel.variant == variant
                                           ? Color(red: 0.62, green: 0.38, blue: 0.20)
                                           : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(Color.white.opacity(0.6)))
        .padding(.horizontal, 16)
    }

    private func requestVariant(_ variant: GameVariant) {
        guard variant != viewModel.variant else { return }
        if viewModel.game.history.isEmpty {
            viewModel.setVariant(variant)
        } else {
            pendingVariantSwitch = variant
        }
    }

    // MARK: Café callouts

    @ViewBuilder
    private var calloutPill: some View {
        if let callout = viewModel.callout {
            Text(callout)
                .font(.footnote.weight(.bold))
                .foregroundStyle(Color.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color(red: 0.62, green: 0.38, blue: 0.20)))
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private var huffBanner: some View {
        if viewModel.awaitingHumanHuff {
            HStack(spacing: 10) {
                Text("💨 Tap a glowing piece to blow it off — or let Dama keep it:")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.11))
                Button("Let it slide") { viewModel.declineHumanHuff() }
                    .buttonStyle(.bordered)
                    .tint(Color(red: 0.48, green: 0.32, blue: 0.18))
            }
            .padding(.horizontal, 16)
        }
    }

    private var capturedRow: some View {
        HStack {
            capturedTray(label: "You captured", count: viewModel.capturedByHuman, color: .black)
            Spacer()
            capturedTray(label: "Dama captured", count: viewModel.capturedByAI, color: .white)
        }
        .padding(.horizontal, 16)
    }

    private func capturedTray(label: String, count: Int, color: PlayerColor) -> some View {
        HStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(color == .black ? Color(red: 0.12, green: 0.08, blue: 0.05)
                                          : Color(red: 0.98, green: 0.95, blue: 0.88))
                    .overlay(Circle().stroke(Color.brown.opacity(0.5), lineWidth: 1))
                    .frame(width: 18, height: 18)
            }
            Text("\(label): \(count)")
                .font(.footnote.weight(.medium))
                .foregroundStyle(Color(red: 0.48, green: 0.38, blue: 0.28))
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if viewModel.isAIThinking {
                ProgressView().controlSize(.small)
            }
            Text(viewModel.statusText)
                .font(.headline)
                .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.11))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(Color.white.opacity(0.75)))
    }

    @ViewBuilder
    private var pendingOptions: some View {
        if !viewModel.pendingOptions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Two capture lines land there — which pieces do you take?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color(red: 0.23, green: 0.16, blue: 0.11))
                ForEach(Array(viewModel.pendingOptions.enumerated()), id: \.offset) { _, move in
                    Button {
                        viewModel.choosePendingOption(move)
                    } label: {
                        Text(move.choiceLabel)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var controls: some View {
        VStack(spacing: 10) {
            // Custom segmented control: the system Picker resolves its
            // colors from the device appearance, which washed the labels
            // out against this app's fixed café palette. Explicit colors
            // read identically in light and dark mode.
            HStack(spacing: 0) {
                ForEach(DamaAI.Difficulty.allCases, id: \.self) { level in
                    Button {
                        viewModel.difficulty = level
                    } label: {
                        Text(level.displayName)
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(viewModel.difficulty == level
                                             ? Color.white
                                             : Color(red: 0.48, green: 0.32, blue: 0.18))
                            .background(
                                Capsule().fill(viewModel.difficulty == level
                                               ? Color(red: 0.48, green: 0.32, blue: 0.18)
                                               : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(Capsule().fill(Color.white.opacity(0.6)))
            .padding(.horizontal, 16)

            HStack(spacing: 12) {
                Button {
                    if viewModel.game.history.isEmpty {
                        viewModel.newGame()
                    } else {
                        confirmingNewGame = true
                    }
                } label: {
                    Label("New game", systemImage: "arrow.counterclockwise")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color(red: 0.48, green: 0.32, blue: 0.18)))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.undoRound()
                } label: {
                    Label("Take back", systemImage: "arrow.uturn.backward")
                        .font(.headline)
                        .foregroundStyle(Color(red: 0.48, green: 0.32, blue: 0.18))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.white.opacity(0.75)))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canUndo)
                .opacity(viewModel.canUndo ? 1 : 0.45)
            }
        }
    }
}

/// The Moroccan rules, in short — the same summary shipped in the repo README.
struct RulesView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("The board") {
                    Text("8×8 board, 12 pieces each. You play White and move first. The board is mirrored the Moroccan way: the double corner is on your left.")
                    Text("Pieces only travel on the dark squares, diagonally.")
                }
                Section("Men") {
                    Text("A man moves one square diagonally forward, and captures diagonally forward only — never backward.")
                    Text("Reaching the far row crowns the piece into a dama (a flying king). If it gets there during a capture, the move stops — it does not keep capturing that turn.")
                }
                Section("Captures — the heart of dama") {
                    Text("Capturing is mandatory. If you can take pieces, you cannot make a quiet move.")
                    Text("You must take the longest line: if a move captures 3 pieces and another captures 1, the 3-piece line is the only legal move.")
                    Text("Multi-captures chain in one turn, turning corners as needed.")
                }
                Section("Café Mode — the Moroccan café rules") {
                    Text("In Café Mode the pieces are bottle caps, and the old café laws apply. Captures work differently here:")
                    Text("Nothing is forced. You may play ANY move — a quiet step, or a smaller capture with another piece — even when a bigger capture is available. (A piece that starts capturing still finishes its whole chain.)")
                    Text("Nefkh (نفخ) — 'blowing': end your turn having taken less than the best capture available, and your opponent blows one of the pieces that should have captured clean off the board before moving. Pfff — gone. It happens every time; there is no letting it slide.")
                    Text("Koul (كول) — 'Eat!': the call that goes with it. If a capture is there, eat — or get blown.")
                    Text("Yeddak 3la lbidaq (يداك على البيدق) — touch-move: touch one of your pieces and you must play it. No switching.")
                }
                Section("The dama (king)") {
                    Text("A dama flies: it moves any distance along an open diagonal, captures from far away, and can land on any empty square beyond the piece it takes.")
                }
                Section("Winning") {
                    Text("Capture all of Dama's pieces, or block them so they have no legal move.")
                    Text("Draws: the same position three times, or 40 moves by each side with no capture and no man moving.")
                }
            }
            .navigationTitle("How to play")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
