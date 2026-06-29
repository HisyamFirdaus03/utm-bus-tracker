import { useState } from 'react';
import { Box } from '@mui/material';

/**
 * Renders the official UTM logo from `public/utm-logo.png` when present.
 * Falls back to a crimson "UTM" badge if the file is missing, so the
 * layout never breaks before the asset is added.
 *
 * To use the real logo: save it (ideally the round crest, square-ish) to
 *   admin-dashboard/public/utm-logo.png
 */
export function UtmLogo({ height = 36 }: { height?: number }) {
  const [failed, setFailed] = useState(false);

  if (!failed) {
    return (
      <Box
        component="img"
        src="/utm-logo.png"
        alt="UTM"
        onError={() => setFailed(true)}
        sx={{ height, width: 'auto', maxWidth: height * 3, display: 'block', objectFit: 'contain' }}
      />
    );
  }

  return (
    <Box
      sx={{
        width: height,
        height,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        bgcolor: 'primary.main',
        color: 'white',
        borderRadius: 1.5,
        fontWeight: 800,
        fontSize: height * 0.36,
        letterSpacing: '0.02em',
        flexShrink: 0,
      }}
    >
      UTM
    </Box>
  );
}
