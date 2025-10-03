//
//  FontsManager.swift
//  CustomFontProviderDemo
//
//  Created by Itsuki on 2025/10/02.
//

import SwiftUI
import Combine

extension FontsManager{
    static let fontUrls: [URL] = ["dopest", "a-bit-sketchy", "a-charming-font", "a-la-nage", "super-mario-bros-alphabet"].map({Bundle.main.url(forResource: $0, withExtension: "ttf")}).filter({$0 != nil}).map({$0!})
    
    static func isSameFontURL(_ first: URL?, _ second: URL?) -> Bool {
        // when running on simulators, the bundle URL could be different between launches sometimes
        #if targetEnvironment(simulator)
        // last past two components: {appName}.app/{fontFileName}.ttf
            first?.pathComponents.suffix(2) == second?.pathComponents.suffix(2)
        #else
            first == second
        #endif

    }
}


@Observable
class FontsManager {
    enum _Error: Error {
        case registrationFailed([NSError])
        case invalidFontURLs
    }
    
    
    var error: Error? {
        didSet {
            if let error {
                print(error)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0, execute: {
                    self.error = nil
                })
            }
        }
    }
    
    // both the fonts registered(installed) by this app as well as by other apps
    private var currentAppFonts: [FontModel] = []
    
    var fontsFromCurrentApp: [String: [FontModel]] {
        let fonts = self.currentAppFonts.filter({$0.providedByCurrentApp})
        return Dictionary(grouping: fonts, by: {$0.fontFamily})
    }
    
    // fonts for other apps will not show up under CTFontManagerCopyRegisteredFontDescriptors even if we have requested it.
    // therefore, we will be persisting those by ourselves here.
    private var otherAppFonts: [FontModel] = [] {
        didSet {
            let fontNames = otherAppFonts.map { $0.fontName }
            UserDefaults.standard.setValue(fontNames, forKey: self.otherAppFontsKey)
        }
    }
    var fontsFromOtherApps: [String: [FontModel]] {
        let fonts = self.otherAppFonts.filter({!$0.providedByCurrentApp})
        return Dictionary(grouping: fonts, by: {$0.fontFamily})
    }

    
    @ObservationIgnored
    private var cancellable: AnyCancellable?
    
    private let registrationScope: CTFontManagerScope = .user
    
    private let otherAppFontsKey = "otherAppFonts"

    init() {
        self.updateFonts()
        
        self.cancellable = NotificationCenter.default.publisher(for: kCTFontManagerRegisteredFontsChangedNotification as NSNotification.Name).receive(
            on: DispatchQueue.main
        ).sink { _ in
            self.updateFonts()
        }
    }
    
    deinit {
        self.cancellable?.cancel()
        self.cancellable = nil
    }
    
    private func updateFonts() {
        self.updateInstalledFonts()
        Task {
            if let otherAppFonts = UserDefaults.standard.value(forKey: self.otherAppFontsKey) as? [String] {
                await self.requestFontWithNames(otherAppFonts)
            }
        }
    }
    
    // update the fonts installed by the current app.
    private func updateInstalledFonts() {
        // CTFontManagerCopyRegisteredFontDescriptors: Retrieves the font descriptors that were registered with the font manager.
        //
        // Fonts registered by other apps will not show up here even if we have requested for those.
        guard let registeredDescriptors = CTFontManagerCopyRegisteredFontDescriptors(registrationScope, true) as? [CTFontDescriptor] else {
            return
        }

        let registerFonts: [FontModel] = registeredDescriptors
            .map({FontModel(fontDescriptor: $0, registered: true)})
            .filter({$0 != nil})
            .map({$0!})
        
        
        let unregisteredFonts: [FontModel] = Self.fontUrls
            .filter({ fontURL in
                !registerFonts.contains(where: {Self.isSameFontURL($0.url, fontURL)})
            })
            .flatMap(\.fontDescriptors)
            .map({FontModel(fontDescriptor: $0, registered: false)})
            .filter({$0 != nil})
            .map({$0!})
        
        self.currentAppFonts = registerFonts + unregisteredFonts
            
    }
    
    // To request a font installed by other apps with a specific name.
    func requestFontWithNames(_ fontNames: [String]) async {
        
        let descriptors = fontNames.map({ fontName in
            CTFontDescriptorCreateWithAttributes([
                kCTFontNameAttribute : fontName
            ] as CFDictionary)})
        
        let unresolvedDescriptors: [CTFontDescriptor] = await withCheckedContinuation({ continuation in
            // On iOS, fonts registered by font provider apps in the CTFontManagerScope.persistent scope aren’t automatically available to other apps.
            // Other apps must call this function to make the fonts available for font descriptor matching.
            CTFontManagerRequestFonts(descriptors as CFArray, { unresolved in
                guard let descriptors = unresolved as? [CTFontDescriptor] else {
                    continuation.resume(returning: [])
                    return
                }
                continuation.resume(returning: descriptors)
            })
        })
        
        // On iOS, if the font descriptors can’t be found, the system presents the user with a dialog that indicates which fonts couldn’t be resolved.
        // The system may provide the user with a way to resolve the missing fonts, if the font manager has a way to enable them.
        //
        // ie: We not need to throw additional errors to prompt the user. However, we will need to remove those from our database (userDefaults if added already)
        let failed = unresolvedDescriptors.map(\.fontName)
        self.otherAppFonts = self.otherAppFonts.filter({failed.contains($0.fontName)})

        
        let successDescriptors = descriptors.filter({!unresolvedDescriptors.contains($0)})
        let successFontNames = successDescriptors.map(\.fontName).filter({$0 != nil}).map({$0!})
        let fonts: [CTFont] = successFontNames.map({.init($0 as CFString, size: 12)})
        let resolvedDescriptors = fonts.map({CTFontCopyFontDescriptor($0)})
        let models = resolvedDescriptors
            .map({FontModel(fontDescriptor: $0, registered: true)})
            .filter({$0 != nil})
            .map({$0!})
        
        self.otherAppFonts.append(contentsOf: models)
    }
    
    
    func registerFonts(_ urls: [URL]) {
        if !validateURLs(urls) {
            self.error = _Error.invalidFontURLs
            return
        }
        // based on the [documentation](https://developer.apple.com/documentation/CoreText/CTFontManagerRegisterFontURLs(_:_:_:_:)),
        // the url has to be a file URL for the fonts or collections in TTC or OTC format,
        // However, TTF or any of the modern variants will work as well.
        CTFontManagerRegisterFontURLs(urls as CFArray, registrationScope, true, { errors, done in
            // A block called as errors arise or upon completion.
            // The block’s errors parameter contains an array of CFError references; an empty array indicates no errors. Each error reference contains a CFArray of font descriptors corresponding to kCTFontManagerErrorFontURLsKey. These URLs represent the font files causing the error and failing to register successfully.
            // This block may be called multiple times during the registration process. The done parameter becomes true when the registration process completes. Return false from the block to stop the registration operation, like after receiving an error
            if let errors = errors as? [NSError], !errors.isEmpty {
                self.error = _Error.registrationFailed(errors)
                return false
            }
            
            return true
        })
    }
    
    func unregisterFonts(_ urls: [URL]) {
        if !validateURLs(urls) {
            self.error = _Error.invalidFontURLs
            return
        }
        // On iOS, we can only use this function to unregister fonts that we registered using CTFontManagerRegisterFontsForURL(_:_:_:) or CTFontManagerRegisterFontsForURLs(_:_:_:).
        CTFontManagerUnregisterFontURLs(urls as CFArray, registrationScope, { errors, done in
            // A block called as errors arise or upon completion.
            // The block’s errors parameter contains an array of CFError references; an empty array indicates no errors. Each error reference contains a CFArray of font descriptors corresponding to kCTFontManagerErrorFontURLsKey. These URLs represent the font files causing the error and failing to register successfully.
            // This block may be called multiple times during the registration process. The done parameter becomes true when the registration process completes. Return false from the block to stop the registration operation, like after receiving an error
            if let errors = errors as? [NSError], !errors.isEmpty {
                self.error = _Error.registrationFailed(errors)
                return false
            }

            return true
        })

    }

    
    private func validateURLs(_ urls: [URL]) -> Bool {
        let results = urls.map({check in
            !Self.fontUrls.filter({provided in FontsManager.isSameFontURL(check, provided)}).isEmpty
        })
        return !results.contains(false)
    }
}

