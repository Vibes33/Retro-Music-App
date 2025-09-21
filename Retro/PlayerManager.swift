//
//  PlayerManager.swift
//  Retro
//
//  Created by Ryan on 21/09/2025.
//

import AVFoundation
import SwiftUI
import Combine
import MediaPlayer

@MainActor
final class PlayerManager: NSObject, ObservableObject {
    @Published var currentTrack: Track?
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0

    @Published var isRepeatOne = false

    var canPlayNext: Bool {
        guard let i = currentIndex else { return false }
        return i + 1 < playlist.count
    }
    var canPlayPrevious: Bool {
        guard let i = currentIndex else { return false }
        return i > 0
    }

    var elapsedString: String { format(time: currentTime) }
    var remainingString: String { format(time: max(0, duration - currentTime), prefixMinus: true) }

    private func format(time: TimeInterval, prefixMinus: Bool = false) -> String {
        let t = Int(time.rounded())
        let m = t / 60
        let s = t % 60
        return (prefixMinus ? "-" : "") + String(format: "%d:%02d", m, s)
    }

    func toggleRepeatOne() { isRepeatOne.toggle() }

    @Published private(set) var playlist: [Track] = []
    @Published private(set) var currentIndex: Int? = nil

    private var player: AVAudioPlayer?
    private var timer: Timer?

    override init() {
        super.init()
        setupRemoteCommands()
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true, options: [])
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(currentTime / duration, 0), 1)
    }

    func play(track: Track) {
        stop()
        guard let url = try? AudioLibrary.absoluteURLForAudio(filename: track.filePath) else { return }
        do {
            configureAudioSession()
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()

            currentTrack = track
            duration = player?.duration ?? 0
            isPlaying = true
            updateNowPlayingInfo(for: track)
            startTicking()
        } catch {
            print("Play failed:", error)
            stop(resetTrack: true)
        }
    }

    func togglePlayPause() {
        guard let p = player else { return }
        if p.isPlaying { pause() } else { resume() }
    }

    func setQueue(_ tracks: [Track], startAt index: Int) {
        playlist = tracks
        guard !tracks.isEmpty else { currentIndex = nil; return }
        currentIndex = max(0, min(index, tracks.count - 1))
        playCurrent()
    }

    private func playCurrent() {
        guard let i = currentIndex, i >= 0, i < playlist.count else { return }
        let t = playlist[i]
        play(track: t)
    }

    func playNext() {
        guard let i = currentIndex else { return }
        let next = i + 1
        if next < playlist.count {
            currentIndex = next
            playCurrent()
        } else {
            stop()
        }
    }

    func playPrevious() {
        guard let i = currentIndex else { return }
        let prev = i - 1
        if prev >= 0 {
            currentIndex = prev
            playCurrent()
        } else {
            seek(toTime: 0)
        }
    }

    private func pause() {
        player?.pause()
        isPlaying = false
        pushNowPlayingProgress()
    }

    private func resume() {
        player?.play()
        isPlaying = true
        pushNowPlayingProgress()
    }

    func seek(to progress: Double) {
        guard let p = player, duration > 0 else { return }
        p.currentTime = duration * min(max(progress, 0), 1)
        currentTime = p.currentTime
        if isPlaying { p.play() }
    }

    func seek(toTime time: TimeInterval) {
        guard let p = player else { return }
        let clamped = max(0, min(time, duration))
        p.currentTime = clamped
        currentTime = clamped
        if isPlaying { p.play() }
        pushNowPlayingProgress()
    }

    func stop(resetTrack: Bool = false) {
        timer?.invalidate(); timer = nil
        player?.stop()
        player = nil
        isPlaying = false
        pushNowPlayingProgress()
        currentTime = 0
        duration = 0
        if resetTrack {
            currentTrack = nil
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        }
    }

    private func startTicking() {
        timer?.invalidate()
        let t = Timer.scheduledTimer(timeInterval: 0.2, target: self, selector: #selector(handleTick), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    @objc private func handleTick() {
        guard let p = player else { return }
        currentTime = p.currentTime
        pushNowPlayingProgress()
        if p.currentTime >= p.duration {
            if isRepeatOne {
                seek(toTime: 0)
                resume()
            } else {
                playNext()
            }
        }
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        center.togglePlayPauseCommand.removeTarget(nil)
        center.changePlaybackPositionCommand.removeTarget(nil)

        center.playCommand.isEnabled = true
        center.playCommand.addTarget { [weak self] _ in
            self?.resume(); return .success
        }
        center.pauseCommand.isEnabled = true
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause(); return .success
        }
        center.togglePlayPauseCommand.isEnabled = true
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.togglePlayPause(); return .success
        }

        center.changePlaybackPositionCommand.isEnabled = true
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self, let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(toTime: e.positionTime)
            return .success
        }

        center.nextTrackCommand.removeTarget(nil)
        center.previousTrackCommand.removeTarget(nil)

        center.nextTrackCommand.isEnabled = true
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.playNext(); return .success
        }
        center.previousTrackCommand.isEnabled = true
        center.previousTrackCommand.addTarget { [weak self] _ in
            self?.playPrevious(); return .success
        }
    }

    private func updateNowPlayingInfo(for track: Track) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyIsLiveStream: false,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
            MPNowPlayingInfoPropertyDefaultPlaybackRate: 1.0,
        ]

        if let art = track.artworkPath,
           let url = try? AudioLibrary.absoluteURLForArtwork(filename: art),
           let data = try? Data(contentsOf: url),
           let image = UIImage(data: data) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func pushNowPlayingProgress() {
        guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
}

extension PlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if isRepeatOne {
            seek(toTime: 0)
            resume()
        } else {
            playNext()
        }
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        stop(resetTrack: true)
    }
}
