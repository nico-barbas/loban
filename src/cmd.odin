package main

import "core:fmt"

cmd_str := [?]string{"create", "update", "delete"}

exec_cmd :: proc(ctx: ^Context) {
	cmd := ctx.cmd.buf[1:ctx.cmd.count]
	init_lexer(&ctx.cmd_lexer, string(cmd))

	op := lexer_next_token(&ctx.cmd_lexer)
	if !(op.kind > Token_Kind.Cmd_Start && op.kind < Token_Kind.Cmd_End) {
		fmt.println("invalid command")
		return
	}

	#partial switch op.kind {
	case .Cmd_Create_Item:
		label_token := lexer_next_token(&ctx.cmd_lexer)
		assert(label_token.kind == .String)

		t := label_token.text[1:len(label_token.text) - 1]
		fmt.println("creating item named:", t)
		push_item(ctx.list_lookup["backlog"], make_item(label = t))
	case:
		assert(false, "invalid command")
	}
	ctx.cmd.count = 0
}

Token :: struct {
	kind:  Token_Kind,
	start: int,
	end:   int,
	text:  string,
}

Token_Kind :: enum {
	EOF,
	Minus,
	Identifier,
	String,

	// Cmds
	Cmd_Start,
	Cmd_Promote_Item,
	Cmd_Create_Item,
	Cmd_End,
}

Lexer :: struct {
	src:     string,
	current: int,
}

keywords := map[string]Token_Kind {
	"promote" = .Cmd_Promote_Item,
	"create"  = .Cmd_Create_Item,
}

init_lexer :: proc(lexer: ^Lexer, src: string) {
	lexer.src = src
	lexer.current = 0
}

lexer_next_token :: proc(lexer: ^Lexer) -> (t: Token) {
	lexer_skip_whitespaces(lexer)

	if lexer_is_eof(lexer) {
		t.kind = .EOF
		return
	}

	start := lexer.current

	c := lexer_advance(lexer)
	switch c {
	case '-':
		t.kind = .Minus
	case '"':
		t.kind = .String
		lex_string: for {
			if lexer_is_eof(lexer) || lexer_advance(lexer) == '"' {
				break lex_string
			}
		}

	case:
		if is_letter(c) {
			lex_word: for {
				if lexer_is_eof(lexer) {
					break lex_word
				}

				if !is_letter(lexer_peek(lexer)) {
					break lex_word
				}
				lexer_advance(lexer)
			}

			word := lexer.src[start:lexer.current]

			if keyword, exist := keywords[word]; exist {
				t.kind = keyword
			} else {
				t.kind = .Identifier
			}
		}
	}

	t.start = start
	t.end = lexer.current
	t.text = lexer.src[t.start:t.end]
	return
}

lexer_skip_whitespaces :: proc(lexer: ^Lexer) {
	for {
		if lexer_is_eof(lexer) {
			return
		}

		c := lexer_peek(lexer)
		if !(c == ' ' || c == '\t' || c == '\r' || c == '\n') {
			break
		}

		lexer_advance(lexer)
	}
}

lexer_is_eof :: proc(lexer: ^Lexer) -> bool {
	return lexer.current >= len(lexer.src)
}

@(private = "file")
is_letter :: proc(c: byte) -> bool {
	return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
}

@(private = "file")
is_number :: proc(c: byte) -> bool {
	return c >= '0' && c <= '9'
}

lexer_advance :: proc(lexer: ^Lexer) -> byte {
	c := lexer.src[lexer.current]
	lexer.current += 1
	return c
}

lexer_peek :: proc(lexer: ^Lexer) -> byte {
	return lexer.src[lexer.current]
}
