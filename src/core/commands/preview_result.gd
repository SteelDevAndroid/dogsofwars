# Preview of a command on the state seen by its faction (ADR-0004 §6).
class_name PreviewResult
extends RefCounted

var validation: ValidationResult
## Revision the preview was computed on: a newer state makes it stale.
var base_revision: int
## Events the command would publish, never published.
var events: Array[PresentationEvent] = []
