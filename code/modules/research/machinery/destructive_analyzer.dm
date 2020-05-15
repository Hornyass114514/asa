

/*
Destructive Analyzer

It is used to destroy hand-held objects and advance technological research. Controls are in the linked R&D console.

Note: Must be placed within 3 tiles of the R&D Console
*/
/obj/machinery/rnd/destructive_analyzer
	name = "destructive analyzer"
	desc = "Learn science by destroying things!"
	icon_state = "d_analyzer"
	circuit = /obj/item/weapon/circuitboard/destructive_analyzer
	idle_power_usage = 30
	active_power_usage = 2500
	var/decon_mod = 0

/obj/machinery/rnd/destructive_analyzer/RefreshParts()
	var/T = 0
	for(var/obj/item/weapon/stock_parts/S in component_parts)
		T += S.rating
	decon_mod = T * 0.1


/obj/machinery/rnd/destructive_analyzer/proc/ConvertReqString2List(list/source_list)
	var/list/temp_list = params2list(source_list)
	for(var/O in temp_list)
		temp_list[O] = text2num(temp_list[O])
	return temp_list

/obj/machinery/rnd/destructive_analyzer/disconnect_console()
	linked_console.linked_destroy = null
	..()

/obj/machinery/rnd/destructive_analyzer/Insert_Item(obj/item/O, mob/user)
	if(user.a_intent != I_HURT)
		. = 1
		if(!is_insertion_ready(user))
			return
		
		if(istype(O, /obj/item/stack/material)) // Only deconsturcts one sheet at a time instead of the entire stack
			var/obj/item/stack/material/S = O
			O = S.split(1)
			if(!O)
				return
		else if(!user.unEquip(O, target = src))
			to_chat(user, "<span class='warning'>\The [O] is stuck to your hand, you cannot put it in \the [src]!</span>")
			return
		busy = TRUE
		loaded_item = O
		to_chat(user, "<span class='notice'>You add \the [O] to \the [src]!</span>")
		flick("d_analyzer_la", src)
		addtimer(CALLBACK(src, .proc/finish_loading), 1 SECOND)
		if(linked_console)
			linked_console.updateUsrDialog()

/obj/machinery/rnd/destructive_analyzer/proc/finish_loading()
	update_icon()
	reset_busy()

/obj/machinery/rnd/destructive_analyzer/update_icon()
	. = ..()
	if(loaded_item)
		icon_state = "d_analyzer_l"
	else
		icon_state = initial(icon_state)

/obj/machinery/rnd/destructive_analyzer/proc/reclaim_materials_from(obj/item/thing)
	log_debug("reclaim_materials_from([thing] ([thing?.type]) matter=")
	. = FALSE
	var/datum/material_container/storage = linked_console?.linked_lathe?.materials.mat_container
	if(storage && LAZYLEN(thing.matter)) // Also sends salvaged materials to a linked protolathe, if any.
		if(storage.can_insert_materials(thing.matter, decon_mod, ignore_disallowed_types = TRUE))
			. = storage.insert_materials(thing.matter, decon_mod)
		if(.)
			linked_console.linked_lathe.materials.silo_log(src, "reclaimed", decon_mod, "[thing.name]", thing.matter)

/obj/machinery/rnd/destructive_analyzer/proc/destroy_item(obj/item/thing, innermode = FALSE)
	if(QDELETED(thing) || QDELETED(src) || QDELETED(linked_console))
		return FALSE
	if(!innermode)
		flick("d_analyzer_process", src)
		busy = TRUE
		addtimer(CALLBACK(src, .proc/reset_busy), 24)
		use_power(250)
		if(thing == loaded_item)
			loaded_item = null
		var/list/food = thing.contents
		for(var/obj/item/innerthing in food)
			destroy_item(innerthing, TRUE)
	reclaim_materials_from(thing)
	for(var/mob/M in thing)
		M.death()
	if(istype(thing, /obj/item/stack/material))
		var/obj/item/stack/material/S = thing
		if(S.amount > 1 && !innermode)
			S.amount--
			loaded_item = S
		else
			qdel(S)
	else
		qdel(thing)
	if(!innermode)
		update_icon()
	return TRUE

/obj/machinery/rnd/destructive_analyzer/proc/user_try_decon_id(id, mob/user)
	if(!istype(loaded_item) || !istype(linked_console))
		return FALSE

	if(id && id != RESEARCH_MATERIAL_RECLAMATION_ID)
		var/datum/techweb_node/TN = SSresearch.techweb_node_by_id(id)
		if(!istype(TN))
			return FALSE
		var/dpath = loaded_item.type
		var/list/worths = TN.boost_item_paths[dpath]
		var/list/differences = list()
		var/list/already_boosted = linked_console.stored_research.boosted_nodes[TN.id]
		for(var/i in worths)
			var/used = already_boosted? already_boosted[i] : 0
			var/value = min(worths[i], TN.research_costs[i]) - used
			if(value > 0)
				differences[i] = value
		if(length(worths) && !length(differences))
			return FALSE
		var/choice = input("Are you sure you want to destroy [loaded_item] to [!length(worths) ? "reveal [TN.display_name]" : "boost [TN.display_name] by [json_encode(differences)] point\s"]?") in list("Proceed", "Cancel")
		if(choice == "Cancel")
			return FALSE
		if(QDELETED(loaded_item) || QDELETED(linked_console) || !user.Adjacent(linked_console) || QDELETED(src))
			return FALSE
		// SSblackbox.record_feedback("nested tally", "item_deconstructed", 1, list("[TN.id]", "[loaded_item.type]"))
		if(destroy_item(loaded_item))
			linked_console.stored_research.boost_with_path(SSresearch.techweb_node_by_id(TN.id), dpath)

	else
		var/list/point_value = techweb_item_point_check(loaded_item)
		if(linked_console.stored_research.deconstructed_items[loaded_item.type])
			point_value = list()
		var/user_mode_string = ""
		if(length(point_value))
			user_mode_string = " for [json_encode(point_value)] points"
		else if(length(loaded_item.matter))
			user_mode_string = " for material reclamation"
		var/choice = input("Are you sure you want to destroy [loaded_item][user_mode_string]?") in list("Proceed", "Cancel")
		if(choice == "Cancel")
			return FALSE
		if(QDELETED(loaded_item) || QDELETED(linked_console) || !user.Adjacent(linked_console) || QDELETED(src))
			return FALSE
		var/loaded_type = loaded_item.type
		if(destroy_item(loaded_item))
			linked_console.stored_research.add_point_list(point_value)
			linked_console.stored_research.deconstructed_items[loaded_type] = point_value
	return TRUE

/obj/machinery/rnd/destructive_analyzer/proc/unload_item()
	if(!loaded_item)
		return FALSE
	loaded_item.forceMove(get_turf(src))
	loaded_item = null
	update_icon()
	return TRUE