package main

import "core:fmt"

import "logf"

Input :: struct {
	buf:          [512]byte,
	count:        int,
	active:       bool,
	repeat_timer: f32,
}

INPUT_REPEAT_RATE :: 0.5

update_input :: proc(input: ^Input, key_pressed: []rune, dt: f32) {
	left_shift := .Pressed in logf.key_state(.Left_Shift)

	if .Just_Pressed in logf.key_state(.Semicolon) && left_shift {
		input.active = true
	} else if .Just_Pressed in logf.key_state(.Escape) {
		input.count = 0
		input.active = false
	}


	if .Just_Pressed in logf.key_state(.Backspace) {
		fmt.println(input.repeat_timer)
		if input.repeat_timer == 0 || input.repeat_timer >= INPUT_REPEAT_RATE {
			if input.count > 0 {
				input.count -= 1
			}
		}
		input.repeat_timer += dt
	} else {
		input.repeat_timer = 0
	}

	if !input.active {
		return
	}

	for c in key_pressed {
		input.buf[input.count] = byte(c)
		input.count += 1
	}
}

reset_input :: proc(input: ^Input) {
	input.count = 0
	input.repeat_timer = 0
}
