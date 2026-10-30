import ActivityKit
import BodyPilotCore
import Foundation
import Training

/// Suivi de la séance en cours sur l'écran verrouillé : démarré depuis la carte Bouger,
/// avancé d'une touche « Série faite », terminé avec la séance.
enum WorkoutLiveActivity {
    private typealias SessionActivity = Activity<WorkoutActivityAttributes>

    static var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }

    static var isRunning: Bool { !SessionActivity.activities.isEmpty }

    /// Les exercices de la séance, dans l'ordre, avec leurs séries et leur repos.
    static func steps(for workout: Workout) -> [SessionStep] {
        workout.exercises.map { exercise in
            SessionStep(
                name: exercise.name,
                detail: exercise.prescription,
                sets: exercise.wave.isEmpty ? exercise.sets : exercise.wave.count + exercise.backoffSets,
                restSeconds: exercise.restSeconds
            )
        }
    }

    /// Une seule séance suivie à la fois : un suivi resté ouvert est remplacé.
    static func start(_ workout: Workout, now: Date = .now) async {
        guard isAvailable, !workout.exercises.isEmpty else { return }
        await endAll()
        let attributes = WorkoutActivityAttributes(title: workout.title, startedAt: now)
        let state = WorkoutActivityAttributes.ContentState(progress: SessionProgress(steps: steps(for: workout)))
        do {
            // Une séance oubliée ne reste pas affichée indéfiniment.
            _ = try SessionActivity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: now.addingTimeInterval(3 * 3600)),
                pushType: nil
            )
        } catch {
            AppLog.persistence.error("Suivi de séance non démarré : \(error.localizedDescription, privacy: .public)")
        }
    }

    static func completeSet(now: Date = .now) async {
        guard let activity = SessionActivity.activities.first else { return }
        let progress = activity.content.state.progress.completingSet(at: now)
        if progress.isFinished {
            await finish(markDone: true)
        } else {
            await activity.update(ActivityContent(state: .init(progress: progress), staleDate: activity.content.staleDate))
        }
    }

    static func skipExercise() async {
        guard let activity = SessionActivity.activities.first else { return }
        let progress = activity.content.state.progress.skippingExercise()
        if progress.isFinished {
            await finish(markDone: true)
        } else {
            await activity.update(ActivityContent(state: .init(progress: progress), staleDate: activity.content.staleDate))
        }
    }

    /// Termine le suivi ; la séance est cochée à la prochaine ouverture de l'app, comme depuis un widget.
    static func finish(markDone: Bool, now: Date = .now) async {
        if markDone, let snapshot = SharedStore.snapshot, snapshot.isCurrent(now: now) {
            SharedStore.record(.workoutDone(day: snapshot.day))
            WidgetBridgeReload.all()
        }
        await endAll()
    }

    static func endAll() async {
        for activity in SessionActivity.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
