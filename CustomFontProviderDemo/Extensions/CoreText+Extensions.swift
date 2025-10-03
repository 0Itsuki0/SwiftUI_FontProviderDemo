//
//  CoreText+Extensions.swift
//  CustomFontProviderDemo
//
//  Created by Itsuki on 2025/10/03.
//

import SwiftUI

extension CTFontDescriptor {
    var fontName: String? {
        return CTFontDescriptorCopyAttribute(self, kCTFontNameAttribute) as? String
    }
    
    var fontFamily: String? {
        return CTFontDescriptorCopyAttribute(self, kCTFontFamilyNameAttribute) as? String
    }
    
    var url: URL? {
        return CTFontDescriptorCopyAttribute(self, kCTFontURLAttribute) as? URL
    }
    
}
