package main

import "core:os"
import "core:fmt"
import "core:sort"
import "core:strings"
import "core:encoding/json"

import "logf"
import "loui"

DEFAULT_CANVAS_NAME :: "./canvas.json"
MAX_SCALE :: 4

Context :: struct {
	using conf:    Config,
	lists:         [dynamic]^List,
	list_lookup:   map[string]^List,
	selected_item: Maybe(Item),

	// Cmd handling
	cmd:           Input,
	cmd_lexer:     Lexer,
	cursor:        [2]int,

	// Windows
	item_window:   Window,

	// Rendering states
	ui:            loui.Context,
	font:          ^logf.Font,
	scale:         f32,
}

Item :: struct {
	parent:      ^List,
	label:       string,
	description: string,
}

List :: struct {
	id:    int,
	label: string,
	rect:  loui.Rect,
	items: [dynamic]Item,
}

init_ctx :: proc(ctx: ^Context, allocator := context.allocator) -> (ok: bool) {
	context.allocator = allocator

	ctx.conf = DEFAULT_CONFIG
	ctx.lists = make([dynamic]^List)
	ctx.list_lookup = make(map[string]^List)

	ctx.font = logf.make_font({path = "./assets/RobotoMono-Regular.ttf", sizes = {18}})
	loui.set_background(&ctx.ui, loui.Background{style = .Flat, clr = ctx.background_clr})
	loui.set_border(&ctx.ui, loui.Border{style = .Outline, clr = ctx.outline_clr, thickness = 1})
	loui.set_text(
		&ctx.ui,
		loui.Text{font = ctx.font, size = 18, clr = logf.CLR_WHITE, align_style = .Center},
	)

	if os.exists(DEFAULT_CANVAS_NAME) {
		data, _ := os.read_entire_file(DEFAULT_CANVAS_NAME, context.temp_allocator)
		input, err := json.parse(data, json.DEFAULT_SPECIFICATION, false, context.temp_allocator)

		if err != nil {
			ok = false
			return
		}

		canvas := input.(json.Object)
		for list_name, json_list in canvas {
			l := json_list.(json.Object)
			list := make_list(list_name, int(l["id"].(json.Float)))

			ctx.list_lookup[list.label] = list
			append(&ctx.lists, list)

			items := l["items"].(json.Array)
			for json_item in items {
				item := json_item.(json.Object)

				push_item(
					list,
					make_item(label = item["label"].(string), desc = item["description"].(string)),
				)
			}
		}
	}

	sort_lists(ctx)

	if len(ctx.lists) > 0 && len(ctx.lists[0].items) == 0 {
		ctx.cursor.y = -1
	}

	ctx.scale = 1

	ctx.item_window = make_window(
		rect = loui.make_rect(100, 100, 1400, 700),
		border = loui.Border{
			style = .Outline,
			clr = ctx.outline_clr,
			inner_margin = 10,
			thickness = 1,
		},
		data = ctx,
	)
	ctx.item_window.content_proc = proc(ui: ^loui.Context, rect: ^loui.Rect, data: rawptr) {
		ctx := cast(^Context)data

		item := ctx.selected_item.?
		name_rect := loui.cut_rect(rect, .Cut_Top, 50)

		loui.label(&ctx.ui, name_rect, item.label)

		loui.label(
			&ctx.ui,
			loui.cut_rect(rect, .Cut_Top, 30),
			fmt.tprintf("In list %s", item.parent.label),
		)

		if item.description != "" {
			loui.cut_rect(rect, .Cut_Top, 20)
			desc_rect := loui.cut_rect(rect, .Cut_Top, 50)
			loui.label(&ctx.ui, desc_rect, item.description)
		}
	}
	ctx.item_window.keybind_help[.Escape] = "close"

	return true
}

destroy_ctx :: proc(ctx: ^Context, allocator := context.allocator) {
	Item_Serializer :: struct {
		label:       string,
		description: string,
	}
	List_Serializer :: struct {
		id:    int,
		items: [dynamic]Item_Serializer,
	}

	context.allocator = allocator
	flat_lists: map[string]List_Serializer
	flat_lists.allocator = context.temp_allocator
	for label, list in ctx.list_lookup {
		l := make([dynamic]Item_Serializer, len(list.items), context.temp_allocator)

		for item, i in list.items {
			l[i] = Item_Serializer {
				label       = item.label,
				description = item.description,
			}
		}

		flat_lists[label] = {
			id    = list.id,
			items = l,
		}
	}

	out, err := json.marshal(flat_lists, {})
	defer delete(out)
	if err == nil {
		os.write_entire_file("./canvas.json", out)
	}


	delete(ctx.lists)
	delete(ctx.list_lookup)
	for list in ctx.lists {
		destroy_list(list)
	}
	destroy_window(&ctx.item_window)

	logf.destroy_font(ctx.font)
}

update_ctx :: proc(ctx: ^Context, dt: f32) {
	if .Pressed in logf.key_state(.Left_Control) {
		if .Just_Pressed in logf.key_state(.Equal) {
			ctx.scale = clamp(ctx.scale + 0.5, 1, MAX_SCALE)
		} else if .Just_Pressed in logf.key_state(.Minus) {
			ctx.scale = clamp(ctx.scale - 0.5, 1, MAX_SCALE)
		}
	}
}


make_list :: proc(label: string, id: int, allocator := context.allocator) -> ^List {
	context.allocator = allocator
	list := new(List)
	list.id = id
	list.label = strings.clone(label)
	list.items = make([dynamic]Item)
	return list
}

destroy_list :: proc(list: ^List) {
	for item in list.items {
		destroy_item(item)
	}
	delete(list.items)
	delete(list.label)
	free(list)
}

sort_lists :: proc(ctx: ^Context) {
	sort.sort(sort.Interface {
		len = proc(it: sort.Interface) -> int {
			c := cast(^Context)it.collection
			return len(c.lists)
		},
		less = proc(it: sort.Interface, i, j: int) -> bool {
			c := cast(^Context)it.collection
			return c.lists[i].id < c.lists[j].id
		},
		swap = proc(it: sort.Interface, i, j: int) {
			c := cast(^Context)it.collection
			c.lists[i], c.lists[j] = c.lists[j], c.lists[i]
		},
		collection = ctx,
	})
}

update_cursor :: proc(ctx: ^Context) {
	if ctx.cmd.active || ctx.selected_item != nil {
		return
	}

	if .Just_Pressed in logf.key_state(.Delete) {
		if ctx.cursor.y >= 0 {
			it := ctx.lists[ctx.cursor.x].items[ctx.cursor.y]
			ordered_remove(&ctx.lists[ctx.cursor.x].items, ctx.cursor.y)
			destroy_item(it)
		}
	}

	dir: [2]int
	if .Just_Pressed in logf.key_state(.Up) {
		dir.y = -1
	} else if .Just_Pressed in logf.key_state(.Down) {
		dir.y = 1
	}

	if .Just_Pressed in logf.key_state(.Left) {
		dir.x = -1
	} else if .Just_Pressed in logf.key_state(.Right) {
		dir.x = 1
	}
	next_cursor := ctx.cursor + dir

	if .Pressed in logf.key_state(.Left_Control) && dir != 0 {
		if next_cursor.x < 0 || next_cursor.x >= len(ctx.lists) {
			return
		}

		current_list := ctx.lists[ctx.cursor.x]
		next_list := ctx.lists[next_cursor.x]

		if next_cursor.y == -1 {
			swap_list_positions(ctx, next_cursor, current_list, next_list)
			return
		}

		item := current_list.items[ctx.cursor.y]
		ordered_remove(&current_list.items, ctx.cursor.y)
		append(&next_list.items, item)

		ctx.cursor = {
			0 = next_cursor.x,
			1 = len(next_list.items) - 1,
		}

		return
	}

	if dir != 0 {
		list_count := len(ctx.lists) - 1
		ctx.cursor.x = clamp(next_cursor.x, 0, list_count)

		list_len := len(ctx.lists[ctx.cursor.x].items)
		if list_len == 0 {
			ctx.cursor.y = -1
		} else {
			ctx.cursor.y = clamp(next_cursor.y, -1, list_len - 1)
		}
	}
}

update_selection :: proc(ctx: ^Context) {
	if ctx.cmd.active {
		return
	}

	if ctx.selected_item != nil && .Just_Pressed in logf.key_state(.Escape) {
		ctx.selected_item = nil
	}

	if .Just_Pressed in logf.key_state(.Enter) && ctx.cursor.y >= 0 {
		ctx.selected_item = ctx.lists[ctx.cursor.x].items[ctx.cursor.y]
	}
}

refresh_layout :: proc(ctx: ^Context, frame_w, frame_h: f32) {
	margin: f32 = 50
	padding: f32 = 35
	list_width: f32 = 200

	for list, i in ctx.lists {
		w := list_width * ctx.scale

		list.rect = loui.make_rect(
			x = margin + (w + padding) * f32(i),
			y = margin,
			w = w,
			h = frame_h - (margin * 2),
		)
	}
}

swap_list_positions :: proc(ctx: ^Context, next_cursor: [2]int, a, b: ^List) {
	a.id, b.id = b.id, a.id
	sort_lists(ctx)
	ctx.cursor = next_cursor
}
