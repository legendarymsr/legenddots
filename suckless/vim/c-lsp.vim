function s:I()
  call LspOptionsSet(#{showDiagWithVirtualText: v:false, showDiagInPopup: v:true})
  call LspAddServer([#{name: 'clangd', filetype: ['c','cpp'], path: 'clangd'}])
  for s in ['Error','Warning','Info','Hint']
    execute 'hi LspDiagInline'..s..' cterm=underline gui=underline'
  endfor
endfunction
function s:N()
  for c in [['LspDiagError',1,'#f7768e'],['LspDiagWarning',3,'#e0af68'],['LspDiagInfo',6,'#7dcfff'],['LspDiagHint',2,'#9ece6a']]
    let d=sign_getdefined(c[0])
    if !empty(d)&&has_key(d[0],'text')
      execute 'hi '..c[0]..'N ctermfg='..c[1]..' guifg='..c[2]
      call sign_undefine(c[0])
      call sign_define(c[0],#{numhl:c[0]..'N'})
    endif
  endfor
endfunction
autocmd VimEnter * call s:I()
autocmd User LspAttached call s:N()
nnoremap <silent> gd <Cmd>LspGotoDefinition<CR>
nnoremap <silent> K <Cmd>LspHover<CR>
nnoremap <silent> gl <Cmd>LspDiag current<CR>
nnoremap <silent> ]g <Cmd>LspDiag next<CR>
nnoremap <silent> [g <Cmd>LspDiag prev<CR>
