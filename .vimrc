source $VIMRUNTIME/defaults.vim

syntax on

set encoding=utf-8
set background=dark

set number
hi LineNr ctermfg=darkgrey

set showmatch
set autoindent
set smartindent
set smarttab
set tabstop=4
set shiftwidth=4
set hlsearch

" The mouse mode breaks Ctrl+Shift+C, making it impossible to copy from vim
" into other visual applications.
" set mouse=a
set mouse=

set colorcolumn=80
hi ColorColumn ctermbg=darkgrey guibg=darkgrey

highlight TrailingWhitespace ctermbg=red guibg=red
match TrailingWhitespace /\s\+$/

set list
set listchars=tab:→\ ,extends:›,precedes:‹,nbsp:○,lead:·,trail:·
let &showbreak = '↪ '
hi SpecialKey ctermfg=darkgrey guifg=darkgrey

filetype plugin on
set omnifunc=syntaxcomplete#Complete

" Keep nested i3 blocks highlighted correctly after jumping or scrolling.
autocmd Syntax i3config syntax sync fromstart

" let mapleader = "\\"

" Escape in normal mode clears highlight.
nnoremap <silent> <Esc> :nohlsearch<CR>
" Kitty's keyboard negotiation can hide the startup Escape mapping.
augroup SearchEscape
  autocmd!
  autocmd SafeState * if empty(maparg('<Esc>', 'n')) | nnoremap <silent> <Esc> :nohlsearch<CR> | endif
augroup END

" Ctrl+D in insert mode performs 'change inner word',
" i.e. deletes the whole word at cursor and switches back to insert mode.
inoremap <C-d> <ESC>ciw

" :set filetype?
autocmd FileType vim let b:comment_prefix = '"'
autocmd FileType python let b:comment_prefix = '#'
autocmd FileType c,cpp let b:comment_prefix = '//'
autocmd FileType asm let b:comment_prefix = ';'

xnoremap <leader>[ :<C-u>call CommentSelection()<CR>
xnoremap <leader>] :<C-u>call UncommentSelection()<CR>

nnoremap <leader>[ :call CommentCurrentLine()<CR>
nnoremap <leader>] :call UncommentCurrentLine()<CR>

function! CommentSelection()
  let l:comment = get(b:, 'comment_prefix', '#')
  execute "'<,'>s/^\\(\\s*\\)\\(\\S.*\\)/\\1" . l:comment . " \\2/"
endfunction

function! UncommentSelection()
  let l:comment = get(b:, 'comment_prefix', '#')
  execute "'<,'>s/^\\(\\s*\\)" . l:comment . " \\(\\S.*\\)/\\1\\2/"
endfunction

function! CommentCurrentLine()
  let l:comment = get(b:, 'comment_prefix', '#')
  let l:line = getline('.')
  if l:line =~ '\S'
    let l:newline = substitute(l:line, '^\(\s*\)', '\1' . l:comment . ' ', '')
    call setline('.', l:newline)
  endif
endfunction

function! UncommentCurrentLine()
  let l:comment = get(b:, 'comment_prefix', '#')
  let l:line = getline('.')
  let l:newline = substitute(l:line, '^\(\s*\)' . escape(l:comment, '#') . '\s\?', '\1', '')
  call setline('.', l:newline)
endfunction
