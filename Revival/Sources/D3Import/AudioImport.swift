// SPDX-License-Identifier: GPL-3.0-or-later
//
// Imports the voice streams and sound clips a level reaches, decoded to
// PCM16. Source provenance:
// - Descent3/streamaudio and DallasFuncs.cpp aSoundPlaySteamingText: a
//   stream file is opened through cfopen, so the first library in search
//   order that holds it wins (cfile/cfile.cpp:264).
// - sndlib/soundload.cpp: a sound page names its WAV file, opened the same
//   way, and its import volume.

import Foundation

enum AudioImportError: Error, Equatable {
    case missingStream(String)
    case missingSoundFile(page: String, file: String)
}

extension ImportSources {
    /// The streamed voice file of this name (an OSF), decoded.
    func voiceClip(named name: String) throws -> CanonicalVoiceClip {
        guard let (library, entry, index) = firstEntry(named: name) else {
            throw AudioImportError.missingStream(name)
        }
        let payload = library.payload(entry)
        let decoded = try decodeOSFACMVoice(payload)
        return CanonicalVoiceClip(
            sourceName: entry.sourceName.lowercased(),
            sourceEntryIndex: index,
            sampleRate: decoded.sampleRate,
            channelCount: decoded.channelCount,
            frameCount: decoded.frameCount,
            pcm16LittleEndian: decoded.pcm16LittleEndian,
            pcmSHA256: canonicalSHA256(decoded.pcm16LittleEndian),
            sourceArchive: library.relativePath,
            sourceSHA256: canonicalSHA256(payload)
        )
    }

    /// The WAV clip of a sound page, keyed by the page name.
    func soundClip(page: RetailSoundPageSelection) throws -> CanonicalSoundClip {
        guard let (library, entry, index) = firstEntry(named: page.sourceName)
        else {
            throw AudioImportError.missingSoundFile(
                page: page.logicalName,
                file: page.sourceName
            )
        }
        let payload = library.payload(entry)
        let decoded = try decodeReachedPCM16WAV(payload)
        return CanonicalSoundClip(
            logicalName: page.logicalName,
            sourceName: page.sourceName,
            sourceEntryIndex: index,
            sampleRate: decoded.sampleRate,
            channelCount: decoded.channelCount,
            frameCount: decoded.frameCount,
            pcm16LittleEndian: decoded.pcm16LittleEndian,
            pcmSHA256: canonicalSHA256(decoded.pcm16LittleEndian),
            sourceArchive: library.relativePath,
            sourceSHA256: canonicalSHA256(payload),
            importVolume: page.importVolume
        )
    }
}

/// The sound pages and clips of one import, each read and decoded once.
struct SoundImportCache {
    let sources: ImportSources
    private var pages: [String: RetailSoundPageSelection] = [:]
    private var clips: [String: CanonicalSoundClip] = [:]

    init(sources: ImportSources) {
        self.sources = sources
    }

    /// FindSoundName's page (stricmp).
    mutating func page(named name: String) throws -> RetailSoundPageSelection {
        let key = name.lowercased()
        if let page = pages[key] { return page }
        let page = try resolveRetailSoundPage(
            table: sources.table,
            overlay: sources.overlay,
            named: name
        )
        pages[key] = page
        return page
    }

    mutating func clip(named name: String) throws -> CanonicalSoundClip {
        let key = name.lowercased()
        if let clip = clips[key] { return clip }
        let clip = try sources.soundClip(page: page(named: name))
        clips[key] = clip
        return clip
    }
}

extension Level {
    /// The level with the voice streams and sound clips its level script
    /// names (LevelModule.scriptReferences), in that order, each once.
    func addingLevelScriptAudio(
        references: LevelScriptReferences,
        sources: ImportSources,
        sounds: inout SoundImportCache
    ) throws -> Level {
        var voices: [CanonicalVoiceClip] = []
        for name in references.streamedAudioNames {
            let clip = try sources.voiceClip(named: name)
            if !(voiceClips + voices).contains(where: {
                $0.sourceName == clip.sourceName
            }) {
                voices.append(clip)
            }
        }
        var clips: [CanonicalSoundClip] = []
        for name in references.soundNames {
            let clip = try sounds.clip(named: name)
            if !(soundClips + clips).contains(where: {
                $0.logicalName == clip.logicalName
            }) {
                clips.append(clip)
            }
        }
        return addingAudioClips(voiceClips: voices, soundClips: clips)
    }

    /// The level with the engine sounds (EngineSound): the static and named
    /// sounds the translated engine plays, which PageInAllData pages in
    /// (gamesequence.cpp:2481).
    func addingEngineSounds(sounds: inout SoundImportCache) throws -> Level {
        var added: [CanonicalSoundClip] = []
        for name in EngineSound.names {
            let clip = try sounds.clip(named: name)
            if !(soundClips + added).contains(where: {
                $0.logicalName == clip.logicalName
            }) {
                added.append(clip)
            }
        }
        return appendingSoundClips(added)
    }
}
