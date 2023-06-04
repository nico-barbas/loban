package logf

import "core:os"
import "core:log"
import "core:fmt"
import "core:runtime"
import "core:strings"
import gl "vendor:OpenGL"

Shader :: struct {
	handle:           u32,
	stages:           Shader_Stages,
	uniforms:         map[string]Shader_Uniform_Info,
	uniform_warnings: map[string]bool,
}

Shader_Stages :: distinct bit_set[Shader_Stage]

Shader_Stage :: enum i32 {
	Invalid,
	Fragment,
	Vertex,
	Geometry,
	Compute,
	Tessalation_Eval,
	Tessalation_Control,
}

@(private)
gl_shader_type :: proc(s: Shader_Stage) -> gl.Shader_Type {
	switch s {
	case .Invalid:
		return .NONE
	case .Fragment:
		return .FRAGMENT_SHADER
	case .Vertex:
		return .VERTEX_SHADER
	case .Geometry:
		return .GEOMETRY_SHADER
	case .Compute:
		return .COMPUTE_SHADER
	case .Tessalation_Eval:
		return .TESS_EVALUATION_SHADER
	case .Tessalation_Control:
		return .TESS_CONTROL_SHADER
	}
	return .SHADER_LINK
}

Uniform_Location :: distinct i32

Shader_Uniform_Info :: struct {
	loc:      Uniform_Location,
	accessor: Buffer_Accessor,
	count:    int,
}

Shader_Loader :: struct {
	name:   string,
	stages: [len(Shader_Stage)]Maybe(Shader_Stage_Loader),
}

Shader_Stage_Loader :: struct {
	kind:      enum {
		File,
		Raw,
	},
	file_path: string,
	source:    string,
}

make_shader :: proc(loader: Shader_Loader, allocator := context.allocator) -> ^Shader {
	context.allocator = allocator

	shader := new(Shader)
	shader.handle = gl.CreateProgram()

	file_based := false
	stage_count: int
	for s, i in loader.stages {
		if s != nil {
			stage := s.?
			switch stage.kind {
			case .File:
				file_based = true
				data, ok := os.read_entire_file(stage.file_path, context.temp_allocator)
				if !ok {
					log.fatalf(
						"[%s]: Failed to read shader source file:\n\t- %s\n",
						"Shader",
						stage.file_path,
					)
					return nil
				}

				stage.source = string(data)
				fallthrough
			case .Raw:
				stage_handle := compile_shader_source(
					stage.source,
					gl_shader_type(Shader_Stage(i)),
					loader.name,
				)
				defer gl.DeleteShader(stage_handle)

				if stage_handle == 0 {
					log.fatalf(
						"[%s]: Failed to compile shader stage %s",
						"Shader",
						Shader_Stage(i),
					)
					return nil
				}
				gl.AttachShader(shader.handle, stage_handle)
				shader.stages += {Shader_Stage(i)}
			}
			stage_count += 1
		}
	}

	gl.LinkProgram(shader.handle)
	compile_ok: i32
	gl.GetProgramiv(shader.handle, gl.LINK_STATUS, &compile_ok)
	if compile_ok == 0 {
		max_length: i32
		gl.GetProgramiv(shader.handle, gl.INFO_LOG_LENGTH, &max_length)

		message: [512]byte
		gl.GetProgramInfoLog(shader.handle, 512, &max_length, &message[0])
		log.debugf(
			"[%s]: Linkage error Shader[%d]:\n\t%s\n",
			"Shader",
			shader.handle,
			string(message[:max_length]),
		)
	}

	// Populate uniform cache
	u_count: i32
	gl.GetProgramiv(shader.handle, gl.ACTIVE_UNIFORMS, &u_count)
	if u_count != 0 {
		shader.uniforms = make(
			map[string]Shader_Uniform_Info,
			runtime.DEFAULT_RESERVE_CAPACITY,
			allocator,
		)
		shader.uniform_warnings.allocator = allocator

		max_name_len: i32
		cur_name_len: i32
		size: i32
		type: u32
		gl.GetProgramiv(shader.handle, gl.ACTIVE_UNIFORM_MAX_LENGTH, &max_name_len)
		for i in 0 ..< u_count {
			buf := make([]u8, max_name_len, context.temp_allocator)
			gl.GetActiveUniform(
				shader.handle,
				u32(i),
				max_name_len,
				&cur_name_len,
				&size,
				&type,
				&buf[0],
			)
			u_name := format_uniform_name(buf, cur_name_len, type)
			shader.uniforms[u_name] = Shader_Uniform_Info {
				loc      = Uniform_Location(
					gl.GetUniformLocation(shader.handle, cstring(raw_data(buf))),
				),
				accessor = uniform_type(type),
				count    = int(size),
			}
		}
	}

	if stage_count == 0 {
		assert(false)
	}

	return shader
}

@(private)
compile_shader_source :: proc(
	shader_data: string,
	shader_type: gl.Shader_Type,
	filepath: string = "",
) -> (
	shader_handle: u32,
) {
	shader_handle = gl.CreateShader(cast(u32)shader_type)
	shader_data_copy := strings.clone_to_cstring(shader_data, context.temp_allocator)
	gl.ShaderSource(shader_handle, 1, &shader_data_copy, nil)
	gl.CompileShader(shader_handle)

	compile_ok: i32
	gl.GetShaderiv(shader_handle, gl.COMPILE_STATUS, &compile_ok)
	if compile_ok == 0 {
		max_length: i32
		gl.GetShaderiv(shader_handle, gl.INFO_LOG_LENGTH, &max_length)

		message: [512]byte
		file_name: string
		if filepath != "" {
			file_name = filepath
		} else {
			#partial switch shader_type {
			case .VERTEX_SHADER:
				file_name = "Vertex shader"
			case .FRAGMENT_SHADER:
				file_name = "Fragment shader"
			case:
				file_name = "Unknown shader"
			}
		}
		gl.GetShaderInfoLog(shader_handle, 512, &max_length, &message[0])
		fmt.println(
			"%s Compilation error [%s]:\n%s\n\nSource:\n",
			shader_type,
			file_name,
			string(message[:max_length]),
		)

		lines := strings.split_lines(shader_data, context.temp_allocator)
		for line, i in lines {
			fmt.printf("%d\t%s\n", i + 1, line)
		}
	}
	return
}

@(private = "file")
format_uniform_name :: proc(buf: []u8, l: i32, t: u32, allocator := context.allocator) -> string {
	length := int(l)
	if t == gl.SAMPLER_2D || t == gl.FLOAT_MAT4 {
		if buf[length - 1] == ']' {
			length -= 3
		}
	}
	return strings.clone_from_bytes(buf[:length], allocator)
}

@(private)
uniform_type :: proc(t: u32) -> (accessor: Buffer_Accessor) {
	switch t {
	case gl.BOOL:
		accessor.kind = .Boolean
		accessor.format = .Scalar

	case gl.INT, gl.SAMPLER_2D, gl.SAMPLER_CUBE:
		accessor.kind = .Signed_32
		accessor.format = .Scalar
	case gl.INT_VEC2:
		accessor.kind = .Signed_32
		accessor.format = .Vector2
	case gl.INT_VEC3:
		accessor.kind = .Signed_32
		accessor.format = .Vector3
	case gl.INT_VEC4:
		accessor.kind = .Signed_32
		accessor.format = .Vector4

	case gl.UNSIGNED_INT:
		accessor.kind = .Unsigned_32
		accessor.format = .Scalar
	case gl.UNSIGNED_INT_VEC2:
		accessor.kind = .Unsigned_32
		accessor.format = .Vector2
	case gl.UNSIGNED_INT_VEC3:
		accessor.kind = .Unsigned_32
		accessor.format = .Vector3
	case gl.UNSIGNED_INT_VEC4:
		accessor.kind = .Unsigned_32
		accessor.format = .Vector4

	case gl.FLOAT:
		accessor.kind = .Float_32
		accessor.format = .Scalar
	case gl.FLOAT_VEC2:
		accessor.kind = .Float_32
		accessor.format = .Vector2
	case gl.FLOAT_VEC3:
		accessor.kind = .Float_32
		accessor.format = .Vector3
	case gl.FLOAT_VEC4:
		accessor.kind = .Float_32
		accessor.format = .Vector4
	case gl.FLOAT_MAT2:
		accessor.kind = .Float_32
		accessor.format = .Mat2
	case gl.FLOAT_MAT3:
		accessor.kind = .Float_32
		accessor.format = .Mat3
	case gl.FLOAT_MAT4:
		accessor.kind = .Float_32
		accessor.format = .Mat4

	case gl.DOUBLE:
		accessor.kind = .Float_64
		accessor.format = .Scalar
	}
	return
}

set_shader_uniform :: proc(
	shader: ^Shader,
	name: string,
	value: rawptr,
	caller_loc := #caller_location,
) {

	if exist := name in shader.uniforms; !exist {
		if exist = name in shader.uniform_warnings; !exist {
			fmt.println(
				"Shader ID[%d]: Failed to retrieve uniform: %s\nCall location: %v",
				shader.handle,
				name,
				caller_loc,
			)
			allocator := shader.uniform_warnings.allocator
			shader.uniform_warnings[strings.clone(name, allocator)] = true
		}
		return
	}
	uniform := shader.uniforms[name]
	loc := i32(uniform.loc)
	switch uniform.accessor.format {
	case .Unspecified:
		assert(false)

	case .Scalar:
		#partial switch uniform.accessor.kind {
		case .Boolean:
			b := 1 if (cast(^bool)value)^ else 0
			// if b {
			// 	log.debug("????")
			// }
			// log.debugf("at %v: %t", caller_loc, b)
			gl.Uniform1iv(loc, i32(uniform.count), cast([^]i32)&b)
		case .Signed_32:
			gl.Uniform1iv(loc, i32(uniform.count), cast([^]i32)value)
		case .Unsigned_32:
			gl.Uniform1uiv(loc, i32(uniform.count), cast([^]u32)value)
		case .Float_32:
			gl.Uniform1fv(loc, i32(uniform.count), cast([^]f32)value)
		}

	case .Vector2:
		#partial switch uniform.accessor.kind {
		case .Signed_32:
			gl.Uniform2iv(loc, i32(uniform.count), cast([^]i32)value)
		case .Unsigned_32:
			gl.Uniform2uiv(loc, i32(uniform.count), cast([^]u32)value)
		case .Float_32:
			gl.Uniform2fv(loc, i32(uniform.count), cast([^]f32)value)
		}

	case .Vector3:
		#partial switch uniform.accessor.kind {
		case .Signed_32:
			gl.Uniform3iv(loc, i32(uniform.count), cast([^]i32)value)
		case .Unsigned_32:
			gl.Uniform3uiv(loc, i32(uniform.count), cast([^]u32)value)
		case .Float_32:
			gl.Uniform3fv(loc, i32(uniform.count), cast([^]f32)value)
		}

	case .Vector4:
		#partial switch uniform.accessor.kind {
		case .Signed_32:
			gl.Uniform4iv(loc, i32(uniform.count), cast([^]i32)value)
		case .Unsigned_32:
			gl.Uniform4uiv(loc, i32(uniform.count), cast([^]u32)value)
		case .Float_32:
			gl.Uniform4fv(loc, i32(uniform.count), cast([^]f32)value)
		}

	case .Mat2:
		#partial switch uniform.accessor.kind {
		case .Float_32:
			gl.UniformMatrix2fv(loc, i32(uniform.count), gl.FALSE, cast([^]f32)value)
		}

	case .Mat3:
		#partial switch uniform.accessor.kind {
		case .Float_32:
			gl.UniformMatrix3fv(loc, i32(uniform.count), gl.FALSE, cast([^]f32)value)
		}

	case .Mat4:
		#partial switch uniform.accessor.kind {
		case .Float_32:
			gl.UniformMatrix4fv(loc, i32(uniform.count), gl.FALSE, cast([^]f32)value)
		}
	}
}

destroy_shader :: proc(shader: ^Shader) {
	for k, _ in shader.uniforms {
		delete(k)
	}
	delete(shader.uniforms)
	for k, _ in shader.uniform_warnings {
		delete(k)
	}
	delete(shader.uniform_warnings)
	gl.DeleteProgram(shader.handle)
	free(shader)
}

bind_shader :: proc(shader: ^Shader) {
	gl.UseProgram(shader.handle)
}

default_shader :: proc() {
	gl.UseProgram(0)
}

shader_vs :: #load("internals/shader.vs")
shader_fs :: #load("internals/shader.fs")
