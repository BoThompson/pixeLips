dlg = Dialog()
function ex()
	app.alert("TESTING!")
end
function ex2()
	local data = dlg.data
	file = io.open(data["papagayo_file"], "r")

	-- prints the first line of the file
	app.alert(file:read())

	-- closes the opened file
	file:close()
end

dlg:file{id="papagayo_file", label="Papagayo File",
		open=true,
		entry=true,
		filetypes={"pgo", "dat", "txt"},
		onchange=ex2 }
dlg:newrow()
dlg:button{ id="play", text="Play", focus=true,
            onclick=ex }
dlg:button{ id="pause", text="Pause", focus=true,
            onclick=ex }
dlg:button{ id="stop", text="Stop", focus=true,
            onclick=ex }
dlg:newrow()
dlg:slider{ id="progress",
            min=0,
            max=100,
            value=0}
dlg:show{ wait=false }