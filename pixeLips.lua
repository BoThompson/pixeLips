-- Print contents of `tbl`, with indentation.
-- `indent` sets the initial level of indentation.
function tprint (tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      tprint(v, indent+1)
    elseif type(v) == 'boolean' then
      print(formatting .. tostring(v))      
    else
      print(formatting .. v)
    end
  end
end


dlg = Dialog()
fps = 0
wav = nil
length = 0
numVoices = 0
papagayo_data = {}
function ex()
	app.alert("TESTING!")
end

function reverseArray(arr)
	local i, j = 1, #arr

	while i < j do
		arr[i], arr[j] = arr[j], arr[i]

		i = i + 1
		j = j - 1
	end
end

function splitLines(text)
	textLines = {}
	for line in string.gmatch(text, "[^\r\n]+") do
		if(line ~= nil) then
			table.insert(textLines, line)
		end
	end
	return textLines
end
function splitLine(line)
	tokens = {}
	for token in string.gmatch(line, "[^%s]+") do
		table.insert(tokens, token)
	end
	return tokens
end
function ex2()
	local data = dlg.data
	local file = io.open(data["papagayo_file"], "r")
	local header = file:read()
	if(header ~= "lipsync version 1") then
		app.alert("File not a valid papagayo file.")
		return
	end
	local s = file:read("*a")
	file:close()
	s = string.gsub(s, "\t+", "")
	fileLines = splitLines(s)
	reverseArray(fileLines)
	-- Load the wav file
	papagayo_data["wavFileName"] = table.remove(fileLines)
	papagayo_data["fps"] = tonumber(table.remove(fileLines))
	papagayo_data["length"] = tonumber(table.remove(fileLines))
	papagayo_data["numVoices"] = tonumber(table.remove(fileLines))
	papagayo_data["voices"] = {}
	-- Load each voice
	for i=1, papagayo_data["numVoices"],1 do
		local voice = {}
		voice["name"] = table.remove(fileLines)
		voice["text"] = table.remove(fileLines)
		voice["phraseNum"] = tonumber(table.remove(fileLines))
		voice["phrases"] = {}
		for j=1, voice["phraseNum"], 1  do
			local phrase = {}
			phrase["text"] = table.remove(fileLines)
			phrase["start"] = tonumber(table.remove(fileLines))
			phrase["end"] = tonumber(table.remove(fileLines))
			phrase["wordNum"] = tonumber(table.remove(fileLines))
			phrase["words"] = {}
			for k=1, phrase["wordNum"], 1 do
				local word = {}
				local wordTokens = splitLine(table.remove(fileLines))
				word["text"] = wordTokens[1]
				word["start"] = wordTokens[2]
				word["end"] = wordTokens[3]
				word["shapeNum"] = wordTokens[4]
				word["shapes"] = {}
				for l=1, word["shapeNum"], 1 do
					local shape = {}
					local shapeTokens = splitLine(table.remove(fileLines))
					shape["start"] = shapeTokens[1]
					shape["phoneme"] = shapeTokens[2]
					table.insert(word["shapes"], shape)
				end
				table.insert(phrase["words"], word)
			end
			table.insert(voice["phrases"], phrase)
		end
		table.insert(papagayo_data["voices"], voice)
	end
	-- prints the first line of the file
	-- closes the opened file
	app.alert("LOADED!")
	tprint(papagayo_data)
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