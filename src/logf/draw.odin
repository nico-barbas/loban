package logf

import "core:math/linalg"
import gl "vendor:OpenGL"

@(private)
set_viewport :: proc(x, y, w, h: int) {
	gl.Viewport(i32(x), i32(y), i32(w), i32(h))
}

@(private)
clear_viewport :: proc(clr: Color) {
	gl.ClearColor(clr.r, clr.g, clr.b, clr.a)
	gl.Clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT)
}

@(private)
draw_triangles :: proc(count: int, byte_offset: uintptr = 0, index_offset := 0) {
	gl.DrawElementsBaseVertex(
		gl.TRIANGLES,
		i32(count),
		gl.UNSIGNED_INT,
		rawptr(byte_offset),
		i32(index_offset),
	)
}

@(private)
draw_instanced_triangles :: proc(
	count: int,
	instance_count: int,
	byte_offset: uintptr = 0,
	index_offset := 0,
) {
	gl.DrawElementsInstancedBaseVertex(
		gl.TRIANGLES,
		i32(count),
		gl.UNSIGNED_INT,
		rawptr(byte_offset),
		i32(instance_count),
		i32(index_offset),
	)
}

@(private)
draw_lines :: proc(count: int, byte_offset: uintptr = 0, index_offset := 0) {
	gl.DrawElementsBaseVertex(
		gl.LINES,
		i32(count),
		gl.UNSIGNED_INT,
		rawptr(byte_offset),
		i32(index_offset),
	)
}

enable_depth :: proc() {
	gl.Enable(gl.DEPTH_TEST)
	gl.DepthMask(true)
}

disable_depth :: proc() {
	gl.DepthMask(false)
	gl.Disable(gl.DEPTH_TEST)
}

Face_Culling_Mode :: enum {
	Front,
	Back,
}

enable_face_culling :: proc(mode := Face_Culling_Mode.Back) {
	gl.Enable(gl.CULL_FACE)
	switch mode {
	case .Front:
		gl.CullFace(gl.FRONT)
	case .Back:
		gl.CullFace(gl.BACK)
	}
}

disable_face_culling :: proc() {
	gl.Disable(gl.CULL_FACE)
}

MAX_TEXTURE_BINDINGS :: 16

@(private)
DEFAULT_BATCH_CAP :: 50_000

Batch :: struct {
	default_shader:   ^Shader,
	shader:           ^Shader,
	attributes:       ^Attributes,
	buffer_allocator: ^Buffer,
	bindings:         Attributes_Bindings,
	positions:        []Vector4,
	tex_coords:       []Vector4,
	colors:           []Color,
	vertex_count:     int,
	indices:          []u32,
	index_count:      int,
	textures:         [MAX_TEXTURE_BINDINGS]^Texture,
	texture_count:    int,
	projection:       Matrix4,
}

init_batch :: proc(batch: ^Batch, cap := DEFAULT_BATCH_CAP, allocator := context.allocator) {
	context.allocator = allocator

	batch.texture_count = 1
	batch.textures[0] = make_texture(
		Texture_Loader{
			name = "default_white",
			kind = .Raw,
			width = 1,
			height = 1,
			channels = 4,
			filter = .Nearest,
			wrap = .Repeat,
			space = .Linear,
			data = {0xff, 0xff, 0xff, 0xff},
			bitmap = true,
		},
	)

	batch.attributes = make_attributes(
		Attributes_Layout{
			enabled = {.Position, .Tex_Coord, .Color},
			accessors = {
				Attribute.Position = Buffer_Accessor{kind = .Float_32, format = .Vector4},
				Attribute.Tex_Coord = Buffer_Accessor{kind = .Float_32, format = .Vector4},
				Attribute.Color = Buffer_Accessor{kind = .Float_32, format = .Vector4},
			},
		},
	)

	v_cap := 4 * cap
	i_cap := 6 * cap
	pos_size := size_of(Vector4) * v_cap
	tex_coord_size := size_of(Vector4) * v_cap
	clr_size := size_of(Color) * v_cap
	indices_size := size_of(u32) * i_cap
	total_size := pos_size + tex_coord_size + clr_size + indices_size

	// GPU side memory
	batch.buffer_allocator = make_buffer(total_size, .Dynamic)
	batch.bindings = Attributes_Bindings {
		vertices = {
			Attribute.Position = append_buffer(
				batch.buffer_allocator,
				Buffer_Source{size = pos_size, data = nil},
			),
			Attribute.Tex_Coord = append_buffer(
				batch.buffer_allocator,
				Buffer_Source{size = tex_coord_size, data = nil},
			),
			Attribute.Color = append_buffer(
				batch.buffer_allocator,
				Buffer_Source{size = clr_size, data = nil},
			),
		},
		indices = append_buffer(
			batch.buffer_allocator,
			Buffer_Source{size = indices_size, data = nil},
		),
	}

	// CPU side memory
	batch.positions = make([]Vector4, cap)
	batch.tex_coords = make([]Vector4, cap)
	batch.colors = make([]Color, cap)
	batch.indices = make([]u32, cap)

	batch.default_shader = make_shader(
		Shader_Loader{
			name = "im2d_shader",
			stages = {
				Shader_Stage.Vertex = Shader_Stage_Loader{kind = .Raw, source = string(shader_vs)},
				Shader_Stage.Fragment = Shader_Stage_Loader{
					kind = .Raw,
					source = string(shader_fs),
				},
			},
		},
	)

	bind_shader(batch.default_shader)
	defer default_shader()

	texture_indices: [MAX_TEXTURE_BINDINGS]u32
	for i in 0 ..< MAX_TEXTURE_BINDINGS {
		texture_indices[i] = u32(i)
	}
	set_shader_uniform(batch.default_shader, "textures", &texture_indices[0])
}

destroy_batch :: proc(batch: ^Batch) {
	destroy_attributes(batch.attributes)
	destroy_texture(batch.textures[0])
	destroy_buffer(batch.buffer_allocator)
	destroy_shader(batch.default_shader)
	delete(batch.positions)
	delete(batch.tex_coords)
	delete(batch.colors)
	delete(batch.indices)
}

begin_batch :: proc(batch: ^Batch, shader: Maybe(^Shader), render_w: int, render_h: int) {
	batch.vertex_count = 0
	batch.index_count = 0
	batch.texture_count = 1
	batch.shader = shader == nil ? batch.default_shader : shader.?

	batch.projection = linalg.matrix_mul(
		linalg.matrix_ortho3d_f32(0, f32(render_w), f32(render_h), 0, 1, 100),
		linalg.matrix4_translate_f32({0, 0, f32(-1)}),
	)
}

end_batch :: proc(batch: ^Batch) {
	disable_depth()
	defer enable_depth()

	bind := &batch.bindings
	update_buffer_memory(
		bind.vertices[Attribute.Position],
		Buffer_Source{data = &batch.positions[0], size = size_of(Vector4) * batch.vertex_count},
	)
	update_buffer_memory(
		bind.vertices[Attribute.Tex_Coord],
		Buffer_Source{data = &batch.tex_coords[0], size = size_of(Vector4) * batch.vertex_count},
	)
	update_buffer_memory(
		bind.vertices[Attribute.Color],
		Buffer_Source{data = &batch.colors[0], size = size_of(Vector4) * batch.vertex_count},
	)
	update_buffer_memory(
		bind.indices,
		Buffer_Source{data = &batch.indices[0], size = size_of(u32) * batch.index_count},
	)

	bind_shader(batch.shader)
	defer default_shader()

	set_shader_uniform(batch.shader, "mat_proj", &batch.projection[0][0])

	if batch.shader != batch.default_shader {
		texture_indices: [MAX_TEXTURE_BINDINGS]u32
		for i in 0 ..< MAX_TEXTURE_BINDINGS {
			texture_indices[i] = u32(i)
		}
		set_shader_uniform(batch.shader, "textures", &texture_indices[0])
	}

	for texture, i in batch.textures[:batch.texture_count] {
		bind_texture(texture, u32(i))
	}

	defer for texture in batch.textures[:batch.texture_count] {
		unbind_texture(texture)
	}
	bind_attributes(batch.attributes, bind)
	draw_triangles(batch.index_count, uintptr(bind.indices.offset))
}

draw_rectangle :: proc(batch: ^Batch, rect: Rectangle, clr: Color) {
	i := u32(batch.vertex_count)
	defer batch.vertex_count += 4

	#no_bounds_check {
		batch.positions[i] = {rect.x, rect.y, 0, 0}
		batch.positions[i + 1] = {rect.x + rect.width, rect.y, 0, 0}
		batch.positions[i + 2] = {rect.x + rect.width, rect.y + rect.height, 0, 0}
		batch.positions[i + 3] = {rect.x, rect.y + rect.height, 0, 0}

		batch.tex_coords[i] = {0, 0, 0, 0}
		batch.tex_coords[i + 1] = {1, 0, 0, 0}
		batch.tex_coords[i + 2] = {1, 1, 0, 0}
		batch.tex_coords[i + 3] = {0, 1, 0, 0}

		batch.colors[i] = clr
		batch.colors[i + 1] = clr
		batch.colors[i + 2] = clr
		batch.colors[i + 3] = clr
	}

	idx := i
	i = u32(batch.index_count)
	defer batch.index_count += 6

	#no_bounds_check {
		batch.indices[i] = idx
		batch.indices[i + 1] = idx + 2
		batch.indices[i + 2] = idx + 1

		batch.indices[i + 3] = idx
		batch.indices[i + 4] = idx + 3
		batch.indices[i + 5] = idx + 2
	}
}

draw_rectangle_outline :: proc(batch: ^Batch, rect: Rectangle, thickness: f32, clr: Color) {
	w, h := rect.width, rect.height
	draw_rectangle(batch, {rect.x, rect.y, w, thickness}, clr)
	draw_rectangle(batch, {rect.x + w, rect.y, thickness, h}, clr)
	draw_rectangle(batch, {rect.x, rect.y + h, w + thickness, thickness}, clr)
	draw_rectangle(batch, {rect.x, rect.y, thickness, h}, clr)
}

draw_rectangle_round :: proc(batch: ^Batch, rect: Rectangle, radius: f32, clr: Color) {
	i := u32(batch.vertex_count)
	defer batch.vertex_count += 4

	r := min(rect.width / 2, rect.height / 2, radius)
	#no_bounds_check {
		batch.positions[i] = {rect.x, rect.y, rect.width, rect.height}
		batch.positions[i + 1] = {rect.x + rect.width, rect.y, rect.width, rect.height}
		batch.positions[i + 2] = {
			rect.x + rect.width,
			rect.y + rect.height,
			rect.width,
			rect.height,
		}
		batch.positions[i + 3] = {rect.x, rect.y + rect.height, rect.width, rect.height}

		batch.tex_coords[i] = {0, 0, 0, r}
		batch.tex_coords[i + 1] = {1, 0, 0, r}
		batch.tex_coords[i + 2] = {1, 1, 0, r}
		batch.tex_coords[i + 3] = {0, 1, 0, r}

		batch.colors[i] = clr
		batch.colors[i + 1] = clr
		batch.colors[i + 2] = clr
		batch.colors[i + 3] = clr
	}

	idx := i
	i = u32(batch.index_count)
	defer batch.index_count += 6

	#no_bounds_check {
		batch.indices[i] = idx
		batch.indices[i + 1] = idx + 2
		batch.indices[i + 2] = idx + 1

		batch.indices[i + 3] = idx
		batch.indices[i + 4] = idx + 3
		batch.indices[i + 5] = idx + 2
	}
}

draw_texture :: proc(batch: ^Batch, texture: ^Texture, src, dst: Rectangle, clr: Color) {
	i := u32(batch.vertex_count)
	defer batch.vertex_count += 4

	tex_index: f32 = -1
	for t, i in batch.textures[:batch.texture_count] {
		if t.handle == texture.handle {
			tex_index = f32(i)
			break
		}
	}

	if tex_index == -1 {
		batch.textures[batch.texture_count] = texture
		tex_index = f32(batch.texture_count)
		batch.texture_count += 1
	}

	#no_bounds_check {
		batch.positions[i] = {dst.x, dst.y, 0, 0}
		batch.positions[i + 1] = {dst.x + dst.width, dst.y, 0, 0}
		batch.positions[i + 2] = {dst.x + dst.width, dst.y + dst.height, 0, 0}
		batch.positions[i + 3] = {dst.x, dst.y + dst.height, 0, 0}

		uvs := Rectangle {
			x      = src.x / texture.width,
			y      = src.y / texture.height,
			width  = src.width / texture.width,
			height = src.height / texture.height,
		}
		batch.tex_coords[i] = {uvs.x, uvs.y, tex_index, 0}
		batch.tex_coords[i + 1] = {uvs.x + uvs.width, uvs.y, tex_index, 0}
		batch.tex_coords[i + 2] = {uvs.x + uvs.width, uvs.y + uvs.height, tex_index, 0}
		batch.tex_coords[i + 3] = {uvs.x, uvs.y + uvs.height, tex_index, 0}

		batch.colors[i] = clr
		batch.colors[i + 1] = clr
		batch.colors[i + 2] = clr
		batch.colors[i + 3] = clr
	}

	idx := i
	i = u32(batch.index_count)
	defer batch.index_count += 6

	#no_bounds_check {
		batch.indices[i] = idx
		batch.indices[i + 1] = idx + 2
		batch.indices[i + 2] = idx + 1

		batch.indices[i + 3] = idx
		batch.indices[i + 4] = idx + 3
		batch.indices[i + 5] = idx + 2
	}
}

draw_text :: proc(
	batch: ^Batch,
	font: ^Font,
	text: string,
	origin: Vector2,
	size: int,
	clr: Color,
) {
	face := &font.faces[size]
	cursor_pos := origin + {0, f32(face.ascent)}
	if len(text) > 1 {
		cursor_pos.x += f32(face.glyphs[text[0]].left_bearing)
	}
	for r in text {
		glyph := face.glyphs[r]
		if r == ' ' {
			cursor_pos.x += f32(glyph.advance)
			continue
		}

		rect := Rectangle{
			cursor_pos.x + f32(glyph.left_bearing),
			cursor_pos.y + f32(glyph.y_offset),
			f32(glyph.width),
			f32(glyph.height),
		}
		draw_texture(
			batch,
			face.texture,
			{f32(glyph.x), f32(glyph.y), f32(glyph.width), f32(glyph.height)},
			rect,
			clr,
		)
		cursor_pos.x += f32(glyph.advance)
	}
}
