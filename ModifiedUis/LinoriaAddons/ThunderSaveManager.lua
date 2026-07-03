local httpService = game:GetService('HttpService')

--[[

    This feels weird...

]]

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.IsNotifyAllowed = false

	SaveManager.Parser = {
		Toggle = {
			Save = function(idx, object)
				return { type = 'Toggle', idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if Toggles[idx] then
					Toggles[idx]:SetValue(data.value)
				end
			end,
		},
		Slider = {
			Save = function(idx, object)
				return { type = 'Slider', idx = idx, value = tostring(object.Value) }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { type = 'Dropdown', idx = idx, value = object.Value, multi = object.Multi }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { type = 'ColorPicker', idx = idx, value = object.Value:ToHex(), transparency = object.Transparency }
			end,
			Load = function(idx, data)
				if Options[idx] then
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		Input = {
			Save = function(idx, object)
				return { type = 'Input', idx = idx, text = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] and type(data.text) == 'string' then
					Options[idx]:SetValue(data.text)
				end
			end,
		},
	}

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder
		self:BuildFolderTree()
	end

	function SaveManager:Save()
		if not isfile(self.Folder .. '/settings/autoload.txt') then
			return false, 'no autoload file'
		end

		local name = readfile(self.Folder .. '/settings/autoload.txt')
		if not name or name == '' then
			return false, 'invalid autoload'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = { objects = {} }

		for idx, option in next, Options do
			if not self.Ignore[idx] and self.Parser[option.Type] then
				local success, saved = pcall(self.Parser[option.Type].Save, idx, option)
				if success and saved then
					table.insert(data.objects, saved)
				end
			end
		end

		for idx, toggle in next, Toggles do
			if not self.Ignore[idx] and self.Parser[toggle.Type] then
				local success, saved = pcall(self.Parser[toggle.Type].Save, idx, toggle)
				if success and saved then
					table.insert(data.objects, saved)
				end
			end
		end

		local success, encoded = pcall(function()
			return httpService:JSONEncode(data)
		end)

		if not success or not encoded then
			return false, "failed to encode data"
		end

		if not isfolder(self.Folder .. '/settings') then
			makefolder(self.Folder .. '/settings')
		end

		pcall(function()
			writefile(fullPath, encoded)
		end)

		return true
	end

	function SaveManager:SetNotifyRules(a)
		SaveManager.IsNotifyAllowed = a
	end

	function SaveManager:Load()
		if not isfile(self.Folder .. '/settings/autoload.txt') then
			return false, 'no autoload file'
		end

		local name = readfile(self.Folder .. '/settings/autoload.txt')
		if not name or name == '' then
			return false, 'invalid autoload'
		end

		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then
			return false, 'invalid file'
		end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then
			return false, 'decode error'
		end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function()
					self.Parser[option.type].Load(option.idx, option)
				end)
			end
		end

		return true
	end

	function SaveManager:BuildFolderTree()
		local paths = {
			self.Folder,
			self.Folder .. '/themes',
			self.Folder .. '/settings'
		}

		for i = 1, #paths do
			local str = paths[i]
			if not isfolder(str) then
				makefolder(str)
			end
		end
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:AddAutoSave()
		task.spawn(function()
			while true do
				task.wait(5)
				pcall(function()
					self:Save()
				end)
			end
		end)
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			local success, err = self:Load()
			if not SaveManager.IsNotifyAllowed then
				if not success then
					return self.Library:Notify('Failed to load autoload config: ' .. err)
				end
				self.Library:Notify(string.format('Auto loaded config %q', name))
			end
		end
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
