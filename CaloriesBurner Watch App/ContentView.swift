//
//  ContentView.swift
//  CaloriesBurner Watch App
//
//  Created by Javier Calatrava on 1/1/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject var healthkitManager = appSingletons.healthkitManager
    var body: some View {
        VStack {
            Group {
                Text(healthkitManager.heartRate)
                Text(healthkitManager.caloriesBurned)
            }
            .font(.largeTitle)

            if [.notStarted, .ended].contains(healthkitManager.workoutSessionState)  {
                Button("Start") {
                    Task {
                        await  healthkitManager.startWorkoutSession()
                    }
                   
                }
            } else if healthkitManager.workoutSessionState == .started {
                Button("Finish") {
                    Task {
                        await  healthkitManager.stopWorkoutSession()
                    }
                }
            }
            Text("\(healthkitManager.workoutSessionState.rawValue)")
        }
        .padding()
        .onAppear() {
            Task {
                await healthkitManager.requestAuthorization()
            }
        }
    }
}

#Preview {
    ContentView()
}
