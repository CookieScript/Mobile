local httpService = game:GetService('HttpService')

function CreateGroupBox(option)
    local names = type(option.Name) == "table" and option.Name or { option.Name }
    local TabBox = option.side == "left" and option.TabGroup:AddLeftTabbox() or option.TabGroup:AddRightTabbox()

    local results = {}
    for i = 1, #names do
        results[i] = TabBox:AddTab(names[i])
    end

    return table.unpack(results)
end

function safeValue(val)
    if typeof(val) == "Color3" then
        return val:ToHex()
    elseif typeof(val) == "Vector3" then
        return { x = val.X, y = val.Y, z = val.Z }
    elseif typeof(val) == "EnumItem" then
        return val.Name
    elseif typeof(val) == "boolean" or typeof(val) == "number" or typeof(val) == "string" then
        return val
    else
        return tostring(val)
    end
end

local SaveManager = {} do
	SaveManager.Folder = 'LinoriaLibSettings'
	SaveManager.Ignore = {}
	SaveManager.Parser = {
        Toggle = {
            Save = function(idx, obj) return { type = "Toggle", idx = idx, value = safeValue(obj.Value) } end,
            Load = function(idx, data) if Toggles[idx] then Toggles[idx]:SetValue(data.value) end end,
        },
        Slider = {
            Save = function(idx, obj) return { type = "Slider", idx = idx, value = safeValue(obj.Value) } end,
            Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(tonumber(data.value)) end end,
        },
        Dropdown = {
            Save = function(idx, obj) return { type = "Dropdown", idx = idx, value = safeValue(obj.Value), multi = obj.Multi } end,
            Load = function(idx, data) if Options[idx] then Options[idx]:SetValue(data.value) end end,
        },
        ColorPicker = {
            Save = function(idx, obj) return { type = "ColorPicker", idx = idx, value = safeValue(obj.Value), transparency = obj.Transparency } end,
            Load = function(idx, data) if Options[idx] then Options[idx]:SetValueRGB(Color3.fromHex(data.value), data.transparency) end end,
        },
        KeyPicker = {
            Save = function(idx, obj) return { type = "KeyPicker", idx = idx, mode = obj.Mode, key = safeValue(obj.Value) } end,
            Load = function(idx, data) if Options[idx] then Options[idx]:SetValue({ data.key, data.mode }) end end,
        },
        Input = {
            Save = function(idx, obj) return { type = "Input", idx = idx, text = safeValue(obj.Value) } end,
            Load = function(idx, data) if Options[idx] and type(data.text) == "string" then Options[idx]:SetValue(data.text) end end,
        },
    }

	function SaveManager:SetIgnoreIndexes(list)
		for _, key in next, list do
			self.Ignore[key] = true
		end
	end

	function SaveManager:SetFolder(folder)
		self.Folder = folder;
		self:BuildFolderTree()
	end

	function SaveManager:Save(name)
		if (not name) then
			return false, 'no config file is selected'
		end

		local fullPath = self.Folder .. '/settings/' .. name .. '.json'

		local data = {
			objects = {}
		}

		for idx, toggle in next, Toggles do
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[toggle.Type].Save(idx, toggle))
		end

		for idx, option in next, Options do
			if not self.Parser[option.Type] then continue end
			if self.Ignore[idx] then continue end

			table.insert(data.objects, self.Parser[option.Type].Save(idx, option))
		end	

		local success, encoded = pcall(httpService.JSONEncode, httpService, data)
		if not success then
			return false, 'failed to encode data'
		end

		writefile(fullPath, encoded)
		return true
	end

	function SaveManager:Load(name)
		if (not name) then
			return false, 'no config file is selected'
		end
		
		local file = self.Folder .. '/settings/' .. name .. '.json'
		if not isfile(file) then return false, 'invalid file' end

		local success, decoded = pcall(httpService.JSONDecode, httpService, readfile(file))
		if not success then return false, 'decode error' end

		for _, option in next, decoded.objects do
			if self.Parser[option.type] then
				task.spawn(function() self.Parser[option.type].Load(option.idx, option) end) -- task.spawn() so the config loading wont get stuck.
			end
		end

		return true
	end

	function SaveManager:IgnoreThemeSettings()
		self:SetIgnoreIndexes({ 
			"BackgroundColor", "MainColor", "AccentColor", "OutlineColor", "FontColor", -- themes
			"ThemeManager_ThemeList", 'ThemeManager_CustomThemeList', 'ThemeManager_CustomThemeName', -- themes
		})
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

	function SaveManager:RefreshConfigList()
		local list = listfiles(self.Folder .. '/settings')

		local out = {}
		for i = 1, #list do
			local file = list[i]
			if file:sub(-5) == '.json' then
				-- i hate this but it has to be done ...

				local pos = file:find('.json', 1, true)
				local start = pos

				local char = file:sub(pos, pos)
				while char ~= '/' and char ~= '\\' and char ~= '' do
					pos = pos - 1
					char = file:sub(pos, pos)
				end

				if char == '/' or char == '\\' then
					table.insert(out, file:sub(pos + 1, start - 1))
				end
			end
		end
		
		return out
	end

	function SaveManager:SetLibrary(library)
		self.Library = library
	end

	function SaveManager:LoadAutoloadConfig()
		if isfile(self.Folder .. '/settings/autoload.txt') then
			local name = readfile(self.Folder .. '/settings/autoload.txt')

			local success, err = self:Load(name)
			if not success then
				return self.Library:Notify('Failed to load autoload config: ' .. err)
			end

			self.Library:Notify(string.format('Auto loaded config %q', name))
		end
	end


	function SaveManager:BuildConfigSection(tab)
		assert(self.Library, 'Must set SaveManager.Library')

		local section = CreateGroupBox({TabGroup = tab, side = "right", Name = "Configuration"})

		section:AddInput('SaveManager_ConfigName',    { Text = 'Config name' })
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
			Options.SaveManager_ConfigList:SetValue(nil)
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

			local success, err = self:Save(name)
			if not success then
				return self.Library:Notify('Failed to overwrite config: ' .. err)
			end

			self.Library:Notify(string.format('Overwrote config %q', name))
		end)

		section:AddButton('Refresh list', function()
			Options.SaveManager_ConfigList:SetValues(self:RefreshConfigList())
			Options.SaveManager_ConfigList:SetValue(nil)
		end)

		section:AddButton('Set autoload', function()
			local name = Options.SaveManager_ConfigList.Value
			writefile(self.Folder .. '/settings/autoload.txt', name)
			SaveManager.AutoloadLabel:SetText('Current autoload config: ' .. name)
			self.Library:Notify(string.format('Set %q to auto load', name))
		end):AddButton('Remove autoload', function()
            local path = self.Folder .. '/settings/autoload.txt'
            if isfile(path) then
                delfile(path)
            end

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
