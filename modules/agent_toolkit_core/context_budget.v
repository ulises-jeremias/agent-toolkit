module agent_toolkit_core

// context_budget — token/char clip parity with Python cli/context_budget.py:455.
// Python: def clip(text: str, budget: int = 2000) -> str: " ".join(tokens[:2000])
// V parity: char-slice clip to budget (devcompanion.v clips plan[..2000], memory inject clips 2000 chars)
// Budget is ~2000 tokens ≈ 8000 chars (chars/4), but V retains 2000-char clip for wire parity.
pub const context_budget_default = 2000

// context_clip clips text to budget chars (parity with Python clip 2000 tokens).
// If text exceeds budget, returns first budget chars; otherwise returns text unchanged.
pub fn context_clip(text string, budget int) string {
	if budget <= 0 {
		return text
	}
	if text.len <= budget {
		return text
	}
	return text[..budget]
}

// context_clip_default clips to the default 2000-char budget.
pub fn context_clip_default(text string) string {
	return context_clip(text, context_budget_default)
}
