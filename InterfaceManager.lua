local HttpService = game:GetService("HttpService")

local InterfaceManager = {} do

    -- ═══════════════════════════════════════
    --              Default Config
    -- ═══════════════════════════════════════
    local DEFAULTS = {
        Theme       = "Darker",
        Acrylic     = true,
        Transparency = true,
        MenuKeybind = "LeftControl",
    }

    InterfaceManager.Folder   = "FluentSettings"
    InterfaceManager.Settings = {}

    -- Deep copy defaults into Settings
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
    --           Save / Load / Reset
    -- ═══════════════════════════════════════
    function InterfaceManager:SaveSettings()
        local success, encoded = pcall(HttpService.JSONEncode, HttpService, self.Settings)
        if success then
            writefile(self.Folder .. "/options.json", encoded)
        else
            warn("[InterfaceManager] Failed to save settings:", encoded)
        end
    end

    function InterfaceManager:LoadSettings()
        local path = self.Folder .. "/options.json"
        if not isfile(path) then return end

        local data = readfile(path)
        local success, decoded = pcall(HttpService.JSONDecode, HttpService, data)

        if success and typeof(decoded) == "table" then
            for k, v in next, decoded do
                -- โหลดเฉพาะ key ที่มีอยู่ใน DEFAULTS เท่านั้น (ป้องกัน key ขยะ)
                if DEFAULTS[k] ~= nil then
                    self.Settings[k] = v
                end
            end
        else
            warn("[InterfaceManager] Corrupted settings file, using defaults.")
        end
    end

    function InterfaceManager:ResetSettings()
        for k, v in next, DEFAULTS do
            self.Settings[k] = v
        end
        self:SaveSettings()
    end

    -- ═══════════════════════════════════════
    --           Apply Settings
    -- ═══════════════════════════════════════
    function InterfaceManager:ApplySettings()
        local Library = self.Library
        local Settings = self.Settings

        assert(Library, "[InterfaceManager] Must call SetLibrary() before ApplySettings()")

        if Settings.Theme then
            Library:SetTheme(Settings.Theme)
        end

        if Library.UseAcrylic and Settings.Acrylic ~= nil then
            Library:ToggleAcrylic(Settings.Acrylic)
        end

        if Settings.Transparency ~= nil then
            Library:ToggleTransparency(Settings.Transparency)
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
                Library:SetTheme(Value)
                Settings.Theme = Value
                self:SaveSettings()
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
                    Settings.Acrylic = Value
                    self:SaveSettings()
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
                Settings.Transparency = Value
                self:SaveSettings()
            end
        })

        -- Keybind
        local MenuKeybind = section:AddKeybind("MenuKeybind", {
            Title   = "Minimize Bind",
            Default = Settings.MenuKeybind,
        })
        MenuKeybind:OnChanged(function()
            Settings.MenuKeybind = MenuKeybind.Value
            self:SaveSettings()
        end)
        Library.MinimizeKeybind = MenuKeybind

        -- Reset to Default
        section:AddButton({
            Title       = "Reset to Default",
            Description = "Resets all interface settings to default.",
            Callback    = function()
                self:ResetSettings()
                self:ApplySettings()
                ThemeDropdown:SetValue(Settings.Theme)
                Library:Notify({
                    Title   = "Interface",
                    Content = "Settings reset to default.",
                    Duration = 3
                })
            end
        })
    end

end

return InterfaceManager
