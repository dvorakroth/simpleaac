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
    @State var voices: [AVSpeechSynthesisVoice]? = nil
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        lookForVoices()
    }
    
    var body: some View {
        if (voices?.count ?? 0) > 0 {
            MainSimpleAACView(voices: voices!)
        } else {
            VStack {
                Text(
"""
SimpleAAC couldn't find any voices!

This could either be because no voices are installed on this device, or because of a random bug.

To try installing some voices on your device, go into iOS Settings > Accessibility > Spoken Content, and turn on Speak Selection. Then go into the new "Voices" menu that should appear underneath, and download some voices. When that's done, try going back into Simple AAC to see if that fixes the problem.

If it doesn't then,, you've probably found a new bug! 🙃
"""
                )
                    .padding(20)
                    .frame(maxWidth: 1000)
            }.onChange(of: scenePhase) { newScenePhase in
                if newScenePhase == .active && (voices?.count ?? 0) == 0 {
                    lookForVoices()
                }
            }
        }
    }
    
    func lookForVoices() {
        let v = AVSpeechSynthesisVoice.speechVoices()
        
        voices = v
    }
}
