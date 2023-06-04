package loui

import "core:math"
import "../logf"

Image :: ^logf.Texture

Image_Slice_Info :: struct {
	top_left:     Rect,
	top_right:    Rect,
	bottom_right: Rect,
	bottom_left:  Rect,
}

Background :: struct {
	style:      enum {
		None,
		Flat,
		Image_Slice,
	},
	clr:        Color,
	image:      Image,
	slice_info: Image_Slice_Info,
}

Border :: struct {
	style:        enum {
		None,
		Outline,
		Rounded,
	},
	clr:          Color,
	radius:       f32,
	inner_margin: f32,
	thickness:    f32,
}

Text :: struct {
	font:        ^logf.Font,
	size:        int,
	clr:         Color,
	align_style: enum {
		Left,
		Center,
		Right,
	},
}

Color :: logf.Color

Rect :: logf.Rectangle

Rect_Cut :: enum u8 {
	Cut_Top,
	Cut_Right,
	Cut_Left,
	Cut_Bottom,
}

make_rect :: proc(x, y, w, h: f32) -> Rect {
	return {x = x, y = y, width = w, height = h}
}

cut_rect :: proc(rect: ^Rect, cut: Rect_Cut, size: f32) -> (result: Rect) {
	switch cut {
	case .Cut_Top:
		y := rect.y
		rect.y = min(y + size, y + rect.height)
		rect.height = max(rect.height - size, 0)

		result = Rect {
			x      = rect.x,
			y      = y,
			width  = rect.width,
			height = size,
		}

	case .Cut_Right:
		x := rect.x + (rect.width - size)
		rect.width = max(rect.width - size, 0)

		result = Rect {
			x      = x,
			y      = rect.y,
			width  = size,
			height = rect.height,
		}

	case .Cut_Bottom:
		y := rect.y + (rect.height - size)
		rect.height = max(rect.height - size, 0)

		result = Rect {
			x      = rect.x,
			y      = y,
			width  = rect.width,
			height = size,
		}

	case .Cut_Left:
		x := rect.x
		rect.x = min(x + size, x + rect.width)
		rect.width = max(rect.width - size, 0)

		result = Rect {
			x      = x,
			y      = rect.y,
			width  = size,
			height = rect.height,
		}
	}

	return
}

cut_rect_margin_h :: proc(rect: ^Rect, margin_h: f32) {
	cut_rect(rect, .Cut_Left, margin_h)
	cut_rect(rect, .Cut_Right, margin_h)
}

cut_rect_margin_v :: proc(rect: ^Rect, margin_v: f32) {
	cut_rect(rect, .Cut_Top, margin_v)
	cut_rect(rect, .Cut_Bottom, margin_v)
}

cut_rect_margin :: proc(rect: ^Rect, margin_h, margin_v: f32) {
	cut_rect(rect, .Cut_Left, margin_h)
	cut_rect(rect, .Cut_Right, margin_h)
	cut_rect(rect, .Cut_Top, margin_v)
	cut_rect(rect, .Cut_Bottom, margin_v)
}

// Drawing procedures

Context :: struct {
	batch:               ^logf.Batch,
	m_pos:               logf.Vector2,
	m_left:              bool,
	previous_m_left:     bool,
	mouse_over_ui:       bool,

	// States
	contrast_multiplier: f32,
	text:                Text,
	background:          Background,
	border:              Border,
	current_window:      Maybe(Rect),
	current_layout:      Maybe(Rect),
}

set_background :: proc(ctx: ^Context, bg: Background) {
	ctx.background = bg
}

set_border :: proc(ctx: ^Context, border: Border) {
	ctx.border = border
}

set_text :: proc(ctx: ^Context, text: Text) {
	ctx.text = text
}

set_contrast :: proc(ctx: ^Context, contrast: f32) {
	ctx.contrast_multiplier = contrast
}

@(private)
draw_background :: proc(ctx: ^Context, rect: Rect, hot := false) {
	clr := ctx.background.clr
	if hot {
		clr *= ctx.contrast_multiplier
	}

	switch ctx.background.style {
	case .None:
	case .Flat:
		switch ctx.border.style {
		case .Rounded:
			logf.draw_rectangle_round(ctx.batch, rect, ctx.border.radius, clr)
		case .None:
			logf.draw_rectangle(ctx.batch, rect, clr)
		case .Outline:
			logf.draw_rectangle(ctx.batch, rect, clr)

			im := ctx.border.inner_margin
			if im > 0 {
				r := rect
				cut_rect_margin(&r, im, im)
				logf.draw_rectangle_outline(ctx.batch, r, ctx.border.thickness, ctx.border.clr)
				return
			}

			logf.draw_rectangle_outline(ctx.batch, rect, ctx.border.thickness, ctx.border.clr)
		}

	case .Image_Slice:
		assert(false)
	}
}

@(private)
align_text :: proc(ctx: ^Context, text: string, rect: logf.Rectangle) -> logf.Vector2 {
	t := &ctx.text

	text_w, text_h := logf.measure_text(t.font, text, int(t.size))
	origin: logf.Vector2
	switch t.align_style {
	case .Left:
		origin.x = rect.x
	case .Center:
		origin.x = rect.x + (rect.width - text_w) / 2
	case .Right:
		origin.x = rect.x + (rect.width - text_w)
	}


	origin.y = math.floor(rect.y + (rect.height - text_h) / 2)
	return origin
}

@(private)
align_text_fit :: proc(
	ctx: ^Context,
	text: string,
	rect: logf.Rectangle,
) -> (
	out: string,
	overflow: bool,
	origin: logf.Vector2,
	suffix_origin: logf.Vector2,
) {
	t := &ctx.text

	text_w, text_h: f32
	out, overflow, text_w, text_h = logf.fit_text(t.font, text, int(t.size), rect, "..")
	switch t.align_style {
	case .Left:
		origin.x = rect.x
	case .Center:
		if overflow {
			origin.x = rect.x
		} else {
			origin.x = rect.x + (rect.width - text_w) / 2
		}
	case .Right:
		origin.x = rect.x + (rect.width - text_w)
	}


	origin.y = math.floor(rect.y + (rect.height - text_h) / 2)
	suffix_origin = origin + {text_w, 0}
	return
}

begin_ui :: proc(ctx: ^Context, batch: ^logf.Batch) {
	ctx.batch = batch
	ctx.m_pos = logf.mouse_position()
	ctx.previous_m_left = ctx.m_left
	ctx.m_left = .Just_Pressed in logf.mouse_button_state(.Left)
	ctx.mouse_over_ui = false
}

end_ui :: proc(ctx: ^Context) {}

begin_window :: proc(ctx: ^Context, rect: Rect) {
	ctx.current_window = rect
	draw_background(ctx, rect)

	ctx.mouse_over_ui |= logf.in_aabb_bounds(rect, ctx.m_pos)
}

end_window :: proc(ctx: ^Context) {
	ctx.current_window = nil
}

begin_layout :: proc(ctx: ^Context, rect: Rect) {
	ctx.current_layout = rect
	draw_background(ctx, rect)
}

end_layout :: proc(ctx: ^Context) {
	ctx.current_layout = nil
}

label :: proc(ctx: ^Context, rect: Rect, text: string, draw_bg := false) {
	text_origin := align_text(ctx, text, rect)

	if draw_bg {
		draw_background(ctx, rect)
	}
	logf.draw_text(ctx.batch, ctx.text.font, text, text_origin, ctx.text.size, ctx.text.clr)
}

boxed_label :: proc(ctx: ^Context, rect: Rect, text: string, draw_bg := false) {
	out, overflow, text_origin, suffix_origin := align_text_fit(ctx, text, rect)

	if draw_bg {
		draw_background(ctx, rect)
	}

	if !overflow {
		logf.draw_text(ctx.batch, ctx.text.font, text, text_origin, ctx.text.size, ctx.text.clr)
		return
	}

	logf.draw_text(ctx.batch, ctx.text.font, out, text_origin, ctx.text.size, ctx.text.clr)
	logf.draw_text(ctx.batch, ctx.text.font, "..", suffix_origin, ctx.text.size, ctx.text.clr)
}

icon :: proc(ctx: ^Context, rect: Rect, image: Image, src_rect: Rect) {
	logf.draw_texture(ctx.batch, image, src_rect, rect, logf.CLR_WHITE)
}

button :: proc(ctx: ^Context, rect: Rect, text: string) -> bool {
	text_origin := align_text(ctx, text, rect)
	hot := logf.in_aabb_bounds(rect, ctx.m_pos)


	draw_background(ctx, rect, hot)
	logf.draw_text(ctx.batch, ctx.text.font, text, text_origin, ctx.text.size, ctx.text.clr)

	return hot && ctx.m_left
}

toggled_button :: proc(ctx: ^Context, rect: Rect, text: string, toggle: ^bool) -> bool {
	active := button(ctx, rect, text)
	toggled := toggle^
	if active {
		toggle^ = !toggled
	}

	// FIXME: Come up with a nice API for toggled indicator
	if toggled {
		logf.draw_rectangle_outline(ctx.batch, rect, 1, logf.CLR_WHITE)
	}

	return active
}

icon_button :: proc(ctx: ^Context, rect: Rect, image: Image, src_rect: Rect) -> bool {
	hot := logf.in_aabb_bounds(rect, ctx.m_pos)

	draw_background(ctx, rect, hot)
	logf.draw_texture(ctx.batch, image, src_rect, rect, logf.CLR_WHITE)

	return hot && ctx.m_left
}

slider :: proc(ctx: ^Context, rect: Rect, t: f32, clr: Color, width: f32 = 15) {
	draw_background(ctx, rect)
	progress_rect := rect
	progress_rect.x = clamp(
		rect.x + (rect.width * t - (width / 2)),
		rect.x,
		rect.x + rect.width - width,
	)
	progress_rect.width = width
	logf.draw_rectangle(ctx.batch, progress_rect, clr)
}

text_tooltip :: proc(ctx: ^Context, parent_rect: Rect, text: string) {
	TOOLTIP_MARGIN :: 3
	tx, ty := logf.measure_text(ctx.text.font, text, ctx.text.size)

	width := tx + (TOOLTIP_MARGIN) * 2
	height := ty + (TOOLTIP_MARGIN) * 2
	x := parent_rect.x
	y := parent_rect.y - height

	tooltip := make_rect(x, y, width, height)
	begin_window(ctx, tooltip)

	cut_rect_margin(&tooltip, TOOLTIP_MARGIN, TOOLTIP_MARGIN)
	label(ctx, tooltip, text)
	end_window(ctx)
}
