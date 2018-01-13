set nocompatible              " be iMproved, required
filetype off                  " required

"Turn on line numbers
set number
"Copy/Paste in OS clipboard
set clipboard=unnamed
"Automatically put selection in visual mode to clipboard, (seems to be broken)
set go+=a
"Set '<' and '>' to match
set matchpairs+=<:>
"Backspace do not delete 'eol'
set bs=indent,start

syntax on
set expandtab
set tabstop=2
set hlsearch
set incsearch
set ignorecase
set smartcase

" Put plugins and dictionaries in this dir (also on Windows)
let vimDir = '$HOME/.vim'
let &runtimepath.=','.vimDir

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
Plug 'scrooloose/nerdtree', { 'on':  'NERDTreeToggle' }
Plug 'jiangmiao/auto-pairs'
Plug 'tpope/vim-fugitive'
Plug 'airblade/vim-gitgutter'
Plug 'ctrlpvim/ctrlp.vim'
"Plug 'Valloric/YouCompleteMe'
"Colorcheme
Plug 'vim-scripts/twilight256.vim'
Plug 'nanotech/jellybeans.vim'
Plug 'drbraden/near-twilight-256'
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
nmap    <silent>   <BS>    :nohlsearch<CR>

python from powerline.vim import setup as powerline_setup
python powerline_setup()
python del powerline_setup
set laststatus=2 " Always display the statusline in all windows
"set showtabline=2 " Always display the tabline, even if there is only one tab
set noshowmode " Hide the default mode text (e.g. -- INSERT -- below the statusline)