package main

// import "core:fmt"
import "core:strings"

make_item :: proc(label: string, desc := "", allocator := context.allocator) -> Item {
	context.allocator = allocator
	it := Item {
		label       = strings.clone(label),
		description = strings.clone(desc),
	}

	return it
}

destroy_item :: proc(item: Item) {
	delete(item.label)
	delete(item.description)
}

push_item :: proc(list: ^List, item: Item) {
	i := item
	i.parent = list
	append(&list.items, i)
}
