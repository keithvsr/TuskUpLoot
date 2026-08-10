-- Handles importing SR data from softres.it in order to merge in
-- non-guildy data if ever necessary

TuskUpLoot.GL = TuskUpLoot.GL or {}
local Import = {}
TuskUpLoot.GL.Import = Import

local LibDeflate = LibStub("LibDeflate")

local function decodeExportString(exportString)
    local compressed = C_EncodingUtil.DecodeBase64(exportString)
    local json = LibDeflate:DecompressZlib(compressed)
    return C_EncodingUtil.DeserializeJSON(json)
end

function Import.import(softresString)
    local data = decodeExportString(softresString)
    if not data then return {} end
    return data
end
