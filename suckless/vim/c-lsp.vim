function s:LspInit()
  call LspOptionsSet(#{showDiagWithVirtualText: v:false, showDiagInPopup: v:true})
  call LspAddServer([#{name: 'clangd', filetype: ['c', 'cpp'], path: 'clangd', args: []}])
  for sev in ['Error', 'Warning', 'Info', 'Hint']
    execute 'highlight LspDiagInline' .. sev .. ' ctermbg=NONE guibg=NONE cterm=underline gui=underline'
  endfor
  highlight LspDiagSignErrorText   ctermbg=NONE guibg=NONE ctermfg=red    guifg=#f7768e
  highlight LspDiagSignWarningText ctermbg=NONE guibg=NONE ctermfg=yellow guifg=#e0af68
  highlight LspDiagSignInfoText    ctermbg=NONE guibg=NONE ctermfg=cyan   guifg=#7dcfff
  highlight LspDiagSignHintText    ctermbg=NONE guibg=NONE ctermfg=green  guifg=#9ece6a
endfunction

augroup c_lsp
  autocmd!
  autocmd VimEnter * call s:LspInit()
augroup END

nnoremap <silent> gd :LspGotoDefinition<CR>
nnoremap <silent> gr :LspShowReferences<CR>
nnoremap <silent> K  :LspHover<CR>
nnoremap <silent> grn :LspRename<CR>
nnoremap <silent> gra :LspCodeAction<CR>
nnoremap <silent> gl :LspDiag current<CR>
nnoremap <silent> ]g :LspDiag next<CR>
nnoremap <silent> [g :LspDiag prev<CR>
