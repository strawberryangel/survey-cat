// Free survey script by Sophie-Jeanne (mommypickles).
// Version 0.1 - Card-driven sript

///////////////////////////////////////
//
// INSTRUCTIONS:
//
// Load this script along with one or more cards with names that end in .survey
// into your container. This script supports no more than 12 cards.
//
// You should be presented with the opportunity to choose which card to load.
// Read you general chat for pertinant information.
//
// When getting ready for use, the script talks to the owner in general chat
// but won't spam general chat. It's only visible to the owner.
//
///////////////////////////////////////

// CREATIVE COMMONS LICENSE
// Attribution-ShareAlike
// CC BY-SA
// https://creativecommons.org/licenses/by-sa/4.0/
//
// This license lets others remix, tweak, and build upon your work even for
// commercial purposes, as long as they credit you and license their new
// creations under the identical terms. This license is often compared to
// “copyleft” free and open source software licenses. All new works based
// on yours will carry the same license, so any derivatives will also allow
// commercial use. This is the license used by Wikipedia, and is
// recommended for materials that would benefit from incorporating content
// from Wikipedia and similarly licensed projects.

// This script will look for all cards that end with this suffix.
string NOTECARD_SUFFIX = ".survey";

integer DEBUG = FALSE;

// Owner dialog constants.
string DENY = "Deny";
string READY = "Ready";
string CHOOSE_CARD = "Choose Card";

// Normal Dialog constants.
string TITLE = "Survey Cat";
string DIALOG_TITLE = "Survey Cat\n\nWhat would you like to do?";

// Card parsing
list cards; // List of all loaded cards.
string notecard_name; // Name of current card.
key notecard_query;
integer line;

list buttons;    // All loaded buttons
list actions;    // Corresponding actions
list sounds;     // Corresponding sounds

// State and global variables.
integer lock = FALSE;
string lock_message;
string object_name;
string owner_name;

////////////////////////////////////////////////////////////////////////////////
// Utility functions
////////////////////////////////////////////////////////////////////////////////

debug(string message)
{
	if(DEBUG) llSay(DEBUG_CHANNEL, message);
}

im(string prefix, key receiver, string message)
{
	llSetObjectName(prefix);
	llInstantMessage(receiver,"/me " + message);
	llSetObjectName(object_name);
}

integer imin(integer a, integer b)
{
	if(a < b) return a; else return b;
}

owner_say(string prefix, string message)
{
	llSetObjectName(prefix);
	llOwnerSay(message);
	llSetObjectName(object_name);
}

say(string message)
{
	llSetObjectName("");
	llSay(0,"/me " + message);
	llSetObjectName(object_name);
}

list split(string what, string where)
{
	return llParseStringKeepNulls(what, [where], [""]);
}

string substitute(string value, string search, string replace) { // v1
	return llDumpList2String(
		llParseStringKeepNulls(value, [search], []),
		replace);
}

////////////////////////////////////////////////////////////////////////////////
// Dialog-specific functions
////////////////////////////////////////////////////////////////////////////////

string PREVIOUS_PAGE_BUTTON = " << ";
string NEXT_PAGE_BUTTON = " >> ";
string HOME_PAGE_BUTTON = " Home ";

integer dialog_channel;
string dialog_title;

list dialog_items;
integer dialog_item_count;
integer current_page;
integer is_paged;
integer page_count;

initialize_dialog(string title, list items)
{
	if(dialog_channel) llListenRemove(dialog_channel);
	dialog_channel = 100 + (integer)llFrand(20000);
	llListen(dialog_channel, "", "", "");

	dialog_title = title;

	dialog_items = items;
	dialog_item_count = llGetListLength(dialog_items);
	is_paged = dialog_item_count > 12;
	current_page = 0;
	page_count = dialog_item_count / 9 + 1;
}

list order_buttons(list buttons)
{
	return llList2List(buttons, -3, -1) + llList2List(buttons, -6, -4)
		+ llList2List(buttons, -9, -7) + llList2List(buttons, -12, -10);
}

integer process_dialog_button(string name, key id, string message)
{
	if(message == PREVIOUS_PAGE_BUTTON)
	{
		if(current_page > 0)
			current_page--;
		else
			current_page = page_count-1;
		return TRUE;
	}
	if (message == NEXT_PAGE_BUTTON)
	{
		if(current_page < page_count-1)
			current_page++;
		else
			current_page = 0;
		return TRUE;
	}
	if(message == HOME_PAGE_BUTTON)
	{
		current_page = 0;
		return TRUE;
	}

	// Not a dialog button.
	return FALSE;
}


show_dialog(key who)
{
	list items;
	if(!is_paged)
	{
		items = order_buttons(dialog_items);
		llDialog(who, dialog_title, items, dialog_channel);
		return;
	}

	integer start = 9 * current_page;
	integer stop = imin(start + 8, dialog_item_count-1);

	items = [PREVIOUS_PAGE_BUTTON, HOME_PAGE_BUTTON, NEXT_PAGE_BUTTON] + order_buttons(llList2List(dialog_items, start, stop));

	llDialog(who, dialog_title, items, dialog_channel);
}

////////////////////////////////////////////////////////////////////////////////
// Script-specific functions
////////////////////////////////////////////////////////////////////////////////

string action2string(string action, string toucher_name)
{
	string result = substitute(action, "@",  owner_name);
	result = substitute(result, "%", toucher_name);
	return result;
}

bad_line()
{
	llOwnerSay(TITLE + ": Configuration could not be read on line " + (string)line);
}

choose_card_dialog(key who)
{
	if(who != llGetOwner())
	{
		im(TITLE, who, owner_name + " has not set up a survey yet.");
		return;
	}

	initialize_dialog(TITLE, cards);
	// TODO: There's a hidden restriction in llDialog. It's limited to 24 characters for labels.
	// TODO: This means we should probably handle verbose card names.
	show_dialog(who);
}

finalize_card_load()
{
	initialize_dialog(DIALOG_TITLE, buttons);
	owner_say(TITLE, notecard_name + " loaded.");
}

get_card_list()
{
	owner_say(TITLE, "Looking for .survey cards to load...");
	notecard_name = "";

	string card;
	cards = [];
	integer n = llGetInventoryNumber(INVENTORY_NOTECARD);
	while (n-- > 0) {
		card = llGetInventoryName(INVENTORY_NOTECARD, n);
		// Note: for simplicity, read cards with the "suffix" anywhere in the name
		if (llSubStringIndex(card, NOTECARD_SUFFIX) != -1) {
			cards += [card];
			owner_say(TITLE, "Found card: " + card);
		}
	}
}

integer init_from_card()
{
	//  reset configuration values to default
	buttons = [];
	actions = [];
	sounds = [];

	//  make sure the file exists and is a notecard
	if(llGetInventoryType(notecard_name) != INVENTORY_NOTECARD)
	{
		llOwnerSay(TITLE + ": Missing inventory notecard " + notecard_name);
		return FALSE;
	}

	//  initialize to start reading from first line (which is 0)
	line = 0;
	notecard_query = llGetNotecardLine(notecard_name, line);
	return TRUE;
}

integer is_owner_menu(key who)
{
	return who == llGetOwner() && !DEBUG;
}

parse_line(string data)
{
	//  if we are at the end of the file
	if(data == EOF)
	{
		//  notify the owner
		if(DEBUG)
		{
			debug("Configuration notecard read.");

			//  notify what was read
			integer count = llGetListLength(buttons);
			integer i;
			do
				debug(llList2String(buttons, i) + " -> " + llList2String(actions, i) + " -> " + llList2String(sounds, i));
			while (++i < count);
		}
		finalize_card_load();
		return;
	}

	//  if we are not working with a blank line
	//  and if the line does not begin with a comment
	if(data != "" && llSubStringIndex(data, "#") != 0)
	{
		// Split on equal signs
		list values = split(data, "=");
		integer len = llGetListLength(values);

		//  if line contains 1 or 2 equal signs
		if(len == 2 || len == 3)
		{
			string button_name = llStringTrim(llList2String(values, 0), STRING_TRIM);
			string action_text = llStringTrim(llList2String(values, 1), STRING_TRIM);
			string sound_id;
			if(len == 3)
				sound_id = llStringTrim(llList2String(values, 2), STRING_TRIM);

			// Forbidden values

			// http://wiki.secondlife.com/wiki/LlDialog
			if(button_name == "!!llTextBox!!")
				bad_line();
			else {
				// Store values
				buttons += button_name;
				actions += action_text;
				sounds += sound_id;
				debug("Line: " + (string)line + " key: " + button_name + " value: " + action_text + "  sound: " + sound_id);
			}
		}
		else
			bad_line();
	}

	//  read the next line
	notecard_query = llGetNotecardLine(notecard_name, ++line);
}

process_button(string name, key id, string message)
{
	if(process_dialog_button(name, id, message))
	{
		show_dialog(id);
		return;
	}

	// Replace name passed in with display name.
	name = llGetDisplayName(id);

	// Find index of message.
	integer idx = llListFindList(buttons, [message]);
	if(idx<0) return;

	string action = action2string(llList2String(actions, idx), name);
	string sound = llList2String(sounds, idx);
	if(sound) llPlaySound(sound, 1.0);
	say(action);
}

set_deny()
{
	debug("Entering DENY mode.");
	lock = TRUE;
	lock_message = "I don't want to play right now.";
	owner_say(TITLE, ": " + lock_message);
}

set_ready()
{
	debug("Entering READY mode.");
	lock = FALSE;
	lock_message = "Let's play!";
	owner_say(TITLE, ": " + lock_message);
}

////////////////////////////////////////////////////////////////////////////////
// States
////////////////////////////////////////////////////////////////////////////////

default
{
	state_entry()
	{
		debug("---------------------------------------");
		debug("Entering default state.");

		// Set the initial state.
		set_ready();

		object_name = llGetObjectName();

		if(DEBUG)
			owner_name = "Juxtaposed Jen";
		else
			owner_name = llGetDisplayName(llGetOwner());

		state load_cards;
	}

	state_exit()
	{
		debug("Leaving default state.");
	}

	changed(integer change)
	{
		if (change & CHANGED_OWNER) llResetScript();
		if(change & CHANGED_INVENTORY) state load_cards;
	}

	attach(key n)
	{
		llResetScript();
	}

	on_rez(integer start_param)
	{
		llResetScript();
	}
}

state run_program
{

	state_entry()
	{
		debug("Entering run_program state.");
		owner_say(TITLE, "Loading card " + notecard_name);
		init_from_card();
	}

	state_exit()
	{
		debug("Leaving run_program state.");
	}

	changed(integer change)
	{
		if (change & CHANGED_OWNER) llResetScript();
		if(change & CHANGED_INVENTORY) state load_cards;
	}

	dataserver(key request_id, string data)
	{
		if(request_id == notecard_query)
			parse_line(data);
	}

	listen(integer channel, string name, key id, string message)
	{
		// Survey commands
		if(is_owner_menu(id)) {
			if(message == DENY)
				set_deny();
			else if(message == READY)
				set_ready();
			else if(message == CHOOSE_CARD)
				state choose_card;
			else
				process_button(name, id, message);
		}
		else
			process_button(name, id, message);
	}

	touch_start(integer total_number)
	{
		key who = llDetectedKey(0);
		if(is_owner_menu(who))
			llDialog(who, "Survey Cat\n\nAs the owner you can enable or disable operation.\n\n" + lock_message,
			[READY, DENY, CHOOSE_CARD], dialog_channel);
		else if(lock == FALSE)
			show_dialog(who);
		else
			im(TITLE, who, "A survey is not available right now.");
	}
}

state bad_cards
{
	state_entry()
	{
		owner_say(TITLE, "Please load good cards and try again.");
		debug("Entering bad_cards state.");
	}

	state_exit()
	{
		debug("Leaving bad_cards state.");
	}


	changed(integer change)
	{
		if (change & CHANGED_OWNER) llResetScript();
		if(change & CHANGED_INVENTORY) state load_cards;
	}
}

state choose_card
{
	state_entry()
	{
		debug("Entering choose_card state.");
		debug("Available cards: " + llList2CSV(cards));
		owner_say(TITLE, "Please touch to choose which card to load.");

		choose_card_dialog(llGetOwner());
	}

	state_exit()
	{
		debug("Leaving choose_card state.");
	}

	changed(integer change)
	{
		if(change & CHANGED_OWNER) llResetScript();
		if(change & CHANGED_INVENTORY) state load_cards;
	}

	listen(integer channel, string name, key id, string message)
	{
		//  make sure the file exists and is a notecard
		if(llGetInventoryType(message) == INVENTORY_NOTECARD)
		{
			notecard_name = message;
			state run_program;
		}
	}

	touch_start(integer total_number)
	{
		key who = llDetectedKey(0);
		choose_card_dialog(who);
	}
}

state load_cards
{
	state_entry()
	{
		debug("Entering load_cards state.");
		get_card_list();
		integer card_count = llGetListLength(cards);
		if(card_count == 0)
		{
			owner_say("ERROR", "No " + NOTECARD_SUFFIX + " cards found.");
			state bad_cards;
		}

		if(card_count > 12)
		{
			owner_say("ERROR", "No more than 12 " + NOTECARD_SUFFIX + " cards supported at this time.");
			state bad_cards;
		}

		if(card_count == 1)
		{
			notecard_name = llList2String(cards, 0);
			owner_say(TITLE, "Only found one card. Auto-loading " + notecard_name);
			state run_program;
		}

		state choose_card;
	}

	state_exit()
	{
		debug("Leaving load_cards state.");
	}

	changed(integer change)
	{
		if (change & CHANGED_OWNER) llResetScript();
		// Need to bounce out of this state and back in in order to touch state_entry() again.
		if(change & CHANGED_INVENTORY) state default;
	}
}
