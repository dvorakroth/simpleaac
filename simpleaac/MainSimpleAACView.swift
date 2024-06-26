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

struct MainSimpleAACView: View {
    @State var currentText: String = ""
    @FocusState var textInFocus: Bool
    
    let synth = AVSpeechSynthesizer()
    @ObservedObject var synthDelegate = SpeechSynthDelegate()
    
    let voiceGroups: [(String, [AVSpeechSynthesisVoice])]
    @State var selectedVoice: (AVSpeechSynthesisVoice, String)
    @State var isShowingAboutBox = false
    
    @State var currentSpeakingScrollPosition: CGRect? = nil
    
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    init(voices rawVoices: [AVSpeechSynthesisVoice]) {
        voiceGroups = Self.groupAndLabelVoices(rawVoices)
        selectedVoice = Self.readSelectedVoice(voiceGroups: voiceGroups) ?? Self.chooseDefaultVoice(voiceGroups: voiceGroups)
        
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
    
    static func groupAndLabelVoices(_ rawVoices: [AVSpeechSynthesisVoice]) -> [(String, [AVSpeechSynthesisVoice])] {
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
            "voiceId": selectedVoice.identifier,
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
        let voiceName = actualDict["voice"]
        let voiceId = actualDict["voiceId"]
        guard let langName  = actualDict["lang"]  else { return nil }
        
        if voiceName == nil && voiceId == nil {
            return nil
        }
        
        var bestMatch: (AVSpeechSynthesisVoice, String)? = nil
        
        for (groupName, voices) in voiceGroups {
            for voice in voices {
                if voice.language == langName && (voice.identifier == voiceId || (voiceId == nil && voice.name == voiceName)) {
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
    
    static func chooseDefaultVoice(voiceGroups: [(String, [AVSpeechSynthesisVoice])]) -> (AVSpeechSynthesisVoice, String) {
        var nonExactGroups: [(String, [AVSpeechSynthesisVoice])] = []
        
        let langaugeCode = Locale.current.languageCode
        let regionCode   = Locale.current.regionCode
        
        for (groupName, voices) in voiceGroups {
            let firstVoice = voices[0]
            
            let groupLocale = Locale(identifier: firstVoice.language)
            
            if groupLocale.languageCode == langaugeCode {
                if groupLocale.regionCode == regionCode {
                    // this is the exact locale we want!
                    return (getFirstVoiceEnhanced(voices) ?? voices[0], groupName)
                } else {
                    nonExactGroups.append((groupName, voices))
                }
            }
        }
        
        if nonExactGroups.count > 0 {
            // we couldn't find a voice group for the exact language+region combination that the user has as their system language
            // but we DO have a list of groups in their system language but from other regions
            
            // so first we rummage through and try to find the first enhanced voice in there
            for (groupName, voices) in nonExactGroups {
                if let firstEnhanced = getFirstVoiceEnhanced(voices) {
                    return (firstEnhanced, groupName)
                }
            }
            
            // and failing that we just return the first voice from the first group
            return (nonExactGroups[0].1[0], nonExactGroups[0].0)
            
        } else if let defaultVoice = AVSpeechSynthesisVoice.init(language: AVSpeechSynthesisVoice.currentLanguageCode()) ?? AVSpeechSynthesisVoice.init(language: "en-US") {
            // otherwise try some defaults
            let voiceLocale = defaultVoice.language
            let voiceLanguageName = Locale(identifier: voiceLocale).localizedString(forLanguageCode: voiceLocale) ?? voiceLocale
            return (defaultVoice, voiceLanguageName)
            
        } else {
            // if even that fails,,,,, just pick the first one and hope for the best
            return (voiceGroups[0].1[0], voiceGroups[0].0)
        }
    }
    
    static func getFirstVoiceEnhanced(_ voices: [AVSpeechSynthesisVoice]) -> AVSpeechSynthesisVoice? {
        if #available(iOS 16.0, *) {
            for v in voices {
                if v.quality == .enhanced || v.quality == .premium {
                    return v
                }
            }
        } else {
            for v in voices {
                if v.quality == .enhanced {
                    return v
                }
            }
        }
        
        // no enhanced voices found
        return nil
    }
    
    static func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    var body: some View {
        VStack {
            HStack {
                Button() {
                    isShowingAboutBox.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                }.sheet(isPresented: $isShowingAboutBox) {
                    AboutView(showModal: $isShowingAboutBox)
                }.disabled(synthDelegate.isSpeaking)
                
                let v = selectedVoice
                Menu("\(v.1)\n\(v.0.name)") {
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
                .disabled(synthDelegate.isSpeaking)
                
                let buttonTitle = synthDelegate.isSpeaking ? "❌" : "🔊"
                
                Button(buttonTitle) {
                    if synthDelegate.isSpeaking {
                        synth.stopSpeaking(at: .immediate)
                    } else {
                        Self.dismissKeyboard()
                        
                        let u = AVSpeechUtterance(string: currentText)
                        u.voice = selectedVoice.0
                        
                        synthDelegate.isSpeaking = true // we set this early so that any pending audio session closures won't interfere
//                        Self.setAudioSessionActive(true)
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            synth.speak(u)
                        }
                    }
                }
            }
            
            var highlightedText: AttributedString? = nil
            
            if synthDelegate.isSpeaking {
                let _ = (highlightedText = AttributedString(stringLiteral: currentText))

                if let (lowerInt, upperInt) = synthDelegate.speakingRange {
                    let lower = highlightedText!.index(highlightedText!.startIndex, offsetByUnicodeScalars: lowerInt)
                    let upper = highlightedText!.index(highlightedText!.startIndex, offsetByUnicodeScalars: upperInt)
                    
                    let _ = highlightedText![lower...upper].backgroundColor = .yellow
                }
            }
            
            let isRtl = Locale.characterDirection(forLanguage: selectedVoice.0.language) == .rightToLeft
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $currentText)
                    .focused($textInFocus)
                    .disabled(synthDelegate.isSpeaking)
                    .font(.custom("Helvetica", size: 35))
                    .padding(.all)
                    .frame(maxWidth: .infinity,
                           maxHeight: .infinity,
                           alignment: .topLeading)
                    .introspectTextView(customize: { uiTextView in
                        if synthDelegate.isSpeaking {
                            if let (lowerInt, upperInt) = synthDelegate.speakingRange {
                                // aaaaallllllllll of this:
                                let pos1 = uiTextView.position(from: uiTextView.beginningOfDocument, offset: lowerInt)
                                let pos2 = uiTextView.position(from: uiTextView.beginningOfDocument, offset: upperInt)
                                
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
                    let paddingTop = 24.0
                    
                    // TODO: this is a crummy solution; maybe i should make my own `some View` object function struct thingy that just makes a UITextView with isUserInteractionEnabled = false?
                
                    ScrollView(.vertical) {
                        Text(highlightedText ?? AttributedString(currentText))
                            .font(.custom("Helvetica", size: 35))
                            .padding(.top, paddingTop)
                            .padding(.leading, 21)
                            .padding(.trailing, 21)
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .topLeading)
                    }
                        .disabled(true)
                        .background(.background)
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
                    let langCodeSpecific = selectedVoice.0.language
                    let langCodeGeneral = langCodeSpecific.split(separator: "-")[safe: 0]
                    let finalLangCode = langCodeGeneral == nil ? langCodeSpecific : String(langCodeGeneral!)
                    
                    ScrollView() {
                        Text("type_here".tryToTranslate(toLanguage: finalLangCode))
                            .font(.custom("Helvetica", size: 35))
                            .padding(.top, 24)
                            .padding(.leading, 21)
                            .padding(.trailing, 21)
                            .frame(maxWidth: .infinity,
                                   maxHeight: .infinity,
                                   alignment: .topLeading)
                            .opacity(0.3)
                    }.introspectScrollView() { uiScrollView in
                        uiScrollView.isUserInteractionEnabled = false
                    }
                    .allowsHitTesting(false)
                }
            }.environment(\.layoutDirection, isRtl ? .rightToLeft : .leftToRight)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        MainSimpleAACView(voices: AVSpeechSynthesisVoice.speechVoices()) // ugh TODO?
    }
}

class SpeechSynthDelegate: NSObject, AVSpeechSynthesizerDelegate, ObservableObject {
    @Published var speakingRange: (Int, Int)? = nil
    @Published var isSpeaking: Bool = false
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        // sometimes we get weird NSRanges from the TTS engine upside-down-smiling-face
        let unicodeCount = utterance.speechString.unicodeScalars.count
        
        let lowerInt = min(unicodeCount - 1, max(0, characterRange.lowerBound))
        let upperInt = min(unicodeCount - 1, max(0, characterRange.upperBound - 1))
        
        speakingRange = (
            min(lowerInt, upperInt),
            max(lowerInt, upperInt)
        )
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
                MainSimpleAACView.setAudioSessionActive(false)
            }
        }
    }
}

