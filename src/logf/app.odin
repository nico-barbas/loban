package logf

import "core:os"
import "core:mem"
import "core:fmt"
import "core:time"
import "core:runtime"
import "core:path/filepath"
import "vendor:glfw"
import gl "vendor:OpenGL"

@(private)
_app: ^App

App :: struct {
	using conf:   App_Config,
	handle:       glfw.WindowHandle,
	input:        Input_Buffer,

	// Allocators
	ctx:          runtime.Context,
	frame_arena:  mem.Arena,

	// Runtime states
	is_running:   bool,
	start_time:   time.Time,
	last_time:    time.Time,
	elapsed_time: f32,
	total_time:   f32,
}

App_Config :: struct {
	width:  int,
	height: int,
	title:  string,
}

init_app :: proc(conf: App_Config, allocator := context.allocator) -> ^App {
	context.allocator = allocator
	app := new(App)
	app.conf = conf

	mem.arena_init(&app.frame_arena, make([]byte, mem.Megabyte * 64))
	context.temp_allocator = mem.arena_allocator(&app.frame_arena)

	exe_path := os.args[0]
	exe_dir := filepath.dir(exe_path, context.temp_allocator)
	os.change_directory(exe_dir)

	if glfw.Init() == 0 {
		fmt.println("Failed to init GLFW")
	}

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
	glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, 1)
	glfw.WindowHint(glfw.SAMPLES, 4)

	app.handle = glfw.CreateWindow(
		i32(app.width),
		i32(app.height),
		cstring(raw_data(app.title)),
		nil,
		nil,
	)
	if app.handle == nil {
		fmt.println("Failed to create window")
		unreachable()
	}

	glfw.MakeContextCurrent(app.handle)

	gl.load_up_to(
		3,
		3,
		proc(p: rawptr, name: cstring) {(cast(^rawptr)p)^ = glfw.GetProcAddress(name)},
	)
	gl.Enable(gl.DEBUG_OUTPUT)
	gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS)
	gl.Enable(gl.MULTISAMPLE)
	gl.Enable(gl.BLEND)
	// gl.Enable(gl.FRAMEBUFFER_SRGB)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)


	glfw.SetKeyCallback(app.handle, key_callback)
	glfw.SetCharCallback(app.handle, char_callback)
	glfw.SetMouseButtonCallback(app.handle, mouse_button_callback)
	glfw.SetScrollCallback(app.handle, mouse_scroll_callback)
	glfw.SwapInterval(1)

	_app = app
	init_input_buffer(&app.input)
	app.is_running = true
	app.start_time = time.now()
	app.last_time = time.now()
	return app
}

destroy_app :: proc(app: ^App) {
	delete(app.frame_arena.data)
	destroy_input_buffer(&app.input)
	free(app)
}

begin_frame :: proc(app: ^App) {
	app.is_running = !bool(glfw.WindowShouldClose(app.handle))
	app.elapsed_time = f32(time.duration_seconds(time.since(app.last_time)))
	app.total_time = f32(time.duration_seconds(time.since(app.start_time)))
	app.last_time = time.now()
	app.frame_arena.offset = 0
	set_viewport(0, 0, app.width, app.height)
	clear_viewport({0.5, 0.5, 0.5, 1})
}

end_frame :: proc(app: ^App) {
	update_input(app)
	swap_buffers(app)
	glfw.PollEvents()
}


@(private = "file")
swap_buffers :: proc(app: ^App) {
	glfw.SwapBuffers(app.handle)
}
