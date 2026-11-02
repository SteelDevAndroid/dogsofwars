# What the player reads for a unit type or a protocol key (provisional wording: the localisation
# comes with the texts). An unknown key falls back to its own spelling.
class_name DisplayNames
extends RefCounted

const UNITS := {
	"eclaireur": "Éclaireur", "assaut": "Assaut", "rempart": "Rempart", "ouvrier": "Ouvrier",
	"sentinelle": "Sentinelle", "chasseur": "Chasseur", "bastion": "Bastion",
}
const PROTOCOLS := {
	"veille_elargie": "Veille élargie", "reveil_sobre": "Réveil sobre", "cadence_de_marche": "Cadence de marche",
	"repos_reglementaire": "Repos réglementaire", "blindage_appoint": "Blindage d'appoint", "rempart_arme": "Rempart armé",
}


static func unit(key: String) -> String:
	return UNITS.get(key, key.replace("_", " ").capitalize())


static func protocol(key: String) -> String:
	return PROTOCOLS.get(key, key.replace("_", " ").capitalize())
