/// Select how a tool observes its stage, independently from the shared chrome.
/// This choice is explicit: the shell does not infer world-camera semantics
/// from a renderer type or add rotation to ordinary two-dimensional stages.
public enum ScienceLabStageInteractionPolicy: Equatable, Sendable {
    /// Shared two-finger observation, bounded to 1–3 times the original stage.
    case bounded2D

    /// The tool owns camera/object gestures and their scientific limits.
    /// Native 3D/world and embedded viewers must not also receive a 2D transform.
    case toolManaged
}
