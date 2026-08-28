---@class TUL
---@field addonName string
---@field version string
---@field State table
---@field Data TULData
---@field QUALITY quality
---@field PHASES phases
local TUL;

_, TUL = ...

---@enum quality resolve quality naming differences between Classic and Retail
TUL.QUALITY = {
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

---@enum phases easy reference for gameplay phases
TUL.PHASES = {
    One = 1,
    Two = 2,
    Three = 3,
    Four = 4,
    Five = 5,
}

---@alias SourceType "npc" | "object"

---@class Item
---@field icon string
---@field id number
---@field name string
---@field source_id? number id of the npc or object that drops the item
---@field source_name? string
---@field source_type? SourceType
---@field trash_drop? boolean

---@class NPC
---@field drops number[] item ids of npc's drops
---@field id number
---@field name string
---@field zone_id number zone id to map NPC to Instance

---@class Object
---@field drops number[] item ids the object contains
---@field id number WoW object id
---@field name string

---@class Zone
---@field bosses number[] npc ids of bosses in the zone
---@field id number WoW zone id
---@field name string

---@class Instance
---@field encounter_type "Raid" literal
---@field encounters number[] encounter ids within instance
---@field id number WoW instance id
---@field name string
---@field zone_id number WoW zone id
---@field gargul_name string name Gargul uses for this instance

---@class EncounterLoot
---@field npc_id? number
---@field object_id? number
---@field type SourceType

---@class Encounter
---@field id number WoW encounter id
---@field instance_id number instance id the encounter is in
---@field loot EncounterLoot[] items that drop from encounter
---@field name string

---@class ItemRollup
---@field characterKey string
---@field name string
---@field gearSets table
---@field hasAcquired boolean
---@field markItemId number | nil

---@class ItemNeed
---@field who string
---@field characterKey string
---@field gearSets table
---@markItemId number | nil

---@class ItemHas
---@field who string
---@field gearSets table

---@class RewardGroup
---@field itemId number
---@field name string
---@field needs ItemNeed[]
---@field has ItemHas[]

---@class ItemNeedInfo
---@field needs ItemNeed[]
---@field has ItemHas[]
---@field rewardGroups RewardGroup[]
---@field hasRewardNeeds boolean | nil
---@field hasNeeds boolean

---@class TULData
---@field TRASH_DROP_BUCKET "trash"
---@field RAID_BROADCAST_EXCLUDED_ITEMS { [number]: boolean }
---@field Items { [number]: Item }
---@field NPCs { [number]: NPC }
---@field Objects { [number]: Object }
---@field Zones { [number]: Zone }
---@field Instances { [number]: Instance }
---@field InstanceTrashLoot { [number]: number[] } map instance id to trash loot ids that drop within
---@field Encounters { [number]: Encounter }
---@field DropRewardResults { [number]: number[] } mapt drop ids to the reward loot they provide
---@field getDropRewardResultIds fun(itemId: number): number[] | nil
---@field getNeedRollupItemIds fun(itemId: number): number[]
---@field getAggregatedItemRollup fun(itemId: number): ItemRollup[] | nil
---@field getTierTokenNeedsByReward fun(tokenId: number): RewardGroup[] | nil
---@field getItemNeedSummary fun(itemId: number): number, number
---@field getItemNeedInfo fun(itemId: number): ItemNeedInfo
---@field getInstanceEncounterIds fun(instanceId: number): number[]
---@field getEncounterLootIds fun(encounterId: number): number[]
---@field getEncounterLootIdsForSource fun(encounterId: number, sourceType: SourceType, sourceId: number): number[]
---@field getInstanceTrashLootIds fun(instanceId: number): number[]
---@field getItemDisplayName fun(itemId: number): string | nil
---@field isRaidBroadcastExcluded fun(itemId: number): boolean
---@field findEncounterForSource fun(instanceId: number, sourceType: SourceType, sourceId: number): number | nil
---@field resolveDropBucket fun(instanceId: number, sourceType: SourceType, sourceId: number, clearedEncounters: { [number]: boolean }): "trash" | number
---@field orderedInstanceIds fun(): number[]
---@field requestEncounterItemData fun(encounterId: number)
---@field requestInstanceItemData fun(instnaceId: number)
---@field getDropItemIds fun(): number[]
