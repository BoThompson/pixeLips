--[[---------------------------------------------------------------------

  PixeLips 1.0 for Aseprite (https://aseprite.org)
  Project page: https://github.org/BoThompson/animationquantizer.git)
   
    by Bo Thompson ( @AimlessZealot / @Joybane )
    Twitter: http://twitter.com/aimlesszealot
    Dribbble: http://twitch.com/joybane

  Copyright (c) 2019 Bo Thompson

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.

  Purpose:
    Generates a talking animation based upon a Papagayo lipsync script file (pgo)
	and a correctly named folder with each mouthshape on a separate layer.
  
  Requirements:
    + Aseprite 1.2.13 or newer
	+ A Papagayo lipsync script file (pgo)
  
  Installation:
    + Open Aseprite
    + Go to `File → Scripts → Open Scripts Folder`
    + Place downloaded LUA script into opened directory
    + Restart Aseprite
  
  Usage:
    + Go to `File → Scripts → pixeLips` to run the script
	+ Make sure that your folder for the mouth shapes is named the same as the 
	  actor from the Papagayo lipsync script.
	+ Make sure that you have all of the necessary mouth shapes correctly within
	  that folder and named properly for identication
    + You can also setup a custom hotkey under `Edit → Keyboard Shortcuts`
    
-----------------------------------------------------------------------]]

dlg = Dialog()
fps = 0
wav = nil
length = 0
numVoices = 0
papagayo_data = {}


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

function findLayer(layerName, sprite, parent, isGroup)
	local found = false
	
	if(sprite == nil) then
		return nil
	end
	for x=1, #sprite.layers, 1 do
		local lyr = sprite.layers[x]
		if(lyr.isGroup == isGroup 
		and lyr.name == layerName) then
			if(not parent) then
				if(lyr.parent == sprite) then
					found = true
				end
			else
				if(parent.__name == sprite.layers[x].parent.__name
				and sprite.layers[x].parent == parent) then
						found = true
				end
			end
			
			if(found == true) then
				return lyr
			end
		end
	end
	return nil
end


function loadPGO()
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
	papagayo_data["timestamps"] = {}
	print("Test")
	-- Load each voice
	for i=1, papagayo_data["numVoices"],1 do
		local voice = {}
		voice["name"] = table.remove(fileLines)
		voice["text"] = table.remove(fileLines)
		voice["phraseNum"] = tonumber(table.remove(fileLines))
		voice["phrases"] = {}
		voice["timestamps"] = {}
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
				word["start"] = tonumber(wordTokens[2])
				word["end"] = tonumber(wordTokens[3])
				word["shapeNum"] = tonumber(wordTokens[4])
				word["shapes"] = {}
				if(k > 1) then
					local shapeEnd = voice.timestamps[#voice.timestamps][3] + voice.timestamps[#voice.timestamps][2]
					local restEnd = word["start"] / papagayo_data.fps
					if(restEnd ~= shapeEnd) then
						table.insert(voice.timestamps, { "rest", shapeEnd, restEnd - shapeEnd})
					end
				end
				for l=1, word["shapeNum"], 1 do
					local shape = {}
					local shapeTokens = splitLine(table.remove(fileLines))
					shape["start"] = tonumber(shapeTokens[1])
					shape["phoneme"] = shapeTokens[2]
					table.insert(word["shapes"], shape)
					local shapeStart = shape.start / papagayo_data.fps
					table.insert(voice.timestamps, {shape.phoneme, shapeStart, shapeStart}) 
				end
				--Update the lengths
				for m=#voice.timestamps - word["shapeNum"] + 1, #voice.timestamps, 1 do
					if(#voice.timestamps == m) then
						voice.timestamps[m][3] = word["end"] / papagayo_data.fps - voice.timestamps[m][3]
					else
						voice.timestamps[m][3] = voice.timestamps[m+1][2] - voice.timestamps[m][3]
					end
				end
				table.insert(phrase["words"], word)
			end
			table.insert(voice["phrases"], phrase)
		end
		table.insert(papagayo_data["voices"], voice)

	end
	
	-- prints the first line of the file
	-- closes the opened file
	sprite = app.activeSprite
	if(sprite == nil) then
		app.alert("No sprite currently selected.")
		return
	end
	
	
	for i=1, papagayo_data["numVoices"],1 do
		local groupLayer = findLayer(papagayo_data["voices"][i]["name"], sprite, nil, true)
		if(groupLayer == nil) then
			app.alert("Voice group layer could not be found. Make sure you have a group named: " .. papagayo_data["voices"][i]["name"])
			return
		end
		local voiceLayers = {
								AI = findLayer("AI", sprite, groupLayer, false), 
								O = findLayer("O", sprite, groupLayer, false),
								E = findLayer("E", sprite, groupLayer, false),
								U = findLayer("U", sprite, groupLayer, false),
								L = findLayer("L", sprite, groupLayer, false),
								WQ = findLayer("WQ", sprite, groupLayer, false),
								MBP = findLayer("MBP", sprite, groupLayer, false),
								FV = findLayer("FV", sprite, groupLayer, false),
								etc = findLayer("etc", sprite, groupLayer, false),
								rest = findLayer("rest", sprite, groupLayer, false)
							}
		if(voiceLayers.AI == nil) then
			app.alert("AI layer is missing from the group.")
			return
		end
		if(voiceLayers.O == nil) then
			app.alert("O layer is missing from the group.")
			return
		end
		if(voiceLayers.E == nil) then
			app.alert("E layer is missing from the group.")
			return
		end
		if(voiceLayers.U == nil) then
			app.alert("U layer is missing from the group.")
			return
		end
		if(voiceLayers.L == nil) then
			app.alert("L layer is missing from the group.")
			return
		end
		if(voiceLayers.WQ == nil) then
			app.alert("WQ layer is missing from the group.")
			return
		end
		if(voiceLayers.MBP == nil) then
			app.alert("MBP layer is missing from the group.")
			return
		end
		if(voiceLayers.FV == nil) then
			app.alert("FV layer is missing from the group.")
			return
		end
		if(voiceLayers.etc == nil) then
			app.alert("etc layer is missing from the group.")
			return
		end
		if(voiceLayers.rest == nil) then
			app.alert("rest layer is missing from the group.")
			return
		end
		papagayo_data.voices[i].layers = voiceLayers
		table.sort(papagayo_data.voices[i].timestamps, function(a,b) return a[2] < b[2] end)
	end
	
	-- Construct the array of millisecond times based upon phrase lengths
end

function generateAnimation()
	local sprite = app.activeSprite
	local baseFrame = sprite.frames[1]
	local mouthCels = {}
	--Create the preparation frame for all others
	local prepFrame = sprite:newFrame(1)
	--Get the mouth cels and clear those cels from the prep frame
	for k,v in pairs(papagayo_data.voices[1].layers) do
		mouthCels[k] = v.cels[1]
		sprite:deleteCel(v, #sprite.frames)
	end
	--Create a new animation layer and name it
	local animationLayer = sprite:newLayer()
	animationLayer.name = papagayo_data.voices[1].name
	--Duplicate the starting frame and remove all mouth shapes to have a default
	
	--Loop through all timestamps for voice 1 and copy each mouth cel into animationLayer cel
	for i = 1, #papagayo_data.voices[1].timestamps, 1 do
		--Generate a new frame
		local currFrame = sprite:newFrame(#sprite.frames) 
		--Set its length
		currFrame.duration = papagayo_data.voices[1].timestamps[i][3]
		--Place correct mouth shape in the cel
		local shape = papagayo_data.voices[1].timestamps[i][1]
		sprite:newCel(animationLayer, currFrame.frameNumber, mouthCels[shape].image, mouthCels[shape].position)
	end
	sprite:deleteFrame(prepFrame)
	print("Complete.")
	
end

dlg:file{id="papagayo_file", label="Papagayo File",
		open=true,
		entry=true,
		filetypes={"pgo", "dat", "txt"},
		onchange=loadPGO }
dlg:newrow()
dlg:button{ id="generate", text="Generate", focus=true,
            onclick=generateAnimation }
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