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
import { BarChart } from '@mui/x-charts/BarChart';
import { LineChart } from '@mui/x-charts/LineChart';

import { listBuses } from '../api/buses';
import { listRoutes, listStops } from '../api/routes';
import {
  getRidershipDaily,
  getRidershipHourly,
  type DailyPoint,
  type HourPoint,
} from '../api/analytics';

type Counts = {
  routes: number;
  buses: number;
  activeBuses: number;
  stops: number;
};

function shortDate(iso: string): string {
  const d = new Date(iso + 'T00:00:00Z');
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function DashboardPage() {
  const [counts, setCounts] = useState<Counts | null>(null);
  const [ridership, setRidership] = useState<DailyPoint[] | null>(null);
  const [hourly, setHourly] = useState<HourPoint[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    (async () => {
      try {
        const [routes, buses, stops, ridershipDaily, ridershipHourly] = await Promise.all([
          listRoutes(),
          listBuses(),
          listStops(),
          getRidershipDaily(30),
          getRidershipHourly(),
        ]);
        setCounts({
          routes: routes.length,
          buses: buses.length,
          activeBuses: buses.filter((b) => b.status === 'active').length,
          stops: stops.length,
        });
        setRidership(ridershipDaily);
        setHourly(ridershipHourly);
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

      <Grid container spacing={2} sx={{ alignItems: 'stretch' }}>
        <Grid size={{ xs: 12, lg: 8 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Ridership — last 30 days
              </Typography>
              {ridership && ridership.length > 0 ? (
                <LineChart
                  height={300}
                  xAxis={[
                    {
                      data: ridership.map((p) => p.date),
                      scaleType: 'band',
                      valueFormatter: shortDate,
                    },
                  ]}
                  series={[
                    {
                      data: ridership.map((p) => p.riders),
                      label: 'Riders',
                      color: '#8B1A2B',
                      area: true,
                    },
                  ]}
                  margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
                />
              ) : (
                <Typography variant="body2" color="text.secondary">
                  No ridership data yet. Seed with <code>python manage.py seed_data_logs</code>.
                </Typography>
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, lg: 4 }}>
          <Card sx={{ height: '100%' }}>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Peak hours (avg riders / hour)
              </Typography>
              {hourly && hourly.length > 0 ? (
                <BarChart
                  height={300}
                  xAxis={[
                    {
                      data: hourly.map((p) => p.hour),
                      scaleType: 'band',
                      valueFormatter: (h: number) => `${h}:00`,
                    },
                  ]}
                  series={[
                    {
                      data: hourly.map((p) => p.avg_riders),
                      label: 'Avg riders',
                      color: '#D42A2A',
                    },
                  ]}
                  margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
                />
              ) : (
                <Typography variant="body2" color="text.secondary">
                  No ridership data yet.
                </Typography>
              )}
            </CardContent>
          </Card>
        </Grid>
      </Grid>
    </Stack>
  );
}
