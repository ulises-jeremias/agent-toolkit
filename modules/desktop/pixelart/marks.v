module pixelart

// Library marks: original 16×16 product/domain glyphs that give
// each catalog card a visual identity (DESIGN.md §13 class 2, "product/domain
// pixel icons"). They share the Paper Co. palette keys and the same outline
// philosophy as the environment set: one-pixel ink outline, flat fills, no
// gradients. Marks are catalog identity only — a mark never encodes runtime
// state, popularity or trust.

// LibraryMark — one glyph per catalog domain / entity kind.
pub enum LibraryMark {
	doc // generic fallback: a paper sheet with lines
	design // painter's palette
	security // shield with a sage check
	delivery // taped crate
	data // stacked database cylinders
	ops // gear
	integrations // two plugs joined
	core // brass compass star
	tooling // wrench
	quality // magnifier with a check
	architecture // temple columns
	cloud // cloud with rain
	loops // cycle ring with arrowheads
	forge // hammer over an anvil
	accessibility // person in a circle
	mcp // three linked nodes
	pack // manila folder
}

const mark_doc = Sprite{
	name: 'mark-doc'
	rows: [
		'................',
		'...kkkkkkkk.....',
		'...kPPPPPPkk....',
		'...kPPPPPPkPk...',
		'...kPPPPPPkkkk..',
		'...kPPPPPPPPPk..',
		'...kPPkkkkkPPk..',
		'...kPPPPPPPPPk..',
		'...kPPkkkkkkPk..',
		'...kPPPPPPPPPk..',
		'...kPPkkkkPPPk..',
		'...kPPPPPPPPPk..',
		'...kPPPPPPPPPk..',
		'...kkkkkkkkkkk..',
		'................',
		'................',
	]
}

const mark_design = Sprite{
	name: 'mark-design'
	rows: [
		'................',
		'.....kkkkkk.....',
		'...kkmmmmmmkk...',
		'..kmmrmmmmsmmk..',
		'..kmmmmmmmmmmk..',
		'.kmmBmmmmmmmfmk.',
		'.kmmmmmmkkmmmmk.',
		'.kmmmmmkppkmmmk.',
		'.kmmrmmkppkmmmk.',
		'.kmmmmmmkkmmmmk.',
		'..kmmmmmmmmmmk..',
		'..kmmmmmsmmmk...',
		'...kkmmmmmkk....',
		'.....kkkkk......',
		'................',
		'................',
	]
}

const mark_security = Sprite{
	name: 'mark-security'
	rows: [
		'................',
		'....kkkkkkkk....',
		'...kSSSSSSSSk...',
		'..kSSSSSSSSSSk..',
		'..kSSSSSSSSSSk..',
		'..kSSSSSSSSfSk..',
		'..kSSSSSSSffSk..',
		'..kSSfSSSffSSk..',
		'..kSSffSffSSSk..',
		'..kSSSfffSSSSk..',
		'...kSSSfSSSSk...',
		'...kSSSSSSSSk...',
		'....kSSSSSSk....',
		'.....kSSSSk.....',
		'......kkkk......',
		'................',
	]
}

const mark_delivery = Sprite{
	name: 'mark-delivery'
	rows: [
		'................',
		'................',
		'..kkkkkkkkkkkk..',
		'.kmmmmmBBmmmmmk.',
		'.kmmmmmBBmmmmmk.',
		'.kkkkkkkkkkkkkk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'.kMMMMMBBMMMMMk.',
		'..kkkkkkkkkkkk..',
		'................',
		'................',
	]
}

const mark_data = Sprite{
	name: 'mark-data'
	rows: [
		'................',
		'....kkkkkkkk....',
		'..kkcccccccckk..',
		'.kcccccccccccck.',
		'.kCCCCCCCCCCCCk.',
		'.kkkkkkkkkkkkkk.',
		'.kcccccccccccck.',
		'.kcccccccccccck.',
		'.kCCCCCCCCCCCCk.',
		'.kkkkkkkkkkkkkk.',
		'.kcccccccccccck.',
		'.kcccccccccccck.',
		'.kCCCCCCCCCCCCk.',
		'..kkkkkkkkkkkk..',
		'................',
		'................',
	]
}

const mark_ops = Sprite{
	name: 'mark-ops'
	rows: [
		'................',
		'......kkkk......',
		'...kk.kllk.kk...',
		'...klkkllkklk...',
		'....kllllllk....',
		'..kkllllllllkk..',
		'.kllllkkkkllllk.',
		'.kllllk..kllllk.',
		'.kllllk..kllllk.',
		'.kllllkkkkllllk.',
		'..kkllllllllkk..',
		'....kllllllk....',
		'...klkkllkklk...',
		'...kk.kllk.kk...',
		'......kkkk......',
		'................',
	]
}

const mark_integrations = Sprite{
	name: 'mark-integrations'
	rows: [
		'................',
		'..kkk......kkk..',
		'.kBBBk....kBBBk.',
		'.kBBBkkkkkkBBBk.',
		'..kkkkBBBBkkkk..',
		'.....kBBBBk.....',
		'......kBBk......',
		'......kBBk......',
		'.....kBBBBk.....',
		'..kkkkBBBBkkkk..',
		'.kBBBkkkkkkBBBk.',
		'.kBBBk....kBBBk.',
		'..kkk......kkk..',
		'................',
		'................',
		'................',
	]
}

const mark_core = Sprite{
	name: 'mark-core'
	rows: [
		'................',
		'.......kk.......',
		'......kBBk......',
		'......kBBk......',
		'.....kBBBBk.....',
		'..kkkkBBBBkkkk..',
		'.kBBBBBeeBBBBBk.',
		'.kBBBBBeeBBBBBk.',
		'..kkkkBBBBkkkk..',
		'.....kBBBBk.....',
		'......kBBk......',
		'......kBBk......',
		'.......kk.......',
		'................',
		'................',
		'................',
	]
}

const mark_tooling = Sprite{
	name: 'mark-tooling'
	rows: [
		'................',
		'..........kkkk..',
		'.........kllllk.',
		'........kll.kllk',
		'........kll..kk.',
		'.......kllllk...',
		'......kllllk....',
		'.....kllllk.....',
		'....kllllk......',
		'...kllllk.......',
		'..kllllk........',
		'.kllllk.........',
		'.klllk..........',
		'.kkkk...........',
		'................',
		'................',
	]
}

const mark_quality = Sprite{
	name: 'mark-quality'
	rows: [
		'................',
		'....kkkkk.......',
		'..kkeeeeekk.....',
		'.keeeeeeeeek....',
		'.keeeeeeeffk....',
		'.keeeeeeffek....',
		'.keffeeffeek....',
		'.keeffffeeek....',
		'..keeffeeek.....',
		'..kkeeeeekk.....',
		'....kkkkkkk.....',
		'.........kWWk...',
		'..........kWWk..',
		'...........kWWk.',
		'............kkk.',
		'................',
	]
}

const mark_architecture = Sprite{
	name: 'mark-architecture'
	rows: [
		'................',
		'.......kk.......',
		'.....kkppkk.....',
		'...kkppppppkk...',
		'.kkppppppppppkk.',
		'.kkkkkkkkkkkkkk.',
		'.kppk.kppk.kppk.',
		'.kppk.kppk.kppk.',
		'.kppk.kppk.kppk.',
		'.kppk.kppk.kppk.',
		'.kppk.kppk.kppk.',
		'.kppk.kppk.kppk.',
		'.kkkkkkkkkkkkkk.',
		'.kppppppppppppk.',
		'.kkkkkkkkkkkkkk.',
		'................',
	]
}

const mark_cloud = Sprite{
	name: 'mark-cloud'
	rows: [
		'................',
		'................',
		'.......kkkk.....',
		'.....kkeeeekk...',
		'....keeeeeeeek..',
		'..kkkeeeeeeeekk.',
		'.keeeeeeeeeeeeek',
		'.keeeeeeeeeeeeek',
		'.keeeeeeeeeeeeek',
		'.keeeeeeeeeeeeek',
		'..kkkkkkkkkkkkk.',
		'................',
		'.....ss..ss.....',
		'....ss..ss......',
		'................',
		'................',
	]
}

const mark_loops = Sprite{
	name: 'mark-loops'
	rows: [
		'................',
		'.....kkkkkk.....',
		'...kkffffffkk...',
		'..kffk....kffk..',
		'..kfk......kfk..',
		'.kfk........kffk',
		'.kfk.......kfffk',
		'.kfk........kfk.',
		'.kfk........kfk.',
		'kfffk.......kfk.',
		'.kffk.......kfk.',
		'..kfk......kfk..',
		'..kffk....kffk..',
		'...kkffffffkk...',
		'.....kkkkkk.....',
		'................',
	]
}

const mark_forge = Sprite{
	name: 'mark-forge'
	rows: [
		'................',
		'..........kkkk..',
		'.........kllllk.',
		'........klllllk.',
		'.......kllllllk.',
		'......kWWkkkkk..',
		'.....kWWk.......',
		'....kWWk........',
		'...kWWk.........',
		'..kWWk..........',
		'.kkkkkkkkkkkk...',
		'.kSSSSSSSSSSSk..',
		'..kkSSSSSSSkk...',
		'....kSSSSSk.....',
		'...kkkkkkkkk....',
		'................',
	]
}

const mark_accessibility = Sprite{
	name: 'mark-accessibility'
	rows: [
		'................',
		'....kkkkkkkk....',
		'..kksssssssskk..',
		'.ksssssseesssssk',
		'.ksssssseesssssk',
		'.kseeeeeeeeeessk',
		'.ksssssseesssssk',
		'.ksssssseesssssk',
		'.ksssssseesssssk',
		'.ksssssseesssssk',
		'.ksssseesseesssk',
		'..kksseeseeskk..',
		'....kkkkkkkk....',
		'................',
		'................',
		'................',
	]
}

const mark_mcp = Sprite{
	name: 'mark-mcp'
	rows: [
		'................',
		'......kkkk......',
		'.....kBBBBk.....',
		'.....kBBBBk.....',
		'......kkkk......',
		'.......kk.......',
		'......kkkk......',
		'.....kk..kk.....',
		'....kk....kk....',
		'...kk......kk...',
		'.kkkk......kkkk.',
		'kBBBBk....kBBBBk',
		'kBBBBk....kBBBBk',
		'.kkkk......kkkk.',
		'................',
		'................',
	]
}

const mark_pack = Sprite{
	name: 'mark-pack'
	rows: [
		'................',
		'................',
		'..kkkkkk........',
		'.kmmmmmmkkkkkkk.',
		'.kmmmmmmmmmmmmk.',
		'.kkkkkkkkkkkkkk.',
		'.kPPPPPPPPPPPPk.',
		'.kPPkkkkkkkPPPk.',
		'.kPPPPPPPPPPPPk.',
		'.kPPkkkkkkkkPPk.',
		'.kPPPPPPPPPPPPk.',
		'.kPPkkkkkPPPPPk.',
		'.kPPPPPPPPPPPPk.',
		'.kkkkkkkkkkkkkk.',
		'................',
		'................',
	]
}

// mark_for returns the sprite for a library mark.
pub fn mark_for(m LibraryMark) Sprite {
	return match m {
		.doc { mark_doc }
		.design { mark_design }
		.security { mark_security }
		.delivery { mark_delivery }
		.data { mark_data }
		.ops { mark_ops }
		.integrations { mark_integrations }
		.core { mark_core }
		.tooling { mark_tooling }
		.quality { mark_quality }
		.architecture { mark_architecture }
		.cloud { mark_cloud }
		.loops { mark_loops }
		.forge { mark_forge }
		.accessibility { mark_accessibility }
		.mcp { mark_mcp }
		.pack { mark_pack }
	}
}

// mark_for_domain maps a catalog skill domain (catalogs/skill-catalog.yaml
// `domain:`) to its glyph. Unknown domains fall back to the generic document
// mark instead of being dropped — every card gets an identity.
pub fn mark_for_domain(domain string) Sprite {
	return match domain.to_lower() {
		'design' { mark_design }
		'agentic-security', 'security' { mark_security }
		'delivery' { mark_delivery }
		'data' { mark_data }
		'ops' { mark_ops }
		'integrations' { mark_integrations }
		'core' { mark_core }
		'tooling' { mark_tooling }
		'quality' { mark_quality }
		'architecture' { mark_architecture }
		'cloud' { mark_cloud }
		'loops' { mark_loops }
		'forge' { mark_forge }
		'accessibility' { mark_accessibility }
		else { mark_doc }
	}
}

// all_library_marks returns every LibraryMark (mapping coverage).
pub fn all_library_marks() []LibraryMark {
	return [.doc, .design, .security, .delivery, .data, .ops, .integrations, .core, .tooling,
		.quality, .architecture, .cloud, .loops, .forge, .accessibility, .mcp, .pack]
}

// library_mark_sprites returns every mark sprite (asset-manifest completeness).
fn library_mark_sprites() []Sprite {
	return [mark_doc, mark_design, mark_security, mark_delivery, mark_data, mark_ops,
		mark_integrations, mark_core, mark_tooling, mark_quality, mark_architecture, mark_cloud,
		mark_loops, mark_forge, mark_accessibility, mark_mcp, mark_pack]
}
