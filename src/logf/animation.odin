package logf

Timer :: struct {
	duration: f32,
	time:     f32,
	reset:    bool,
}

advance_timer :: proc(timer: ^Timer, dt: f32) -> bool {
	timer.time += dt
	if timer.time >= timer.duration {
		if timer.reset {
			timer.time = 0
		}
		return true
	}

	return false
}

reset_timer :: proc(timer: ^Timer) {
	timer.time = 0
}

Animation :: struct {
	using timer: Timer,
	start:       f32,
	end:         f32,
}

advance_animation :: proc(anim: ^Animation, dt: f32) -> (value: f32, done: bool) {
	done = advance_timer(anim, dt)
	t := min(anim.time / anim.duration, 1)
	value = (1 - t) * anim.start + t * anim.end
	return
}
