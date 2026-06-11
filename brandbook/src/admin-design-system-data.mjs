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
    bg: 'surface-raised',
    theme: 'dark',
    min: 4.5,
    context: `status chips ${state} dark foreground/background`,
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
];
