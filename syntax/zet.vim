if exists("b:current_syntax")
  finish
endif

runtime! syntax/markdown.vim
unlet! b:current_syntax

" HTML comments
syn region Comment matchgroup=Comment start="<!--" end="-->"  contains=zkTag keepend

" Wiki-style links [[link]] with alias concealing
syntax region zkLink matchgroup=zkBrackets start=/\[\[/ end=/\]\]/ keepend display contains=zkAliasedLink
syntax match zkAliasedLink "[^\[\]]\+|" contained conceal

" Highlighted text ==text==
syntax region zkHighlight matchgroup=zkBrackets start=/==/ end=/==/ display

" Tags: #tag notation
syntax match zkTag "\v#[a-zA-ZÀ-ÿ]+[a-zA-ZÀ-ÿ0-9/\-_]*"
syntax match zkTag "\v:[a-zA-ZÀ-ÿ]+[a-zA-ZÀ-ÿ0-9/\-_]*:"

" Tag lists in YAML frontmatter: tags: [tag1, tag2]
syntax match zkTagSep "\v\s*,\s*" contained
syntax region zkTag matchgroup=zkBrackets start=/^tags\s*:\s*\[\s*/ end=/\s*\]\s*$/ contains=zkTagSep display oneline

let b:current_syntax = 'zet'
