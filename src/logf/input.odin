package logf

import "vendor:glfw"

Input_Buffer :: struct {
	keys:                   Keyboard_State,
	previous_keys:          Keyboard_State,
	char_buf:               [dynamic]rune,

	// mouse buttons
	mouse_buttons:          Mouse_State,
	previous_mouse_buttons: Mouse_State,

	// mouse position
	mouse_pos:              Vector2,
	previous_mouse_pos:     Vector2,
	mouse_scroll:           f32,
	previous_mouse_scroll:  f32,
}

Input_State :: distinct bit_set[Input_State_Kind]

Input_State_Kind :: enum {
	Just_Pressed,
	Pressed,
	Just_Released,
	Released,
}

init_input_buffer :: proc(input: ^Input_Buffer, allocator := context.allocator) {
	input.char_buf = make([dynamic]rune, 0, 50, allocator)
}

destroy_input_buffer :: proc(input: ^Input_Buffer) {
	delete(input.char_buf)
}

@(private)
update_input :: proc(app: ^App) {
	mx, my := glfw.GetCursorPos(app.handle)
	i := &app.input

	i.previous_mouse_pos = i.mouse_pos
	i.mouse_pos = {f32(mx), f32(my)}

	i.previous_keys = i.keys
	i.previous_mouse_buttons = i.mouse_buttons
	i.previous_mouse_scroll = i.mouse_scroll
	i.mouse_scroll = 0

	clear(&i.char_buf)
}

Mouse_State :: distinct [len(Mouse_Button)]bool

Mouse_Button :: enum {
	Left   = 0,
	Right  = 1,
	Middle = 2,
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = _app.ctx
	if button >= 0 && button < i32(max(Mouse_Button)) {
		btn := Mouse_Button(button)
		_app.input.mouse_buttons[btn] = action == glfw.PRESS
	}
}

mouse_position :: proc() -> Vector2 {
	return _app.input.mouse_pos
}

mouse_delta :: proc() -> Vector2 {
	return _app.input.mouse_pos - _app.input.previous_mouse_pos
}

mouse_button_state :: proc(btn: Mouse_Button) -> (state: Input_State) {
	current := _app.input.mouse_buttons[btn]
	previous := _app.input.previous_mouse_buttons[btn]
	switch {
	case current && !previous:
		state = {.Just_Pressed, .Pressed}
	case current && previous:
		state = {.Pressed}
	case !current && previous:
		state = {.Just_Released, .Released}
	case !current && !previous:
		state = {.Released}
	}
	return
}

mouse_scroll_callback :: proc "c" (window: glfw.WindowHandle, x_offset: f64, y_offset: f64) {
	context = _app.ctx
	_app.input.mouse_scroll = f32(y_offset)
}

mouse_scroll :: proc() -> f32 {
	return _app.input.previous_mouse_scroll
}

Keyboard_State :: distinct [max(Key)]bool

key_state :: proc(key: Key) -> (state: Input_State) {
	current := _app.input.keys[key]
	previous := _app.input.previous_keys[key]
	switch {
	case current && !previous:
		state = {.Just_Pressed, .Pressed}
	case current && previous:
		state = {.Pressed}
	case !current && previous:
		state = {.Just_Released, .Released}
	case !current && !previous:
		state = {.Released}
	}
	return
}

pressed_char :: proc() -> []rune {
	return _app.input.char_buf[:]
}

key_callback :: proc "c" (window: glfw.WindowHandle, k, scancode, action, mods: i32) {
	context = _app.ctx
	key := Key(k)

	if k < 0 {
		return
	}

	_app.input.keys[key] = action == glfw.PRESS || action == glfw.REPEAT
}

char_callback :: proc "c" (window: glfw.WindowHandle, r: rune) {
	context = _app.ctx
	append(&_app.input.char_buf, r)
}

key_strings := map[string]Key {
	"space"         = .Space,
	"apostrophe"    = .Apostrophe,
	"comma"         = .Comma,
	"minus"         = .Minus,
	"period"        = .Period,
	"slash"         = .Slash,
	"semicolon"     = .Semicolon,
	"equal"         = .Equal,
	"left_bracket"  = .Left_bracket,
	"backslash"     = .Backslash,
	"right_bracket" = .Right_bracket,
	"grave_accent"  = .Grave_accent,
	"world_1"       = .World_1,
	"world_2"       = .World_2,
	"zero"          = .Zero,
	"one"           = .One,
	"two"           = .Two,
	"three"         = .Three,
	"four"          = .Four,
	"five"          = .Five,
	"six"           = .Six,
	"seven"         = .Seven,
	"height"        = .Height,
	"nine"          = .Nine,
	"a"             = .A,
	"b"             = .B,
	"c"             = .C,
	"d"             = .D,
	"e"             = .E,
	"f"             = .F,
	"g"             = .G,
	"h"             = .H,
	"i"             = .I,
	"j"             = .J,
	"k"             = .K,
	"l"             = .L,
	"m"             = .M,
	"n"             = .N,
	"o"             = .O,
	"p"             = .P,
	"q"             = .Q,
	"r"             = .R,
	"s"             = .S,
	"t"             = .T,
	"u"             = .U,
	"v"             = .V,
	"w"             = .W,
	"x"             = .X,
	"y"             = .Y,
	"z"             = .Z,
	"escape"        = .Escape,
	"enter"         = .Enter,
	"tab"           = .Tab,
	"backspace"     = .Backspace,
	"insert"        = .Insert,
	"delete"        = .Delete,
	"right"         = .Right,
	"left"          = .Left,
	"down"          = .Down,
	"up"            = .Up,
	"page_up"       = .Page_up,
	"page_down"     = .Page_down,
	"home"          = .Home,
	"end"           = .End,
	"caps_lock"     = .Caps_lock,
	"scroll_lock"   = .Scroll_lock,
	"num_lock"      = .Num_lock,
	"print_screen"  = .Print_screen,
	"pause"         = .Pause,
	"f1"            = .F1,
	"f2"            = .F2,
	"f3"            = .F3,
	"f4"            = .F4,
	"f5"            = .F5,
	"f6"            = .F6,
	"f7"            = .F7,
	"f8"            = .F8,
	"f9"            = .F9,
	"f10"           = .F10,
	"f11"           = .F11,
	"f12"           = .F12,
	"f13"           = .F13,
	"f14"           = .F14,
	"f15"           = .F15,
	"f16"           = .F16,
	"f17"           = .F17,
	"f18"           = .F18,
	"f19"           = .F19,
	"f20"           = .F20,
	"f21"           = .F21,
	"f22"           = .F22,
	"f23"           = .F23,
	"f24"           = .F24,
	"f25"           = .F25,
	"kp_0"          = .Kp_0,
	"kp_1"          = .Kp_1,
	"kp_2"          = .Kp_2,
	"kp_3"          = .Kp_3,
	"kp_4"          = .Kp_4,
	"kp_5"          = .Kp_5,
	"kp_6"          = .Kp_6,
	"kp_7"          = .Kp_7,
	"kp_8"          = .Kp_8,
	"kp_9"          = .Kp_9,
	"kp_decimal"    = .Kp_decimal,
	"kp_divide"     = .Kp_divide,
	"kp_multiply"   = .Kp_multiply,
	"kp_subtract"   = .Kp_subtract,
	"kp_add"        = .Kp_add,
	"kp_enter"      = .Kp_enter,
	"kp_equal"      = .Kp_equal,
	"left_shift"    = .Left_Shift,
	"left_control"  = .Left_Control,
	"left_alt"      = .Left_Alt,
	"left_super"    = .Left_Super,
	"right_shift"   = .Right_Shift,
	"right_control" = .Right_Control,
	"right_alt"     = .Right_Alt,
	"right_super"   = .Right_Super,
	"menu"          = .Menu,
}

Key :: enum i32 {
	Space         = 32,
	Apostrophe    = 39,
	Comma         = 44,
	Minus         = 45,
	Period        = 46,
	Slash         = 47,
	Semicolon     = 59,
	Equal         = 61,
	Left_bracket  = 91,
	Backslash     = 92,
	Right_bracket = 93,
	Grave_accent  = 96,
	World_1       = 161,
	World_2       = 162,
	Zero          = 48,
	One           = 49,
	Two           = 50,
	Three         = 51,
	Four          = 52,
	Five          = 53,
	Six           = 54,
	Seven         = 55,
	Height        = 56,
	Nine          = 57,
	A             = 65,
	B             = 66,
	C             = 67,
	D             = 68,
	E             = 69,
	F             = 70,
	G             = 71,
	H             = 72,
	I             = 73,
	J             = 74,
	K             = 75,
	L             = 76,
	M             = 77,
	N             = 78,
	O             = 79,
	P             = 80,
	Q             = 81,
	R             = 82,
	S             = 83,
	T             = 84,
	U             = 85,
	V             = 86,
	W             = 87,
	X             = 88,
	Y             = 89,
	Z             = 90,
	Escape        = 256,
	Enter         = 257,
	Tab           = 258,
	Backspace     = 259,
	Insert        = 260,
	Delete        = 261,
	Right         = 262,
	Left          = 263,
	Down          = 264,
	Up            = 265,
	Page_up       = 266,
	Page_down     = 267,
	Home          = 268,
	End           = 269,
	Caps_lock     = 280,
	Scroll_lock   = 281,
	Num_lock      = 282,
	Print_screen  = 283,
	Pause         = 284,
	F1            = 290,
	F2            = 291,
	F3            = 292,
	F4            = 293,
	F5            = 294,
	F6            = 295,
	F7            = 296,
	F8            = 297,
	F9            = 298,
	F10           = 299,
	F11           = 300,
	F12           = 301,
	F13           = 302,
	F14           = 303,
	F15           = 304,
	F16           = 305,
	F17           = 306,
	F18           = 307,
	F19           = 308,
	F20           = 309,
	F21           = 310,
	F22           = 311,
	F23           = 312,
	F24           = 313,
	F25           = 314,
	Kp_0          = 320,
	Kp_1          = 321,
	Kp_2          = 322,
	Kp_3          = 323,
	Kp_4          = 324,
	Kp_5          = 325,
	Kp_6          = 326,
	Kp_7          = 327,
	Kp_8          = 328,
	Kp_9          = 329,
	Kp_decimal    = 330,
	Kp_divide     = 331,
	Kp_multiply   = 332,
	Kp_subtract   = 333,
	Kp_add        = 334,
	Kp_enter      = 335,
	Kp_equal      = 336,
	Left_Shift    = 340,
	Left_Control  = 341,
	Left_Alt      = 342,
	Left_Super    = 343,
	Right_Shift   = 344,
	Right_Control = 345,
	Right_Alt     = 346,
	Right_Super   = 347,
	Menu          = 348,
}
