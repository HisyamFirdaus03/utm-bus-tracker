import { useEffect, useState } from 'react';
import {
  Alert,
  Box,
  Button,
  Card,
  CardContent,
  CircularProgress,
  Stack,
  TextField,
  Typography,
} from '@mui/material';
import { Save as SaveIcon } from '@mui/icons-material';

import { listRoutes, updateRoute } from '../api/routes';
import type { BusRoute, RouteSchedule } from '../api/types';

type Draft = RouteSchedule;

export function SchedulesPage() {
  const [routes, setRoutes] = useState<BusRoute[] | null>(null);
  const [drafts, setDrafts] = useState<Record<string, Draft>>({});
  const [error, setError] = useState<string | null>(null);
  const [savingId, setSavingId] = useState<string | null>(null);

  const reload = async () => {
    try {
      const r = await listRoutes();
      setRoutes(r);
      const init: Record<string, Draft> = {};
      for (const route of r) {
        init[route.id] = route.schedule ?? {
          departure_time: '07:00',
          arrival_time: '22:00',
          frequencies: 15,
        };
      }
      setDrafts(init);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const save = async (routeId: string) => {
    setSavingId(routeId);
    try {
      await updateRoute(routeId, { schedule: drafts[routeId] });
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setSavingId(null);
    }
  };

  if (!routes) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', mt: 6 }}>
        <CircularProgress />
      </Box>
    );
  }

  return (
    <Stack spacing={2}>
      <Typography variant="h5" sx={{ fontWeight: 600 }}>
        Schedules
      </Typography>
      <Typography variant="body2" color="text.secondary">
        Schedules are stored embedded on each route. Edits here patch the route's <code>schedule</code> field — the same data shown in the Routes page edit dialog.
      </Typography>

      {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}

      {routes.map((r) => {
        const draft = drafts[r.id];
        if (!draft) return null;
        return (
          <Card key={r.id}>
            <CardContent>
              <Stack direction="row" spacing={1} sx={{ alignItems: 'center', mb: 2 }}>
                <Box
                  sx={{ width: 6, height: 24, borderRadius: 0.5, bgcolor: r.color }}
                />
                <Typography variant="subtitle1" sx={{ fontWeight: 600 }}>
                  {r.name}
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  {r.description}
                </Typography>
              </Stack>
              <Stack direction="row" spacing={2} sx={{ alignItems: 'center' }}>
                <TextField
                  label="Departure"
                  value={draft.departure_time}
                  onChange={(e) =>
                    setDrafts({
                      ...drafts,
                      [r.id]: { ...draft, departure_time: e.target.value },
                    })
                  }
                />
                <TextField
                  label="Arrival"
                  value={draft.arrival_time}
                  onChange={(e) =>
                    setDrafts({
                      ...drafts,
                      [r.id]: { ...draft, arrival_time: e.target.value },
                    })
                  }
                />
                <TextField
                  label="Every N min"
                  type="number"
                  value={draft.frequencies}
                  onChange={(e) =>
                    setDrafts({
                      ...drafts,
                      [r.id]: { ...draft, frequencies: Number(e.target.value) },
                    })
                  }
                />
                <Button
                  variant="contained"
                  startIcon={<SaveIcon />}
                  onClick={() => save(r.id)}
                  disabled={savingId === r.id}
                >
                  {savingId === r.id ? 'Saving…' : 'Save'}
                </Button>
              </Stack>
            </CardContent>
          </Card>
        );
      })}
    </Stack>
  );
}
