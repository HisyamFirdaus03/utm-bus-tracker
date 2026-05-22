import { createTheme } from '@mui/material/styles';

// Matches the Flutter app's palette (mobile/lib/theme/app_theme.dart):
// dark crimson primary, red secondary, white surfaces.
export const theme = createTheme({
  palette: {
    primary: { main: '#8B1A2B' },
    secondary: { main: '#D42A2A' },
    background: { default: '#F5F5F5' },
  },
  typography: {
    fontFamily: '"Inter", "Roboto", "Helvetica", "Arial", sans-serif',
    h6: { fontWeight: 600 },
  },
  components: {
    MuiAppBar: {
      defaultProps: { elevation: 0, color: 'default' },
      styleOverrides: {
        root: { backgroundColor: '#FFFFFF', borderBottom: '1px solid #E0E0E0' },
      },
    },
    MuiButton: { defaultProps: { disableElevation: true } },
  },
});
