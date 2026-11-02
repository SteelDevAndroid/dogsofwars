# RESYNCHRONISER (ADR-0002 §3 and §7): the queue overflowed and was emptied, or a match was
# loaded. The presentation drops what it was playing and redraws from the state.
class_name ResyncEvent
extends PresentationEvent
