------------------------------------------------
--  Copyright © 2013-2020   Hugula: Arpg game Engine
--
--  author pu
------------------------------------------------
local type = type
local ipairs = ipairs
local pairs = pairs
local string_match = string.match
local table_insert = table.insert

local profiler = require("perf.profiler")

local CS = CS
local GameObject = CS.UnityEngine.GameObject
local Hugula = CS.Hugula
local ResourcesLoader = Hugula.Loader.ResourcesLoader
local VMGenerate = VMGenerate
local VMConfig = VMConfig

local LoadSceneMode = CS.UnityEngine.SceneManagement.LoadSceneMode
local BindingUtility = Hugula.Databinding.BindingUtility

ResourcesLoader.Initialize()

---检查view_base的所有资源是否都加载完成
---@overload fun(view_base:VMBase)
---@param view_base VMBase
local function check_vm_base_all_done(vm_base)
    local views = vm_base.views
    if views then
        for k, v in ipairs(views) do
            if v:is_initialized() == false then
                return false
            end
        end
    end
    vm_base.is_res_ready = true
    vm_base.is_active = true
    vm_base:on_active()
    return true
end

---设置view的BindableContainer,并标记资源完成
---@overload fun(gobj:GameObject,view_base:ViewBase)
---@param gobj GameObject
---@param view_base ViewBase
local function set_view_child(gobj, view_base)
    local bindable_container = BindingUtility.GetBindableObject(gobj)
    view_base:set_child(bindable_container or gobj)
end

---初始化视图和viewmode并设置他们的关系
---@overload fun(gobj:GameObject,view_base:ViewBase)
---@param gobj GameObject
---@param view_base ViewBase
local function init_view(view_base)
    -- body
    local on_asset_load = view_base.on_asset_load
    if on_asset_load then
        on_asset_load(view_base, view_base._child)
    end
    view_base:set_active(true)
    view_base:initialized() --标记初始化
    local vm_base = view_base._vm_base
    if vm_base.auto_context then
        view_base:set_child_context(vm_base)
    end

    check_vm_base_all_done(vm_base)
end

---资源加载完成
---@overload fun(data:GameObject,view_base:ViewBase)
---@param data GameObject
---@param view_base ViewBase
local function on_res_comp(data, view_base)
    -- profiler.start()
    if view_base:has_child() ~= true then
        local inst = GameObject.Instantiate(data)
        set_view_child(inst, view_base)
    end

    init_view(view_base)
    -- Logger.Log(string.format("init_view_wm:%s\r\n",inst.name), profiler.report())
    -- profiler.stop()
end

---资源预加载完成
---@overload fun(data:GameObject,view_base:ViewBase)
---@param data GameObject
---@param view_base ViewBase
local function on_pre_load_comp(data, view_base)
    if view_base:has_child() ~= true then
        -- data:SetActive(false)
        local inst = GameObject.Instantiate(data)
        set_view_child(inst, view_base)
        inst:SetActive(false)
    end

end

---场景加载完成
---@overload fun(data:GameObject,view_base:ViewBase)
---@param data GameObject
---@param view_base ViewBase
local function on_scene_comp(data, view_base)
    if view_base:has_child() ~= true then
        -- set_view_child(data, view_base)
        view_base:set_child(data)
    end

    init_view(view_base)
    -- Logger.Log(string.format("on_scene_comp : %s", view_base))
end

---场景预加载完成
---@overload fun(data:GameObject,view_base:ViewBase)
---@param data GameObject
---@param view_base ViewBase
local function on_pre_scene_comp(data, view_base)
    if view_base:has_child() ~= true then
        -- set_view_child(data, view_base)
        view_base:set_child(data)
    end
    -- Logger.Log(string.format("on_pre_scene_comp : %s", view_base))
end

local function on_res_end(data, view_base)
    Logger.Log(string.format("on_res_end : %s", view_base))
end

---利用find查找view的gameobject root
---@overload fun(name:string,view_base:ViewBase)
---@param name string
---@param vm_base VMBase
---@param view_base ViewBase
local function find_gameobject(name, view_base)
    -- profiler.start()
    local find_name = name
    local inst = GameObject.Find(find_name)
    set_view_child(inst, view_base)
    init_view(view_base)
    -- Logger.Log("init_view_wm\r\n",profiler.report())
    -- profiler.stop()
end

--- 将vm关联的所有view 状态设置为参数enable的值
---@overload fun(vm_name:string,enable:boolean)
---@param vm_name string
---@param enable boolean
local function active_view(self, vm_name)
    ---@class VMBase
    local curr_vm = VMGenerate[vm_name] --获取vm实例
    -- local vm_config = VMConfig[vm_name] --获取配置信息
    if curr_vm.is_res_ready == true then --已经加载过
        local views = curr_vm.views
        if views then
            for k, v in ipairs(views) do
                v:set_active(true)
            end
        end

        curr_vm.is_active = true
        curr_vm:on_active()
    end
end

local function deactive_view(self, vm_name)
    local curr_vm = VMGenerate[vm_name] --获取vm实例
    if curr_vm.is_res_ready == true then --已经加载过
        local views = curr_vm.views
        if views then
            for k, v in ipairs(views) do
                v:set_active(false)
            end
        end

        curr_vm.is_active = false
        curr_vm:on_deactive()
    end
end

--- 销毁vm关联的所有view的资源
---@overload fun(vm_name:string)
---@param vm_name string
local function destory_view(self, vm_name)
    local curr_vm = VMGenerate[vm_name] --获取vm实例
    -- if curr_vm.is_res_ready == true then --已经加载过
    local views = curr_vm.views
    if views then
        for k, v in ipairs(views) do
            v:clear()
        end
    end

    curr_vm.is_active = false
    curr_vm.is_res_ready = false
    curr_vm:on_deactive()
    curr_vm:on_destroy()
    -- else
    --     Logger.Log(vm_name," is not ready")
    -- end
end

---加载配置的资源
---@overload fun(res_path:string,res_name:string,view_base:ViewBase,on_asset_comp:function,is_pre_load:boolean)
---@param res_path string
---@param res_name string
---@param view_base ViewBase
---@param on_asset_comp function
---@param is_pre_load boolean
local function load_resource(res_path, res_name, view_base, on_asset_comp, is_pre_load)
    local vm_name = view_base._vm_base.name
    local vm_config = VMConfig[vm_name]
    local async = vm_config.async

    if is_pre_load == true then
        async = is_pre_load
    end
    if on_asset_comp == nil then
        on_asset_comp = on_res_comp
    end

    if view_base:has_child() == true then --and is_pre_load ~= true then --如果已经加载资源
        init_view(view_base)
    else
        if async ~= false then ---异步加载
            ResourcesLoader.LoadAssetAsync(res_path, res_name, nil, on_asset_comp, nil, view_base)
        else
            local gobj = ResourcesLoader.LoadAsset(res_path, res_name, nil)
            on_asset_comp(gobj, view_base) ---同步步加载
        end
    end
end

---加载场景
---@overload fun(res_path:string,res_name:string,view_base:ViewBase,on_asset_comp:function,is_pre_load:boolean)
---@param res_path string
---@param res_name string
---@param view_base ViewBase
---@param on_asset_comp function
---@param is_pre_load boolean
local function load_scene(res_path, scene_name, view_base, on_asset_comp, is_pre_load) --LoadScene
    local load_scene_mode
    if view_base.load_scene_mode ~= nil then
        load_scene_mode = view_base.load_scene_mode
    else
        load_scene_mode = LoadSceneMode.Additive
    end

    if on_asset_comp == nil then
        on_asset_comp = on_scene_comp
    end

    local allow_scene_activation = true
    if view_base.allow_scene_activation ~= nil then
        allow_scene_activation = view_base.allow_scene_activation
    end

    if is_pre_load == true then --强制设置scene active 一般用于预加载
        allow_scene_activation = false
    end

    ResourcesLoader.LoadScene(
        res_path,
        scene_name,
        on_asset_comp,
        on_res_end,
        view_base,
        allow_scene_activation,
        load_scene_mode
    )
end

--- 开始加载或者激活vm关联的view
---@overload fun(vm_name:string,arg:any)
---@param vm_name string
---@param arg any
local function load(self, vm_name, arg)
    local curr_vm = VMGenerate[vm_name] --获取vm实例
    curr_vm:on_push_arg(arg) --有参数
    if curr_vm.is_res_ready == true then --已经加载过
        active_view(self, vm_name)
    else
        local views = curr_vm.views
        if views then
            local find_path, res_name, scene_name, res_path
            for k, v in ipairs(views) do
                find_path, res_name, scene_name, res_path = v.find_path, v.asset_name, v.scene_name, v.res_path
                if res_name ~= nil and res_path ~= nil then
                    load_resource(res_path, res_name, v)
                elseif scene_name ~= nil and res_path ~= nil then
                    load_scene(res_path, scene_name, v)
                elseif v.find_path ~= nil then
                    find_gameobject(v.find_path, v)
                end
            end
        end
    end
end

---激活vm 加载资源或者激活ui
---当vm为string单个
---vm table 时候多个
---@overload fun(vm_name:any,arg:any)
---@param vm_name any
---@param arg any
local function active(self, vm_name, arg)
    if vm_name == nil then
        error("VMManager.active vm_name is nil")
    end
    if type(vm_name) == "string" then --单个
        load(self, vm_name, arg)
    else
        for k, v in ipairs(vm_name) do --多个
            load(self, v, arg)
        end
    end
end

---预加载vm资源
---当vm为string单个
---@overload fun(vm_name:string)
---@param vm_name string
local function pre_load(self, vm_name)
    local curr_vm = VMGenerate[vm_name] --获取vm实例
    local views = curr_vm.views
    if views then
        local find_path, res_name, scene_name, res_path
        for k, v in ipairs(views) do
            find_path, res_name, scene_name, res_path = v.find_path, v.asset_name, v.scene_name, v.res_path
            if scene_name ~= nil and res_path ~= nil then
                load_scene(res_path, scene_name, v, on_pre_scene_comp, true)
            elseif res_name ~= nil and res_path ~= nil then
                load_resource(res_path, res_name, v, on_pre_load_comp, true)
            end
            -- Logger.Log("pre_load", vm_name, k, v)
        end
    end
end

local vm_manager = {}
vm_manager.pre_load = pre_load
vm_manager.load = load
vm_manager.active = active
vm_manager.destory_view = destory_view
vm_manager.deactive_view = deactive_view

---vm的激活与失活管理
---@class VMManager
---@field active function
---@field pre_load function
---@field load function
---@field destory_view function
---@field deactive_view function
VMManager = vm_manager
