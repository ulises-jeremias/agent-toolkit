/**
 * Tracks individual Operations dialog openings, not just dialog names.
 * A mutation callback retains the opening token it was created under.
 * Invalidation is synchronous so a close/reopen cannot reuse an old token.
 */
export class DialogOpeningGuard {
  private dialog: string | null = null;
  private epoch = 0;

  observe(dialog: string | null): void {
    if (this.dialog !== dialog) {
      this.dialog = dialog;
      this.epoch += 1;
    }
  }

  invalidate(): void {
    this.epoch += 1;
  }

  capture(dialog: string): () => boolean {
    const epoch = this.epoch;
    return () => this.dialog === dialog && this.epoch === epoch;
  }
}
