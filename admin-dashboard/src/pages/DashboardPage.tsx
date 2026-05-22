import { useEffect, useState } from 'react';
import {
  Box,
  Card,
  CardContent,
  CircularProgress,
  Grid,
  Stack,
  Typography,
} from '@mui/material';
import {
  AltRoute as RouteIcon,
  DirectionsBus as BusIcon,
  CheckCircle as ActiveIcon,
  LocationOn as StopIcon,
} from '@mui/icons-material';

import { listBuses } from '../api/buses';
import { listRoutes, listStops } from '../api/routes';

type Counts = {
  routes: number;
  buses: number;
  activeBuses: number;
  stops: number;
};

export function DashboardPage() {
  const [counts, setCounts] = useState<Counts | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const [routes, buses, stops] = await Promise.all([
          listRoutes(),
          listBuses(),
          listStops(),
        ]);
        setCounts({
          routes: routes.length,
          buses: buses.length,
          activeBuses: buses.filter((b) => b.status === 'active').length,
          stops: stops.length,
        });
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load');
      }
    })();
  }, []);

  if (error) return <Typography color="error">{error}</Typography>;
  if (!counts) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}>
        <CircularProgress />
      </Box>
    );
  }

  const tiles = [
    { label: 'Routes', value: counts.routes, icon: <RouteIcon /> },
    { label: 'Buses', value: counts.buses, icon: <BusIcon /> },
    { label: 'Active buses', value: counts.activeBuses, icon: <ActiveIcon /> },
    { label: 'Stops', value: counts.stops, icon: <StopIcon /> },
  ];

  return (
    <Stack spacing={3}>
      <Typography variant="h5" sx={{ fontWeight: 600 }}>
        Overview
      </Typography>
      <Grid container spacing={2}>
        {tiles.map((t) => (
          <Grid key={t.label} size={{ xs: 12, sm: 6, md: 3 }}>
            <Card>
              <CardContent>
                <Stack direction="row" spacing={2} sx={{ alignItems: 'center' }}>
                  <Box
                    sx={{
                      p: 1,
                      borderRadius: 1,
                      bgcolor: 'primary.main',
                      color: 'white',
                      display: 'flex',
                    }}
                  >
                    {t.icon}
                  </Box>
                  <Box>
                    <Typography variant="body2" color="text.secondary">
                      {t.label}
                    </Typography>
                    <Typography variant="h5" sx={{ fontWeight: 700 }}>
                      {t.value}
                    </Typography>
                  </Box>
                </Stack>
              </CardContent>
            </Card>
          </Grid>
        ))}
      </Grid>
    </Stack>
  );
}
