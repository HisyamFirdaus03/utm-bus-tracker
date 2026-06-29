import { createTheme } from '@mui/material/styles';

// Design tokens extracted from the Figma PSM-1 admin screens
// (View Analytic, Manage Bus, Feedback Response). Cool light-gray page,
// soft rounded white cards, dark-crimson primary, Poppins typography.
export const tokens = {
  crimson: '#8B1A2B',
  crimsonDeep: '#6E1422',
  crimsonSoft: '#F4E7E9',
  red: '#D42A2A',
  orange: '#F5A623',
  ink: '#1A1B2E', // headings / near-black (cool)
  inkMuted: '#6B6C7E', // secondary text
  inkFaint: '#9A9BAA', // tertiary / placeholders
  page: '#F1F2F6', // app background
  card: '#FFFFFF',
  border: '#ECEDF2',
  success: '#2E9E5B',
  fontSans: '"Poppins", "Inter", "Helvetica", "Arial", sans-serif',
  fontMono: '"JetBrains Mono", "Roboto Mono", monospace',
  radius: 16, // card radius
  shadowCard: '0 4px 20px rgba(26, 27, 46, 0.05)',
  shadowPop: '0 8px 28px rgba(26, 27, 46, 0.12)',
};

export const theme = createTheme({
  palette: {
    primary: { main: tokens.crimson, dark: tokens.crimsonDeep, contrastText: '#FFFFFF' },
    secondary: { main: tokens.red },
    success: { main: tokens.success },
    warning: { main: tokens.orange },
    background: { default: tokens.page, paper: tokens.card },
    text: { primary: tokens.ink, secondary: tokens.inkMuted },
    divider: tokens.border,
  },
  shape: { borderRadius: 10 },
  typography: {
    fontFamily: tokens.fontSans,
    h4: { fontWeight: 700, color: tokens.ink, letterSpacing: '-0.01em' },
    h5: { fontWeight: 700, color: tokens.ink, letterSpacing: '-0.01em' },
    h6: { fontWeight: 700, color: tokens.ink, letterSpacing: '-0.01em' },
    subtitle1: { fontWeight: 600 },
    subtitle2: { fontWeight: 600 },
    button: { fontWeight: 600, textTransform: 'none' },
    body2: { color: tokens.inkMuted },
  },
  components: {
    MuiAppBar: {
      defaultProps: { elevation: 0, color: 'default' },
      styleOverrides: {
        root: {
          backgroundColor: tokens.card,
          color: tokens.ink,
          borderBottom: `1px solid ${tokens.border}`,
        },
      },
    },
    MuiDrawer: {
      styleOverrides: {
        paper: { backgroundColor: tokens.card, borderRight: `1px solid ${tokens.border}` },
      },
    },
    MuiPaper: {
      styleOverrides: {
        rounded: { borderRadius: tokens.radius },
        elevation1: { boxShadow: tokens.shadowCard },
      },
    },
    MuiCard: {
      defaultProps: { elevation: 0 },
      styleOverrides: {
        root: {
          borderRadius: tokens.radius,
          border: `1px solid ${tokens.border}`,
          boxShadow: tokens.shadowCard,
        },
      },
    },
    MuiButton: {
      defaultProps: { disableElevation: true },
      styleOverrides: {
        root: ({ ownerState }) => ({
          borderRadius: 10,
          paddingInline: 18,
          paddingBlock: 8,
          fontWeight: 600,
          ...(ownerState.variant === 'contained' &&
            ownerState.color === 'primary' && {
              boxShadow: '0 6px 16px rgba(139, 26, 43, 0.24)',
              '&:hover': { backgroundColor: tokens.crimsonDeep },
            }),
        }),
      },
    },
    MuiChip: {
      styleOverrides: { root: { fontWeight: 600, borderRadius: 8 } },
    },
    MuiTextField: {
      defaultProps: { size: 'small' },
    },
    MuiOutlinedInput: {
      styleOverrides: { root: { borderRadius: 10 } },
    },
    MuiTableHead: {
      styleOverrides: {
        root: {
          '& .MuiTableCell-head': {
            fontWeight: 700,
            color: tokens.inkMuted,
            backgroundColor: '#FAFAFC',
            borderBottom: `1px solid ${tokens.border}`,
          },
        },
      },
    },
    MuiTableCell: {
      styleOverrides: { root: { borderBottom: `1px solid ${tokens.border}` } },
    },
    MuiMenu: {
      styleOverrides: {
        paper: { borderRadius: 12, boxShadow: tokens.shadowPop, border: `1px solid ${tokens.border}` },
      },
    },
    MuiDialog: {
      styleOverrides: { paper: { borderRadius: tokens.radius } },
    },
  },
});
