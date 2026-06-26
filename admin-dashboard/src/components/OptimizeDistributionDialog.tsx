import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Chip,
  CircularProgress,
  Dialog,
  DialogActions,
  DialogContent,
  DialogTitle,
  MenuItem,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import { BarChart } from '@mui/x-charts/BarChart';

import { predictDemand, type DemandResult } from '../api/analytics';

const WEATHER_OPTIONS = ['clear', 'cloudy', 'rain'];

function todayISO(): string {
  return new Date().toISOString().slice(0, 10);
}

type Props = {
  open: boolean;
  onClose: () => void;
};

export function OptimizeDistributionDialog({ open, onClose }: Props) {
  const [date, setDate] = useState(todayISO());
  const [hour, setHour] = useState(new Date().getHours());
  const [weather, setWeather] = useState('clear');
  const [result, setResult] = useState<DemandResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) {
      // Auto-run once on open with today/current-hour/clear so the user
      // sees results immediately without having to click Run.
      void run();
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [open]);

  async function run() {
    setLoading(true);
    setError(null);
    try {
      const r = await predictDemand({ date, hour, weather });
      setResult(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Prediction failed');
    } finally {
      setLoading(false);
    }
  }

  const topPredictions = useMemo(
    () => (result ? result.predictions.slice(0, 10) : []),
    [result],
  );

  return (
    <Dialog open={open} onClose={onClose} maxWidth="md" fullWidth>
      <DialogTitle sx={{ fontWeight: 600 }}>Optimize Bus Distribution</DialogTitle>
      <DialogContent dividers>
        <Stack spacing={2}>
          <Typography variant="body2" color="text.secondary">
            Predicts ridership demand at each stop using a Random Forest model trained
            on historical <code>data_logs</code> (weather + day-of-week + hour
            features) and recommends bus allocation across the fleet proportional to
            predicted demand.
          </Typography>

          <Stack direction={{ xs: 'column', sm: 'row' }} spacing={2}>
            <TextField
              type="date"
              label="Date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              slotProps={{ inputLabel: { shrink: true } }}
              fullWidth
            />
            <TextField
              type="number"
              label="Hour (0-23)"
              value={hour}
              onChange={(e) => setHour(Math.max(0, Math.min(23, Number(e.target.value))))}
              slotProps={{ htmlInput: { min: 0, max: 23 } }}
              fullWidth
            />
            <TextField
              select
              label="Weather"
              value={weather}
              onChange={(e) => setWeather(e.target.value)}
              fullWidth
            >
              {WEATHER_OPTIONS.map((w) => (
                <MenuItem key={w} value={w}>
                  {w}
                </MenuItem>
              ))}
            </TextField>
            <Button
              variant="contained"
              color="primary"
              onClick={run}
              disabled={loading}
              sx={{ minWidth: 120 }}
            >
              {loading ? <CircularProgress size={20} sx={{ color: 'white' }} /> : 'Run'}
            </Button>
          </Stack>

          {error && <Alert severity="error">{error}</Alert>}

          {result && (
            <>
              <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                <Chip
                  size="small"
                  color={result.model_trained ? 'primary' : 'warning'}
                  label={
                    result.model_trained
                      ? 'Source: Random Forest (sklearn)'
                      : 'Source: seasonal-average fallback (no trained model)'
                  }
                />
                <Chip size="small" variant="outlined" label={`Fleet: ${result.fleet_size}`} />
                <Chip
                  size="small"
                  variant="outlined"
                  label={`${result.input.date} · ${result.input.hour}:00 · ${result.input.weather}`}
                />
              </Stack>

              {!result.model_trained && (
                <Alert severity="info">
                  No trained model found. Showing seasonal averages. Run{' '}
                  <code>python manage.py train_demand_model</code> to enable ML predictions.
                </Alert>
              )}

              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
                  Predicted demand by stop
                </Typography>
                <BarChart
                  height={260}
                  layout="horizontal"
                  yAxis={[
                    {
                      data: topPredictions.map((p) => p.stop_name),
                      scaleType: 'band',
                    },
                  ]}
                  series={[
                    {
                      data: topPredictions.map((p) => p.predicted_riders),
                      label: 'Predicted riders',
                      color: '#8B1A2B',
                    },
                  ]}
                  margin={{ left: 8, right: 8, top: 8, bottom: 8 }}
                />
              </Box>

              <Box>
                <Typography variant="subtitle2" sx={{ mb: 1, fontWeight: 600 }}>
                  Recommended allocation
                </Typography>
                <Table size="small">
                  <TableHead>
                    <TableRow>
                      <TableCell>Stop</TableCell>
                      <TableCell align="right">Predicted riders</TableCell>
                      <TableCell align="right">Buses</TableCell>
                    </TableRow>
                  </TableHead>
                  <TableBody>
                    {result.predictions.map((p) => (
                      <TableRow key={p.stop_id}>
                        <TableCell>{p.stop_name}</TableCell>
                        <TableCell align="right">{p.predicted_riders}</TableCell>
                        <TableCell align="right">
                          <Chip
                            size="small"
                            label={p.recommended_buses}
                            color={p.recommended_buses > 0 ? 'primary' : 'default'}
                            variant={p.recommended_buses > 0 ? 'filled' : 'outlined'}
                          />
                        </TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              </Box>
            </>
          )}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose}>Close</Button>
      </DialogActions>
    </Dialog>
  );
}
