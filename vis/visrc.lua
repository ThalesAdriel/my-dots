-- load standard vis module, providing parts of the Lua API
require('vis')

vis.events.subscribe(vis.events.INIT, function()
	vis:command("set theme base-16")
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
