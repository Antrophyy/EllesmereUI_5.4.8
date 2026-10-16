setfenv(1, select(2, ...).env) -- 5.4.8 port: retail APIs from EllesmereUIDataBars_Compat.lua
-- Blocks\Spacer.lua
-- Spacer block factory.

local ADDON_NAME, ns = ...
local K = ns.BlockKit

local InstKey = K.InstKey

-------------------------------------------------------------------------------
--  SPACER (transparent block; the slot's optional bg tint still applies)
-------------------------------------------------------------------------------
ns.BlockFactories.spacer = function(blockCfg, slot, content, barCtx)
    local inst = { cfg = blockCfg, slot = slot, content = content, ctx = barCtx }
    inst.key = InstKey(barCtx, blockCfg)
    function inst:Refresh() end
    function inst:Enable() end
    function inst:Disable() end
    function inst:Destroy() self._dead = true end
    function inst:GetAutoLength() return 0 end
    return inst
end
