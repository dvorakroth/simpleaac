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
    
    let voices: [AVSpeechSynthesisVoice]
    @State var selectedVoiceIdx: Int = 0
    
    init() {
        voices = AVSpeechSynthesisVoice.speechVoices()
        synth.delegate = synthDelegate
    }
    
    var body: some View {
        VStack {
            HStack {
                Picker("Select Voice", selection: $selectedVoiceIdx) {
                    ForEach(Array(voices.enumerated()), id: \.offset) { index, voice in
                        Text(voice.name + " (" + voice.language + ")")
                    }
                }.pickerStyle(.menu)
                
                let buttonTitle = synthDelegate.isSpeaking ? "❌" : "🔊"
                
                Button(buttonTitle) {
                    if synthDelegate.isSpeaking {
                        synth.stopSpeaking(at: .immediate)
                    } else {
                        let u = AVSpeechUtterance(string: currentText)
                        
                        u.voice = voices[selectedVoiceIdx]
                        
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
                    
//                    let _ = highlightedText.foregroundColor = UIColor.red
                        
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
                    Text("(enter text here)")
                        .font(.custom("Helvetica", size: 40))
                        .padding(.top, 30)
                        .padding(.leading, 21)
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
