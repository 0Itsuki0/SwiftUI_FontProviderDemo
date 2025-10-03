//
//  URL+Extensions.swift
//  CustomFontProviderDemo
//
//  Created by Itsuki on 2025/10/03.
//

import SwiftUI

extension URL {
    var fontDescriptors: [CTFontDescriptor] {
        return CTFontManagerCreateFontDescriptorsFromURL(self as CFURL) as? [CTFontDescriptor] ?? []
    }
}
