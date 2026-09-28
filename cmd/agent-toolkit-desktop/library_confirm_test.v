module main

// Remove-confirm contract (M3): keyboard Enter on a destructive Library
// primary arms on first press and fires only on the confirming second press.
// Clicks bypass the gate; selection and navigation changes disarm it.

fn test_library_confirm_remove_arms_first_enter() {
	mut app := &GuiApp{}
	assert !library_confirm_remove(mut app, 'skill:review', 'skill review'), 'first Enter arms, never fires'
	assert app.library_arm == 'skill:review', 'arm must record kind:id'
	assert app.inspector_msg.contains('skill review'), 'arm message must name the item: ${app.inspector_msg}'
	assert app.inspector_msg.contains('Esc'), 'arm message must name the way out: ${app.inspector_msg}'
}

fn test_library_confirm_remove_fires_on_second_enter() {
	mut app := &GuiApp{
		library_arm: 'skill:review'
	}
	assert library_confirm_remove(mut app, 'skill:review', 'skill review'), 'confirming Enter fires'
	assert app.library_arm == '', 'firing must disarm'
}

fn test_library_confirm_remove_rearms_on_different_item() {
	mut app := &GuiApp{
		library_arm: 'skill:review'
	}
	assert !library_confirm_remove(mut app, 'agent:review', 'agent review'), 'a different id re-arms, never fires'
	assert app.library_arm == 'agent:review'
}

fn test_library_selection_change_disarms() {
	mut app := &GuiApp{
		selected_panel: 1
		library_arm: 'skill:review'
	}
	library_set_selected(mut app, 2)
	assert app.library_arm == '', 'a new selection is a new intent'
}

fn test_library_navigation_disarms() {
	mut app := &GuiApp{
		selected_panel: 1
		library_arm: 'skill:review'
	}
	select_panel(mut app, 6)
	assert app.library_arm == '', 'arms never cross destinations'
	assert app.selected_panel == 6
}
