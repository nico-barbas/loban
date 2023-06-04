package main

import "core:fmt"

import "logf"
import "loui"

Window :: struct {
	rect:         loui.Rect,
	border:       loui.Border,
	data:         rawptr,
	content_proc: proc(ui: ^loui.Context, rect: ^loui.Rect, data: rawptr),
	keybind_help: map[logf.Key]string,
}

make_window :: proc(
	rect: loui.Rect,
	border: loui.Border,
	data: rawptr,
	allocator := context.allocator,
) -> Window {
	window := Window {
		rect   = rect,
		border = border,
		data   = data,
	}
	window.keybind_help.allocator = allocator

	return window
}

destroy_window :: proc(window: ^Window) {
	delete(window.keybind_help)
}

render_window :: proc(window: ^Window, ui: ^loui.Context) {
	r := window.rect

	b := ui.border
	ui.border = window.border

	loui.begin_window(ui, r)
	defer loui.end_window(ui)

	im := window.border.inner_margin
	if im > 0 {
		loui.cut_rect_margin(&r, im, im)
	}

	ui.border = b
	gutter := loui.cut_rect(&r, .Cut_Bottom, 50)
	loui.cut_rect_margin(&r, 10, 10)
	window.content_proc(ui, &r, window.data)

	loui.begin_layout(ui, gutter)
	loui.cut_rect_margin(&gutter, 10, 5)
	for key, desc in window.keybind_help {
		loui.label(ui, loui.cut_rect(&gutter, .Cut_Left, 100), fmt.tprintf("%s: %s", key, desc))
		loui.cut_rect(&gutter, .Cut_Left, 5)
	}
	loui.end_layout(ui)
}
