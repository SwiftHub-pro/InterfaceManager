local httpService = game:GetService("HttpService")

local InterfaceManager = {} do
    InterfaceManager.Folder = "FluentSettings"
    InterfaceManager.Settings = {
        Theme = "Dark",
        Acrylic = true,
        Transparency = true,
        MenuKeybind = "LeftControl",
        UISize = 1,          -- ✅ ใหม่
        Notifications = true -- ✅ ใหม่
    }

    function InterfaceManager:SetFolder(folder)
        self.Folder = folder
        self:BuildFolderTree()
    end

    function InterfaceManager:SetLibrary(library)
        self.Library = library
    end

    function InterfaceManager:BuildFolderTree()
        local paths = {}
        local parts = self.Folder:split("/")
        for idx = 1, #parts do
            paths[#paths + 1] = table.concat(parts, "/", 1, idx)
        end
        table.insert(paths, self.Folder)
        table.insert(paths, self.Folder .. "/settings")
        for i = 1, #paths do
            local str = paths[i]
            if not isfolder(str) then
                makefolder(str)
            end
        end
    end

    function InterfaceManager:SaveSettings()
        writefile(self.Folder .. "/options.json", httpService:JSONEncode(InterfaceManager.Settings))
    end

    function InterfaceManager:LoadSettings()
        local path = self.Folder .. "/options.json"
        if isfile(path) then
            local data = readfile(path)
            local success, decoded = pcall(httpService.JSONDecode, httpService, data)
            if success then
                for i, v in next, decoded do
                    InterfaceManager.Settings[i] = v
                end
            end
        end
    end

    -- ✅ function ใหม่ — โหลดและ Apply ค่าทั้งหมดทีเดียว
    function InterfaceManager:ApplySettings()
        local Library = self.Library
        local Settings = self.Settings

        assert(Library, "Must set InterfaceManager.Library before calling ApplySettings")

        -- Apply Theme
        if Settings.Theme then
            Library:SetTheme(Settings.Theme)
        end

        -- Apply Acrylic
        if Library.UseAcrylic and Settings.Acrylic ~= nil then
            Library:ToggleAcrylic(Settings.Acrylic)
        end

        -- Apply Transparency
        if Settings.Transparency ~= nil then
            Library:ToggleTransparency(Settings.Transparency)
        end

        -- Apply UI Size
        if Settings.UISize then
            local gui = Library.GUI or Library.Parent
            if gui then
                gui.Size = UDim2.fromScale(Settings.UISize, Settings.UISize)
            end
        end

        -- Apply Notifications
        if Settings.Notifications ~= nil then
            Library.Notifications = Settings.Notifications
        end
    end

    function InterfaceManager:BuildInterfaceSection(tab)
        assert(self.Library, "Must set InterfaceManager.Library")
        local Library = self.Library
        local Settings = InterfaceManager.Settings

        InterfaceManager:LoadSettings()

        local section = tab:AddSection("Interface")

        -- Theme Dropdown (เดิม)
        local InterfaceTheme = section:AddDropdown("InterfaceTheme", {
            Title = "Theme",
            Description = "Changes the interface theme.",
            Values = Library.Themes,
            Default = Settings.Theme,
            Callback = function(Value)
                Library:SetTheme(Value)
                Settings.Theme = Value
                InterfaceManager:SaveSettings()
            end
        })
        InterfaceTheme:SetValue(Settings.Theme)

        -- Acrylic Toggle (เดิม)
        if Library.UseAcrylic then
            section:AddToggle("AcrylicToggle", {
                Title = "Acrylic",
                Description = "The blurred background requires graphic quality 8+",
                Default = Settings.Acrylic,
                Callback = function(Value)
                    Library:ToggleAcrylic(Value)
                    Settings.Acrylic = Value
                    InterfaceManager:SaveSettings()
                end
            })
        end

        -- Transparency Toggle (เดิม)
        section:AddToggle("TransparentToggle", {
            Title = "Transparency",
            Description = "Makes the interface transparent.",
            Default = Settings.Transparency,
            Callback = function(Value)
                Library:ToggleTransparency(Value)
                Settings.Transparency = Value
                InterfaceManager:SaveSettings()
            end
        })

        -- ✅ UI Size Slider
        section:AddSlider("UISizeSlider", {
            Title = "UI Size",
            Description = "ปรับขนาด UI (0.5 = เล็ก, 1 = ปกติ, 1.5 = ใหญ่)",
            Default = Settings.UISize or 1,
            Min = 0.5,
            Max = 1.5,
            Rounding = 1,
            Callback = function(Value)
                local gui = Library.GUI or Library.Parent
                if gui then
                    gui.Size = UDim2.fromScale(Value, Value)
                end
                Settings.UISize = Value
                InterfaceManager:SaveSettings()
            end
        })

        -- ✅ Notifications Toggle
        section:AddToggle("NotificationsToggle", {
            Title = "Notifications",
            Description = "เปิด/ปิดการแจ้งเตือน",
            Default = Settings.Notifications ~= false,
            Callback = function(Value)
                Library.Notifications = Value
                Settings.Notifications = Value
                InterfaceManager:SaveSettings()
            end
        })

        -- Keybind (เดิม)
        local MenuKeybind = section:AddKeybind("MenuKeybind", {
            Title = "Minimize Bind",
            Default = Settings.MenuKeybind
        })
        MenuKeybind:OnChanged(function()
            Settings.MenuKeybind = MenuKeybind.Value
            InterfaceManager:SaveSettings()
        end)
        Library.MinimizeKeybind = MenuKeybind
    end
end

return InterfaceManager