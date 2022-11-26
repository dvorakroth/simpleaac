//
//  VoiceManager.swift
//  simpleaac
//
//  Created by Amit Ron on 24/11/2022.
//

import Foundation
import SwiftUI
import AVFoundation

struct VoiceManager: View {
    @State var voicesLoaded = false
    @State var voices: [AVSpeechSynthesisVoice] = []
    
    @Environment(\.scenePhase) var scenePhase
    
    var body: some View {
        if !voicesLoaded {
            let _ = DispatchQueue.main.asyncAfter(deadline: .now() + 0.001) {
                lookForVoices() // i have NO idea why we can't do this in the init() but whatever
            }
            
            VStack {}
        } else if voices.count > 0 {
            MainSimpleAACView(voices: voices)
        } else {
            NoVoicesFoundApologyView().onChange(of: scenePhase) { newScenePhase in
                if newScenePhase == .active && voices.count == 0 {
                    lookForVoices()
                }
            }
        }
    }
    
    func lookForVoices() {
        if (voices.count == 0) {
            voices.append(contentsOf: AVSpeechSynthesisVoice.speechVoices())
            if (!voicesLoaded) {
                voicesLoaded.toggle()
            }
        }
    }
}

struct NoVoicesFoundApologyView: View {
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                Text("no_voices_apology_title".tryToTranslate().markdownToAttributed())
                    .font(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("no_voices_apology_text".tryToTranslate().markdownToAttributed())
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
            .padding(20)
            .frame(maxWidth: 1000)
    }
}
