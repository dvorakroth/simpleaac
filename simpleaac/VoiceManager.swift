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
                Text("Simple AAC couldn't find any voices!")
                    .font(.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(
"""

This could either be because no voices are installed on this device, or because of a random bug.

To try installing some voices, go into iOS Settings > Accessibility > Spoken Content, and turn on Speak Selection. Then go into the new "Voices" menu that should appear underneath, and download some voices. When that's done, try going back into Simple AAC to see if that fixes the problem.

If it doesn't, then congratulations! You might have found a new bug! 🙃

If you're into that sort of thing, you could search the [issues page on GitHub](https://github.com/dvorakroth/simpleaac/issues) to see if anyone else encountered this problem in similar circumstances.

My website is at [ish.works](https://ish.works/), where you can also read the [privacy policy](https://ish.works/privacy.html).
"""
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
            .padding(20)
            .frame(maxWidth: 1000)
    }
}
