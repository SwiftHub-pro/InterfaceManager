local HttpService = game:GetService("HttpService")

local InterfaceManager = {} do

    -- ═══════════════════════════════════════
    --              Constants
    -- ═══════════════════════════════════════
    local DEFAULTS = {
        Theme        = "Darker",
        Acrylic      = true,
        Transparency = true,
        MenuKeybind  = "LeftControl",
    }

    local TYPES = {
        Theme        = "string",
        Acrylic      = "boolean",
        Transparency = "boolean",
        MenuKeybind  = "string",
    }

    -- ═══════════════════════════════════════
    --              State
    -- ═══════════════════════════════════════
    InterfaceManager.Folder    = "FluentSettings"
    InterfaceManager.Settings  = {}
    InterfaceManager.IsLoaded  = false
    InterfaceManager._listeners = {}
    InterfaceManager._saveDebounce = nil

    for k, v in next, DEFAULTS do
        InterfaceManager.Settings[k] = v
    end

    -- ═══════════════════════════════════════
    --              Setup
    -- ═══════════════════════════════════════
    function InterfaceManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function InterfaceManager:SetLibrary(library)
        self.Library = library
    end

    -- ═══════════════════════════════════════
    --           Folder Management
    -- ═══════════════════════════════════════
    function InterfaceManager:BuildFolderTree()
        local paths = {}
        local parts = self.Folder:split("/")

        for idx = 1, #parts do
            paths[#paths + 1] = table.concat(parts, "/", 1, idx)
        end

        table.insert(paths, self.Folder .. "/settings")

        for _, path in next, paths do
            if not isfolder(path) then
                makefolder(path)
            end
        end
    end

    -- ═══════════════════════════════════════
    --           Event System
    -- ═══════════════════════════════════════
    function InterfaceManager:OnSettingChanged(key, callback)
        if not self._listeners[key] then
            self._listeners[key] = {}
        end
        table.insert(self._listeners[key], callback)
    end

    function InterfaceManager:_fire(key, value)
        if self._listeners[key] then
            for _, cb in next, self._listeners[key] do
                task.spawn(cb, value)
            end
        end
    end

    -- ═══════════════════════════════════════
    --           Get / Set
    -- ═══════════════════════════════════════
    function InterfaceManager:GetSetting(key, fallback)
        if self.Settings[key] ~= nil then
            return self.Settings[key]
        end
        return fallback ~= nil and fallback or DEFAULTS[key]
    end

    function InterfaceManager:SetSetting(key, value)
        if DEFAULTS[key] == nil then
            return warn("[InterfaceManager] Unknown key:", key)
        end
        if typeof(value) ~= TYPES[key] then
            return warn("[InterfaceManager] Wrong type for '" .. key .. "' — expected " .. TYPES[key] .. ", got " .. typeof(value))
        end
        local old = self.Settings[key]
        self.Settings[key] = value
        if old ~= value then
            self:_fire(key, value)
        end
        self:SaveSettings()
    end

    -- ═══════════════════════════════════════
    --           Save / Load
    -- ═══════════════════════════════════════
    function InterfaceManager:SaveSettings()
        -- Debounce: ป้องกัน write file ถี่เกินไป
        if self._saveDebounce then
            task.cancel(self._saveDebounce)
        end
        self._saveDebounce = task.delay(0.5, function()
            local data = {}
            for k, v in next, self.Settings do
                data[k] = v
            end
            data["_savedAt"] = os.time()  -- timestamp สำหรับ debug

            local success, encoded = pcall(HttpService.JSONEncode, HttpService, data)
            if success then
                writefile(self.Folder .. "/options.json", encoded)
            else
                warn("[InterfaceManager] Failed to save settings:", encoded)
            end
            self._saveDebounce = nil
        end)
    end

    function InterfaceManager:LoadSettings()
        local path = self.Folder .. "/options.json"
        if not isfile(path) then
            self.IsLoaded = true
            return
        end

        local data = readfile(path)
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)

        if success and typeof(decoded) == "table" then
            for k, v in next, decoded do
                -- กรอง _savedAt และ key ที่ไม่รู้จัก
                if DEFAULTS[k] ~= nil and typeof(v) == TYPES[k] then
                    self.Settings[k] = v
                end
            end
            -- Backfill: ถ้ามี key ใหม่ใน DEFAULTS ที่ save เก่าไม่มี
            for k, v in next, DEFAULTS do
                if self.Settings[k] == nil then
                    self.Settings[k] = v
                end
            end
        else
            -- Backup ไฟล์เสีย แทนที่จะลบทิ้ง
            pcall(function()
                writefile(self.Folder .. "/options.backup.json", data)
            end)
            warn("[InterfaceManager] Corrupted settings — backed up to options.backup.json, using defaults.")
        end

        self.IsLoaded = true
    end

    -- ═══════════════════════════════════════
    --           Reset
    -- ═══════════════════════════════════════
    function InterfaceManager:ResetSettings()
        for k, v in next, DEFAULTS do
            local old = self.Settings[k]
            self.Settings[k] = v
            if old ~= v then
                self:_fire(k, v)
            end
        end
        self:SaveSettings()
        self:ApplySettings()
        print("[InterfaceManager] Settings reset to defaults.")
    end

    -- ═══════════════════════════════════════
    --           Export / Import
    -- ═══════════════════════════════════════
    function InterfaceManager:ExportConfig()
        local export = {}
        for k, v in next, self.Settings do
            export[k] = v
        end
        local success, encoded = pcall(HttpService.JSONEncode, HttpService, export)
        if success then
            setclipboard(encoded)
            print("[InterfaceManager] Config copied to clipboard!")
        else
            warn("[InterfaceManager] Failed to export config.")
        end
    end

    function InterfaceManager:ImportConfig(json)
        if typeof(json) ~= "string" or json == "" then
            return warn("[InterfaceManager] ImportConfig requires a JSON string.")
        end
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, json)
        if not success or typeof(decoded) ~= "table" then
            return warn("[InterfaceManager] Invalid config string.")
        end
        for k, v in next, decoded do
            if DEFAULTS[k] ~= nil and typeof(v) == TYPES[k] then
                local old = self.Settings[k]
                self.Settings[k] = v
                if old ~= v then
                    self:_fire(k, v)
                end
            end
        end
        self:SaveSettings()
        self:ApplySettings()
        print("[InterfaceManager] Config imported successfully.")
    end

    -- ═══════════════════════════════════════
    --           Apply Settings
    -- ═══════════════════════════════════════
    function InterfaceManager:ApplySettings()
        assert(self.Library, "[InterfaceManager] Must call SetLibrary() before ApplySettings()")

        if not self.IsLoaded then
            return warn("[InterfaceManager] Call LoadSettings() before ApplySettings()")
        end

        local Library = self.Library
        local Settings = self.Settings

        if Settings.Theme then
            Library:SetTheme(Settings.Theme)
        end

        if Library.UseAcrylic and Settings.Acrylic ~= nil then
            Library:ToggleAcrylic(Settings.Acrylic)
        end

        if Settings.Transparency ~= nil then
            Library:ToggleTransparency(Settings.Transparency)
        end

        -- Apply MenuKeybind ด้วย (ของเดิมไม่มี)
        if self.Library.MinimizeKeybind and Settings.MenuKeybind then
            self.Library.MinimizeKeybind:SetValue(Settings.MenuKeybind)
        end
    end

    -- ═══════════════════════════════════════
    --           Build UI Section
    -- ═══════════════════════════════════════
    function InterfaceManager:BuildInterfaceSection(tab)
        assert(self.Library, "[InterfaceManager] Must call SetLibrary() before BuildInterfaceSection()")

        local Library = self.Library
        local Settings = self.Settings

        self:LoadSettings()
        self:ApplySettings()

        local section = tab:AddSection("Interface")

        -- Theme
        local ThemeDropdown = section:AddDropdown("InterfaceTheme", {
            Title       = "Theme",
            Description = "Changes the interface theme.",
            Values      = Library.Themes,
            Default     = Settings.Theme,
            Callback    = function(Value)
                self:SetSetting("Theme", Value)
            end
        })
        ThemeDropdown:SetValue(Settings.Theme)

        -- Acrylic
        if Library.UseAcrylic then
            section:AddToggle("AcrylicToggle", {
                Title       = "Acrylic",
                Description = "Blurred background (requires graphics quality 8+).",
                Default     = Settings.Acrylic,
                Callback    = function(Value)
                    Library:ToggleAcrylic(Value)
                    self:SetSetting("Acrylic", Value)
                end
            })
        end

        -- Transparency
        section:AddToggle("TransparentToggle", {
            Title       = "Transparency",
            Description = "Makes the interface transparent.",
            Default     = Settings.Transparency,
            Callback    = function(Value)
                Library:ToggleTransparency(Value)
                self:SetSetting("Transparency", Value)
            end
        })

        -- Menu Keybind
        local MenuKeybind = section:AddKeybind("MenuKeybind", {
            Title   = "Minimize Bind",
            Default = Settings.MenuKeybind,
        })
        MenuKeybind:OnChanged(function()
            self:SetSetting("MenuKeybind", MenuKeybind.Value)
        end)
        Library.MinimizeKeybind = MenuKeybind

        -- Export Config
        section:AddButton("ExportConfig", {
            Title       = "Export Config",
            Description = "Copies current settings to clipboard.",
            Callback    = function()
                self:ExportConfig()
            end
        })

        -- Reset to Defaults
        section:AddButton("ResetInterface", {
            Title       = "Reset to Defaults",
            Description = "Restores all interface settings to default.",
            Callback    = function()
                self:ResetSettings()
                ThemeDropdown:SetValue(DEFAULTS.Theme)
            end
        })
    end

end

return InterfaceManager
