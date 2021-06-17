/mob/living/simple_mob //makes it so that any simplemob can potentially be revived by players and joined by ghosts
	var/ghostjoin = 0
	var/ic_revivable = 0
	var/revivedby = "no one"

//The stuff we want to be revivable normally
/mob/living/simple_mob/animal
	ic_revivable = 1
/mob/living/simple_mob/otie
	ic_revivable = 1
/mob/living/simple_mob/vore
	ic_revivable = 1
//The stuff that would be revivable but that we don't want to be revivable
/mob/living/simple_mob/animal/giant_spider/nurse //no you can't revive the ones who can lay eggs and get webs everywhere
	ic_revivable = 0
/mob/living/simple_mob/animal/giant_spider/carrier //or the ones who fart babies when they die
	ic_revivable = 0

//WHEN GHOSTS ATTACK!!!!!
/mob/living/simple_mob/attack_ghost(mob/observer/dead/user as mob)
	if(!ghostjoin)
		return ..()

	var/reply = alert("Would you like to become [src]? It is bound to [revivedby].",,"Yes","No")
	if(reply == "No")
		return

	if(ckey) //FIRST ONE TO CLICK YES GETS IT!!!!!! Channel your inner youtube commenter.
		to_chat(src, "<span class='notice'>Sorry, someone else has already inhabited [src].</span>")
		return
	
	log_and_message_admins("[key_name_admin(user)] joined [src] as a ghost [ADMIN_FLW(src)]")
	active_ghost_pods -= src
	if(user.mind)
		user.mind.active = TRUE
		user.mind.transfer_to(src)
	else
		src.ckey = user.ckey
	qdel(user)
	ghostjoin = 0
	ghostjoin_icon()
	if(revivedby != "no one")
		to_chat(src, "<span class='notice'>Where once your life had been rough and scary, you have been assisted by [revivedby]. They seem to be the reason you are on your feet again... so perhaps you should help them out.</span> <span class= warning> Being as you were revived, you are allied with the station. Do not attack anyone unless they are threatening the one who revived you. And try to listen to the one who revived you within reason. Of course, you may do scenes as you like, but you must still respect preferences.</span>")
		visible_message("[src]'s eyes flicker with a curious intelligence.")


/obj/item/device/denecrotizer //Away map reward. FOR TRAINED NECROMANCERS ONLY. >:C
	name = "experimental denecrotizer"
	desc = "It looks simple on the outside but this device radiates some unknown dread. It does not appear to be of any ordinary make, and just how it works is unclear, but this device seems to interact with dead flesh."
	icon = 'icons/obj/device_vr.dmi'
	icon_state = "denecrotizer"
	w_class = ITEMSIZE_COST_NORMAL
	var/charges = 5 //your army of minions can only be this big
	var/last_used
	var/cooldown = 10 MINUTES //LONG
	var/revive_time = 30 SECONDS //Don't do this in combat
	var/advanced = 1 //allows for ghosts to join mobs who get revived by this, and updates their faction to yours

/obj/item/device/denecrotizer/examine(var/mob/user)
	. = ..()
	var/cooldowntime = round((cooldown - (world.time - last_used)) * 0.1)
	if(Adjacent(user))
		if(cooldowntime <= 0)
			. += "<span class='notice'>The screen indicates that this device is ready to be used, and that it has enough energy for [charges] uses.</span>"
		else
			. += "<span class='notice'>The screen indicates that this device can be used again in [cooldowntime] seconds, and that it has enough energy for [charges] uses.</span>"

/obj/item/device/denecrotizer/proc/check_target(mob/living/simple_mob/target, mob/living/user) 
	if(!target.Adjacent(user))
		return FALSE
	if(user.a_intent != I_HELP) //be gentle
		user.visible_message("[user] bonks [target] with [src].", runemessage = "bonks [target]")
		return FALSE
	if(!istype(target))
		to_chat(user, "<span class='notice'>[target] seems to be too complicated for [src] to interface with.</span>")
		return FALSE
	if(!(world.time - last_used > cooldown))
		to_chat(user, "<span class='notice'>[src] doesn't seem to be ready yet.</span>")
		return FALSE
	if(!charges)
		to_chat(user, "<span class='notice'>[src] doesn't seem to be active anymore.</span>")
		return FALSE
	if(!target.ic_revivable)
		to_chat(user, "<span class='notice'>[src] doesn't seem to interface with [target].</span>")
		return FALSE
	if(target.stat != DEAD)
		if(!advanced)
			to_chat(user, "<span class='notice'>[src] doesn't seem to work on that.</span>")
			return FALSE
		if(target.ai_holder.retaliate || target.ai_holder.hostile) // You can be friends with still living mobs if they are passive I GUESS 
			to_chat(user, "<span class='notice'>[src] doesn't seem to work on that.</span>")
			return FALSE
		if(!target.mind) 
			user.visible_message("[user] gently presses [src] to [target]...", runemessage = "presses [src] to [target]")
			if(do_after(user, revive_time, exclusive = 1, target = target))
				target.faction = user.faction
				target.revivedby = user.name
				target.ghostjoin = 1
				active_ghost_pods += target
				target.ghostjoin_icon()
				last_used = world.time
				charges--
				log_and_message_admins("[key_name_admin(user)] used a denecrotizer to tame/offer a simplemob to ghosts: [target]. [ADMIN_FLW(src)]")
				target.visible_message("[target]'s eyes widen, as though in revelation as it looks at [user].", runemessage = "eyes widen")
				if(charges == 0)
					icon_state = "[initial(icon_state)]-o"
					update_icon()
			return FALSE
		else
			to_chat(user, "<span class='notice'>[src] doesn't seem to work on that.</span>")
			return FALSE
	return TRUE

/obj/item/device/denecrotizer/proc/ghostjoin_rez(mob/living/simple_mob/target, mob/living/user)
	user.visible_message("[user] gently presses [src] to [target]...", runemessage = "presses [src] to [target]")
	if(do_after(user, revive_time, exclusive = 1, target = target))
		target.faction = user.faction
		target.revivedby = user.name
		target.revive()
		target.sight = initial(target.sight)
		target.see_in_dark = initial(target.see_in_dark)
		target.see_invisible = initial(target.see_invisible)
		target.update_icon()
		visible_message("[target] lifts its head and looks at [user].", runemessage = "lifts its head and looks at [user]")
		log_and_message_admins("[key_name_admin(user)] used a denecrotizer to revive a simple mob: [target]. [ADMIN_FLW(src)]")
		if(!target.mind) //if it doesn't have a mind then no one has been playing as it, and it is safe to offer to ghosts.
			target.ghostjoin = 1
			active_ghost_pods += target
			target.ghostjoin_icon()
		last_used = world.time
		charges--
		if(charges == 0)
			icon_state = "[initial(icon_state)]-o"
			update_icon()
		return
		
/obj/item/device/denecrotizer/proc/basic_rez(mob/living/simple_mob/target, mob/living/user) //so medical can have a way to bring back people's pets or whatever, does not change any settings about the mob or offer it to ghosts.
	user.visible_message("[user] presses [src] to [target]...", runemessage = "presses [src] to [target]")
	if(do_after(user, revive_time, exclusive = 1, target = target))
		target.revive()
		target.sight = initial(target.sight)
		target.see_in_dark = initial(target.see_in_dark)
		target.see_invisible = initial(target.see_invisible)
		target.update_icon()
		visible_message("[target] lifts its head and looks at [user].", runemessage = "lifts its head and looks at [user]")
		last_used = world.time
		charges--
		if(charges == 0)
			icon_state = "[initial(icon_state)]-o"
			update_icon()
		return
	else
		user.visible_message("[user] bonks [target] with [src]. Nothing happened.")
		return



/obj/item/device/denecrotizer/attack(mob/living/simple_mob/target, mob/living/user)
	if(check_target(target, user))
		if(advanced)
			ghostjoin_rez(target, user)
		else
			basic_rez(target, user)
	else
		return ..()

/mob/living/simple_mob/proc/ghostjoin_icon() //puts an icon on mobs for ghosts, so they can see if a mob has been revived and is joinable
	var/static/image/I
	if(!I)
		I = image('icons/mob/hud_vr.dmi', "ghostjoin")
		I.invisibility = INVISIBILITY_OBSERVER
		I.plane = PLANE_GHOSTS
		I.appearance_flags = KEEP_APART|RESET_TRANSFORM

	if(ghostjoin)
		add_overlay(I)
	else
		cut_overlay(I)

/obj/item/device/denecrotizer/medical //Can revive more things, but without the special ghost and faction stuff. For medical use.
	name = "commercial denecrotizer"
	desc = "A curious device who's purpose is reviving simpler life forms. It seems to radiate menace."
	icon_state = "m-denecrotizer"
	advanced = 0 //This one isn't as fancy
	cooldown = 5 MINUTES //not as long
	charges = 20 //in case spiders merc Ian