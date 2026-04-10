//
//  UpdaterManager.swift
//  OpenCode Stats
//
//  Created by Fayaz Ahmed Aralikatti on 10/04/26.
//

import Combine
import Foundation
import Sparkle

/// Manages Sparkle auto-update lifecycle.
@MainActor
final class UpdaterManager: NSObject, ObservableObject {
    private let controller: SPUStandardUpdaterController

    var updater: SPUUpdater { controller.updater }

    @Published var canCheckForUpdates = false

    var automaticallyChecksForUpdates: Bool {
        get { controller.updater.automaticallyChecksForUpdates }
        set { controller.updater.automaticallyChecksForUpdates = newValue }
    }

    override init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        super.init()

        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func start() {
        #if DEBUG
        return
        #else
        controller.startUpdater()
        #endif
    }

    func checkForUpdates() {
        #if DEBUG
        return
        #else
        controller.checkForUpdates(nil)
        #endif
    }
}
