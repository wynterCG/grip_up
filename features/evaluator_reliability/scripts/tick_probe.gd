extends Node
## Two ordered probes bracket existing gameplay callbacks. No world mutation.
signal tick(delta:float)
func _physics_process(delta:float)->void:tick.emit(delta)
