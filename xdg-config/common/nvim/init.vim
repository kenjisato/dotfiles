syntax enable

set number
set ruler
set list
set listchars=tab:>-,trail:-,nbsp:%,extends:>,precedes:<,eol:<
set incsearch
set hlsearch
set nowrap
set showmatch
set whichwrap=h,l
set nowrapscan
set ignorecase
set smartcase
set hidden
set history=2000

set helplang=en
set autoindent
set tabstop=4
set shiftwidth=4
set softtabstop=4
set expandtab

filetype plugin on

" Enable 24-bit color so colorschemes render with their full palette instead
" of being quantized to the terminal's 256-color set.
set termguicolors

" Built-in scheme (no plugin manager needed). retrobox is a gruvbox-style
" warm/retro palette. Swap for another built-in (habamax, sorbet, unokai, ...)
" to taste, or set background=light for its light variant.
colorscheme retrobox

" Keep the colorscheme's syntax colors but let the terminal's own background
" show through instead of the scheme's. Must come after :colorscheme, since it
" clears the background the scheme just set. (If you switch schemes with
" :colorscheme later, re-run these or wrap them in a ColorScheme autocmd.)
highlight Normal      guibg=NONE ctermbg=NONE
highlight NormalNC    guibg=NONE ctermbg=NONE
highlight EndOfBuffer guibg=NONE ctermbg=NONE
highlight SignColumn  guibg=NONE ctermbg=NONE
highlight LineNr      guibg=NONE ctermbg=NONE
