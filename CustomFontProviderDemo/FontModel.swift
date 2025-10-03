//
//  FontModel.swift
//  CustomFontProviderDemo
//
//  Created by Itsuki on 2025/10/03.
//

import SwiftUI

struct FontModel: Identifiable {
    var fontName: String
    var fontFamily: String
    var url: URL?
    
    var registered: Bool
    var providedByCurrentApp: Bool {
        return !FontsManager.fontUrls.filter({FontsManager.isSameFontURL($0, url)}).isEmpty
    }
    
    var id: String {
        return "\(self.fontFamily)\(self.fontName)\(self.registered)"
    }
    
    init?(fontDescriptor: CTFontDescriptor, registered: Bool) {
        guard let name = fontDescriptor.fontName, let fontFamily = fontDescriptor.fontFamily else {
            return nil
        }
        self.fontName = name
        self.fontFamily = fontFamily
        self.url = fontDescriptor.url
        self.registered = registered
    }
}
