// WorkoutAttributes.swift
// This file re-exports the shared model from the SharedWorkoutModels package.
// Both the App target and WorkoutWidgets extension import the same package,
// ensuring Activity<WorkoutActivityAttributes>.activities resolves correctly
// across process boundaries.

@_exported import SharedWorkoutModels
