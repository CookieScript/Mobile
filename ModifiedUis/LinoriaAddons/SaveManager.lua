local httpService = game:GetService('HttpService')

--[[
testing
]]

function CreateGroupBox(option)
    local names = type(option.Name) == "table" and option.Name or { option.Name }
    local TabBox = option.side == "left" and option.TabGroup:AddLeftTabbox() or option.TabGroup:AddRightTabbox()

    local results = {}
    for i = 1, #names do
        results[i] = TabBox:AddTab(names[i])
    end

    return table.unpack(results)
end

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
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
				return { type = 'Slider', idx = idx, value = object.Value }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		Dropdown = {
			Save = function(idx, object)
				return { 
                    type = 'Dropdown', 
                    idx = idx, 
                    value = object.Value, 
                    multi = object.Multi 
                }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue(data.value)
				end
			end,
		},
		ColorPicker = {
			Save = function(idx, object)
				return { 
                    type = 'ColorPicker', 
                    idx = idx, 
                    value = object.Value:ToHex(), 
                    transparency = object.Transparency 
                }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency)
				end
			end,
		},
		KeyPicker = {
			Save = function(idx, object)
				return { 
                    type = 'KeyPicker', 
                    idx = idx, 
                    mode = object.Mode, 
                    key = object.Value 
                }
			end,
			Load = function(idx, data)
				if Options[idx] then 
					Options[idx]:SetValue({ data.key, data.mode })
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

	function SaveManager:Save(name)
		if not name then
			return false, 'no config file is selected'
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

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, "failed to encode config: " .. tostring(encoded)
		end

		if not isfolder(self.Folder .. '/settings') then
			makefolder(self.Folder .. '/settings')
		end

		local writeSuccess = pcall(writefile, fullPath, encoded)
		if not writeSuccess then
			return false, "failed to write config file"
		end

		return true
	end

	function SaveManager:Load(name)
		if not name then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then 
            return false, 'config does not exist' 
        end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then 
            return false, 'failed to decode config' 
        end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				pcall(self.Parser[option.type].Load, option.idx, option)
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor",
			"ThemeManager_ThemeList", "ThemeManager_CustomThemeList", "ThemeManager_CustomThemeName",
		})
	end

	function SaveManager:BuildFolderTree()
		local paths = {self.Folder, self.Folder .. '/themes', self.Folder .. '/settings'}
		for _, path in ipairs(paths) do
			if not isfolder(path) then
				makefolder(path)
			end
		end
	end

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')
		local out = {}
		for _, file in ipairs(list) do
			if file:sub(-5) == '.json' then
				local name = file:match("([^/\\]+)%.json$")
				if name then table.insert(out, name) end
			end
		end
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		local autoloadPath = self.Folder .. '/settings/autoload.txt'
		if isfile(autoloadPath) then
			local name = readfile(autoloadPath):gsub("%s+", "")
			if name \~= "" then
				local success, err = self:Load(name)
				if success then
					self.Library:Notify(string.format('Auto loaded config %q', name))
				else
					self.Library:Notify('Failed to load autoload config: ' .. err)
				end
			end
		end
	end

	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = CreateGroupBox({TabGroup = tab, side = "right", Name = "Configuration"})

		section:AddInput('SaveManager_ConfigName', { Text = 'Config name' })
		section:AddDropdown('SaveManager_ConfigList', { Text = 'Config list', Values = self:RefreshConfigList(), AllowNull = true })

		section:AddDivider()

		section:AddButton('Create config', function()
			local name = Options.SaveManager_ConfigName.Value
			if name:gsub(' ', '') == '' then 
				return self.Library:Notify('Invalid config name (empty)', 2)
			end

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to save config: ' .. err)
			end

			self.Library:Notify(string.format('Created config %q', name))
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
		end):AddButton('Load config', function()
			local name = Options.SaveManager_ConfigList.Value
			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load config: ' .. err)
			end
			self.Library:Notify(string.format('Loaded config %q', name))
		end)

		section:AddButton('Overwrite config', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then return end
			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end
			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
		end)

		section:AddButton('Set autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			if not name then return end
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Remove autoload', function()
			local path = self.Folder .. '/settings/autoload.txt'
			if isfile(path) then delfile(path) end
			SaveManager.AutoloadLabel:SetText('Current autoload config: none')
			self.Library:Notify('Removed autoload config')
		end)

		SaveManager.AutoloadLabel = section:AddLabel('Current autoload config: none', true)

		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
		end

		SaveManager:SetIgnoreIndexes({ 'SaveManager_ConfigList', 'SaveManager_ConfigName' })
	end

	SaveManager:BuildFolderTree()
end

return SaveManager
