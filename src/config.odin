package main

import "logf"

Config :: struct {
	gutter_height:  f32,
	background_clr: logf.Color,
	gutter_clr:     logf.Color,
	accent_clr:     logf.Color,
	outline_clr:    logf.Color,
}

DEFAULT_CONFIG := Config {
	gutter_height  = 30,
	background_clr = logf.normalize_u8_rgba({37, 34, 35, 255}),
	gutter_clr     = logf.normalize_u8_rgba({87, 84, 85, 255}),
	accent_clr     = logf.normalize_u8_rgba({57, 54, 55, 255}),
	outline_clr    = logf.normalize_u8_rgba({217, 232, 225, 255}),
}
