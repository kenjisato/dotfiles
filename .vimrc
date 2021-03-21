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
set cindent
set tabstop=4
set shiftwidth=4

let _curfile = expand("%:t")
set softtabstop=4
if _curfile =~ "Makefile" || _curfile =~ "makefile"
  set noexpandtab
else
  set expandtab
endif

colorscheme desert
