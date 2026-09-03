function s:Init()
  call LspOptionsSet(#{showDiagWithVirtualText: v:false, showDiagInPopup: v:true})
  call LspAddServer([#{name: 'clangd', filetype: ['c', 'cpp'], path: 'clangd'}])
  for s in ['Error', 'Warning', 'Info', 'Hint']
    execute 'highlight LspDiagInline' .. s .. ' ctermbg=NONE guibg=NONE cterm=underline gui=underline'
  endfor
endfunction

" turn the plugin's E>/W> signs into line-number colors (red number = broken line)
function s:NumSigns()
  for c in [['LspDiagError','red','#f7768e'], ['LspDiagWarning','yellow','#e0af68'], ['LspDiagInfo','cyan','#7dcfff'], ['LspDiagHint','green','#9ece6a']]
    let d = sign_getdefined(c[0])
    if !empty(d) && has_key(d[0], 'text')
      execute 'highlight ' .. c[0] .. 'Num ctermfg=' .. c[1] .. ' guifg=' .. c[2]
      call sign_undefine(c[0])
      call sign_define(c[0], #{numhl: c[0] .. 'Num'})
    endif
  endfor
endfunction

autocmd VimEnter * call s:Init()
autocmd User LspAttached call s:NumSigns()

nnoremap <silent> gd <Cmd>LspGotoDefinition<CR>
nnoremap <silent> gr <Cmd>LspShowReferences<CR>
nnoremap <silent> K  <Cmd>LspHover<CR>
nnoremap <silent> gl <Cmd>LspDiag current<CR>
nnoremap <silent> ]g <Cmd>LspDiag next<CR>
nnoremap <silent> [g <Cmd>LspDiag prev<CR>
