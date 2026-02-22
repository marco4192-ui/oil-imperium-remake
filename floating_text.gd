extends Label

var velocity = Vector2(0, -50) # Bewegt sich nach oben
var duration = 1.5
var timer = 0.0

func _ready():
	# Wichtig: Maus-Events ignorieren, damit man durchklicken kann
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# Start-Zustand (Transparenz voll da)
	modulate.a = 1.0

func _process(delta):
	timer += delta
	
	# Bewegung
	position += velocity * delta
	
	# Langsamer werden (optional)
	velocity = velocity.move_toward(Vector2.ZERO, 10.0 * delta)
	
	# Verblassen im letzten Drittel der Zeit
	if timer > (duration * 0.6):
		var fade_speed = 1.0 / (duration * 0.4)
		modulate.a -= fade_speed * delta
	
	# Löschen wenn Zeit um
	if timer >= duration:
		queue_free()

func set_amount(value: int):
	if value >= 0:
		text = "+$" + str(value)
		modulate = Color(0.2, 1.0, 0.2, 1.0) # Grün
	else:
		text = "-$" + str(abs(value))
		modulate = Color(1.0, 0.2, 0.2, 1.0) # Rot
