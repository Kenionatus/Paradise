/**
 * Will teleport the given atom to the given destination using the other parameters
 *
 * Arguments:
 * - atom_to_teleport - Atom to teleport
 * - destination - Where to teleport the atom to
 * - variance_range - With what precision to do the teleport. 0 means on target. Higher means that many turfs around it
 * - force_teleport - Whether to use forceMove instead of Move to move the atom to the destination
 * - effect_in - The effect started at the starting turf. If set to NONE then no effect is used
 * - effect_out - The effect started at the destination turf. If set to NONE then no effect is used
 * - sound_in - The sound played at the starting turf
 * - sound_out - The sound played at the destination turf
 * - bypass_area_flag - Whether is_teleport_allowed is skipped or not
 * - safe_turf_pick - Whether the chosen random turf from the variance is prefered to be a safe turf or not
 * - do_effect - Whether to play the effect or not
 */
/proc/do_teleport(atom_to_teleport, destination, variance_range = 0, force_teleport = TRUE, datum/effect_system/effect_in = null, datum/effect_system/effect_out = null, sound_in = null, sound_out = null, bypass_area_flag = FALSE, safe_turf_pick = FALSE, do_effect = TRUE)
	var/datum/teleport/instant/science/D = new // default here
	if((isnull(effect_in) || isnull(effect_out)) && do_effect) // Set default effects
		var/datum/effect_system/spark_spread/effect = new
		effect.set_up(5, 1, atom_to_teleport)
		if(isnull(effect_in))
			effect_in = effect
		if(isnull(effect_out))
			effect_out = effect
	return D.start(atom_to_teleport, destination, variance_range, force_teleport, effect_in, effect_out, sound_in, sound_out, bypass_area_flag, safe_turf_pick, do_effect)

/datum/teleport
	var/atom/movable/teleatom //atom to teleport
	var/atom/destination //destination to teleport to
	var/precision = 0 //teleport precision
	var/datum/effect_system/effectin //effect to show right before teleportation
	var/datum/effect_system/effectout //effect to show right after teleportation
	var/soundin //soundfile to play before teleportation
	var/soundout //soundfile to play after teleportation
	var/force_teleport = 1 //if false, teleport will use Move() proc (dense objects will prevent teleportation)
	var/ignore_area_flag = FALSE
	var/safe_turf_first = FALSE //If the teleport isn't precise and this is TRUE, only non-space, non-dense turfs will be selected, unless there's no other option for teleportation.
	var/static/list/blacklisted = list(/obj/machinery/teleport/perma, /obj/machinery/teleport/hub) //List of objects that the destination turf cannot contain

/datum/teleport/proc/start(ateleatom, adestination, aprecision = 0, afteleport = 1, aeffectin = null, aeffectout = null, asoundin = null, asoundout = null, bypass_area_flag = FALSE, safe_turf_pick = FALSE, do_effect = FALSE)
	if(!initTeleport(arglist(args)))
		return FALSE
	return TRUE

/datum/teleport/proc/initTeleport(ateleatom, adestination, aprecision, afteleport, aeffectin, aeffectout, asoundin, asoundout, bypass_area_flag = FALSE, safe_turf_pick = FALSE, do_effect = FALSE)
	if(!setTeleatom(ateleatom))
		return FALSE
	if(!setDestination(adestination))
		return FALSE
	safe_turf_first = safe_turf_pick //before precision for bag of holding interference
	if(!setPrecision(aprecision))
		return FALSE
	if(do_effect)
		setEffects(aeffectin, aeffectout)
	setForceTeleport(afteleport)
	setSounds(asoundin,asoundout)
	ignore_area_flag = bypass_area_flag
	return TRUE

//must succeed
/datum/teleport/proc/setPrecision(aprecision)
	if(isnum(aprecision))
		precision = aprecision
		return TRUE
	return FALSE

//must succeed
/datum/teleport/proc/setDestination(atom/adestination)
	if(istype(adestination))
		destination = adestination
		return TRUE
	return FALSE

//must succeed in most cases
/datum/teleport/proc/setTeleatom(atom/movable/ateleatom)
	if(iseffect(ateleatom) && !HAS_TRAIT(ateleatom, TRAIT_EFFECT_CAN_TELEPORT))
		qdel(ateleatom)
		return FALSE
	if(istype(ateleatom))
		teleatom = ateleatom
		return TRUE
	return FALSE

//custom effects must be properly set up first for instant-type teleports
//optional
/datum/teleport/proc/setEffects(datum/effect_system/aeffectin=null,datum/effect_system/aeffectout=null)
	effectin = istype(aeffectin) ? aeffectin : null
	effectout = istype(aeffectout) ? aeffectout : null
	return TRUE

//optional
/datum/teleport/proc/setForceTeleport(afteleport)
	force_teleport = afteleport
	return TRUE

//optional
/datum/teleport/proc/setSounds(asoundin=null,asoundout=null)
	soundin = isfile(asoundin) ? asoundin : null
	soundout = isfile(asoundout) ? asoundout : null
	return TRUE

//placeholder
/datum/teleport/proc/teleportChecks()
	return TRUE

/datum/teleport/proc/playSpecials(atom/location,datum/effect_system/effect,sound)
	if(location)
		if(effect)
			src = null
			effect.attach(location)
			effect.start()
		if(sound)
			src = null
			playsound(location,sound,60,1)
	return

//do the monkey dance
/datum/teleport/proc/doTeleport()

	var/turf/destturf
	var/turf/curturf = get_turf(teleatom)
	var/area/curarea = get_area(curturf)

	if(precision)
		var/list/posturfs = list()
		var/center = get_turf(destination)
		if(!center)
			center = destination
		if(safe_turf_first)
			for(var/turf/T in range(precision, center))
				if(isspaceturf(T))
					continue
				if(T.density)
					continue
				posturfs.Add(T)
		if(!length(posturfs)) //This is either an unsafe teleport or we didnt find a single safe turf for a safe teleport
			for(var/turf/T in range(precision, center))
				posturfs.Add(T)
		destturf = safepick(posturfs)
	else
		destturf = get_turf(destination)

	// Make sure the target tile does not contain a teleporter on it
	for(var/teleporter_type in blacklisted)
		var/teleporters = destturf.search_contents_for(teleporter_type)
		if(length(teleporters))
			return FALSE

	if(!is_teleport_allowed(destturf.z) && !ignore_area_flag)
		return FALSE
	if(!ignore_area_flag) // Admin or contractor portal, let em through without running signals
		if(SEND_SIGNAL(teleatom, COMSIG_MOVABLE_TELEPORTING, destination) & COMPONENT_BLOCK_TELEPORT)
			return FALSE

	// Only check the destination zlevel for is_teleport_allowed. Checking origin as well breaks ERT teleporters.

	var/area/destarea = get_area(destturf)

	if(!ignore_area_flag)
		if(curarea.tele_proof)
			return FALSE
		if(destarea.tele_proof)
			return FALSE

	if(!destturf || !curturf)
		return FALSE

	playSpecials(curturf,effectin,soundin)

	if(isliving(teleatom))
		var/mob/living/target_mob = teleatom
		if(target_mob.buckled)
			target_mob.unbuckle(force = TRUE)
		if(target_mob.has_buckled_mobs())
			target_mob.unbuckle_all_mobs(force = TRUE)
		if(ismachinery(target_mob.loc) || istype(target_mob.loc, /obj/item/mecha_parts/mecha_equipment/medical/sleeper))
			var/obj/location = target_mob.loc
			location.force_eject_occupant(target_mob)

	if(force_teleport)
		teleatom.forceMove(destturf)
		playSpecials(destturf,effectout,soundout)
	else
		if(teleatom.Move(destturf))
			playSpecials(destturf,effectout,soundout)

	destarea.Entered(teleatom)

	return TRUE

/datum/teleport/proc/teleport()
	if(teleportChecks())
		return doTeleport()
	return FALSE

/datum/teleport/instant/start(ateleatom, adestination, aprecision = 0, afteleport = 1, aeffectin = null, aeffectout = null, asoundin = null, asoundout = null, bypass_area_flag = FALSE, safe_turf_pick = FALSE)
	if(..())
		if(teleport())
			return TRUE
	return FALSE


/datum/teleport/instant/science

/datum/teleport/instant/science/setPrecision(aprecision)
	..()
	if(!is_admin_level(destination.z))
		if(istype(teleatom, /obj/item/storage/backpack/holding))
			precision = rand(1, 100)

		var/list/bagholding = teleatom.search_contents_for(/obj/item/storage/backpack/holding)
		if(length(bagholding))
			if(safe_turf_first) //If this is true, this is already a random teleport. Make it unsafe but do not touch the precision.
				safe_turf_first = FALSE
			else
				precision = max(rand(1, 100) * length(bagholding), 100)

			if(isliving(teleatom))
				var/mob/living/MM = teleatom
				to_chat(MM, "<span class='warning'>The bluespace interface on your bag of holding interferes with the teleport!</span>")
	return TRUE

// Random safe location finder
/proc/find_safe_turf(zlevel, list/zlevels)
	if(!zlevels)
		if(zlevel)
			zlevels = list(zlevel)
		else
			zlevels = levels_by_trait(STATION_LEVEL)
	var/cycles = 1000
	for(var/cycle in 1 to cycles)
		// DRUNK DIALLING WOOOOOOOOO
		var/x = rand(1, world.maxx)
		var/y = rand(1, world.maxy)
		var/z = pick(zlevels)
		var/turf/random_location = locate(x, y, z)

		if(random_location.is_safe())
			return random_location
