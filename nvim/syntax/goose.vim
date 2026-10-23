" Vim syntax for the Goose programming language (aardappel/goose).
"
" Конвертировано из TextMate-грамматики, которая идёт в goose-language.vsix
" (extension/syntaxes/goose.tmLanguage.json). Это fallback: при наличии
" tree-sitter-парсера Neovim подсвечивает через nvim/queries/goose.
"
" https://aardappel.github.io/goose/
"
" Порядок правил важен: в Vim при совпадении в одной позиции выигрывает
" объявленное ПОЗЖЕ (keywords имеют низший приоритет).

if exists("b:current_syntax")
  finish
endif

" ── Ключевые слова ────────────────────────────────────────────────────────
syn keyword gooseConditional if else while for in loop block guard match
syn keyword gooseStatement return break continue
syn keyword gooseOther import namespace as
syn keyword gooseType bool varint u8 u16 u32 u64 i8 i16 i32 i64 f32 f64
syn keyword gooseStorage struct enum type fn thread_fn let var const
syn keyword gooseModifier export extern simd recursive pad reusable
syn keyword gooseConstant true false null
syn keyword gooseSelf self

" ── Имена: тип (CamelCase) ────────────────────────────────────────────────
syn match gooseTypeName "\<[A-Z]\h\w*\>"

" ── Имена: вызов функции ──────────────────────────────────────────────────
syn match gooseFunction "\<\h\w*\ze\s*("

" ── Имена: namespace (через ::) ───────────────────────────────────────────
syn match gooseNamespace "\<\h\w*\ze::"

" ── Имя namespace после ключевого слова: namespace geo; ───────────────────
syn match gooseNamespaceName "\%(\<namespace\>\s\+\)\@<=\h\w*"

" ── Встроенные функции (print( ... ), str( ... ) и т.п.) ──────────────────
syn match gooseBuiltin "\<\%(print\|str\|format\|assert\|abort\|exit\|hardware_threads\|thread_spawn\|thread_wait\|qput\|qget\|qpoll\|default\|copy\|to_bytes\|bytes_of\|from_bytes\|embed_shader\|embed_file\|index_of\|push\|append\|pop\|pop_n\|resize\|clear\|alloc_index\|alloc_ref\|free\|alloc_slice\|realloc_slice\|free_slice\)\>\ze\s*\%([<(]\)"

" ── Имена: КОНСТАНТА (SCREAMING_CASE) — после TypeName, чтобы побеждал ────
syn match gooseConstantName "\<[A-Z][A-Z0-9_]*\>"

" ── Свойства после точки ──────────────────────────────────────────────────
syn match gooseProperty "\.\zs\<\%(len\|cap\)\>"

" ── Числа ──────────────────────────────────────────────────────────────────
syn match gooseNumber "\<\d\+\>"
syn match gooseFloat "\<\d\+\%(\.\d\+\%([eE][+-]\=\d\+\)\=\|[eE][+-]\=\d\+\)\>"
syn match gooseHexInt "\<0x\%(\x\|[0-9a-fA-F]\)\+\>"
syn match gooseHexFloat "\<0x\%(\x\|[0-9a-fA-F]\)\+\%(\.[0-9a-fA-F]\+\)\=p\%([+-]\=\d\+\)\>"

" ── Операторы и пунктуация ────────────────────────────────────────────────
syn match gooseOperator "\%(\.==\|\.!=\|\.=\|\.\.\|::\|->\|=>\|<<=\?\|>>=\?\|[+*/%=&|^!<>-]=\?\|[?~]\)"
syn match goosePunctuation "[{}()\[\]]"
syn match gooseSeparator "[.,;:]"

" ── Строки ────────────────────────────────────────────────────────────────
syn match gooseEscape "\\\%(x\x\x\|[ntr0\\\"']\)" contained
syn match gooseInvalidEscape "\\." contained
syn region gooseTripleString start=+"""+ end=+"""+ contains=gooseEscape,gooseInvalidEscape
syn region gooseString start=+"+ end=+"+ contains=gooseEscape,gooseInvalidEscape
syn region gooseChar start=+'+ end=+'+ contains=gooseEscape,gooseInvalidEscape

" ── Комментарии ───────────────────────────────────────────────────────────
syn match gooseComment "//.*$"
syn region gooseCommentBlock start=+/\*+ end=+\*/+ contains=gooseCommentBlock

" ── Цвета ─────────────────────────────────────────────────────────────────
hi def link gooseComment Comment
hi def link gooseCommentBlock Comment
hi def link gooseString String
hi def link gooseTripleString String
hi def link gooseChar String
hi def link gooseEscape SpecialChar
hi def link gooseInvalidEscape Error
hi def link gooseNumber Number
hi def link gooseFloat Float
hi def link gooseHexInt Number
hi def link gooseHexFloat Float
hi def link gooseType Type
hi def link gooseTypeName Type
hi def link gooseStorage StorageClass
hi def link gooseModifier StorageClass
hi def link gooseConstant Constant
hi def link gooseConstantName Constant
hi def link gooseSelf Identifier
hi def link gooseConditional Conditional
hi def link gooseStatement Statement
hi def link gooseOther Statement
hi def link gooseFunction Function
hi def link gooseBuiltin Function
hi def link gooseNamespace Structure
hi def link gooseProperty Identifier
hi def link gooseOperator Operator
hi def link goosePunctuation Delimiter
hi def link gooseSeparator Delimiter

let b:current_syntax = "goose"
