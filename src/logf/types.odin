package logf

import "core:math/linalg"

Vector2 :: linalg.Vector2f32
Vector4 :: linalg.Vector4f32
Color :: linalg.Vector4f32

Matrix4 :: linalg.Matrix4x4f32

Rectangle :: struct {
	x:      f32,
	y:      f32,
	width:  f32,
	height: f32,
}

in_aabb_bounds :: proc(r: Rectangle, p: Vector2) -> bool {
	return (p.x >= r.x && p.x <= r.x + r.width) && (p.y >= r.y && p.y <= r.y + r.height)
}

normalize_u8_rgba :: proc(rgba: [4]byte) -> Color {
	#no_bounds_check {
		clr := Color {
			0 = f32(rgba[0]) / 255,
			1 = f32(rgba[1]) / 255,
			2 = f32(rgba[2]) / 255,
			3 = f32(rgba[3]) / 255,
		}
		return clr
	}
}

CLR_WHITE :: Color{1, 1, 1, 1}
