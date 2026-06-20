export const THEMES = ['light', 'dark', 'auto'];

export const SURFACES = [
  'Home/Status',
  'Assets',
  'Upload Sessions',
  'Variants/Jobs',
  'Runtime/Doctor',
  'Actions',
];

export const STATUS_STATES = [
  'ready',
  'processing',
  'warning',
  'danger',
  'quarantine',
  'info',
];

export const STATUS_TOKEN_NAMES = [
  'status-ready',
  'status-processing',
  'status-warning',
  'status-danger',
  'status-quarantine',
  'status-info',
];

export const COMPONENTS = [
  'shell',
  'nav',
  'table',
  'status-chip',
  'button',
  'theme-picker',
  'confirm-dialog',
  'drawer',
  'toast',
  'empty-state',
  'skeleton',
];

export const MOTION_TOKENS = [
  'press',
  'popover',
  'toast',
  'transition',
  'easing',
  'easing-standard',
  'easing-decelerate',
  'easing-accelerate',
];

export const MIN_TARGET_PX = 44;

export const CONSOLE_CONTRAST_PAIRS = [
  { fg: 'text-on-brand', bg: 'brand', theme: 'light', min: 4.5, context: 'buttons primary text' },
  { fg: 'text-on-brand', bg: 'brand-hover', theme: 'light', min: 4.5, context: 'buttons primary hover text' },
  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'buttons secondary text' },
  { fg: 'text', bg: 'surface', theme: 'light', min: 4.5, context: 'buttons quiet text' },
  { fg: 'text-on-brand', bg: 'status-danger', theme: 'light', min: 4.5, context: 'buttons destructive text' },
  { fg: 'text-secondary', bg: 'surface-sunken', theme: 'light', min: 4.5, context: 'buttons disabled text' },
  { fg: 'border-strong', bg: 'surface-raised', theme: 'light', min: 3, context: 'buttons secondary border non-text' },

  // Dark theme flips brand/danger to luminous fills (rindle-green, dark-danger); the
  // on-brand foreground must be ink, not warm-shell, to stay legible. These pairs
  // enforce that — the gap that let cream-on-green (1.81:1) ship unflagged.
  { fg: 'text-on-brand', bg: 'brand', theme: 'dark', min: 4.5, context: 'buttons primary text (dark)' },
  { fg: 'text-on-brand', bg: 'brand-hover', theme: 'dark', min: 4.5, context: 'buttons primary hover text (dark)' },
  { fg: 'text-on-brand', bg: 'status-danger', theme: 'dark', min: 4.5, context: 'buttons destructive text (dark)' },

  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'table text on surface-raised' },
  { fg: 'text-secondary', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'table secondary text on surface-raised' },

  { fg: 'focus-ring', bg: 'surface', theme: 'light', min: 3, context: 'focus ring on surface non-text' },
  { fg: 'focus-ring', bg: 'dark-bg', theme: 'dark', min: 3, context: 'focus ring on dark-bg non-text' },

  ...STATUS_STATES.map((state) => ({
    fg: `status-${state}`,
    bg: `status-${state}-surface`,
    theme: 'light',
    min: 4.5,
    context: `status chips ${state} foreground on light surface`,
  })),

  ...STATUS_STATES.map((state) => ({
    fg: `status-${state}`,
    bg: `status-${state}-surface`,
    theme: 'dark',
    min: 4.5,
    context: `status chips ${state} foreground on dark surface`,
  })),

  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'toasts text on surface-raised' },
  { fg: 'status-ready', bg: 'surface-raised', theme: 'light', min: 3, context: 'toasts success marker non-text' },
  { fg: 'status-warning', bg: 'surface-raised', theme: 'light', min: 3, context: 'toasts warning marker non-text' },
  { fg: 'status-danger', bg: 'surface-raised', theme: 'light', min: 3, context: 'toasts danger marker non-text' },
  { fg: 'status-info', bg: 'surface-raised', theme: 'light', min: 3, context: 'toasts info marker non-text' },

  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'confirm dialog text on surface-raised' },
  { fg: 'text', bg: 'surface-raised', theme: 'dark', min: 4.5, context: 'confirm dialog text on dark surface-raised' },
  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'drawer text on surface-raised' },
  { fg: 'text', bg: 'surface-raised', theme: 'dark', min: 4.5, context: 'drawer text on dark surface-raised' },
  { fg: 'text', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'empty state text on surface-raised' },
  { fg: 'text-secondary', bg: 'surface-raised', theme: 'light', min: 4.5, context: 'empty state secondary text on surface-raised' },

  { fg: 'border-strong', bg: 'surface-raised', theme: 'light', min: 3, context: 'skeleton non-text boundary' },
  { fg: 'border-strong', bg: 'surface-raised', theme: 'dark', min: 3, context: 'skeleton dark non-text boundary' },
  { fg: 'border-strong', bg: 'surface', theme: 'light', min: 3, context: 'borders on surface non-text' },
  { fg: 'border-strong', bg: 'surface-raised', theme: 'dark', min: 3, context: 'borders on dark surface-raised non-text' },

  // Dark elevation ladder: primary dark text must clear AA on every raised tint step
  // (elevation-1/2/3). elevation-0 == dark-bg is the app base, already covered by the
  // dark primary-text pair above. Raw hexes resolve directly via color.raw.
  { fg: 'dark-text', bg: 'elevation-1', theme: 'dark', min: 4.5, context: 'elevation-1 raised panel dark text' },
  { fg: 'dark-text', bg: 'elevation-2', theme: 'dark', min: 4.5, context: 'elevation-2 nested/hover surface dark text' },
  { fg: 'dark-text', bg: 'elevation-3', theme: 'dark', min: 4.5, context: 'elevation-3 overlay/modal dark text' },
];
