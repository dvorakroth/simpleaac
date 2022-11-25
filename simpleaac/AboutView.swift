//
//  AboutView.swift
//  simpleaac
//
//  Created by Amit Ron on 24/11/2022.
//

import Foundation
import SwiftUI

struct AboutView: View {
    @Binding var showModal: Bool
    
    var body: some View {
        ScrollView(.vertical) {
            VStack {
                Button() {
                    showModal.toggle()
                } label: {
                    Image(systemName: "x.square")
                    Text("Dismiss")
                }
                .padding(.bottom, 5)
                
                Text("Simple AAC")
                    .font(.custom("Helvetica", size: 50))
                    //.padding(.bottom, 2)
                    .lineLimit(1)
                    .scaledToFit()
                    .minimumScaleFactor(0.4)
                
                let version = Bundle.main.releaseVersionNumber ?? "??"
                Text("version_\(version)")
                    .font(.custom("Helvetica", size: 12))
                    .padding(.bottom, 6)
                    .lineLimit(1)
                    .scaledToFit()
                    .minimumScaleFactor(0.4)
                
                Text("about_box_text")
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("\nSimple AAC also uses SwiftUI-Introspect, which is released under the MIT License, reproduced below:")
                    .padding(.bottom, 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .environment(\.layoutDirection, .leftToRight)
                Text(
"""
Copyright 2019 Timber Software

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
"""
                )
                .font(.custom("Helvetica", size: 8))
                .padding(.leading, 5)
                .padding(.trailing, 5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
            }
            .padding(20)
            .frame(maxWidth: 500)
        }
    }
}

struct AboutView_Preivews_Wrapper: View {
    @State var showModal = true
    
    var body: some View {
        Button("Show AboutView") {
            showModal.toggle()
        }.sheet(isPresented: $showModal) {
            AboutView(showModal: $showModal)
        }
    }
}

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView_Preivews_Wrapper()
    }
}
