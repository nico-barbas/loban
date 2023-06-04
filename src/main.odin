package main

import "core:mem"
import "core:fmt"

import "logf"
import "loui"

ITEM_PADDING :: 10

main :: proc() {
	tracking_allocator: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracking_allocator, context.allocator)
	context.allocator = mem.tracking_allocator(&tracking_allocator)

	defer {
		for _, entry in tracking_allocator.allocation_map {
			fmt.printf("Leak: %v\n", entry)
		}
	}

	app := logf.init_app(logf.App_Config{width = 1600, height = 900, title = "loban"})
	defer logf.destroy_app(app)

	fmt.println(DEFAULT_CONFIG)

	ctx: Context
	init_ctx(&ctx)
	defer destroy_ctx(&ctx)

	batch: logf.Batch
	logf.init_batch(&batch)
	defer logf.destroy_batch(&batch)

	screen := loui.make_rect(0, 0, f32(app.width), f32(app.height))
	gutter := loui.cut_rect(&screen, .Cut_Bottom, ctx.gutter_height)

	for app.is_running {
		logf.begin_frame(app)
		defer logf.end_frame(app)

		main_panel := screen
		char_pressed := logf.pressed_char()

		update_ctx(&ctx, app.elapsed_time)
		update_cursor(&ctx)
		update_selection(&ctx)
		update_input(&ctx.cmd, char_pressed, app.elapsed_time)
		if ctx.cmd.active && .Just_Pressed in logf.key_state(.Enter) {
			exec_cmd(&ctx)
			reset_input(&ctx.cmd)
			ctx.cmd.active = false
		}

		frame_w := f32(app.width)
		frame_h := f32(app.height)
		refresh_layout(&ctx, frame_w, frame_h - ctx.gutter_height)


		logf.begin_batch(&batch, nil, app.width, app.height)
		defer logf.end_batch(&batch)

		loui.begin_ui(&ctx.ui, &batch)

		b := ctx.ui.border
		ctx.ui.border = {}

		ctx.ui.background.clr = ctx.gutter_clr
		loui.begin_window(&ctx.ui, gutter)
		if ctx.cmd.active {
			ctx.ui.text.align_style = .Left
			defer ctx.ui.text.align_style = .Center
			loui.label(&ctx.ui, gutter, string(ctx.cmd.buf[:ctx.cmd.count]))
		}
		loui.end_window(&ctx.ui)


		ctx.ui.background.clr = ctx.background_clr
		loui.begin_window(&ctx.ui, main_panel)

		info_panel := loui.cut_rect(&main_panel, .Cut_Top, 40)
		loui.cut_rect_margin(&info_panel, 10, 5)
		loui.begin_layout(&ctx.ui, info_panel)
		ctx.ui.border = b

		slider := loui.cut_rect(&info_panel, .Cut_Right, 150)
		loui.cut_rect_margin_v(&slider, 5)
		loui.label(&ctx.ui, loui.cut_rect(&slider, .Cut_Left, 25), "-")
		loui.slider(
			&ctx.ui,
			loui.cut_rect(&slider, .Cut_Left, 100),
			(ctx.scale - 1) / (MAX_SCALE - 1),
			ctx.gutter_clr,
		)
		loui.label(&ctx.ui, slider, "+")

		loui.end_layout(&ctx.ui)

		loui.end_window(&ctx.ui)

		for list, i in ctx.lists {
			panel := list.rect

			if ctx.cursor.y == -1 && ctx.cursor.x == i {
				SELECT_PADDING :: 5

				select_rect := panel
				select_rect.x -= SELECT_PADDING
				select_rect.y -= SELECT_PADDING
				select_rect.width += SELECT_PADDING * 2
				select_rect.height += SELECT_PADDING * 2

				logf.draw_rectangle_outline(&batch, select_rect, 1, ctx.outline_clr)
			}

			loui.begin_window(&ctx.ui, panel)
			defer loui.end_window(&ctx.ui)

			list_label_rect := loui.cut_rect(&panel, .Cut_Top, 50)
			loui.label(&ctx.ui, list_label_rect, list.label)

			loui.cut_rect_margin(&panel, 10, 20)
			for item, j in list.items {
				item_rect := loui.cut_rect(&panel, .Cut_Top, 40)
				loui.boxed_label(&ctx.ui, item_rect, item.label, true)

				if ctx.cursor == {i, j} {
					cursor_rect := item_rect
					cursor_rect.width = 10
					cursor_rect.height = 10
					logf.draw_rectangle(&batch, cursor_rect, logf.CLR_WHITE)
				}

				if j < len(list.items) - 1 {
					loui.cut_rect(&panel, .Cut_Top, ITEM_PADDING)
				}
			}
		}

		if ctx.selected_item != nil {
			render_window(&ctx.item_window, &ctx.ui)
		}

	}
}
