//
//  HealthKitManager.swift
//  CaloriesBurner Watch App
//
//  Created by Javier Calatrava on 31/12/24.
//

import Foundation
import HealthKit

protocol HealthkitManagerProtocol {
    func requestAuthorization() async
    func startWorkoutSession() async
    func stopWorkoutSession() async
}

final class HealthkitManager: NSObject, ObservableObject, @unchecked Sendable {

    enum WorkoutSessionState: String, Sendable {
        case needsAuthorization
        case notStarted
        case started
        case ended
    }

    @MainActor
    static let shared = HealthkitManager()

    @MainActor
    @Published var workoutSessionState: WorkoutSessionState = .needsAuthorization
    private var internalWorkoutSessionState: WorkoutSessionState = .needsAuthorization {
        didSet {
            Task { [internalWorkoutSessionState] in
                await MainActor.run {
                    self.workoutSessionState = internalWorkoutSessionState
                }
            }
        }
    }

    @MainActor
    @Published var heartRate = ""
    private var internalHeartRate: String = "" {
        didSet {
            Task { [internalHeartRate] in
                await MainActor.run {
                    self.heartRate = internalHeartRate
                }
            }
        }
    }

    @MainActor
    @Published var caloriesBurned = ""
    private var internalCaloriesBurned: String = "" {
        didSet {
            Task { [internalCaloriesBurned] in
                await MainActor.run {
                    self.caloriesBurned = internalCaloriesBurned
                }
            }
        }
    }

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
   // private var timer: Timer?


    let healthStore = HKHealthStore()
}

extension HealthkitManager: HealthkitManagerProtocol {
    
    func requestAuthorization() async {
        let typesToShare: Set = [HKObjectType.workoutType()]
        let typesToRead: Set = [HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!]

        do {
            try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
            internalWorkoutSessionState = .notStarted
        } catch {
            internalWorkoutSessionState = .needsAuthorization
        }
    }
    
    func stopWorkoutSession() async {
        guard let session else { return }
        session.end()
        do {
            try await builder?.endCollection(at: Date())
        } catch {
            print("Error on ending data collection: \(error.localizedDescription)")
        }
        do {
            try await builder?.finishWorkout()
        } catch {
            print("Error on ending training: \(error.localizedDescription)")
        }

        internalWorkoutSessionState = .ended
    }

    func startWorkoutSession() async {
        guard session == nil else { return }

        guard HKHealthStore.isHealthDataAvailable() else {
            print("HealthKit is not ready on this device")
            return
        }

        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            session?.delegate = self

            builder = session?.associatedWorkoutBuilder()
            builder?.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            builder?.delegate = self
            session?.startActivity(with: Date())

            do {
                try await builder?.beginCollection(at: Date())
            } catch {
                print("Error starting workout collection: \(error.localizedDescription)")
                session?.end()
                internalWorkoutSessionState = .needsAuthorization
            }

            internalWorkoutSessionState = .started
        } catch {
            print("Error creating session or builder: \(error.localizedDescription)")
            session = nil
        }
    }
}

extension HealthkitManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        print("Workout event collected.")
    }

    func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf types: Set<HKSampleType>) {
        for type in types {
            if let quantityType = type as? HKQuantityType, quantityType == HKQuantityType.quantityType(forIdentifier: .heartRate) {
                handleHeartRateData(from: workoutBuilder)
            }
            if let quantityType = type as? HKQuantityType, quantityType == HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
                handleActiveEnergyData(from: workoutBuilder)
            }
        }
    }

    private func handleHeartRateData(from builder: HKLiveWorkoutBuilder) {
        if let statistics = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .heartRate)!) {
            let heartRateUnit = HKUnit(from: "count/min")
            if let heartRate = statistics.mostRecentQuantity()?.doubleValue(for: heartRateUnit) {
                print("Heart rate: \(heartRate) BPM")
                internalHeartRate = "\(heartRate) BPM"
            }
        }
    }

    private func handleActiveEnergyData(from builder: HKLiveWorkoutBuilder) {
        if let statistics = builder.statistics(for: HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!) {
            let energyUnit = HKUnit.kilocalorie()
            if let activeEnergy = statistics.sumQuantity()?.doubleValue(for: energyUnit) {
                print("Active Energy Burned: \(activeEnergy) kcal")
                internalCaloriesBurned = String(format: "%.2f kcal", activeEnergy)
            }
        }
    }
}

extension HealthkitManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        switch toState {
        case .running:
            print("Workout started.")
        case .ended:
            print("Workout ended.")
        default:
            print("Workout session state changed to \(toState).")
        }
    }

    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: any Error) {
        print("Workout session failed: \(error.localizedDescription)")
    }
}
