import AVFoundation

// One sample for every key, played on keyDown with slight random rate/volume so it never sounds looped.
// pool of 4 players; overlapping fast typing beyond that just reuses the oldest.
enum KeySound {
    // Written by the @AppStorage toggle in the View menu.
    static var enabled: Bool { UserDefaults.standard.object(forKey: "typingSounds") as? Bool ?? true }
    private static let players: [AVAudioPlayer] = {
        guard let url = Bundle.main.url(forResource: "key", withExtension: "wav", subdirectory: "Sounds") else { return [] }
        return (0..<4).compactMap { _ in
            let p = try? AVAudioPlayer(contentsOf: url)
            p?.enableRate = true
            p?.prepareToPlay()
            return p
        }
    }()
    private static var next = 0

    static func play() {
        guard enabled, !players.isEmpty else { return }
        let p = players[next % players.count]; next += 1
        p.currentTime = 0
        p.rate = Float.random(in: 0.94...1.06)
        p.volume = Float.random(in: 0.7...1.0)
        p.play()
    }
}
