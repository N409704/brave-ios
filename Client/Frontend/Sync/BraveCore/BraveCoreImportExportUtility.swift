// Copyright 2020 The Brave Authors. All rights reserved.
// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import Foundation
import Shared
import BraveRewards

private let log = Logger.browserLogger

class BraveCoreImportExportUtility {
    
    // Import an array of bookmarks into BraveCore
    func importBookmarks(from array: [BraveImportedBookmark], _ completion: @escaping (_ success: Bool) -> Void) {
        precondition(state == .none, "Bookmarks Import - Error Importing while an Import/Export operation is in progress")
        
        state = .importing
        self.queue.async {
            self.importer.import(from: array)
            self.state = .none
            DispatchQueue.main.async {
                completion(true)
            }
        }
    }
    
    // Import bookmarks from a file into BraveCore
    func importBookmarks(from path: URL, _ completion: @escaping (_ success: Bool) -> Void) {
        precondition(state == .none, "Bookmarks Import - Error Importing while an Import/Export operation is in progress")
        
        state = .importing
        self.queue.async {
            self.importer.import(fromFile: path.absoluteString, automaticImport: true) { [weak self] state, bookmarks in
                guard let self = self else { return }
                
                do {
                    try self.rethrow(state)
                    self.state = .none
                    log.info("Bookmarks Import - Completed Import Successfully")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } catch {
                    self.state = .none
                    log.error(error)
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
    }
    
    // Import bookmarks from a file into an array
    func importBookmarks(from path: URL, _ completion: @escaping (_ success: Bool, _ bookmarks: [BraveImportedBookmark]) -> Void) {
        precondition(state == .none, "Bookmarks Import - Error Importing while an Import/Export operation is in progress")
        
        state = .importing
        self.queue.async {
            self.importer.import(fromFile: path.absoluteString, automaticImport: false) { [weak self] state, bookmarks in
                guard let self = self, state != .started else { return }
                
                do {
                    try self.rethrow(state)
                    self.state = .none
                    log.info("Bookmarks Import - Completed Import Successfully")
                    DispatchQueue.main.async {
                        completion(true, bookmarks ?? [])
                    }
                } catch {
                    self.state = .none
                    log.error(error)
                    DispatchQueue.main.async {
                        completion(false, [])
                    }
                }
            }
        }
    }
    
    // Export bookmarks from BraveCore to a file
    func exportBookmarks(to path: URL, _ completion: @escaping (_ success: Bool) -> Void) {
        precondition(state == .none, "Bookmarks Import - Error Exporting while an Import/Export operation is in progress")
        
        self.state = .exporting
        self.queue.async {
            self.exporter.export(toFile: path.absoluteString) { [weak self] state in
                guard let self = self, state != .started else { return }
                
                do {
                    try self.rethrow(state)
                    self.state = .none
                    log.info("Bookmarks Export - Completed Export Successfully")
                    DispatchQueue.main.async {
                        completion(true)
                    }
                } catch {
                    self.state = .none
                    log.error(error)
                    DispatchQueue.main.async {
                        completion(false)
                    }
                }
            }
        }
    }
    
    // MARK: - Private
    private var state: State = .none
    private let importer = BraveBookmarksImporter()
    private let exporter = BraveBookmarksExporter()
    
    //Serial queue because we don't want someone accidentally importing and exporting at the same time..
    private let queue = DispatchQueue(label: "brave.core.import.export.utility", qos: .userInitiated)
    
    private enum State {
        case importing
        case exporting
        case none
    }
}

// MARK: - Errors

private enum ParsingError: String, Error {
    case errorCreatingFile = "Error Creating File"
    case errorWritingHeader = "Error Writing Header"
    case errorWritingNode = "Error Writing Node"
    case errorUnknown = "Unknown Error"
}

// MARK: - Private

extension BraveCoreImportExportUtility {
    private func rethrow(_ state: BraveBookmarksImporterState) throws {
        switch state {
        case .started, .completed, .autoCompleted:
            return
        case .cancelled:
            throw ParsingError.errorUnknown
        @unknown default:
            throw ParsingError.errorUnknown
        }
    }
    
    private func rethrow(_ state: BraveBookmarksExporterState) throws {
        switch state {
        case .started, .completed:
            return
        case .errorCreatingFile:
            throw ParsingError.errorCreatingFile
        case .errorWritingHeader:
            throw ParsingError.errorWritingHeader
        case .errorWritingNodes:
            throw ParsingError.errorWritingNode
        @unknown default:
            throw ParsingError.errorUnknown
        }
    }
}
