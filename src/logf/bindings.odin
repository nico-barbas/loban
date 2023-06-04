package logf

import gl "vendor:OpenGL"

Attributes :: struct {
	using layout: Attributes_Layout,
	handle:       u32,
}

DEFAULT_ATTRIBUTES :: Enabled_Attributes{.Position, .Normal, .Tex_Coord}
DEFAULT_INSTANCED_ATTRIBUTES :: Enabled_Attributes{
	.Position,
	.Normal,
	.Tex_Coord,
	.Instance_Transform,
}

Enabled_Attributes :: distinct bit_set[Attribute]
Attribute :: enum {
	Position           = 0,
	Normal             = 1,
	Tex_Coord          = 2,
	Color              = 3,
	Instance_Transform = 4,
}

Attributes_Layout :: struct {
	enabled:   Enabled_Attributes,
	accessors: [len(Attribute)]Maybe(Buffer_Accessor),
}

Attributes_Bindings :: struct {
	vertices: [len(Attribute)]Buffer_Memory,
	indices:  Buffer_Memory,
}

make_attributes :: proc(layout: Attributes_Layout, allocator := context.allocator) -> ^Attributes {
	context.allocator = allocator

	attributes := new_clone(Attributes{layout = layout})
	gl.GenVertexArrays(1, &attributes.handle)
	gl.BindVertexArray(attributes.handle)

	// offset := 0
	// size := layout_size(layout)
	// for kind in Attribute do if kind in attributes.enabled {
	// 		accessor := attributes.accessors[kind].?
	// 		location := u32(kind)
	// 		gl.EnableVertexAttribArray(location)
	// 		gl.VertexAttribPointer(location, i32(buffer_element_len[accessor.format]), gl.FLOAT, false, i32(size), uintptr(offset))

	// 		offset += accessor_size(accessor)
	// 	}

	return attributes
}

destroy_attributes :: proc(attributes: ^Attributes) {
	gl.DeleteVertexArrays(1, &attributes.handle)
	free(attributes)
}

bind_attributes :: proc(attributes: ^Attributes, bindings: ^Attributes_Bindings) {
	gl.BindVertexArray(attributes.handle)

	for kind in Attribute do if kind in attributes.enabled {
			accessor := attributes.accessors[kind].?
			size := accessor_size(accessor)
			m := bindings.vertices[kind]

			if m.buf == nil {
				continue
			}
			location := u32(kind)
			gl.BindBuffer(gl.ARRAY_BUFFER, m.buf.handle)
			gl.EnableVertexAttribArray(location)
			gl.VertexAttribPointer(location, i32(buffer_element_len[accessor.format]), gl.FLOAT, false, i32(size), uintptr(m.offset))
		}

	gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, bindings.indices.buf.handle)
}

//////
Buffer :: struct {
	handle: u32,
	size:   int,
	used:   int,
	usage:  Buffer_Usage,
}

Buffer_Memory :: struct {
	buf:    ^Buffer,
	size:   int,
	offset: int,
}

Buffer_Usage :: enum {
	Static  = 0x88E4,
	Dynamic = 0x88E8,
}

Buffer_Accessor :: struct {
	kind:   Buffer_Element_Kind,
	format: Buffer_Element_Format,
}

Buffer_Source :: struct {
	size: int,
	data: rawptr,
}


Buffer_Element_Format :: enum {
	Unspecified,
	Scalar,
	Vector2,
	Vector3,
	Vector4,
	Mat2,
	Mat3,
	Mat4,
}

Buffer_Element_Kind :: enum {
	Byte,
	Boolean,
	Unsigned_16,
	Signed_16,
	Unsigned_32,
	Signed_32,
	Float_16,
	Float_32,
	Float_64,
}

buffer_element_len := map[Buffer_Element_Format]int {
	.Unspecified = 0,
	.Scalar      = 1,
	.Vector2     = 2,
	.Vector3     = 3,
	.Vector4     = 4,
	.Mat2        = 4,
	.Mat3        = 9,
	.Mat4        = 16,
}

buffer_element_size := map[Buffer_Element_Kind]int {
	.Byte        = size_of(byte),
	.Boolean     = size_of(bool),
	.Unsigned_16 = size_of(u16),
	.Signed_16   = size_of(i16),
	.Unsigned_32 = size_of(u32),
	.Signed_32   = size_of(i32),
	.Float_16    = size_of(f16be),
	.Float_32    = size_of(f32),
	.Float_64    = size_of(f64),
}

@(private)
accessor_size :: proc(a: Buffer_Accessor) -> int {
	return buffer_element_size[a.kind] * buffer_element_len[a.format]
}

layout_size :: proc(l: Attributes_Layout) -> int {
	accumulator := 0

	for kind in Attribute {
		if kind not_in l.enabled {
			continue
		}
		accumulator += accessor_size(l.accessors[kind].?)
	}

	return accumulator
}

make_buffer :: proc(size: int, usage: Buffer_Usage, allocator := context.allocator) -> ^Buffer {
	context.allocator = allocator

	buffer := new_clone(Buffer{size = size, used = 0, usage = usage})
	gl.GenBuffers(1, &buffer.handle)
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer.handle)
	gl.BufferData(gl.ARRAY_BUFFER, size, nil, gl.STATIC_DRAW)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
	return buffer
}

destroy_buffer :: proc(buffer: ^Buffer) {
	gl.DeleteBuffers(1, &buffer.handle)
	free(buffer)
}

append_buffer :: proc(
	buffer: ^Buffer,
	source: Buffer_Source,
	align_forward := false,
) -> Buffer_Memory {
	if source.size > buffer.size - buffer.used {
		assert(false)
	}

	if align_forward {
		alignment: i32
		gl.GetIntegerv(gl.UNIFORM_BUFFER_OFFSET_ALIGNMENT, &alignment)

		gap := int(alignment) - (buffer.used % int(alignment))

		if gap > 0 {
			buffer.used += gap
		}
	}
	gl.BindBuffer(gl.ARRAY_BUFFER, buffer.handle)
	gl.BufferSubData(gl.ARRAY_BUFFER, buffer.used, source.size, source.data)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)

	memory := Buffer_Memory {
		buf    = buffer,
		size   = source.size,
		offset = buffer.used,
	}
	buffer.used += source.size
	return memory
}

update_buffer_memory :: proc(memory: Buffer_Memory, source: Buffer_Source, offset := 0) {
	assert(memory.size - offset >= source.size)
	gl.BindBuffer(gl.ARRAY_BUFFER, memory.buf.handle)
	gl.BufferSubData(gl.ARRAY_BUFFER, memory.offset + offset, source.size, source.data)
	gl.BindBuffer(gl.ARRAY_BUFFER, 0)
}
