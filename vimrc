if has('autocmd')
  filetype plugin indent on
endif

if has('syntax') && !exists('g:syntax_on')
  syntax enable
endif

let mapleader=' '

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

"Folding
set foldmethod=indent
set foldopen=all
set foldclose=all

"Soft Indentation
set autoindent
set smartindent
set expandtab
set tabstop=2
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

set diffopt+=vertical

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
" Plug 'tpope/vim-sensible'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'idanarye/vim-merginal'
Plug 'tommcdo/vim-fugitive-blame-ext'

Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'Xuyuanp/nerdtree-git-plugin'

Plug 'ctrlpvim/ctrlp.vim'
" Plug 'Valloric/YouCompleteMe'
" Colorcheme
Plug 'vim-scripts/twilight256.vim'
Plug 'nanotech/jellybeans.vim'
Plug 'drbraden/near-twilight-256'

Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-surround'
Plug 'scrooloose/nerdcommenter'

Plug 'pearofducks/ansible-vim'
" Plug 'gisphm/vim-gradle'
Plug 'tfnico/vim-gradle'
Plug 'gabrielelana/vim-markdown'
Plug 'sjl/gundo.vim'

Plug 'benmills/vimux'
Plug 'tmux-plugins/vim-tmux'

Plug 'mattn/webapi-vim'
Plug 'mattn/pastebin-vim'
" Initialize plugin system

Plug 'christoomey/vim-tmux-navigator'
Plug 'heavenshell/vim-slack'

Plug 'francoiscabrol/ranger.vim'

Plug 'xuhdev/vim-latex-live-preview', { 'for': 'tex' }
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

" NERD Comenter settings
let g:NERDSpaceDelims = 1
let g:NERDCompactSexyComs = 1
let g:NERDDefaultAlign = 'left'

" Ansible syntax settings
let g:ansible_unindent_after_newline = 1

" Fuggitive keybindings
map <Leader>gs :Gstatus<CR>
map <Leader>gw :Gwrite<CR>
map <Leader>gc :Gcommit<CR>
map <Leader>gr :Gread<CR>
map <leader>w :w<CR>
map <leader>q :q<CR>
map <leader>x :wq<CR>

xnoremap <leader>p "_dP

" Run the current file with rspec
map <Leader>rb :call VimuxRunCommand("clear; rspec " . bufname("%"))<CR>

" Prompt for a command to run
map <Leader>vp :VimuxPromptCommand<CR>

" Run last command executed by VimuxRunCommand
map <Leader>vl :VimuxRunLastCommand<CR>

" Inspect runner pane
map <Leader>vi :VimuxInspectRunner<CR>

" Close vim tmux runner opened by VimuxRunCommand
map <Leader>vq :VimuxCloseRunner<CR>

" Interrupt any command running in the runner pane
map <Leader>vx :VimuxInterruptRunner<CR>

" Zoom the runner pane (use <bind-key> z to restore runner pane)
map <Leader>vz :call VimuxZoomRunner()<CR>

let g:tmux_navigator_no_mappings = 1

nnoremap <silent> <c-h> :TmuxNavigateLeft<cr>
nnoremap <silent> <c-j> :TmuxNavigateDown<cr>
nnoremap <silent> <c-k> :TmuxNavigateUp<cr>
nnoremap <silent> <c-l> :TmuxNavigateRight<cr>
nnoremap <silent> <c-\> :TmuxNavigatePrevious<cr>

" PowerLine configuration
python from powerline.vim import setup as powerline_setup
python powerline_setup()
python del powerline_setup
set laststatus=2 " Always display the statusline in all windows
" set showtabline=2 " Always display the tabline, even if there is only one tab
set noshowmode " Hide the default mode text (e.g. -- INSERT -- below the statusline)
