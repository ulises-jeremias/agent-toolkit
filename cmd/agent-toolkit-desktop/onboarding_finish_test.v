module main

// Onboarding finish contract: exactly two setup paths, one primary finish
// action on the review stage. The footer advances stages 0..3; on stage 4 the
// in-strip CTA ('Finish setup and enter the office →') is the single mouse
// path while Back/Skip/Details stay live. Keyboard (Enter/Right/n) finishes
// independently via onboarding_advance.

fn finish_layout() OnboardingLayout {
	app := &GuiApp{}
	return onboarding_layout(app, 1280, 800)
}

fn test_onboarding_setup_choice_is_two_paths() {
	assert onboarding_choices.len == 2, 'setup choice must offer exactly two paths, not a three-way guess'
	assert onboarding_choices[0] == 'Start fresh'
	assert onboarding_choices[1] == 'Use my existing setup'
}

fn test_onboarding_setup_cards_fit_side_by_side() {
	l := finish_layout()
	sx, sy, sw, _ := onboarding_sec_rect(l, 0)
	mut prev_end := sx
	for i in 0 .. onboarding_choices.len {
		cx, cy, cw, ch := onboarding_card_rect(l, 0, i, onboarding_choices.len)
		assert ch > 0, 'setup card ${i} must render'
		assert cx >= sx && cx + cw <= sx + sw, 'setup card ${i} must stay inside its sheet'
		assert cx >= prev_end, 'setup card ${i} must not overlap its neighbour'
		assert cy >= sy, 'setup card ${i} must start below the sheet title'
		prev_end = cx + cw
	}
}

fn test_onboarding_choice_click_selects_path() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: 0
		onboarding_choice: 0
	}
	l := onboarding_layout(app, 1280, 800)
	cx, cy, cw, ch := onboarding_card_rect(l, 0, 1, onboarding_choices.len)
	assert onboarding_click(mut app, cx + cw / 2, cy + ch / 2, 1280, 800), 'existing-setup card click must be consumed'
	assert app.onboarding_choice == 1, 'click must select the existing-setup path'
	assert app.onboarding_step == 0, 'choosing a path must not advance the stage'
	assert onboarding_choice_verb(app) == 'Use existing'
	app.onboarding_choice = 0
	assert onboarding_choice_verb(app) == 'Start fresh'
}

fn test_onboarding_footer_advance_dead_on_review_stage() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: onboarding_last_stage
	}
	l := onboarding_layout(app, 1280, 800)
	nx, ny, nw, nh := onboarding_next_rect(l)
	cx, cy, cw, ch := onboarding_cta_rect(l)
	assert ch == 0 || ny >= cy + ch, 'footer next must not overlap the review CTA'
	onboarding_click(mut app, nx + nw / 2, ny + nh / 2, 1280, 800)
	assert app.onboarding_step == onboarding_last_stage, 'footer click on review must not advance or finish'
	assert app.show_onboarding, 'footer click on review must not dismiss the journey'
}

fn test_onboarding_footer_hover_ignores_next_on_review_stage() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: onboarding_last_stage
	}
	l := onboarding_layout(app, 1280, 800)
	nx, ny, nw, nh := onboarding_next_rect(l)
	onboarding_hover_at(mut app, nx + nw / 2, ny + nh / 2, 1280, 800)
	assert app.onboarding_hover != 11, 'hidden footer next must not take hover on review'
}

fn test_onboarding_footer_back_alive_on_review_stage() {
	mut app := &GuiApp{
		show_onboarding: true
		onboarding_step: onboarding_last_stage
	}
	l := onboarding_layout(app, 1280, 800)
	bx, by, bw, bh := onboarding_back_rect(l)
	assert onboarding_click(mut app, bx + bw / 2, by + bh / 2, 1280, 800), 'Back click must be consumed'
	assert app.onboarding_step == onboarding_last_stage - 1, 'Back must step off the review stage'
	assert app.show_onboarding, 'Back must hold the journey'
}
