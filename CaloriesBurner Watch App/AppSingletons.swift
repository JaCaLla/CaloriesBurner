//
//  AppSingletons.swift
//  LocationSampleApp
//
//  Created by Javier Calatrava on 1/12/24.
//

import Foundation

@MainActor
struct AppSingletons {
    var healthkitManager: HealthkitManager
    
    init(healthkitManager: HealthkitManager? = nil) {
        self.healthkitManager = healthkitManager ?? HealthkitManager.shared
    }
}

@MainActor var appSingletons = AppSingletons()
