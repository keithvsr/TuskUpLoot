TuskUpLoot = TuskUpLoot or {}

-- Redefine item quality enum for naming clarity
---@enum TuskUpLoot.Quality
TuskUpLoot.Quality = {
    Poor = Enum.ItemQuality.Poor or 0,
    Common = Enum.ItemQuality.Common or 1,
    Uncommon = Enum.ItemQuality.Uncommon or 2,
    Rare = Enum.ItemQuality.Rare or 3,
    Epic = Enum.ItemQuality.Epic or 4,
    Legendary = Enum.ItemQuality.Legendary or 5,
    Artifact = Enum.ItemQuality.Artifact or 6,
    Heirloom = Enum.ItemQuality.Heirloom or 7,
    WoWToken = Enum.ItemQuality.WoWToken or 8,
}
