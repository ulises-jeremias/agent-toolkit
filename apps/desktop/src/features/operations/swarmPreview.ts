/** A successful legacy preview can ignore `project_id`; require explicit backend evidence. */
export function hasProjectBoundSwarmPreview(data: Record<string, string> | undefined, projectId: string): boolean {
  return data?.['project_id'] === projectId && Boolean(data['project_path']?.trim());
}
