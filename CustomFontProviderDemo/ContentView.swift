//
//  ContentView.swift
//  CustomFontProviderDemo
//
//  Created by Itsuki on 2025/10/02.
//

import SwiftUI

struct ContentView: View {
    @State private var manager = FontsManager()
    
    @State private var showFontNameEntry: Bool = false
    @State private var requestFontName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                if let error = manager.error {
                    Text(String("\(error)"))
                        .foregroundStyle(.red)
                }
                
                fontsSectionView(manager.fontsFromCurrentApp, title: "Fonts Provided")
                
                fontsSectionView(manager.fontsFromOtherApps, title: "Other Fonts Installed")
            }
            .buttonStyle(.plain)
            .navigationTitle("Custom Fonts")
            .navigationSubtitle(" Provide & Use SystemWide Custom Fonts")
            .toolbar(content: {
                ToolbarItem(placement: .topBarTrailing, content: {
                    Button(action: {
                        showFontNameEntry = true
                    }, label: {
                        Image(systemName: "plus")
                    })
                })
            })
            .sheet(isPresented: $showFontNameEntry, content: {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Add Installed Fonts")
                        .font(.headline)
                    
                    TextField(text: $requestFontName, label: {})
                        .textFieldStyle(.roundedBorder)
                    
                    HStack(spacing: 24) {
                        
                        Button(role: .destructive, action: {
                            showFontNameEntry = false
                        }, label: {
                            Text("Cancel")
                                .padding(.horizontal, 16)
                        })
                        .buttonStyle(.glassProminent)

                        
                        Button(action: {
                            Task {
                                await manager.requestFontWithNames([requestFontName])
                                requestFontName = ""
                                showFontNameEntry = false
                            }

                        }, label: {
                            Text("Add")
                                .padding(.horizontal, 16)
                        })
                        .buttonStyle(.glassProminent)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding()
                .onAppear {
                    requestFontName = ""
                }
                .presentationDetents([.height(200)])
            })

        }
    }
    
    
    private func fontsSectionView(_ fontsByFamilyName: [String: [FontModel]], title: String) -> some View {
        Section(title) {
            if fontsByFamilyName.keys.isEmpty {
                Text("No Fonts available.")
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(fontsByFamilyName.keys.sorted()), id: \.self) { familyName in
                
                let fonts: [FontModel] = fontsByFamilyName[familyName] ?? []
                
                if !fonts.isEmpty {
                    let font = fonts.first!
                    HStack {
                        Text(familyName)
                            .font(font.registered ? .custom(font.fontName, size: 16) : .system(size: 16))
                        
                        Spacer()
                        
                        if font.providedByCurrentApp {
                            Button(action: {
                                let urls = fonts.filter({$0.providedByCurrentApp && $0.url != nil}).map { $0.url! }
                                font.registered ? manager.unregisterFonts(urls) : manager.registerFonts(urls)
                            }, label: {
                                Text(font.registered ? "Uninstall" : "Install")
                            })
                            .buttonStyle(.borderless)
                        }
                    }
                }
            }

        }
    }
}
