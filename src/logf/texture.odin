package logf

import "core:os"
import "core:fmt"
import "core:image"
import "core:image/png"
import gl "vendor:OpenGL"

Texture :: struct {
	kind:       enum {
		Texture,
		Cubemap,
	},
	handle:     u32,
	width:      f32,
	height:     f32,
	unit_index: u32,
	format:     u32,
}

Texture_Filter_Mode :: enum uint {
	Nearest                = 9728,
	Linear                 = 9729,
	Nearest_Mipmap_Nearest = 9984,
	Linear_Mipmap_Nearest  = 9985,
	Nearest_Mipmap_Linear  = 9986,
	Linear_Mipmap_Linear   = 9987,
}

Texture_Wrap_Mode :: enum uint {
	Clamp_To_Edge   = 33071,
	Mirrored_Repeat = 33648,
	Repeat          = 10497,
}

Texture_Space :: enum {
	Invalid,
	Linear,
	sRGB,
}

Texture_Loader :: struct {
	name:     string,
	kind:     enum {
		File,
		Raw,
	},
	width:    int,
	height:   int,
	channels: int,
	filter:   Texture_Filter_Mode,
	wrap:     Texture_Wrap_Mode,
	space:    Texture_Space,
	path:     string,
	data:     []byte,
	bitmap:   bool,
}

make_texture :: proc(loader: Texture_Loader, allocator := context.allocator) -> ^Texture {
	context.allocator = allocator
	if loader.bitmap {
		return make_bitmap_texture(loader)
	}

	texture := new(Texture)

	data := loader.data
	switch loader.kind {
	case .File:
		ok: bool
		data, ok = os.read_entire_file(loader.path, context.temp_allocator)
		if !ok {
			fmt.println("Texture: Failed to read file: %s", loader.path)
			free(texture)
			return nil
		}
		fallthrough
	case .Raw:
		assert(int(loader.filter) != 0 && int(loader.wrap) != 0)
		if loader.space == .Invalid {
			fmt.println("Texture: Invalid Texture color space", loader.path)
			free(texture)
			return nil
		}

		options := image.Options{}
		img, err := png.load_from_bytes(data, options, context.temp_allocator)
		if err != nil {
			fmt.println("Texture loading error: %s", err)
			free(texture)
			return nil
		}
		if img.depth != 8 {
			fmt.println("Texture: Only supports 8bits channels", err)
			free(texture)
			return nil
		}

		texture.kind = .Texture
		texture.width = f32(img.width)
		texture.height = f32(img.height)
		gl_internal_format: u32
		gl_format: u32
		switch img.channels {
		case 1:
			gl_format = gl.RED
			gl_internal_format = gl.R8
		case 2:
			gl_format = gl.RG
			gl_internal_format = gl.RG8
		case 3:
			gl_format = gl.RGB
			gl_internal_format = gl.RGB8 if loader.space == .Linear else gl.SRGB8
		case 4:
			gl_format = gl.RGBA
			gl_internal_format = gl.RGBA8 if loader.space == .Linear else gl.SRGB8_ALPHA8
		}
		texture.format = gl_format

		gl.GenTextures(1, &texture.handle)
		gl.BindTexture(gl.TEXTURE_2D, texture.handle)
		defer gl.BindTexture(gl.TEXTURE_2D, 0)

		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(loader.wrap))
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(loader.wrap))
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(loader.filter))
		gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(loader.filter))

		gl.TexImage2D(
			gl.TEXTURE_2D,
			0,
			i32(gl_internal_format),
			i32(texture.width),
			i32(texture.height),
			0,
			gl_format,
			gl.UNSIGNED_BYTE,
			nil,
		)
		gl.TexSubImage2D(
			gl.TEXTURE_2D,
			0,
			0,
			0,
			i32(texture.width),
			i32(texture.height),
			gl_format,
			gl.UNSIGNED_BYTE,
			raw_data(img.pixels.buf),
		)
		gl.GenerateMipmap(gl.TEXTURE_2D)
	}

	return texture
}

make_bitmap_texture :: proc(loader: Texture_Loader, allocator := context.allocator) -> ^Texture {
	context.allocator = allocator
	if int(loader.filter) == 0 || int(loader.wrap) == 0 {
		assert(false)
	}

	texture := new(Texture)
	texture.width = f32(loader.width)
	texture.height = f32(loader.height)

	gl_internal_format: u32
	gl_format: u32

	switch loader.channels {
	case 1:
		gl_format = gl.RED
		gl_internal_format = gl.R8
	case 2:
		gl_format = gl.RG
		gl_internal_format = gl.RG8
	case 3:
		gl_format = gl.RGB
		gl_internal_format = gl.RGB8
	case 4:
		gl_format = gl.RGBA
		gl_internal_format = gl.RGBA8
	}
	texture.format = gl_format

	gl.GenTextures(1, &texture.handle)
	gl.BindTexture(gl.TEXTURE_2D, texture.handle)
	defer gl.BindTexture(gl.TEXTURE_2D, 0)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, i32(loader.wrap))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, i32(loader.wrap))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, i32(loader.filter))
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, i32(loader.filter))

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		i32(gl_internal_format),
		i32(texture.width),
		i32(texture.height),
		0,
		gl_format,
		gl.UNSIGNED_BYTE,
		nil,
	)
	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(texture.width),
		i32(texture.height),
		gl_format,
		gl.UNSIGNED_BYTE,
		raw_data(loader.data),
	)
	gl.GenerateMipmap(gl.TEXTURE_2D)

	return texture
}

update_texture :: proc(texture: ^Texture, data: []byte) {
	gl.TexSubImage2D(
		gl.TEXTURE_2D,
		0,
		0,
		0,
		i32(texture.width),
		i32(texture.height),
		texture.format,
		gl.UNSIGNED_BYTE,
		raw_data(data),
	)
}

bind_texture :: proc(texture: ^Texture, unit_index: u32) {
	gl.ActiveTexture(gl.TEXTURE0 + unit_index)
	gl.BindTexture(gl.TEXTURE_2D, texture.handle)
	texture.unit_index = unit_index
}

unbind_texture :: proc(texture: ^Texture) {
	gl.ActiveTexture(gl.TEXTURE0 + texture.unit_index)
	gl.BindTexture(gl.TEXTURE_2D, 0)
	texture.unit_index = 0
}

destroy_texture :: proc(texture: ^Texture) {
	gl.DeleteTextures(1, &texture.handle)
	free(texture)
}
