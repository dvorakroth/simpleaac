//
//  ContentView.swift
//  simpleaac
//
//  Created by Amit Ron on 22/11/2022.
//

import Foundation
import SwiftUI
import AVFoundation
import Introspect

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
    @State var selectedVoice: (AVSpeechSynthesisVoice, String)
    
    @State var currentSpeakingScrollPosition: CGRect? = nil
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init() {
        voiceGroups = Self.groupAndLabelVoices()
        selectedVoice = Self.readSelectedVoice(voiceGroups: voiceGroups) ?? (voiceGroups[0].1[0], voiceGroups[0].0)
        
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
    
    static func readSelectedVoice(voiceGroups: [(String, [AVSpeechSynthesisVoice])]) -> (AVSpeechSynthesisVoice, String)? {
        let jsonIn = try? Data(contentsOf: Self.savedVoiceFilename)
        
        guard let jsonIn = jsonIn else { return nil }
        
        let jsonDict = try? JSONSerialization.jsonObject(with: jsonIn)
        
        guard let actualDict = jsonDict as? [String:String] else { return nil }
        guard let voiceName = actualDict["voice"] else { return nil }
        guard let langName  = actualDict["lang"]  else { return nil }
        
        var bestMatch: (AVSpeechSynthesisVoice, String)? = nil
        
        for (groupName, voices) in voiceGroups {
            for voice in voices {
                if voice.language == langName && voice.name == voiceName {
                    bestMatch = (voice: voice, languagePretty: groupName)
                    break // perfect match found! end here
                } else if bestMatch == nil && voice.language == langName {
                    // if it's not the correct voice, but at least the correct language
                    // (but still keep going in case we find the right one)
                    bestMatch = (voice: voice, languagePretty: groupName)
                }
            }
        }
        
        return bestMatch
    }
    
    static func dismissKeyboard() {
        UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.endEditing(true) // 4
    }
    
    var body: some View {
        VStack {
            HStack {
                let v = selectedVoice
                Menu(v.0.name + " (" + v.1 + ")") {
                    ForEach(Array(voiceGroups.enumerated()), id: \.0) { (groupIdx, g) in
                        let (groupName, voices) = g
                        
                        Menu(groupName) {
                            ForEach(Array(voices.enumerated()), id: \.0) { (voiceIdx, voice) in
                                Button() {
                                    self.selectedVoice = (voice, groupName)
                                    Self.saveSelectedVoice(voice)
                                } label: {
                                    if (self.selectedVoice.0 == voice) {
                                        Image(systemName: "checkmark")
                                    }
                                    
                                    Text(voice.name)
                                }
                            }
                        }
                    }
                }
                
                let buttonTitle = synthDelegate.isSpeaking ? "❌" : "🔊"
                
                Button(buttonTitle) {
                    if synthDelegate.isSpeaking {
                        synth.stopSpeaking(at: .immediate)
                    } else {
                        Self.dismissKeyboard()
                        
                        let u = AVSpeechUtterance(string: currentText)
                        u.voice = selectedVoice.0
                        Self.setAudioSessionActive(true)
                        synth.speak(u)
                    }
                }
            }
            
            var highlightedText: AttributedString? = nil
            
            if synthDelegate.isSpeaking {
                let _ = (highlightedText = AttributedString(stringLiteral: currentText))

                if let r = synthDelegate.speakingRange {
                    // what. the. eff. apple. why is it so bureaucratically intensive to get a range of an attributed string,,,,,,
                    let lower = highlightedText!.index(highlightedText!.startIndex, offsetByCharacters: r.lowerBound)
                    let upper = highlightedText!.index(highlightedText!.startIndex, offsetByCharacters: r.upperBound - 1)

                    let _ = highlightedText![lower...upper].backgroundColor = .yellow
                }
            }
            
            let isRtl = Locale.characterDirection(forLanguage: selectedVoice.0.language) == .rightToLeft
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $currentText)
                    .focused($textInFocus)
                    .disabled(synthDelegate.isSpeaking)
                    .font(.custom("Helvetica", size: 50))
                    .padding(.all)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topLeading)
                    .introspectTextView(customize: { uiTextView in
                        if synthDelegate.isSpeaking {
                            if let r = synthDelegate.speakingRange {
                                // aaaaallllllllll of this:
                                let pos1 = uiTextView.position(from: uiTextView.beginningOfDocument, offset: r.lowerBound)
                                let pos2 = uiTextView.position(from: uiTextView.beginningOfDocument, offset: r.upperBound - 1)
                                
                                guard let pos1 = pos1, let pos2 = pos2 else { return; }
                                
                                let range = uiTextView.textRange(from: pos1, to: pos2)
                                guard let range = range else { return; }
                                
                                let rect1 = uiTextView.firstRect(for: range)
                                // ^^^^^^^ up to here,
                                // is just apple's way of saying: "get me the first CGRect for enclosing all of the characters in range r"
                                
                                let visibleBounds = CGRect(origin: uiTextView.contentOffset, size: uiTextView.bounds.size)
                                if (rect1.maxY >= visibleBounds.maxY || rect1.maxY <= visibleBounds.minY) {
                                    currentSpeakingScrollPosition = CGRect(origin: rect1.origin, size: visibleBounds.size)
                                    uiTextView.scrollRectToVisible(currentSpeakingScrollPosition!, animated: false)
                                }
                            }
                        } else {
                            if currentSpeakingScrollPosition != nil {
                                // haha imperative code go brrrrr
                                currentSpeakingScrollPosition = nil
                            }
                        }
                    })
                    .toolbar {
                        ToolbarItem(placement: .keyboard) {
                            Button(action: { Self.dismissKeyboard() }) {
                                Label("", systemImage: "keyboard.chevron.compact.down")
                            }
                        }
                    }
                
                if synthDelegate.isSpeaking {
                    weak var scrollViewRef: UIScrollView? = nil
                    let paddingTop = 19.0
                
                    ScrollView(.vertical) {
                        Text(highlightedText!)
                            .font(.custom("Helvetica", size: 50))
                            .padding(.top, paddingTop)
                            .padding(.leading, 21)
                            .padding(.trailing, 21)
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .topLeading)
                    }
                        .background(.black)
                        .introspectScrollView(customize: { uiScrollView in
                            scrollViewRef = uiScrollView // haha reactjs lol
                        })
                        .onChange(of: currentSpeakingScrollPosition, perform: { newValue in
                            if var newValue = newValue {
                                newValue.origin.y += paddingTop + 6 // upside down smiley face this is fine dot jpeg
                                scrollViewRef?.scrollRectToVisible(newValue, animated: !reduceMotion)
                            }
                        })
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
