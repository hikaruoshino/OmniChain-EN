-- =============================================================================
-- sc_dict.lua : WS data for all 14 weapon types + PUP automaton WS + SMN blood pacts, combined skillchain matrix (v7.4.1)
-- =============================================================================

local sc_dict = {}

-- Skillchain level / element rules
sc_dict.SC_ELEMENTS = {
    ["Liquefaction"] = { level = 1, elements = {"Fire"} },
    ["Induration"] = { level = 1, elements = {"Ice"} },
    ["Detonation"] = { level = 1, elements = {"Wind"} },
    ["Scission"] = { level = 1, elements = {"Earth"} },
    ["Impaction"] = { level = 1, elements = {"Thunder"} },
    ["Reverberation"] = { level = 1, elements = {"Water"} },
    ["Transfixion"] = { level = 1, elements = {"Light"} },
    ["Compression"] = { level = 1, elements = {"Dark"} },

    ["Fusion"] = { level = 2, elements = {"Fire", "Light"} },
    ["Gravitation"] = { level = 2, elements = {"Earth", "Dark"} },
    ["Fragmentation"] = { level = 2, elements = {"Wind", "Thunder"} },
    ["Distortion"] = { level = 2, elements = {"Ice", "Water"} },

    ["Light"]   = { level = 3, elements = {"Fire", "Wind", "Thunder", "Light"} },
    ["Darkness"]   = { level = 3, elements = {"Ice", "Earth", "Water", "Dark"} },

    ["Radiance"] = { level = 4, elements = {"Fire", "Wind", "Thunder", "Light"} },
    ["Umbra"] = { level = 4, elements = {"Ice", "Earth", "Water", "Dark"} },
}

-- Skillchain matrix: [previous property/chain][closing WS property] = resulting chain
-- Source: BG-Wiki "Skillchain" https://www.bg-wiki.com/ffxi/Skillchain
-- (stacking the same property chains only for Light/Darkness. Two Level 2 properties do not chain)
-- Light->Light / Darkness->Darkness gives one more Level 3 (Light/Darkness), after which nothing can chain.
-- Radiance/Umbra (Level 4) occur only during aeonic aftermath, so they are not predicted here.
sc_dict.SC_COMBO_MAP = {
    ["Liquefaction"] = { ["Scission"] = "Scission", ["Impaction"] = "Fusion" },
    ["Induration"] = { ["Compression"] = "Compression", ["Reverberation"] = "Fragmentation", ["Impaction"] = "Impaction" },
    ["Detonation"] = { ["Scission"] = "Scission", ["Compression"] = "Gravitation" },
    ["Scission"] = { ["Liquefaction"] = "Liquefaction", ["Reverberation"] = "Reverberation", ["Detonation"] = "Detonation" },
    ["Impaction"] = { ["Liquefaction"] = "Liquefaction", ["Detonation"] = "Detonation" },
    ["Reverberation"] = { ["Induration"] = "Induration", ["Impaction"] = "Impaction" },
    ["Transfixion"] = { ["Compression"] = "Compression", ["Scission"] = "Distortion", ["Reverberation"] = "Reverberation" },
    ["Compression"] = { ["Transfixion"] = "Transfixion", ["Detonation"] = "Detonation" },

    ["Fusion"] = { ["Gravitation"] = "Gravitation", ["Fragmentation"] = "Light" },
    ["Gravitation"] = { ["Distortion"] = "Darkness", ["Fragmentation"] = "Fragmentation" },
    ["Fragmentation"] = { ["Fusion"] = "Light", ["Distortion"] = "Distortion" },
    ["Distortion"] = { ["Gravitation"] = "Darkness", ["Fusion"] = "Fusion" },

    ["Light"]   = { ["Light"] = "Light" },
    ["Darkness"]   = { ["Darkness"] = "Darkness" }
}

-- Aeonic weapon WS: using one while wielding that weapon grants aftermath and adds a Level 3 property (Light/Darkness)
-- (it also applies to the WS that triggers the aftermath. Keys are the English WS names in res; slot defaults to the main weapon)
-- Source: BG-Wiki "REMA Cheat Sheet", "Aeonic Weapon Skill"
sc_dict.AEONIC_WS = {
    ["Shijin Spiral"] = { prop = "Light", weapon = "Godhands" },
    ["Exenterator"]   = { prop = "Light", weapon = "Aeneas" },
    ["Requiescat"]    = { prop = "Darkness", weapon = "Sequence" },
    ["Resolution"]    = { prop = "Light", weapon = "Lionheart" },
    ["Ruinator"]      = { prop = "Darkness", weapon = "Tri-edge" },
    ["Upheaval"]      = { prop = "Light", weapon = "Chango" },
    ["Entropy"]       = { prop = "Darkness", weapon = "Anguta" },
    ["Stardiver"]     = { prop = "Darkness", weapon = "Trishula" },
    ["Blade: Shun"]   = { prop = "Light", weapon = "Heishi Shorinken" },
    ["Tachi: Shoha"]  = { prop = "Light", weapon = "Dojikiri Yasutsuna" },
    ["Realmrazer"]    = { prop = "Light", weapon = "Tishtrya" },
    ["Shattersoul"]   = { prop = "Darkness", weapon = "Khatvanga" },
    ["Apex Arrow"]    = { prop = "Light", weapon = "Fail-Not", slot = "range" },
    ["Last Stand"]    = { prop = "Light", weapon = "Fomalhaut", slot = "range" },
}

-- Can the chain no longer be continued? (after Light->Light / Darkness->Darkness, and after Radiance/Umbra)
function sc_dict.is_terminal_chain(prev_sc, result_sc)
    if result_sc == "Radiance" or result_sc == "Umbra" then return true end
    return (result_sc == "Light" or result_sc == "Darkness") and prev_sc == result_sc
end

-- Alias map for property names that res may spell differently
sc_dict.SC_ALIAS = {
    -- In res/*.lua skillchain_a/b/c use "Darkness" for Darkness (the old spelling "Dark" is kept just in case)
    ['Light'] = 'Light', ['Darkness'] = 'Darkness', ['Dark'] = 'Darkness',
    ['Gravitation'] = 'Gravitation', ['Fragmentation'] = 'Fragmentation',
    ['Distortion'] = 'Distortion', ['Fusion'] = 'Fusion',
    ['Compression'] = 'Compression', ['Liquefaction'] = 'Liquefaction',
    ['Induration'] = 'Induration', ['Reverberation'] = 'Reverberation',
    ['Transfixion'] = 'Transfixion', ['Scission'] = 'Scission',
    ['Detonation'] = 'Detonation', ['Impaction'] = 'Impaction',
    ['Radiance'] = 'Radiance', ['Umbra'] = 'Umbra'
}

-- Usable weapon types per job (all 22 jobs)
sc_dict.JOB_WEAPONS = {
    ["WAR"] = {"Great Axe", "Axe", "Great Sword", "Sword", "Polearm", "Club", "Hand-to-Hand"},
    ["PLD"] = {"Sword", "Great Sword", "Club", "Staff"},
    ["SAM"] = {"Great Katana", "Archery", "Polearm", "Katana"},
    ["THF"] = {"Dagger", "Sword", "Archery", "Marksmanship"},
    ["DRK"] = {"Scythe", "Great Sword", "Sword", "Great Axe"},
    ["DRG"] = {"Polearm", "Dagger", "Sword"},
    ["MNK"] = {"Hand-to-Hand", "Staff"},
    ["RDM"] = {"Sword", "Dagger", "Club", "Staff"},
    ["BLU"] = {"Sword", "Dagger", "Club"},
    ["COR"] = {"Marksmanship", "Dagger", "Sword"},
    ["DNC"] = {"Dagger", "Hand-to-Hand"},
    ["RUN"] = {"Great Sword", "Sword", "Great Axe", "Axe"},
    ["RNG"] = {"Archery", "Marksmanship", "Dagger", "Sword", "Polearm"},
    ["NIN"] = {"Katana", "Dagger", "Great Katana"},
    ["BST"] = {"Axe", "Scythe", "Club"},
    ["BRD"] = {"Dagger", "Sword", "Club"},
    ["PUP"] = {"Hand-to-Hand", "Dagger"},
    ["SCH"] = {"Staff", "Club"},
    ["GEO"] = {"Club", "Staff"},
    ["WHM"] = {"Club", "Staff"},
    ["BLM"] = {"Staff", "Club", "Dagger"},
    ["SMN"] = {"Staff", "Club"},
}

-- Weapon skills and properties for all 14 weapon types (including prime WS)
sc_dict.WEAPON_WS = {
    ["Hand-to-Hand"] = {
        { en = "Maru Kala", sc = {"Detonation", "Compression", "Distortion"} },
        { en = "Victory Smite", sc = {"Light", "Fragmentation"} },
        { en = "Shijin Spiral", sc = {"Fusion", "Reverberation"} },
        { en = "Dragon Kick", sc = {"Fragmentation"} },
        { en = "Asuran Fists", sc = {"Gravitation", "Liquefaction"} },
        { en = "Stringing Pummel", sc = {"Gravitation", "Liquefaction"} },
        { en = "Raging Fists", sc = {"Impaction"} },
        { en = "Combo", sc = {"Impaction"} },
        { en = "Shoulder Tackle", sc = {"Reverberation", "Impaction"} },
        { en = "One Inch Punch", sc = {"Compression"} },
        { en = "Backhand Blow", sc = {"Detonation"} },
        { en = "Spinning Attack", sc = {"Liquefaction", "Impaction"} },
        { en = "Howling Fist", sc = {"Transfixion", "Impaction"} },
        { en = "Tornado Kick", sc = {"Induration", "Impaction", "Detonation"} },
        { en = "Final Heaven", sc = {"Light", "Fusion"} },
        { en = "Ascetic's Fury", sc = {"Fusion", "Transfixion"} },
        { en = "Final Paradise", sc = {"Light"} },
        { en = "Dragon Blow", sc = {"Distortion"} },
    },
    ["Dagger"] = {
        { en = "Ruthless Stroke", sc = {"Liquefaction", "Impaction", "Fragmentation"} },
        { en = "Rudra's Storm", sc = {"Darkness", "Distortion"} },
        { en = "Evisceration", sc = {"Gravitation", "Transfixion"} },
        { en = "Aeolian Edge", sc = {"Scission", "Detonation", "Impaction"} },
        { en = "Pyrrhic Kleos", sc = {"Distortion", "Scission"} },
        { en = "Mandalic Stab", sc = {"Fusion", "Compression"} },
        { en = "Mordant Rime", sc = {"Fragmentation", "Distortion"} },
        { en = "Mercy Stroke", sc = {"Darkness", "Gravitation"} },
        { en = "Wasp Sting", sc = {"Scission"} },
        { en = "Viper Bite", sc = {"Scission"} },
        { en = "Shadowstitch", sc = {"Reverberation"} },
        { en = "Gust Slash", sc = {"Detonation"} },
        { en = "Cyclone", sc = {"Detonation", "Impaction"} },
        { en = "Energy Steal", sc = {"None"} },
        { en = "Energy Drain", sc = {"None"} },
        { en = "Dancing Edge", sc = {"Scission", "Detonation"} },
        { en = "Shark Bite", sc = {"Fragmentation"} },
        { en = "Exenterator", sc = {"Fragmentation", "Scission"} },
    },
    ["Sword"] = {
        { en = "Imperator", sc = {"Detonation", "Compression", "Distortion"} },
        { en = "Savage Blade", sc = {"Fragmentation", "Scission"} },
        { en = "Chant du Cygne", sc = {"Light", "Distortion"} },
        { en = "Death Blossom", sc = {"Fragmentation", "Distortion"} },
        { en = "Atonement", sc = {"Fusion", "Reverberation"} },
        { en = "Requiescat", sc = {"Gravitation", "Scission"} },
        { en = "Vorpal Blade", sc = {"Scission", "Impaction"} },
        { en = "Fast Blade", sc = {"Scission"} },
        { en = "Burning Blade", sc = {"Liquefaction"} },
        { en = "Red Lotus Blade", sc = {"Liquefaction", "Detonation"} },
        { en = "Flat Blade", sc = {"Impaction"} },
        { en = "Shining Blade", sc = {"Scission"} },
        { en = "Seraph Blade", sc = {"Scission"} },
        { en = "Circle Blade", sc = {"Reverberation", "Impaction"} },
        { en = "Spirits Within", sc = {"None"} },
        { en = "Swift Blade", sc = {"Gravitation"} },
        { en = "Sanguine Blade", sc = {"None"} },
        { en = "Knights of Round", sc = {"Light", "Fusion"} },
        { en = "Expiacion", sc = {"Distortion", "Scission"} },
        { en = "Knights of Rotund", sc = {"Light"} },
        { en = "Uriel Blade", sc = {"Light", "Fragmentation"} },
        { en = "Glory Slash", sc = {"Light", "Fusion"} },
        { en = "Fast Blade II", sc = {"Fusion"} },
    },
    ["Great Sword"] = {
        { en = "Fimbulvetr", sc = {"Detonation", "Compression", "Distortion"} },
        { en = "Dimidiation", sc = {"Light", "Fragmentation"} },
        { en = "Torcleaver", sc = {"Light", "Distortion"} },
        { en = "Resolution", sc = {"Fragmentation", "Scission"} },
        { en = "Hard Slash", sc = {"Scission"} },
        { en = "Power Slash", sc = {"Transfixion"} },
        { en = "Frostbite", sc = {"Induration"} },
        { en = "Freezebite", sc = {"Induration", "Detonation"} },
        { en = "Shockwave", sc = {"Reverberation"} },
        { en = "Spinning Slash", sc = {"Fragmentation"} },
        { en = "Ground Strike", sc = {"Fragmentation", "Distortion"} },
        { en = "Scourge", sc = {"Light", "Fusion"} },
        { en = "Crescent Moon", sc = {"Scission"} },
        { en = "Sickle Moon", sc = {"Scission", "Impaction"} },
        { en = "Herculean Slash", sc = {"Induration", "Detonation", "Impaction"} },
    },
    ["Axe"] = {
        { en = "Blitz", sc = {"Liquefaction", "Impaction", "Fragmentation"} },
        { en = "Avalanche Axe", sc = {"Scission", "Impaction"} },
        { en = "Rampage", sc = {"Scission"} },
        { en = "Calamity", sc = {"Scission", "Impaction"} },
        { en = "Mistral Axe", sc = {"Fusion"} },
        { en = "Decimation", sc = {"Fusion", "Reverberation"} },
        { en = "Ruinator", sc = {"Distortion", "Detonation"} },
        { en = "Onslaught", sc = {"Darkness", "Gravitation"} },
        { en = "Cloudsplitter", sc = {"Darkness", "Fragmentation"} },
        { en = "Primal Rend", sc = {"Gravitation", "Reverberation"} },
        { en = "Raging Axe", sc = {"Detonation", "Impaction"} },
        { en = "Smash Axe", sc = {"Induration", "Reverberation"} },
        { en = "Gale Axe", sc = {"Detonation"} },
        { en = "Spinning Axe", sc = {"Liquefaction", "Scission", "Impaction"} },
        { en = "Bora Axe", sc = {"Detonation", "Scission"} },
    },
    ["Great Axe"] = {
        { en = "Disaster", sc = {"Transfixion", "Scission", "Gravitation"} },
        { en = "Upheaval", sc = {"Fusion", "Compression"} },
        { en = "Ukko's Fury", sc = {"Light", "Fragmentation"} },
        { en = "King's Justice", sc = {"Fragmentation", "Scission"} },
        { en = "Fell Cleave", sc = {"Scission", "Detonation", "Impaction"} },
        { en = "Shield Break", sc = {"Impaction"} },
        { en = "Iron Tempest", sc = {"Scission"} },
        { en = "Full Break", sc = {"Distortion"} },
        { en = "Raging Rush", sc = {"Induration", "Reverberation"} },
        { en = "Steel Cyclone", sc = {"Distortion", "Detonation"} },
        { en = "Metatron Torment", sc = {"Light", "Fusion"} },
        { en = "Sturmwind", sc = {"Reverberation", "Scission"} },
        { en = "Armor Break", sc = {"Impaction"} },
        { en = "Keen Edge", sc = {"Compression"} },
        { en = "Weapon Break", sc = {"Impaction"} },
    },
    ["Scythe"] = {
        { en = "Origin", sc = {"Induration", "Reverberation", "Fusion"} },
        { en = "Cross Reaper", sc = {"Distortion"} },
        { en = "Entropy", sc = {"Gravitation", "Reverberation"} },
        { en = "Catastrophe", sc = {"Darkness", "Gravitation"} },
        { en = "Quietus", sc = {"Darkness", "Distortion"} },
        { en = "Slice", sc = {"Scission"} },
        { en = "Dark Harvest", sc = {"Reverberation"} },
        { en = "Nightmare Scythe", sc = {"Compression", "Scission"} },
        { en = "Guillotine", sc = {"Induration"} },
        { en = "Spiral Hell", sc = {"Distortion", "Scission"} },
        { en = "Insurgency", sc = {"Fusion", "Compression"} },
        { en = "Infernal Scythe", sc = {"Compression", "Reverberation"} },
        { en = "Shadow of Death", sc = {"Induration", "Reverberation"} },
        { en = "Spinning Scythe", sc = {"Scission", "Reverberation"} },
        { en = "Vorpal Scythe", sc = {"Transfixion", "Scission"} },
    },
    ["Polearm"] = {
        { en = "Diarmuid", sc = {"Transfixion", "Scission", "Gravitation"} },
        { en = "Impulse Drive", sc = {"Gravitation", "Induration"} },
        { en = "Camlann's Torment", sc = {"Light", "Fragmentation"} },
        { en = "Stardiver", sc = {"Gravitation", "Transfixion"} },
        { en = "Drakesbane", sc = {"Fusion", "Transfixion"} },
        { en = "Geirskogul", sc = {"Light", "Distortion"} },
        { en = "Double Thrust", sc = {"Transfixion"} },
        { en = "Thunder Thrust", sc = {"Transfixion", "Impaction"} },
        { en = "Raiden Thrust", sc = {"Transfixion", "Impaction"} },
        { en = "Leg Sweep", sc = {"Impaction"} },
        { en = "Penta Thrust", sc = {"Compression"} },
        { en = "Vorpal Thrust", sc = {"Reverberation", "Transfixion"} },
        { en = "Wheeling Thrust", sc = {"Fusion"} },
        { en = "Sonic Thrust", sc = {"Transfixion", "Scission"} },
        { en = "Skewer", sc = {"Transfixion", "Impaction"} },
    },
    ["Katana"] = {
        { en = "Zesho Meppo", sc = {"Induration", "Reverberation", "Fusion"} },
        { en = "Blade: Rin", sc = {"Transfixion"} },
        { en = "Blade: Retsu", sc = {"Scission"} },
        { en = "Blade: Teki", sc = {"Reverberation"} },
        { en = "Blade: To", sc = {"Induration", "Detonation"} },
        { en = "Blade: Chi", sc = {"Transfixion", "Impaction"} },
        { en = "Blade: Ei", sc = {"Compression"} },
        { en = "Blade: Jin", sc = {"Detonation", "Impaction"} },
        { en = "Blade: Ten", sc = {"Gravitation"} },
        { en = "Blade: Ku", sc = {"Gravitation", "Transfixion"} },
        { en = "Blade: Metsu", sc = {"Darkness", "Fragmentation"} },
        { en = "Blade: Kamu", sc = {"Fragmentation", "Compression"} },
        { en = "Blade: Hi", sc = {"Darkness", "Gravitation"} },
        { en = "Blade: Shun", sc = {"Fusion", "Impaction"} },
        { en = "Blade: Yu", sc = {"Reverberation", "Scission"} },
    },
    ["Great Katana"] = {
        { en = "Tachi: Mumei", sc = {"Detonation", "Compression", "Distortion"} },
        { en = "Tachi: Enpi", sc = {"Transfixion", "Scission"} },
        { en = "Tachi: Hobaku", sc = {"Induration"} },
        { en = "Tachi: Goten", sc = {"Transfixion", "Impaction"} },
        { en = "Tachi: Kagero", sc = {"Liquefaction"} },
        { en = "Tachi: Jinpu", sc = {"Scission", "Detonation"} },
        { en = "Tachi: Koki", sc = {"Reverberation", "Impaction"} },
        { en = "Tachi: Yukikaze", sc = {"Induration", "Detonation"} },
        { en = "Tachi: Gekko", sc = {"Distortion", "Reverberation"} },
        { en = "Tachi: Kasha", sc = {"Fusion", "Compression"} },
        { en = "Tachi: Kaiten", sc = {"Light", "Fragmentation"} },
        { en = "Tachi: Rana", sc = {"Gravitation", "Induration"} },
        { en = "Tachi: Ageha", sc = {"Compression", "Scission"} },
        { en = "Tachi: Shoha", sc = {"Fragmentation", "Compression"} },
        { en = "Tachi: Fudo", sc = {"Light", "Distortion"} },
        { en = "Tachi: Suikawari", sc = {"Fusion"} },
    },
    ["Club"] = {
        { en = "Dagda", sc = {"Transfixion", "Scission", "Gravitation"} },
        { en = "Shining Strike", sc = {"Impaction"} },
        { en = "Seraph Strike", sc = {"Impaction"} },
        { en = "Brainshaker", sc = {"Reverberation"} },
        { en = "Judgment", sc = {"Impaction"} },
        { en = "Hexa Strike", sc = {"Fusion"} },
        { en = "Black Halo", sc = {"Fragmentation", "Compression"} },
        { en = "Randgrith", sc = {"Light", "Fragmentation"} },
        { en = "Realmrazer", sc = {"Fusion", "Impaction"} },
        { en = "Exudation", sc = {"Darkness", "Fragmentation"} },
        { en = "Flash Nova", sc = {"Induration", "Reverberation"} },
        { en = "Skullbreaker", sc = {"Induration", "Reverberation"} },
        { en = "True Strike", sc = {"Detonation", "Impaction"} },
    },
    ["Staff"] = {
        { en = "Oshala", sc = {"Induration", "Reverberation", "Fusion"} },
        { en = "Heavy Swing", sc = {"Impaction"} },
        { en = "Rock Crusher", sc = {"Impaction"} },
        { en = "Earth Crusher", sc = {"Impaction", "Detonation"} },
        { en = "Starburst", sc = {"Compression", "Reverberation"} },
        { en = "Sunburst", sc = {"Compression", "Reverberation"} },
        { en = "Retribution", sc = {"Gravitation", "Reverberation"} },
        { en = "Vidohunir", sc = {"Fragmentation", "Distortion"} },
        { en = "Garland of Bliss", sc = {"Fusion", "Reverberation"} },
        { en = "Omniscience", sc = {"Gravitation", "Transfixion"} },
        { en = "Myrkr", sc = {"None"} },
        { en = "Cataclysm", sc = {"Compression", "Reverberation"} },
        { en = "Shattersoul", sc = {"Gravitation", "Induration"} },
        { en = "Shell Crusher", sc = {"Detonation"} },
        { en = "Full Swing", sc = {"Liquefaction", "Impaction"} },
        { en = "Gate of Tartarus", sc = {"Darkness", "Distortion"} },
    },
    ["Archery"] = {
        { en = "Sarv", sc = {"Transfixion", "Scission", "Gravitation"} },
        { en = "Flaming Arrow", sc = {"Liquefaction", "Transfixion"} },
        { en = "Piercing Arrow", sc = {"Reverberation", "Transfixion"} },
        { en = "Dulling Arrow", sc = {"Liquefaction", "Transfixion"} },
        { en = "Blast Arrow", sc = {"Induration", "Transfixion"} },
        { en = "Arching Arrow", sc = {"Fusion"} },
        { en = "Empyreal Arrow", sc = {"Fusion", "Transfixion"} },
        { en = "Namas Arrow", sc = {"Light", "Distortion"} },
        { en = "Refulgent Arrow", sc = {"Reverberation", "Transfixion"} },
        { en = "Jishnu's Radiance", sc = {"Light", "Fusion"} },
        { en = "Apex Arrow", sc = {"Fragmentation", "Transfixion"} },
        { en = "Sidewinder", sc = {"Reverberation", "Transfixion", "Detonation"} },
    },
    ["Marksmanship"] = {
        { en = "Terminus", sc = {"Induration", "Reverberation", "Fusion"} },
        { en = "Hot Shot", sc = {"Liquefaction", "Transfixion"} },
        { en = "Split Shot", sc = {"Reverberation", "Transfixion"} },
        { en = "Sniper Shot", sc = {"Liquefaction", "Transfixion"} },
        { en = "Slug Shot", sc = {"Reverberation", "Transfixion", "Detonation"} },
        { en = "Detonator", sc = {"Fusion", "Transfixion"} },
        { en = "Coronach", sc = {"Darkness", "Fragmentation"} },
        { en = "Trueflight", sc = {"Fragmentation", "Scission"} },
        { en = "Leaden Salute", sc = {"Gravitation", "Transfixion"} },
        { en = "Wildfire", sc = {"Darkness", "Gravitation"} },
        { en = "Last Stand", sc = {"Fusion", "Reverberation"} },
        { en = "Blast Shot", sc = {"Induration", "Transfixion"} },
        { en = "Heavy Shot", sc = {"Fusion"} },
        { en = "Numbing Shot", sc = {"Induration", "Detonation", "Impaction"} },
    }
}

-- PUP automaton WS property table
sc_dict.PUP_WS_DATABASE = {
    ["String Shredder"] = {"Distortion", "Scission"},
    ["Bone Crusher"]     = {"Fragmentation"},
    ["Cannibal Blade"]       = {"Compression", "Reverberation"},
    ["Chimera Ripper"]           = {"Induration", "Detonation"},
    ["String Clipper"]   = {"Scission", "Impaction"},
    ["Magic Mortar"]       = {"Fusion"},
    ["Slapstick"]     = {"Reverberation", "Impaction"},
    ["Knockout"]           = {"Scission", "Detonation"},
    ["Armor Shatterer"]   = {"Fusion", "Impaction"},
    ["Armor Piercer"]     = {"Gravitation"},
    ["Daze"]                 = {"Transfixion", "Impaction"},
    ["Arcuballista"]         = {"Liquefaction", "Transfixion"}
}

-- SMN blood pact property table
sc_dict.SMN_BP_DATABASE = {
    ["Volt Strike"]     = {"Fragmentation", "Scission"}, ["Chaotic Strike"]   = {"Fragmentation", "Transfixion"},
    ["Shock Strike"]   = {"Impaction"},         ["Flaming Crush"] = {"Fusion", "Reverberation"},
    ["Burning Strike"] = {"Impaction"},         ["Punch"]             = {"Liquefaction"},
    ["Predator Claws"]     = {"Fragmentation", "Scission"}, ["Claw"]             = {"Detonation"},
    ["Rush"]             = {"Distortion", "Scission"}, ["Double Slap"]     = {"Scission"},
    ["Axe Kick"]         = {"Induration"},         ["Spinning Dive"]   = {"Distortion", "Detonation"},
    ["Tail Whip"]       = {"Detonation"},         ["Barracuda Dive"]   = {"Reverberation"},
    ["Mountain Buster"]   = {"Gravitation", "Induration"}, ["Crag Throw"]     = {"Gravitation", "Scission"},
    ["Megalith Throw"]       = {"Induration"},         ["Rock Buster"]     = {"Reverberation"},
    ["Rock Throw"]         = {"Scission"},         ["Eclipse Bite"]   = {"Gravitation", "Scission"},
    ["Crescent Fang"]   = {"Transfixion"},         ["Moonlit Charge"] = {"Compression"},
    ["Blindside"]     = {"Gravitation", "Transfixion"}, ["Camisado"]         = {"Compression"},
    ["Hysteric Assault"] = {"Fragmentation", "Transfixion"}, ["Roundhouse"]     = {"Detonation"},
    ["Welt"]             = {"Scission"},         ["Regal Gash"]   = {"Distortion", "Detonation"},
    ["Regal Scratch"]   = {"Scission"},         ["Poison Nails"]     = {"Transfixion"},
    ["Double Punch"]         = {"Compression"}
}

-- [Universal WS lookup] one place to search every weapon type, pet skill and resource definition
function sc_dict.find_ws_info(ws_name, weapon_hint)
    if not ws_name or ws_name == "" then return nil end

    -- 1. Search the specified weapon type first
    if weapon_hint and sc_dict.WEAPON_WS[weapon_hint] then
        for _, info in ipairs(sc_dict.WEAPON_WS[weapon_hint]) do
            if info.en == ws_name then
                return info
            end
        end
    end

    -- 2. Search across all weapon types
    for category, ws_list in pairs(sc_dict.WEAPON_WS) do
        for _, info in ipairs(ws_list) do
            if info.en == ws_name then
                return info
            end
        end
    end

    -- 3. Search the PUP / SMN databases
    if sc_dict.PUP_WS_DATABASE[ws_name] then
        return { en = ws_name, sc = sc_dict.PUP_WS_DATABASE[ws_name] }
    end
    if sc_dict.SMN_BP_DATABASE[ws_name] then
        return { en = ws_name, sc = sc_dict.SMN_BP_DATABASE[ws_name] }
    end

    -- 4. Not found: default assumed definition
    return { en = ws_name, sc = {"Fusion", "Gravitation", "Fragmentation", "Distortion"} }
end

-- Skillchain matcher: computes the chain that occurs when ws_info is used after prev_sc
-- prev_sc is a single property name, or an array in priority order {A1, A2, A3}.
-- Order follows the wiki: A1+B1, A1+B2, A1+B3 -> if none match, A2+B1 ... (the first match is used)
-- From the 2nd chain on, pass only the chain that occurred as A1 (the other properties of the previous WS are ignored)
function sc_dict.evaluate_ws_for_sc(ws_info, prev_sc)
    if not ws_info or not ws_info.sc or not prev_sc then return nil end

    local prev_list = type(prev_sc) == "table" and prev_sc or { prev_sc }
    for _, prev_prop in ipairs(prev_list) do
        local map = sc_dict.SC_COMBO_MAP[prev_prop]
        if map then
            for _, ws_prop in ipairs(ws_info.sc) do
                local result = map[ws_prop]
                if result then
                    return {
                        result = result,
                        prev_used = prev_prop,
                        prop_used = ws_prop,
                        level = sc_dict.SC_ELEMENTS[result] and sc_dict.SC_ELEMENTS[result].level or 1
                    }
                end
            end
        end
    end
    return nil
end

function sc_dict.get_ws_properties(ws_name)
    local info = sc_dict.find_ws_info(ws_name, nil)
    return info and info.sc or nil
end

function sc_dict.get_pet_properties(pet_ability_name)
    return sc_dict.PUP_WS_DATABASE[pet_ability_name] or sc_dict.SMN_BP_DATABASE[pet_ability_name]
end

-- -----------------------------------------------------------------------------
-- Trusts (v7.3.0)
--   Trust move properties are in res/monster_abilities.lua (0x028 category 11).
--   Compared against 111 trusts / 303 moves from the wiki; only moves missing a property in res are added here.
--   A move without chain properties is not treated as an opener
-- -----------------------------------------------------------------------------
sc_dict.TRUST_WS_EXTRA = {
    ["Eternal Vana Illusion"] = {"Fusion"},   -- Mumor II
    ["Final Eternal Heart"]     = {"Fragmentation"},   -- Mumor II
}

-- Trusts that aim for a solo skillchain (the trait text "aims for a solo skillchain when X is available")
--   key       : the trust's English name (as shown in the enemy/ally list), lowercased with non-letters removed
--   abilities : when the trust uses one of these abilities, it is considered to be about to do a solo chain
--   last_ws   : when the last move of the solo chain is known (once it appears the solo chain is over; the chain it makes is not continued)
--   max_ws    : when the number of moves is fixed (after that many the solo chain is over; the chain it makes may be continued)
sc_dict.TRUST_SOLO = {
    -- Tenzen also does solo chains (Meditate, Hagakure), but the order of moves changes each time and it lasts about 40 s, so we interject instead of waiting (author's decision 2026-10-10)
    iroha     = { name = "Iroha",         abilities = {"Meditate"},               last_ws = {"Amatsu: Gachirin"} },  -- Iroha II has the same name
    noillurie = { name = "Noillurie",         abilities = {"Sekkanoki"},           last_ws = {"Tachi: Kaiten"} },
    gilgamesh = { name = "Gilgamesh", abilities = {"Sekkanoki"} },  -- the wiki also lists Hagakure, but Hagakure alone did not start a solo chain (measured 2026-10-10)
    -- Ark GK goes Sekkanoki -> Meditate -> 1st move -> Hagakure -> 2nd move, and the solo chain ends after 2 moves (measured 2026-10-10, 3 times out of 3)
    arkgk     = { name = "Ark GK",       abilities = {"Meditate", "Hagakure", "Sekkanoki"}, max_ws = 2 },
}
sc_dict.TRUST_SOLO.aagk = sc_dict.TRUST_SOLO.arkgk

-- After these moves, your WS does not chain even if stacked (measured 2026-10-10). Start over from an opener
--   actors : trust names (same key form as TRUST_SOLO). Every move of that trust
--            Selh'teus: WS used 4-5 s afterwards did not chain 13 times out of 13
--   ws     : move names. Iroha's Gachirin: after both an opener and a chain, WS used 3-7 s later never chained
sc_dict.NO_FOLLOW = {
    actors = { selhteus = true },
    ws     = { ["Amatsu: Gachirin"] = true },
}

function sc_dict.is_no_follow(mob_name, ws_name)
    if ws_name and sc_dict.NO_FOLLOW.ws[ws_name] then return true end
    if type(mob_name) ~= "string" then return false end
    return sc_dict.NO_FOLLOW.actors[(mob_name:lower():gsub("[^a-z]", ""))] == true
end

-- Look up a solo-chain trust definition by name (nil if none)
function sc_dict.find_trust_solo(mob_name)
    if type(mob_name) ~= "string" then return nil end
    return sc_dict.TRUST_SOLO[(mob_name:lower():gsub("[^a-z]", ""))]
end

return sc_dict
