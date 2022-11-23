//
//  ContentView.swift
//  simpleaac
//
//  Created by Amit Ron on 22/11/2022.
//

import Foundation
import SwiftUI
import AVFoundation

struct VoiceIndex: Hashable, Equatable {
    var _0: Int
    var _1: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(self._0)
        hasher.combine(self._1)
    }
    
    static func ==(lhs: VoiceIndex, rhs: VoiceIndex) -> Bool {
        return lhs._0 == rhs._0 && lhs._1 == rhs._1
    }
}

enum VoiceListEntry: Hashable {
    case group(name: String, defaultVoiceIdx: VoiceIndex)
    case voice(voice: AVSpeechSynthesisVoice, idx: VoiceIndex)
    
    func hash(into hasher: inout Hasher) {
        switch(self) {
        case let .group(name: name, defaultVoiceIdx: defaultVoiceIdx):
            hasher.combine(0)
            hasher.combine(name)
            hasher.combine(defaultVoiceIdx)
        case let .voice(voice: voice, idx: idx):
            hasher.combine(1)
            hasher.combine(voice.name)
            hasher.combine(idx)
        }
    }
}

struct ContentView: View {
    @State var currentText: String = ""
    @FocusState var textInFocus: Bool
    
    let synth = AVSpeechSynthesizer()
    @ObservedObject var synthDelegate = SpeechSynthDelegate()
    
    let voiceGroups: [(String, [AVSpeechSynthesisVoice])]
    let voiceGroupsFlat: [VoiceListEntry]
    @State var selectedVoiceIdx: VoiceIndex
    var selectedVoice: AVSpeechSynthesisVoice {
        get {
            voiceGroups[selectedVoiceIdx._0].1[selectedVoiceIdx._1]
        }
    }
    
    init() {
        voiceGroups = Self.groupAndLabelVoices()
        voiceGroupsFlat = Self.flattenVoiceGroups(voiceGroups)
        selectedVoiceIdx = Self.readSelectedVoice(voiceGroups: voiceGroups) ?? VoiceIndex(_0: 0, _1: 0)
        
        synth.delegate = synthDelegate
        
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
        }
        catch let error as NSError {
            print("Error: Could not set audio category: \(error), \(error.userInfo)")
        }
    }
    
    static func setAudioSessionActive(_ active: Bool) {
        do {
            try AVAudioSession.sharedInstance().setActive(active)
        }
        catch let error as NSError {
            print("Error: Could not setActive to \(active): \(error), \(error.userInfo)")
        }
    }
    
    static func flattenVoiceGroups(_ voiceGroups: [(String, [AVSpeechSynthesisVoice])]) -> [VoiceListEntry] {
        // (sigh)
        var result: [VoiceListEntry] = []
        
        for (groupIdx, (groupName, voices)) in voiceGroups.enumerated() {
            result.append(.group(name: groupName, defaultVoiceIdx: VoiceIndex(_0: groupIdx, _1: 0)))
            
            for (voiceIdx, voice) in voices.enumerated() {
                result.append(.voice(voice: voice, idx: VoiceIndex(_0: groupIdx, _1: voiceIdx)))
            }
        }
        
        return result
    }
    
    static func groupAndLabelVoices() -> [(String, [AVSpeechSynthesisVoice])] {
        let rawVoices = AVSpeechSynthesisVoice.speechVoices()
        
        var groups: [String: [String: [AVSpeechSynthesisVoice]]] = [:]
        
        for voice in rawVoices {
            let locale = Locale(identifier: voice.language)
            
            let languageName = locale.localizedString(forLanguageCode: voice.language) ?? ""
            let regionName = locale.regionCode == nil ? "" : (locale.localizedString(forRegionCode: locale.regionCode!) ?? "")
            
            if groups[languageName] == nil {
                groups[languageName] = [:]
            }
            
            if groups[languageName]![regionName] == nil {
                groups[languageName]![regionName] = []
            }
            groups[languageName]![regionName]!.append(voice)
        }
        
        var finalOrdered: [(String, [AVSpeechSynthesisVoice])] = []
        
        let sortedGroups = groups.sorted(by: { a, b in a.key < b.key })
        
        for (languageName, subgroups) in sortedGroups {
            let addRegionName = subgroups.count > 1
            
            let sortedSubgroups = subgroups.sorted(by: { a, b in a.key < b.key })
            
            for (regionName, voices) in sortedSubgroups {
                let prettyLangName = addRegionName ? (
                    languageName + " (" + regionName + ")"
                ) : languageName
                
                let sortedVoices = voices.sorted(by: { a, b in a.name < b.name })
                
                finalOrdered.append((prettyLangName, sortedVoices))
            }
        }
        
        return finalOrdered
    }
    
    static var savedVoiceFilename: URL {
        get {
            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            return documentDirectory.appendingPathComponent("selectedVoice.json")
        }
    }
    
    static func saveSelectedVoice(_ selectedVoice: AVSpeechSynthesisVoice) {
        let jsonOut = try? JSONSerialization.data(withJSONObject: [
            "voice": selectedVoice.name,
            "lang": selectedVoice.language
        ])
        
        if jsonOut != nil {
            try? jsonOut!.write(to: Self.savedVoiceFilename)
        }
    }
    
    static func readSelectedVoice(voiceGroups: [(String, [AVSpeechSynthesisVoice])]) -> VoiceIndex? {
        let jsonIn = try? Data(contentsOf: Self.savedVoiceFilename)
        
        guard let jsonIn = jsonIn else { return nil }
        
        let jsonDict = try? JSONSerialization.jsonObject(with: jsonIn)
        
        guard let actualDict = jsonDict as? [String:String] else { return nil }
        guard let voiceName = actualDict["voice"] else { return nil }
        guard let langName  = actualDict["lang"]  else { return nil }
        
        var bestIndex: VoiceIndex? = nil
        
        for (groupIdx, (_, voices)) in voiceGroups.enumerated() {
            for (voiceIdx, voice) in voices.enumerated() {
                if voice.language == langName && voice.name == voiceName {
                    bestIndex = VoiceIndex(_0: groupIdx, _1: voiceIdx)
                    break // perfect match found! end here
                } else if bestIndex == nil && voice.language == langName {
                    // if it's not the correct voice, but at least the correct language
                    // (but still keep going in case we find the right one)
                    bestIndex = VoiceIndex(_0: groupIdx, _1: voiceIdx)
                }
            }
        }
        
        return bestIndex
    }
    
    static func dismissKeyboard() {
      UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.endEditing(true) // 4
    }
    
    var body: some View {
        VStack {
            HStack {
                let pickerBinding = Binding<VoiceListEntry>(get: {
                    .voice(voice: selectedVoice, idx: selectedVoiceIdx)
                }) {
                    switch $0 {
                    case let .voice(voice: _, idx: idx):
                        self.selectedVoiceIdx = idx
                    case let .group(name: _, defaultVoiceIdx: idx):
                        self.selectedVoiceIdx = idx
                    }
                    
                    Self.saveSelectedVoice(selectedVoice)
                }
                Picker("Select Voice", selection: pickerBinding) {
                    ForEach(voiceGroupsFlat, id: \.self) {
                        switch $0 {
                        case let .group(name: name, defaultVoiceIdx: _):
                            Text("--" + name + "--").foregroundColor(.gray) // (sigh)
                        case let .voice(voice: voice, idx: _):
                            Text(voice.name)
                        }
                    }
                }.pickerStyle(.menu)
                
                let buttonTitle = synthDelegate.isSpeaking ? "❌" : "🔊"
                
                Button(buttonTitle) {
                    if synthDelegate.isSpeaking {
                        synth.stopSpeaking(at: .immediate)
                    } else {
                        Self.dismissKeyboard()
                        
                        let u = AVSpeechUtterance(string: currentText)
                        u.voice = selectedVoice
                        Self.setAudioSessionActive(true)
                        synth.speak(u)
                    }
                }
            }
            
            let isRtl = Locale.characterDirection(forLanguage: selectedVoice.language) == .rightToLeft
            
            ZStack(alignment: .topLeading) {
                if synthDelegate.isSpeaking {
                    var highlightedText = AttributedString(stringLiteral: currentText)
                    
                    if let r = synthDelegate.speakingRange {
                        // what. the. eff. apple. why is it so bureaucratically intensive to get a range of an attributed string,,,,,,
                        let lower = highlightedText.index(highlightedText.startIndex, offsetByCharacters: r.lowerBound)
                        let upper = highlightedText.index(highlightedText.startIndex, offsetByCharacters: r.upperBound - 1)
                        
                        let _ = highlightedText[lower...upper].backgroundColor = .yellow
                    }
                        
                    Text(highlightedText)
                        .font(.custom("Helvetica", size: 50))
                        .padding(.top, 24)
                        .padding(.leading, 21)
                        .padding(.trailing, 21)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .topLeading)
                }
                
                TextEditor(text: $currentText)
                    .focused($textInFocus)
                    .disabled(synthDelegate.isSpeaking)
                    .font(.custom("Helvetica", size: 50))
                    .padding(.all)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topLeading)
                    .toolbar {
                        ToolbarItem(placement: .keyboard) {
                            Button(action: { Self.dismissKeyboard() }) {
                                Label("", systemImage: "keyboard.chevron.compact.down")
                            }
                        }
                    }
                
                if currentText.isEmpty {
                    Text("type here")
                        .font(.custom("Helvetica", size: 50))
                        .padding(.top, 24)
                        .padding(.leading, 21)
                        .padding(.trailing, 21)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .topLeading)
                        .opacity(0.3)
                        .onTapGesture {
                            textInFocus = true
                        }
                }
            }.environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct VoiceWrapper {
    let voice: AVSpeechSynthesisVoice
    let languageName: String
    
    var prettyName: String {
        get {
            voice.name + " (" + languageName + ")"
        }
    }
}

class SpeechSynthDelegate: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var speakingRange: NSRange? = nil
    @Published var isSpeaking: Bool = false
    
//    init() {}
    
//    init(speakingRange: Binding<NSRange?>, isSpeaking: Binding<Bool>) {
//        _speakingRange = speakingRange;
//        _isSpeaking = isSpeaking;
//    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        speakingRange = characterRange
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        isSpeaking = true
        speakingRange = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        // pass
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingRange = nil
        
        deferDeactiveAudioSession()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingRange = nil
        
        deferDeactiveAudioSession()
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
    
    func deferDeactiveAudioSession() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self != nil && !self!.isSpeaking {
                ContentView.setAudioSessionActive(false)
            }
        }
    }
}
