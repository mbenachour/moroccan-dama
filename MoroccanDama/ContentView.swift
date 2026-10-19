import SwiftUI
import DamaEngine

struct ContentView: View {
    @StateObject private var viewModel = GameViewModel()
    @State private var showingRules = false
    @State private var confirmingNewGame = false

    var body: some View {
        ZStack {
            Color(red: 0.97, green: 0.93, blue: 0.84).ignoresSafeArea()

            VStack(spacing: 14) {
                header
                capturedRow
                BoardView(viewModel: viewModel)
                    .padding(.horizontal, 12)
                statusPill
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
    }

    // MARK: Sections

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text("Dama")
                    .font(.largeTitle.bold())
                Text("Moroccan Checkers")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showingRules = true
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.title2)
            }
            .accessibilityLabel("How to play")
        }
        .padding(.horizontal, 16)
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
                .foregroundStyle(.secondary)
        }
    }

    private var statusPill: some View {
        HStack(spacing: 8) {
            if viewModel.isAIThinking {
                ProgressView().controlSize(.small)
            }
            Text(viewModel.statusText)
                .font(.headline)
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
            Picker("Difficulty", selection: $viewModel.difficulty) {
                ForEach(DamaAI.Difficulty.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            .pickerStyle(.segmented)
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
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.undoRound()
                } label: {
                    Label("Take back", systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .disabled(!viewModel.canUndo)
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
