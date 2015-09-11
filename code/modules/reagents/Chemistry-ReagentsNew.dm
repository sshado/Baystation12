/datum/reagent
	var/name = "Reagent"
	var/id = "reagent"
	var/description = ""
	var/datum/reagents/holder = null
	var/reagent_state = SOLID
	var/list/data = null
	var/glass_icon_state = null
	var/glass_name = null
	var/glass_desc = null
	var/glass_center_of_mass = null
	var/volume = 0
	var/ingest_met = 0
	var/touch_met = 0
	var/nutriment_factor = 0
	var/metabolization_rate = REM
	var/scannable = 0 // Shows up on health analyzers.
	var/shock_reduction = 0 //Used for painkillers. Reduces Shock (duh)
	var/color = "#000000"
	var/color_weight = 1
	var/process_flags = ORGANIC

// This doesn't apply to skin contact - this is for, e.g. extinguishers and sprays. The difference is that reagent is not directly on the mob's skin - it might just be on their clothing.
/datum/reagent/proc/affect_touch_mob(var/mob/M, var/amount)
	return

/datum/reagent/proc/affect_touch_obj(var/obj/O, var/amount) // Acid melting, cleaner cleaning, etc
	return

/datum/reagent/proc/affect_touch_turf(var/turf/T, var/amount) // Cleaner cleaning, lube lubbing, etc, all go here
	return

// This doesn't apply to skin contact - this is for, e.g. extinguishers and sprays. The difference is that reagent is not directly on the mob's skin - it might just be on their clothing.
/datum/reagent/proc/touch_mob(var/mob/M, var/amount)
	return

/datum/reagent/proc/touch_obj(var/obj/O, var/amount) // Acid melting, cleaner cleaning, etc
	return

/datum/reagent/proc/touch_turf(var/turf/T, var/amount) // Cleaner cleaning, lube lubbing, etc, all go here
	return

/datum/reagent/proc/on_mob_life(var/mob/living/carbon/M, var/alien, var/location) // Currently, on_mob_life is called on carbons. Any interaction with non-carbon mobs (lube) will need to be done in touch_mob.
	if(!istype(M))
		return
	if(!affects_dead && M.stat == DEAD)
		return
	if(overdose && (dose > overdose) && (location != CHEM_TOUCH))
		overdose(M, alien)
	var/removed = metabolism
	if(ingest_met && (location == CHEM_INGEST))
		removed = ingest_met
	if(touch_met && (location == CHEM_TOUCH))
		removed = touch_met
	removed = min(removed, volume)
	max_dose = max(volume, max_dose)
	dose = min(dose + removed, max_dose)
	if(removed >= (metabolism * 0.1) || removed >= 0.1) // If there's too little chemical, don't affect the mob, just remove it
		switch(location)
			if(CHEM_BLOOD)
				affect_blood(M, alien, removed)
			if(CHEM_INGEST)
				affect_ingest(M, alien, removed)
			if(CHEM_TOUCH)
				affect_touch(M, alien, removed)
	remove_self(removed)
	return

/datum/reagent/proc/overdose(var/mob/living/carbon/M, var/alien) // Overdose effect. Doesn't happen instantly.
	M.adjustToxLoss(REM)
	return

/datum/reagent/Destroy() // This should only be called by the holder, so it's already handled clearing its references
	..()
	holder = null

/* DEPRECATED - TODO: REMOVE EVERYWHERE */

/datum/reagent/proc/reaction_turf(var/turf/target)
	touch_turf(target)

/datum/reagent/proc/reaction_obj(var/obj/target)
	touch_obj(target)

/datum/reagent/proc/reaction_mob(var/mob/target)
	touch_mob(target)

/datum/reagent/woodpulp
	name = "Wood Pulp"
	id = "woodpulp"
	description = "A mass of wood fibers."
	reagent_state = LIQUID
	color = "#B97A57"
