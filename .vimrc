set number
set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set hlsearch
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

