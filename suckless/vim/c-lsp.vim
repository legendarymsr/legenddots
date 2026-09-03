augroup c_lsp
  autocmd!
  autocmd VimEnter * call LspOptionsSet(#{showDiagWithVirtualText: v:true, diagVirtualTextAlign: 'below'})
  autocmd VimEnter * call LspAddServer([#{name: 'clangd', filetype: ['c', 'cpp'], path: 'clangd', args: []}])
augroup END

nnoremap <silent> gd :LspGotoDefinition<CR>
nnoremap <silent> gr :LspShowReferences<CR>
nnoremap <silent> K  :LspHover<CR>
nnoremap <silent> grn :LspRename<CR>
nnoremap <silent> gra :LspCodeAction<CR>
nnoremap <silent> gl :LspDiag current<CR>
