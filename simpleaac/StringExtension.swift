//
//  StringExtension.swift
//  simpleaac
//
//  Created by Amit Ron on 27/11/2022.
//

import Foundation
import SwiftUI

extension String {
    func tryToTranslate(toLanguage: String? = nil) -> String {
        // apparently passing value:nil to Bundle.localizedString(forKey:value:table:) is the same as passing the same value as the key
        let thisStringShouldntEvenExistButHereWeAreLmao = "!@!@!@!@";
        
        var result: String = thisStringShouldntEvenExistButHereWeAreLmao;
        
        if let toLanguage = toLanguage,
           let bundlePath = Bundle.main.path(forResource: toLanguage, ofType: "lproj"),
           let bundle = Bundle(path: bundlePath) {
            // try translating to the language that was requested
            result = bundle.localizedString(forKey: self, value: thisStringShouldntEvenExistButHereWeAreLmao, table: nil)
        }
        
        if result == thisStringShouldntEvenExistButHereWeAreLmao {
            // if that wasn't found, try the device's current language
            result = Bundle.main.localizedString(forKey: self, value: thisStringShouldntEvenExistButHereWeAreLmao, table: nil)
        }
        
        if result == thisStringShouldntEvenExistButHereWeAreLmao && toLanguage != "en"  {
            // and failing that, just go for english
            
            if let bundlePath = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let bundle = Bundle(path: bundlePath) {
                result = bundle.localizedString(forKey: self, value: self, table: nil)
            }
        }
        
        return result == thisStringShouldntEvenExistButHereWeAreLmao ? self : result; // and failing english, just return self
    }
    
    func markdownToAttributed() -> AttributedString {
        do {
            return try AttributedString(
                markdown: self,
                options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            ) /// convert to AttributedString
        } catch {
            print("Error parsing markdown: \(error)")
            return AttributedString(stringLiteral: self)
        }
    }
}
