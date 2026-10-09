-- load standard vis module, providing parts of the Lua API
require('vis')

vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme base-16")
	
	vis:map(vis.modes.NORMAL, "<C-k>", "0D")
	vis:map(vis.modes.INSERT, "<C-k>", "<Escape>0DA")

	for _, mode in ipairs({ vis.modes.NORMAL, vis.modes.INSERT, vis.modes.VISUAL }) do
		vis:map(mode, "<C-Left>", "<vis-motion-word-start-prev>")
		vis:map(mode, "<C-Right>", "<vis-motion-word-start-next>")
		vis:map(mode, "<C-Up>", "<vis-motion-paragraph-prev>")
		vis:map(mode, "<C-Down>", "<vis-motion-paragraph-next>")
	end
end)

vis.events.subscribe(vis.events.WIN_OPEN, function(win)
	vis:command("set tabwidth 4")
	vis:command("set numbers true")
	vis:command("set autoindent true")
	vis:command("set showspaces false")
	vis:command("set showtabs false")
	vis:command("set expandtab off")
	vis:command("set shell /usr/bin/env sh")
end)
