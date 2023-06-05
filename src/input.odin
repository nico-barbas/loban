package main

import "core:fmt"

import "logf"
import "loui"

Input :: struct {
	buf:          [512]byte,
	count:        int,
	active:       bool,
	repeat_timer: f32,
	blink_timer:  f32,
	blink:        bool,
}

INPUT_REPEAT_RATE :: 0.5
INPUT_BLINK_RATE :: 0.75

update_input :: proc(input: ^Input, key_pressed: []rune, dt: f32) -> (changed: bool) {
	if .Just_Pressed in logf.key_state(.Backspace) {
		fmt.println(input.repeat_timer)
		if input.repeat_timer == 0 || input.repeat_timer >= INPUT_REPEAT_RATE {
			if input.count > 0 {
				input.count -= 1
				changed = true
			}
		}
		input.repeat_timer += dt
	} else {
		input.repeat_timer = 0
	}

	if !input.active {
		return
	}

	input.blink_timer += dt
	if input.blink_timer >= INPUT_BLINK_RATE {
		input.blink_timer = 0
		input.blink = !input.blink
	}

	changed |= len(key_pressed) > 0
	for c in key_pressed {
		input.buf[input.count] = byte(c)
		input.count += 1
	}

	return
}

render_input :: proc(input: ^Input, ui: ^loui.Context) {

}

reset_input :: proc(input: ^Input) {
	input.count = 0
	input.repeat_timer = 0
}

input_string :: proc(input: ^Input) -> string {
	return string(input.buf[:input.count])
}
