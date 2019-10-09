set number
set showmatch
set autoindent
set smartindent
set smarttab
set tabstop=4
set shiftwidth=4
set hlsearch
set nocompatible
set mouse=a
set backspace=2

syntax on
nnoremap <leader><leader> :noh<return><esc>

" Indentation guidelines (the trailing space is necessary)
set listchars=tab:\|\ 
set list

" Highlight trailing whitespace
highlight ExtraWhitespace ctermbg=red guibg=red
match ExtraWhitespace /\s\+$/

" hi Comment ctermfg=LightBlue
set background=dark

