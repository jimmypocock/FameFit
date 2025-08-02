//
//  DependencyContainer+Environment.swift
//  FameFit
//
//  SwiftUI Environment integration for DependencyContainer
//

import SwiftUI

// MARK: - Environment Key

private struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue = DependencyContainer()
}

// MARK: - Environment Values Extension

extension EnvironmentValues {
    var dependencyContainer: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}