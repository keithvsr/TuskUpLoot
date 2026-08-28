-- Per-raid trash loot catalog (item IDs that drop from trash, not bosses).
local _, TUL = ...

---@type TULData
TUL.Data = TUL.Data or {}
local Data = TUL.Data

Data.InstanceTrashLoot = {
  -- Karazhan
  [532] = {
    30641, -- Boots of Elusion
    30642, -- Drape of the Righteous
    30643, -- Belt of the Tracker
    30644, -- Grips of Deftness
    30666, -- Ritssyn's Lost Pendant
    30667, -- Ring of Unrelenting Storms
    30668, -- Grasp of the Dead
    30673, -- Inferno Waist Cord
    30674, -- Zierhut's Lost Treads
  },
  -- Hyjal Summit
  [534] = {
    32589, -- Hellfire-Encased Pendant
    32590, -- Nethervoid Cloak
    32591, -- Choker of Serrated Blades
    32592, -- Chestguard of Relentless Storms
    32609, -- Boots of the Divine Light
    32945, -- Fist of Molten Fury
    32946, -- Claw of Molten Fury
    34009, -- Hammer of Judgement
    34010, -- Pepe's Shroud of Pacification
  },
  -- Serpentshrine Cavern
  [548] = {
    30021, -- Wildfury Greatstaff
    30022, -- Pendant of the Perilous
    30023, -- Totem of the Maelstrom
    30025, -- Serpentshrine Shuriken
    30027, -- Boots of Courage Unending
    30620, -- Spyglass of the Hidden Fleet
  },
  -- Tempest Keep
  [550] = {
    30020, -- Fire-Cord of the Magus
    30024, -- Mantle of the Elven Kings
    30026, -- Bands of the Celestial Archer
    30028, -- Seventh Ring of the Tirisfalen
    30029, -- Bark-Gloves of Ancient Wisdom
    30030, -- Girdle of Fallen Stars
  },
  -- Black Temple
  [564] = {
    32526, -- Band of Devastation
    32527, -- Ring of Ancient Knowledge
    32528, -- Blessed Band of Karabor
    32589, -- Hellfire-Encased Pendant
    32590, -- Nethervoid Cloak
    32591, -- Choker of Serrated Blades
    32592, -- Chestguard of Relentless Storms
    32593, -- Treads of the Den Mother
    32606, -- Girdle of the Lightbearer
    32608, -- Pillager's Gauntlets
    32609, -- Boots of the Divine Light
    32943, -- Swiftsteel Bludgeon
    34009, -- Hammer of Judgement
    34011, -- Illidari Runeshield
    34012, -- Shroud of the Final Stand
  },
}
