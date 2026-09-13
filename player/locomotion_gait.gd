extends RefCounted
## Un ciclo completo contiene los dos apoyos. Cámara, sonido y cuerpo comparten
## esta distancia de zancada para que su ritmo dependa del desplazamiento real.

static func run_weight(speed: float, stance: float) -> float:
	return smoothstep(1.55, 3.45, speed) * (1.0 - clampf(stance, 0.0, 1.0))


static func cycle_length(speed: float, stance: float) -> float:
	var crouch := clampf(stance, 0.0, 1.0)
	var prone := clampf(stance - 1.0, 0.0, 1.0)
	var length := lerpf(1.05, 1.7, run_weight(speed, stance))
	length = lerpf(length, 0.72, crouch)
	length = lerpf(length, 0.65, prone)
	return length * lerpf(0.45, 1.0, smoothstep(0.0, 1.0, speed))


static func phase_advance(delta: float, speed: float, stance: float) -> float:
	return delta * TAU * speed / cycle_length(speed, stance) if speed > 0.035 else 0.0


static func foot_sample(phase: float, support: float, travel: float, lift: float) -> Vector3:
	# x = avance del tobillo, y = altura, z = cabeceo talón/punta.
	var cycle := fposmod(phase / TAU, 1.0)
	if cycle < support:
		var t := cycle / support
		var heel := -0.16 * (1.0 - smoothstep(0.0, 0.2, t))
		var toe := 0.34 * smoothstep(0.65, 1.0, t)
		return Vector3(travel * (0.5 - t), 0.0, heel + toe)
	var t := (cycle - support) / (1.0 - support)
	# Hermite conserva la velocidad al despegar/aterrizar. La pierna recupera
	# hacia delante durante el vuelo, mientras el pie de apoyo queda atrás.
	var tangent := -travel * (1.0 - support) / support
	var t2 := t * t
	var t3 := t2 * t
	var forward := (2.0 * t3 - 3.0 * t2 + 1.0) * -travel * 0.5
	forward += (t3 - 2.0 * t2 + t) * tangent
	forward += (-2.0 * t3 + 3.0 * t2) * travel * 0.5
	forward += (t3 - t2) * tangent
	var height := pow(sin(PI * t), 2.0) * lift
	var pitch := lerpf(0.34, -0.16, smoothstep(0.0, 0.85, t))
	return Vector3(forward, height, pitch)
