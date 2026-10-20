import AVFoundation
import Foundation

/// Plays the synthesized sound pack in `Sounds/` (see tools/make_sounds.py).
///
/// Uses the *ambient* audio category: the sounds mix with the user's music
/// and are silenced by the ring/silent switch, like a polite game should.
final class SoundPlayer: ObservableObject {
    static let shared = SoundPlayer()

    enum Sound: String {
        case puff = "nfokh-puff"
        case tok = "piece-tok"
        case capture = "capture-clatter"
        case crown = "crown-chime"
        case win = "win"
        case lose = "lose"
    }

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "dama.soundMuted") }
    }

    private var players: [Sound: AVAudioPlayer] = [:]

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: "dama.soundMuted")
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
        for sound in [Sound.puff, .tok, .capture, .crown, .win, .lose] {
            guard let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav", subdirectory: "Sounds")
                ?? Bundle.main.url(forResource: sound.rawValue, withExtension: "wav")
            else { continue }
            let player = try? AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            players[sound] = player
        }
    }

    func play(_ sound: Sound) {
        guard !isMuted, let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }
}
