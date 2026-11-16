import AppKit

// Hood hats and onesie costumes in the spirit of the reference sheets.
// Character-like items are generic look-alikes: no letters, logos or names.


// MARK: - Costumes (recolour the body, then add details)

struct Costume {
    let name: String
    let body: UInt32
    var belly: UInt32? = nil
    var paws: UInt32? = nil
    var legs: UInt32? = nil
    var tail = false            // the costume covers the tail too
    var stripes: UInt32? = nil
    var spots: [UInt32]? = nil  // seeded dots (leopard, polka dots)
}

let costumes: [String: Costume] = [
    "c_chick":   Costume(name: "Chick", body: 0xF6D44A, paws: 0xF0A12F),
    "c_shark":   Costume(name: "Shark", body: 0x5D7C9C, belly: 0xF2EEE6, paws: 0xF2EEE6, tail: true),
    "c_vampire": Costume(name: "Vampire", body: 0x2A2730, paws: 0x1C1A20),
    "c_dino":    Costume(name: "Dinosaur", body: 0x79A85A, belly: 0xF1E3A0, paws: 0xF1E3A0, tail: true),
    "c_bunny":   Costume(name: "Bunny", body: 0xF7F4F0, paws: 0xFFFFFF, tail: true),
    "c_panda":   Costume(name: "Panda", body: 0xF4F2EE, legs: 0x2A2A2E),
    "c_plumber": Costume(name: "Overalls", body: 0xD9302C, paws: 0xF4F2EE, legs: 0x2F5DAE),
    "c_kitty":   Costume(name: "Bow jumpsuit", body: 0xF7F5F2, paws: 0xF7F5F2, legs: 0xD7262F),
    "c_bee":     Costume(name: "Bee", body: 0xF4C430, stripes: 0x4A3423),
    "c_wizard":  Costume(name: "Wizard", body: 0x2C2F55, legs: 0x2C2F55),
    "c_frog":    Costume(name: "Froggy", body: 0x79A85A, belly: 0xF1EBC4, paws: 0x79A85A),
    "c_cowboy":  Costume(name: "Cowboy", body: 0x8B5A2B, belly: 0xF1E7D2, legs: 0xF4F2EE),
    "c_penguin": Costume(name: "Penguin", body: 0x2D3756, belly: 0xF4F2EE, paws: 0xF4F2EE),
    "c_pinkdino": Costume(name: "Pink dino", body: 0xF2A9C4, belly: 0xFBE3EC, paws: 0xFBE3EC, tail: true),
    "c_bear":    Costume(name: "Teddy bear", body: 0xA7703F, belly: 0xE8C9A0, paws: 0x7B4F2A),
    "c_ghost":   Costume(name: "Ghost", body: 0xF6F4EE, tail: true),
    "c_banana":  Costume(name: "Banana", body: 0xF6D84B, paws: 0x6B4A2B),
    "c_merc":    Costume(name: "Mercenary", body: 0xC62828, legs: 0x2A2A2E),
    "c_spider":  Costume(name: "Spider", body: 0xD7262F, paws: 0xD7262F, legs: 0x1E4FA3),
    "c_royal":   Costume(name: "Royal robe", body: 0xB71C1C, paws: 0xF4F2EE),
    "c_party":   Costume(name: "Party", body: 0xF48FB1, paws: 0xFFFFFF, spots: [0xFFEB3B, 0x4FC3F7, 0x81C784]),
    "c_trickster": Costume(name: "Trickster", body: 0x2E7D32, belly: 0xE3B23C, legs: 0x1B1B1F),
    "c_jester":  Costume(name: "Jester", body: 0x2E2A33, belly: 0xF2EEE8, paws: 0xF4A7C0),
    "c_monster": Costume(name: "Monster", body: 0x9B7FD1, belly: 0xD9CCF2, paws: 0x7E62B8, tail: true),
    "c_unicorn": Costume(name: "Unicorn", body: 0xF7F3EE, paws: 0xF2C230, tail: true),
]
let costumeOrder = ["c_chick", "c_shark", "c_vampire", "c_dino", "c_bunny", "c_panda", "c_plumber", "c_kitty",
                    "c_bee", "c_wizard", "c_frog", "c_cowboy", "c_penguin", "c_pinkdino",
                    "c_bear", "c_ghost", "c_banana", "c_merc", "c_spider", "c_royal", "c_party", "c_trickster",
                    "c_jester", "c_monster", "c_unicorn"]

let hoodHats: [(id: String, name: String)] = [
    ("chick", "Chick"), ("jester", "Black jester"), ("banana", "Banana"), ("dino", "Dinosaur"),
    ("panda", "Panda"), ("bunny", "Bunny"), ("cap", "Red cap"), ("bee", "Bee"), ("cowboy", "Cowboy"),
    ("bear", "Teddy bear"), ("penguin", "Penguin"), ("merc", "Mercenary mask"), ("witch", "Witch"),
    ("monster", "Monster"), ("ghost", "Ghost"), ("unicorn", "Unicorn"), ("pinkdino", "Pink dino"),
    ("vampire", "Vampire"), ("santa", "Santa"), ("tophat", "Top hat"), ("starhelm", "Star helmet"),
    ("ironhelm", "Iron helmet"),
]

func hatHidesEars(_ id: String) -> Bool {
    !["none", "crown", "party", "bow", "spider", "merc", "tophat"].contains(id)
}
