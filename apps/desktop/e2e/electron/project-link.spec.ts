import fs from 'node:fs';
import path from 'node:path';
import { expect, test } from '@playwright/test';
import { openDesktop, setViewport, waitForBackend } from './fixtures';

test('links an existing project from the GUI and places it in the world', async () => {
  const desktop = await openDesktop();
  try {
    const { page, home } = desktop;
    await waitForBackend(page);
    const captureDir =
      process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/world');
    if (process.env.ATK_CAPTURE === '1') {
      fs.mkdirSync(captureDir, { recursive: true });
      await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
      await expect(page.getByRole('button', { name: /No projects yet/ })).toBeVisible();
      for (const size of [
        { width: 1024, height: 640, key: 'compact' },
        { width: 1920, height: 1080, key: 'large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.getByRole('button', { name: 'Fit world' }).click();
        await page.screenshot({ path: path.join(captureDir, `world-empty-${size.key}.png`) });
      }
    }
    const projectPath = path.join(home, '.ai-workspace', 'repos', 'local', 'garden-api');
    fs.mkdirSync(projectPath, { recursive: true });
    fs.writeFileSync(path.join(projectPath, 'README.md'), '# Garden API\n');

    // The native picker itself is platform-owned. Stub only its result, then
    // exercise the real preload bridge and HTTP API, including an outside-root
    // rejection with a recoverable message before the successful retry.
    const pick = (selected: string) =>
      desktop.app.evaluate(({ dialog }, folder) => {
        dialog.showOpenDialog = async () => ({ canceled: false, filePaths: [folder] });
      }, selected);
    const outsideAllowedRoots =
      process.platform === 'win32'
        ? (process.env.SystemRoot ?? 'C:/Windows').replaceAll('\\', '/')
        : process.platform === 'darwin'
          ? '/System'
          : '/etc';
    expect(fs.existsSync(outsideAllowedRoots)).toBe(true);
    await pick(outsideAllowedRoots);

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    const emptyMarker = page.getByRole('button', { name: /No projects yet/ });
    await emptyMarker.click();
    await expect(page.getByRole('heading', { name: 'Projects' })).toBeVisible();
    await page.getByRole('button', { name: 'Link existing folder' }).click();

    const review = page.getByRole('dialog', { name: 'Review project link' });
    const outsideName = path.basename(outsideAllowedRoots);
    await expect(review.getByText(new RegExp(`projects/${outsideName}`))).toBeVisible();
    await review.getByRole('button', { name: `Link ${outsideName}` }).click();
    await expect(review.getByRole('alert')).toContainText('outside allowed roots');

    await pick(projectPath);
    await review.getByRole('button', { name: 'Choose another folder' }).click();
    await expect(review.getByText(projectPath)).toBeVisible();
    await expect(review.getByText(/projects\/garden-api/)).toBeVisible();
    await review.getByRole('button', { name: 'Link garden-api' }).click();
    await expect(review).toBeHidden();
    await expect(
      page.getByRole('region', { name: 'Receipts' }).getByText('Project linked', { exact: true }),
    ).toBeVisible();
    await page.getByRole('button', { name: 'Dismiss: Project linked' }).click();

    const linkPath = path.join(home, '.ai-workspace', 'projects', 'garden-api');
    await expect.poll(() => fs.realpathSync(linkPath)).toBe(fs.realpathSync(projectPath));
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await expect(page.getByRole('button', { name: /garden-api.*Project/ })).toBeVisible();
    await page.keyboard.press('Control+k');
    const palette = page.getByRole('dialog', { name: 'Commands' });
    await palette.getByLabel('Filter commands').fill('Open project garden-api');
    const projectCommand = palette.getByRole('option', { name: /Open project garden-api/ });
    await expect(projectCommand).toBeVisible();
    await projectCommand.click();
    await expect(page.getByRole('application', { name: 'Interior of garden-api' })).toBeVisible();
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    const world = page.getByRole('application', { name: 'Semantic workspace world' });
    if (process.env.ATK_CAPTURE === '1') {
      for (const size of [
        { width: 1024, height: 640, key: 'compact' },
        { width: 1920, height: 1080, key: 'large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.getByRole('button', { name: 'Fit world' }).click();
        await expect(world).toHaveAttribute('data-zoom', size.key === 'large' ? '48' : '16');
        await page.screenshot({ path: path.join(captureDir, `world-one-project-${size.key}.png`) });
      }
    }
    await setViewport(desktop.app, 1024, 640);
    await page.getByRole('button', { name: 'Fit world' }).click();
    await expect(world).toHaveAttribute('data-zoom', '16');
    await page.getByRole('button', { name: 'Pan map with arrow keys; Home fits the world' }).focus();
    await page.keyboard.press('Home');
    await expect(world).toHaveAttribute('data-zoom', '16');
    await setViewport(desktop.app, 1920, 1080);
    await page.getByRole('button', { name: 'Fit world' }).click();
    await expect(world).toHaveAttribute('data-zoom', '48');
    // Spatial and direct navigation share the same canonical destinations:
    // entering the house opens its project interior; its terminal desk opens
    // the actual Terminal route.
    await page.getByRole('button', { name: /garden-api · Project/ }).click();
    await expect(page.getByRole('application', { name: 'Interior of garden-api' })).toBeVisible();
    if (process.env.ATK_CAPTURE === '1') {
      const captureDir =
        process.env.ATK_CAPTURE_DIR ?? path.resolve(__dirname, '../../../../docs/desktop/assets/electron/world');
      fs.mkdirSync(captureDir, { recursive: true });
      await setViewport(desktop.app, 1024, 640);
      await page.screenshot({ path: path.join(captureDir, 'project-files-room-compact.png') });
      await setViewport(desktop.app, 1920, 1080);
      await page.screenshot({ path: path.join(captureDir, 'project-files-room-large.png') });
    }
    await page.getByRole('button', { name: /Files · Project files/ }).click();
    await expect(page).toHaveURL(/workspace\?[^#]*panel=files[^#]*project=garden-api/);
    await expect(page.getByRole('heading', { name: 'garden-api files' })).toBeVisible();
    await page.getByRole('button', { name: /README\.md/ }).click();
    await expect(page.getByText('# Garden API')).toBeVisible();
    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
    await page.getByRole('button', { name: /garden-api · Project/ }).click();
    await expect(page.getByRole('application', { name: 'Interior of garden-api' })).toBeVisible();
    await page.getByRole('button', { name: /Terminal · Terminal \/ PTY workstation/ }).click();
    await expect(page).toHaveURL(/terminal/);
    await expect(
      page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Terminal' }),
    ).toHaveAttribute('aria-current', 'page');

    await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Library' }).click();
    await page.getByLabel('Project', { exact: true }).selectOption('garden-api');
    const githubDir = path.join(projectPath, '.github');
    const copilotFile = path.join(githubDir, 'copilot-instructions.md');
    fs.mkdirSync(githubDir, { recursive: true });
    fs.writeFileSync(copilotFile, 'Repository-owned Copilot instructions.\n');
    await page.getByRole('button', { name: 'Review project setup' }).click();
    const copilotReview = page.getByRole('dialog', { name: 'Review GitHub Copilot setup' });
    await expect(copilotReview).toBeVisible();
    await expect(copilotReview).toContainText('Existing project instructions are preserved');
    await expect(copilotReview).toContainText(path.join(projectPath, '.github', 'copilot-instructions.md'));
    await expect(copilotReview.getByRole('button', { name: 'Install reviewed instructions' })).toHaveCount(0);
    expect(fs.readFileSync(copilotFile, 'utf8')).toBe('Repository-owned Copilot instructions.\n');
    await copilotReview.getByRole('button', { name: 'Close' }).click();
    fs.rmSync(copilotFile);
    await page.getByRole('button', { name: 'Review project setup' }).click();
    await expect(copilotReview).toContainText('Review one new file');
    await copilotReview.getByText('Review file contents').click();
    await expect(copilotReview.getByLabel('Copilot instructions file contents')).toContainText(
      '# Copilot Instructions Template',
    );
    await copilotReview.getByText('Review file contents').click();
    if (process.env.ATK_CAPTURE === '1') {
      const libraryDir = path.resolve(__dirname, '../../../../docs/desktop/assets/electron/library');
      fs.mkdirSync(libraryDir, { recursive: true });
      for (const size of [
        { width: 1024, height: 768, key: 'compact' },
        { width: 1440, height: 900, key: 'large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.screenshot({
          path: path.join(libraryDir, `copilot-project-review-${size.key}.png`),
          fullPage: true,
        });
      }
      await setViewport(desktop.app, 1280, 800);
    }
    fs.writeFileSync(copilotFile, 'Appeared after the review was prepared.\n');
    await copilotReview.getByRole('button', { name: 'Install reviewed instructions' }).click();
    await expect(copilotReview.getByRole('alert')).toContainText('changed after review');
    expect(fs.readFileSync(copilotFile, 'utf8')).toBe('Appeared after the review was prepared.\n');
    await copilotReview.getByRole('button', { name: 'Review again' }).click();
    await expect(copilotReview).toContainText('Existing project instructions are preserved');
    await expect(copilotReview.getByRole('button', { name: 'Install reviewed instructions' })).toHaveCount(0);
    await copilotReview.getByRole('button', { name: 'Close' }).click();
    fs.rmSync(copilotFile);
    await page.getByRole('button', { name: 'Review project setup' }).click();
    await expect(copilotReview).toContainText('Review one new file');
    await copilotReview.getByText('Review file contents').click();
    await copilotReview.getByText('Review file contents').click();
    await copilotReview.getByRole('button', { name: 'Install reviewed instructions' }).click();
    await expect(copilotReview).toContainText('Installed Agent Toolkit instructions for GitHub Copilot');
    expect(fs.readFileSync(path.join(projectPath, '.github', 'copilot-instructions.md'), 'utf8')).toContain(
      '# Copilot Instructions Template',
    );
    await copilotReview.getByRole('button', { name: 'Close' }).click();
    const bundledInstructions = fs.readFileSync(copilotFile, 'utf8');
    await expect(page.getByRole('region', { name: 'Installation evidence' })).toContainText(
      'GitHub Copilot · repository',
    );
    await expect(page.getByRole('button', { name: 'Review removal', exact: true })).toHaveCount(2);
    const githubSidecar = path.join(githubDir, 'settings.yml');
    fs.writeFileSync(githubSidecar, 'pull_request_targets: all\n');
    fs.writeFileSync(copilotFile, `${bundledInstructions}\nUser-owned addition.\n`);
    await page.getByRole('button', { name: 'Review removal' }).last().click();
    const protectedCopilot = page.getByRole('dialog', { name: 'Review GitHub Copilot removal' });
    await expect(protectedCopilot).toContainText('changed after Agent Toolkit created it');
    await expect(protectedCopilot.getByRole('button', { name: 'Remove reviewed instructions' })).toHaveCount(0);
    await protectedCopilot.getByRole('button', { name: 'Close' }).click();
    fs.writeFileSync(copilotFile, bundledInstructions);
    await page.getByRole('button', { name: 'Review removal' }).last().click();
    const safeCopilotRemoval = page.getByRole('dialog', { name: 'Review GitHub Copilot removal' });
    await expect(safeCopilotRemoval.getByRole('button', { name: 'Remove reviewed instructions' })).toBeEnabled();
    await safeCopilotRemoval.getByRole('button', { name: 'Remove reviewed instructions' }).click();
    await expect(safeCopilotRemoval).toContainText('Removed the unchanged Agent Toolkit Copilot instructions');
    expect(fs.existsSync(copilotFile)).toBe(false);
    expect(fs.readFileSync(githubSidecar, 'utf8')).toBe('pull_request_targets: all\n');
    await safeCopilotRemoval.getByRole('button', { name: 'Close' }).click();

    if (process.env.ATK_CAPTURE === '1') {
      // Add two more registered projects through the same reviewed GUI flow,
      // then capture the actual multi-house world at both product scales.
      for (const name of ['maple-worker', 'river-notes']) {
        const target = path.join(home, '.ai-workspace', 'repos', 'local', name);
        fs.mkdirSync(target, { recursive: true });
        fs.writeFileSync(path.join(target, 'README.md'), `# ${name}\n`);
        await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'Workspace' }).click();
        await page.getByRole('button', { name: 'Link existing folder' }).click();
        const review = page.getByRole('dialog', { name: 'Review project link' });
        await pick(target);
        await review.getByRole('button', { name: 'Choose another folder' }).click();
        await expect(review.getByText(new RegExp(`projects/${name}`))).toBeVisible();
        await review.getByRole('button', { name: `Link ${name}` }).click();
        await expect(review).toBeHidden();
        await page.getByRole('button', { name: 'Dismiss: Project linked' }).click();
      }
      await page.getByRole('navigation', { name: 'Destinations' }).getByRole('link', { name: 'World' }).click();
      await expect(page.getByRole('button', { name: /garden-api.*Project/ })).toBeVisible();
      for (const size of [
        { width: 1024, height: 640, key: 'compact' },
        { width: 1920, height: 1080, key: 'large' },
      ]) {
        await setViewport(desktop.app, size.width, size.height);
        await page.getByRole('button', { name: 'Fit world' }).click();
        await expect(page.getByRole('application', { name: 'Semantic workspace world' })).toHaveAttribute(
          'data-zoom',
          size.key === 'large' ? '32' : '16',
        );
        await page.screenshot({ path: path.join(captureDir, `world-several-projects-${size.key}.png`) });
      }
    }
  } finally {
    await desktop.close();
  }
});
