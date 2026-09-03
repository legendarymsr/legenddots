" Dead-simple C/C++ LSP for Vim (needs Vim 9). Uses yegappan/lsp — pure Vim9,
" no node/python, no plugin manager. Needs: clangd on PATH.
"   1. install clangd (your clang package)
"   2. install the plugin via Vim's own native packages:
"        git clone https://github.com/yegappan/lsp ~/.vim/pack/lsp/start/lsp
"   3. source this from ~/.vimrc:
"        source ~/legenddots/suckless/vim/c-lsp.vim
"      (kept out of the base vimrc so that stays minimal)

augroup c_lsp
  autocmd!
  autocmd VimEnter * call LspAddServer([#{name: 'clangd', filetype: ['c', 'cpp'], path: 'clangd', args: []}])
augroup END

nnoremap <silent> gd :LspGotoDefinition<CR>
nnoremap <silent> gr :LspShowReferences<CR>
nnoremap <silent> K  :LspHover<CR>
nnoremap <silent> grn :LspRename<CR>
nnoremap <silent> gra :LspCodeAction<CR>
