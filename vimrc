if has('autocmd')
  filetype plugin indent on
endif

if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

set autoread

"Turn on line numbers
set number
"
"Copy/Paste in OS clipboard
set clipboard=unnamed
"
"Automatically put selection in visual mode to clipboard, (seems to be broken)
set go+=a

"Set '<' and '>' to match
set matchpairs+=<:>

"Backspace do not delete 'eol'
set bs=indent,start

"Soft Indentation
set autoindent
set expandtab
set shiftwidth=2
set softtabstop=2

"Incremental search with smartcase and backspace behavior
set incsearch
set ignorecase
set smartcase
nmap  <silent> <BS> :nohlsearch<CR>

" Put plugins and dictionaries in this dir (also on Windows)
let vimDir = '$HOME/.vim'
let &runtimepath.=','.vimDir

set nrformats-=octal

" Keep undo history across sessions by storing it in a file
if has('persistent_undo')
    let myUndoDir = expand(vimDir . '/undodir')
    " Create dirs
    call system('mkdir ' . vimDir)
    call system('mkdir ' . myUndoDir)
    let &undodir = myUndoDir
    set undofile
	set undolevels=5000         " How many undos
	set undoreload=10000        " number of lines to save for undo
endif

if &history < 1000
  set history=1000
endif

set laststatus=2
set ruler
set wildmenu

if !&scrolloff
  set scrolloff=1
endif
if !&sidescrolloff
  set sidescrolloff=5
endif
set display+=lastline

if &encoding ==# 'latin1' && has('gui_running')
  set encoding=utf-8
endif

if &listchars ==# 'eol:$'
  set listchars=tab:>\ ,trail:-,extends:>,precedes:<,nbsp:+
endif

if v:version > 703 || v:version == 703 && has("patch541")
  set formatoptions+=j " Delete comment character when joining commented lines
endif

if has('path_extra')
  setglobal tags-=./tags tags-=./tags; tags^=./tags;
endif

if &tabpagemax < 50
  set tabpagemax=50
endif
if !empty(&viminfo)
  set viminfo^=!
endif
set sessionoptions-=options

" vim:set ft=vim et sw=2:

"set term=pcansi
"set t_Co=256
"let &t_AB="\e[48;5;%dm"
"let &t_AF="\e[38;5;%dm"

"inoremap <Char-0x07F> <BS>
"nnoremap <Char-0x07F> <BS>
""""""""""""""""""""""""""""""""""""""""
""" let mouse wheel scroll file contents
"""""""""""""""""""""""""""""""""""""""
"set mouse=a
"inoremap <Esc>[62~ <C-X><C-E>
"inoremap <Esc>[63~ <C-X><C-Y>
"nnoremap <Esc>[62~ <C-E>
"nnoremap <Esc>[63~ <C-Y>
"_____________________VIM-PLUG_______________________________________________

" Specify a directory for plugins (for Neovim: ~/.local/share/nvim/plugged)
call plug#begin('~/.vim/plugged')

" On-demand loading
"Plug 'tpope/vim-sensible'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-fugitive'
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'jiangmiao/auto-pairs'
Plug 'airblade/vim-gitgutter'
Plug 'ctrlpvim/ctrlp.vim'
"Plug 'Valloric/YouCompleteMe'
"Colorcheme
Plug 'vim-scripts/twilight256.vim'
Plug 'nanotech/jellybeans.vim'
Plug 'drbraden/near-twilight-256'
Plug 'scrooloose/nerdcommenter'
" Initialize plugin system
call plug#end()


if !has("gui_running")
    set term=xterm
    ""set term=pcansi
    set t_Co=256
    let &t_AB="\e[48;5;%dm"
    let &t_AF="\e[38;5;%dm"
    colorscheme twilight256
    set background=dark
endif

"____________________Mappings________________________________________________
map <C-n> :NERDTreeToggle<CR>

let g:NERDSpaceDelims = 1
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'

"PowerLine configuration
python from powerline.vim import setup as powerline_setup
python powerline_setup()
python del powerline_setup
set laststatus=2 " Always display the statusline in all windows
"set showtabline=2 " Always display the tabline, even if there is only one tab
set noshowmode " Hide the default mode text (e.g. -- INSERT -- below the statusline)
