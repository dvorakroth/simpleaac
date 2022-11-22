//
//  ContentView.swift
//  simpleaac
//
//  Created by Amit Ron on 22/11/2022.
//

import Foundation
import SwiftUI
import AVFoundation

struct ContentView: View {
    @State var currentText: String = ""
    @FocusState var textInFocus: Bool
    
    let synth = AVSpeechSynthesizer()
    @ObservedObject var synthDelegate = SpeechSynthDelegate()
    
    let voices: [VoiceWrapper]
    @State var selectedVoiceIdx: Int = 0
    
    init() {
        voices = Self.groupAndLabelVoices()
        
        synth.delegate = synthDelegate
    }
    
    static func groupAndLabelVoices() -> [VoiceWrapper] {
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
        
        var finalOrdered: [VoiceWrapper] = []
        
        let sortedGroups = groups.sorted(by: { a, b in a.key < b.key })
        
        for (languageName, subgroups) in sortedGroups {
            let addRegionName = subgroups.count > 1
            
            let sortedSubgroups = subgroups.sorted(by: { a, b in a.key < b.key })
            
            for (regionName, voices) in sortedSubgroups {
                let prettyLangName = addRegionName ? (
                    languageName + " (" + regionName + ")"
                ) : languageName
                
                let sortedVoices = voices.sorted(by: { a, b in a.name < b.name })
                
                for voice in sortedVoices {
                    finalOrdered.append(VoiceWrapper(voice: voice, languageName: prettyLangName))
                }
            }
        }
        
        return finalOrdered
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Select Voice", selection: $selectedVoiceIdx) {
                    ForEach(Array(voices.enumerated()), id: \.offset) { index, voice in
                        Text(voice.prettyName)
                    }
                }.pickerStyle(.menu)
                
                let buttonTitle = synthDelegate.isSpeaking ? "❌" : "🔊"
                
                Button(buttonTitle) {
                    if synthDelegate.isSpeaking {
                        synth.stopSpeaking(at: .immediate)
                    } else {
                        let u = AVSpeechUtterance(string: currentText)
                        
                        u.voice = voices[selectedVoiceIdx].voice
                        
                        synth.speak(u)
                    }
                }
            }
            ZStack(alignment: .topLeading) {
                if false || synthDelegate.isSpeaking {
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
                } else {
                    TextEditor(text: $currentText)
                        .focused($textInFocus)
                        .font(.custom("Helvetica", size: 50))
                        .padding(.all)
                        .frame(maxWidth: .infinity,
                               maxHeight: .infinity,
                               alignment: .topLeading)
                }
                
                if currentText.isEmpty {
                    Text("(type here)")
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
            }
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
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        isSpeaking = false
        speakingRange = nil
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        isSpeaking = true
    }
}
