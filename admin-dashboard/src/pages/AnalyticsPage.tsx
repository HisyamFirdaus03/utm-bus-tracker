import { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Grid,
  Snackbar,
  Stack,
  Typography,
} from '@mui/material';
import {
  AltRoute as RouteIcon,
  AutoFixHigh as OptimizeIcon,
  DirectionsBus as BusIcon,
  Download as DownloadIcon,
  Feedback as FeedbackIcon,
  PeopleAlt as PeopleIcon,
} from '@mui/icons-material';
import { OptimizeDistributionDialog } from '../components/OptimizeDistributionDialog';
import { BarChart } from '@mui/x-charts/BarChart';
import { LineChart } from '@mui/x-charts/LineChart';

import {
  downloadReport,
  getDemandByStop,
  getFeedbackDaily,
  getOverview,
  getRidershipDaily,
  getRidershipHourly,
  type DailyPoint,
  type FeedbackPoint,
  type HourPoint,
  type Overview,
  type StopPoint,
} from '../api/analytics';

type Bundle = {
  overview: Overview;
  ridershipDaily: DailyPoint[];
  ridershipHourly: HourPoint[];
  demandByStop: StopPoint[];
  feedbackDaily: FeedbackPoint[];
};

function shortDate(iso: string): string {
  // "2026-05-22" -> "May 22"
  const d = new Date(iso + 'T00:00:00Z');
  return d.toLocaleDateString(undefined, { month: 'short', day: 'numeric' });
}

export function AnalyticsPage() {
  const [data, setData] = useState<Bundle | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [downloading, setDownloading] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [optimizeOpen, setOptimizeOpen] = useState(false);

  async function handleExport() {
    setDownloading(true);
    try {
      await downloadReport(30);
      setToast('Report downloaded');
    } catch (e) {
      setToast(e instanceof Error ? e.message : 'Failed to download report');
    } finally {
      setDownloading(false);
    }
  }

  useEffect(() => {
    (async () => {
      try {
        const [overview, ridershipDaily, ridershipHourly, demandByStop, feedbackDaily] =
          await Promise.all([
            getOverview(),
            getRidershipDaily(30),
            getRidershipHourly(),
            getDemandByStop(10),
            getFeedbackDaily(30),
          ]);
        setData({ overview, ridershipDaily, ridershipHourly, demandByStop, feedbackDaily });
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Failed to load');
      }
    })();
  }, []);

  if (error) {
    return <Alert severity="error">{error}</Alert>;
  }

  if (!data) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}>
        <CircularProgress />
      </Box>
    );
  }

  const tiles = [
    {
      label: 'Riders (last 24h)',
      value: data.overview.riders_last_24h.toLocaleString(),
      icon: <PeopleIcon />,
    },
    {
      label: 'Active buses',
      value: `${data.overview.buses_active}/${data.overview.buses_total}`,
      icon: <BusIcon />,
    },
    {
      label: 'Active routes',
      value: `${data.overview.routes_active}/${data.overview.routes_total}`,
      icon: <RouteIcon />,
    },
    {
      label: 'Feedback (open)',
      value: `${data.overview.feedback_new + data.overview.feedback_in_progress}/${data.overview.feedback_total}`,
      icon: <FeedbackIcon />,
    },
  ];

  return (
    <Stack spacing={3}>
      <Stack direction="row" spacing={2} sx={{ alignItems: 'center', justifyContent: 'space-between' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Analytics
        </Typography>
        <Stack direction="row" spacing={1}>
          <Button
            variant="outlined"
            color="primary"
            startIcon={<OptimizeIcon />}
            onClick={() => setOptimizeOpen(true)}
          >
            Optimize Bus Distribution
          </Button>
          <Button
            variant="contained"
            color="primary"
            startIcon={downloading ? <CircularProgress size={16} sx={{ color: 'white' }} /> : <DownloadIcon />}
            disabled={downloading}
            onClick={handleExport}
          >
            {downloading ? 'Generating…' : 'Export PDF'}
          </Button>
        </Stack>
      </Stack>

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

      <Grid container spacing={2}>
        <Grid size={{ xs: 12, lg: 8 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Ridership — last 30 days
              </Typography>
              <LineChart
                height={280}
                xAxis={[
                  {
                    data: data.ridershipDaily.map((p) => p.date),
                    scaleType: 'band',
                    valueFormatter: shortDate,
                  },
                ]}
                series={[
                  {
                    data: data.ridershipDaily.map((p) => p.riders),
                    label: 'Riders',
                    color: '#8B1A2B',
                    area: true,
                  },
                ]}
                margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
              />
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, lg: 4 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Peak hours (avg riders / hour)
              </Typography>
              <BarChart
                height={280}
                xAxis={[
                  {
                    data: data.ridershipHourly.map((p) => p.hour),
                    scaleType: 'band',
                    valueFormatter: (h: number) => `${h}:00`,
                  },
                ]}
                series={[
                  {
                    data: data.ridershipHourly.map((p) => p.avg_riders),
                    label: 'Avg riders',
                    color: '#D42A2A',
                  },
                ]}
                margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
              />
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, lg: 7 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Top stops by demand — last 30 days
              </Typography>
              {data.demandByStop.length === 0 ? (
                <Typography variant="body2" color="text.secondary">
                  No ridership data yet. Seed with{' '}
                  <code>python manage.py seed_data_logs</code>.
                </Typography>
              ) : (
                <BarChart
                  height={280}
                  layout="horizontal"
                  yAxis={[
                    {
                      data: data.demandByStop.map((p) => p.stop_name),
                      scaleType: 'band',
                    },
                  ]}
                  series={[
                    {
                      data: data.demandByStop.map((p) => p.riders),
                      label: 'Riders',
                      color: '#8B1A2B',
                    },
                  ]}
                  margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
                />
              )}
            </CardContent>
          </Card>
        </Grid>

        <Grid size={{ xs: 12, lg: 5 }}>
          <Card>
            <CardContent>
              <Typography variant="subtitle1" sx={{ fontWeight: 600, mb: 1 }}>
                Feedback submissions — last 30 days
              </Typography>
              <LineChart
                height={280}
                xAxis={[
                  {
                    data: data.feedbackDaily.map((p) => p.date),
                    scaleType: 'band',
                    valueFormatter: shortDate,
                  },
                ]}
                series={[
                  {
                    data: data.feedbackDaily.map((p) => p.count),
                    label: 'Submissions',
                    color: '#D42A2A',
                  },
                ]}
                margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
              />
            </CardContent>
          </Card>
        </Grid>
      </Grid>

      <Snackbar
        open={toast !== null}
        autoHideDuration={3500}
        onClose={() => setToast(null)}
        message={toast ?? ''}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
      />

      <OptimizeDistributionDialog
        open={optimizeOpen}
        onClose={() => setOptimizeOpen(false)}
      />
    </Stack>
  );
}
