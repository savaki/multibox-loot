local _, ns = ...

local Items = {}
ns.Items = Items

local TRADESKILL_CLASS = 7
local QUEST_CLASS = 12

-- Tradeskill subclass → category, used only when an item isn't in the ID tables.
-- Many Classic items carry the generic subclass 0 ("Trade Goods"), which stays unclassified.
local BY_SUBCLASS = {
  [1] = "EngineeringParts", -- Parts
  [3] = "EngineeringParts", -- Devices
  [4] = "Gem",              -- Jewelcrafting
  [5] = "Cloth",
  [6] = "Leather",
  [7] = "Metal",            -- Metal & Stone
  [8] = "Cooking",
  [9] = "Herb",
  [12] = "Enchanting",
}

local BY_ID = {}

local function add(category, ids)
  for _, id in ipairs(ids) do
    BY_ID[id] = category
  end
end

add("Cloth", {
  2589,  -- Linen Cloth
  2592,  -- Wool Cloth
  4306,  -- Silk Cloth
  4338,  -- Mageweave Cloth
  14047, -- Runecloth
  14256, -- Felcloth
})

add("Leather", {
  2934,  -- Ruined Leather Scraps
  2318,  -- Light Leather
  2319,  -- Medium Leather
  4234,  -- Heavy Leather
  4304,  -- Thick Leather
  8170,  -- Rugged Leather
  783,   -- Light Hide
  4232,  -- Medium Hide
  4235,  -- Heavy Hide
  8169,  -- Thick Hide
  8171,  -- Rugged Hide
  8154,  -- Scorpid Scale
  7286,  -- Black Whelp Scale
  15417, -- Devilsaur Leather
  17012, -- Core Leather
  -- WoW: Forever
  249427, -- Pristine Leather
  249428, -- Pristine Hide
  249429, -- Pristine Scale
  248824, -- Fel Hide
  248825, -- Fel Leather
})

add("Herb", {
  2447,  -- Peacebloom
  765,   -- Silverleaf
  2449,  -- Earthroot
  785,   -- Mageroyal
  2450,  -- Briarthorn
  2452,  -- Swiftthistle
  2453,  -- Bruiseweed
  3820,  -- Stranglekelp
  3355,  -- Wild Steelbloom
  3369,  -- Grave Moss
  3356,  -- Kingsblood
  3357,  -- Liferoot
  3818,  -- Fadeleaf
  3821,  -- Goldthorn
  3358,  -- Khadgar's Whisker
  3819,  -- Wintersbite
  4625,  -- Firebloom
  8831,  -- Purple Lotus
  8836,  -- Arthas' Tears
  8838,  -- Sungrass
  8839,  -- Blindweed
  8845,  -- Ghost Mushroom
  8846,  -- Gromsblood
  13464, -- Golden Sansam
  13463, -- Dreamfoil
  13465, -- Mountain Silversage
  13466, -- Plaguebloom
  13467, -- Icecap
  13468, -- Black Lotus
  -- WoW: Forever
  249274, -- Stranglevine
  249424, -- Rosecap
  248821, -- Demonsage
  248822, -- Death Lotus
  248823, -- Marefoil
})

-- WoW: Forever herb seeds
add("HerbSeed", {
  268415, -- Commonplace Herb Seeds
  268416, -- Uncommon Herb Seeds
  268417, -- Unusual Herb Seeds
  268418, -- Scarce Herb Seeds
})

add("Metal", {
  2770,  -- Copper Ore
  2771,  -- Tin Ore
  2772,  -- Iron Ore
  2775,  -- Silver Ore
  2776,  -- Gold Ore
  3858,  -- Mithril Ore
  7911,  -- Truesilver Ore
  10620, -- Thorium Ore
  11370, -- Dark Iron Ore
  2840,  -- Copper Bar
  3576,  -- Tin Bar
  2841,  -- Bronze Bar
  3575,  -- Iron Bar
  3859,  -- Steel Bar
  2842,  -- Silver Bar
  3577,  -- Gold Bar
  3860,  -- Mithril Bar
  6037,  -- Truesilver Bar
  12359, -- Thorium Bar
  2835,  -- Rough Stone
  2836,  -- Coarse Stone
  2838,  -- Heavy Stone
  7912,  -- Solid Stone
  12365, -- Dense Stone
  -- WoW: Forever
  248815, -- Heavy Thorium Ore
  251291, -- Heavy Thorium Bar
  249726, -- Azerothium Bar
  251290, -- Legionite Bar
  249426, -- Pitchblende
  249425, -- Bauxite
  248820, -- Torbernite
})

add("Enchanting", {
  10940, -- Strange Dust
  11083, -- Soul Dust
  11137, -- Vision Dust
  11176, -- Dream Dust
  16204, -- Illusion Dust
  10938, -- Lesser Magic Essence
  10939, -- Greater Magic Essence
  10998, -- Lesser Astral Essence
  11082, -- Greater Astral Essence
  11134, -- Lesser Mystic Essence
  11135, -- Greater Mystic Essence
  11174, -- Lesser Nether Essence
  11175, -- Greater Nether Essence
  16202, -- Lesser Eternal Essence
  16203, -- Greater Eternal Essence
  10978, -- Small Glimmering Shard
  11084, -- Large Glimmering Shard
  11138, -- Small Glowing Shard
  11139, -- Large Glowing Shard
  11177, -- Small Radiant Shard
  11178, -- Large Radiant Shard
  14343, -- Small Brilliant Shard
  14344, -- Large Brilliant Shard
  20725, -- Nexus Crystal
  -- WoW: Forever
  247786, -- Mote of Magic
  274030, -- Malleable Essence of Nature
  248819, -- Fel Crystal
})

add("Cooking", {
  769,   -- Chunk of Boar Meat
  723,   -- Goretusk Liver
  729,   -- Stringy Vulture Meat
  1015,  -- Lean Wolf Flank
  2672,  -- Stringy Wolf Meat
  2673,  -- Coyote Meat
  2674,  -- Crawler Meat
  2675,  -- Crawler Claw
  3173,  -- Bear Meat
  3685,  -- Raptor Egg
  3712,  -- Turtle Meat
  3730,  -- Big Bear Meat
  3731,  -- Lion Meat
  5503,  -- Clam Meat
  5504,  -- Tangy Clam Meat
  6289,  -- Raw Longjaw Mud Snapper
  6291,  -- Raw Brilliant Smallfish
  6889,  -- Small Egg
  12037, -- Mystery Meat
  12184, -- Raptor Flesh
  12203, -- Red Wolf Meat
  12205, -- White Spider Meat
  12207, -- Giant Egg
  12208, -- Tender Wolf Meat
  730,   -- Murloc Eye
  731,   -- Goretusk Snout
  1080,  -- Tough Condor Meat
  1081,  -- Crisp Spider Meat
  1468,  -- Murloc Fin
  2251,  -- Gooey Spider Leg
  2296,  -- Great Goretusk Snout
  2677,  -- Boar Ribs
  2886,  -- Crag Boar Rib
  2924,  -- Crocolisk Meat
  3172,  -- Boar Intestines
  3174,  -- Spider Ichor
  3404,  -- Buzzard Wing
  3667,  -- Tender Crocolisk Meat
  4655,  -- Giant Clam Meat
  5051,  -- Dig Rat
  5465,  -- Small Spider Leg
  5467,  -- Kodo Meat
  5468,  -- Soft Frenzy Flesh
  5469,  -- Strider Meat
  5470,  -- Thunder Lizard Tail
  5471,  -- Stag Meat
  7974,  -- Zesty Clam Meat
  12202, -- Tiger Meat
  12204, -- Heavy Kodo Meat
  12206, -- Tender Crab Meat
  12223, -- Meaty Bat Wing
  20424, -- Sandworm Meat
  -- Fish
  4603,  -- Raw Spotted Yellowtail
  6303,  -- Raw Slitherskin Mackerel
  6308,  -- Raw Bristle Whisker Catfish
  6317,  -- Raw Loch Frenzy
  6361,  -- Raw Rainbow Fin Albacore
  6362,  -- Raw Rockscale Cod
  6522,  -- Deviate Fish
  8365,  -- Raw Mithril Head Trout
  13754, -- Raw Glossy Mightfish
  13758, -- Raw Redgill
  13759, -- Raw Nightfin Snapper
  13760, -- Raw Sunscale Salmon
  13888, -- Darkclaw Lobster
  13889, -- Raw Whitescale Salmon
  13893, -- Large Raw Mightfish
  21071, -- Raw Sagefish
  21153, -- Raw Greater Sagefish
})

add("Gem", {
  774,   -- Malachite
  818,   -- Tigerseye
  1210,  -- Shadowgem
  1206,  -- Moss Agate
  1705,  -- Lesser Moonstone
  1529,  -- Jade
  3864,  -- Citrine
  7909,  -- Aquamarine
  7910,  -- Star Ruby
  12361, -- Blue Sapphire
  12364, -- Huge Emerald
  12799, -- Large Opal
  12800, -- Azerothian Diamond
})

-- Mostly an Alchemy transmute reagent, so it doesn't follow the gem chain.
add("ArcaneCrystal", {
  12363, -- Arcane Crystal
})

-- Returns a category name, or nil when the item isn't a known profession material.
function Items.Classify(itemID, classID, subClassID)
  local category = BY_ID[itemID]
  if category then return category end
  if classID == TRADESKILL_CLASS then return BY_SUBCLASS[subClassID] end
  return nil
end

-- isQuestItem/questID come from GetLootSlotInfo, classID from GetItemInfoInstant.
function Items.IsQuest(isQuestItem, questID, classID)
  if isQuestItem then return true end
  if questID and questID ~= 0 then return true end
  return classID == QUEST_CLASS
end
