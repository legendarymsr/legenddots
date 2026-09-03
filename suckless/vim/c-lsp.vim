function s:LspInit()
  call LspOptionsSet(#{showDiagWithVirtualText: v:false, showDiagInPopup: v:true})
  call LspAddServer([#{name: 'clangd', filetype: ['c', 'cpp'], path: 'clangd', args: []}])
  for sev in ['Error', 'Warning', 'Info', 'Hint']
    execute 'highlight LspDiagInline' .. sev .. ' ctermbg=NONE guibg=NONE cterm=underline gui=underline'
  endfor
  highlight LspDiagSignErrorText   ctermbg=NONE guibg=NONE cterm=bold gui=bold ctermfg=red    guifg=#f7768e
  highlight LspDiagSignWarningText ctermbg=NONE guibg=NONE ctermfg=yellow guifg=#e0af68
  highlight LspDiagSignInfoText    ctermbg=NONE guibg=NONE ctermfg=cyan   guifg=#7dcfff
  highlight LspDiagSignHintText    ctermbg=NONE guibg=NONE ctermfg=green  guifg=#9ece6a
endfunction

function s:NumSigns()
  let bnr = bufnr('%')
  let placed = sign_getplaced(bnr, {'group': 'LSPDiag'})
  let m = {'LspDiagError': 'LspDiagSignErrorText', 'LspDiagWarning': 'LspDiagSignWarningText', 'LspDiagInfo': 'LspDiagSignInfoText', 'LspDiagHint': 'LspDiagSignHintText'}
  let converted = v:false
  for [nm, hl] in items(m)
    let d = sign_getdefined(nm)
    if !empty(d) && has_key(d[0], 'text')
      call sign_undefine(nm)
      call sign_define(nm, {'numhl': hl})
      let converted = v:true
    endif
  endfor
  if converted && !empty(placed) && !empty(placed[0].signs)
    call sign_unplace('LSPDiag', {'buffer': bnr})
    for s in placed[0].signs
      call sign_place(0, 'LSPDiag', s.name, bnr, {'lnum': s.lnum})
    endfor
  endif
endfunction

augroup c_lsp
  autocmd!
  autocmd VimEnter * call s:LspInit()
  autocmd User LspAttached call s:NumSigns()
  autocmd User LspDiagsUpdated call s:NumSigns()
augroup END

nnoremap <silent> gd :LspGotoDefinition<CR>
nnoremap <silent> gr :LspShowReferences<CR>
nnoremap <silent> K  :LspHover<CR>
nnoremap <silent> grn :LspRename<CR>
nnoremap <silent> gra :LspCodeAction<CR>
nnoremap <silent> gl :LspDiag current<CR>
nnoremap <silent> ]g :LspDiag next<CR>
nnoremap <silent> [g :LspDiag prev<CR>
