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
  IconButton,
  Link,
  Paper,
  Stack,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  TextField,
  Typography,
} from '@mui/material';
import {
  Add as AddIcon,
  Edit as EditIcon,
  Delete as DeleteIcon,
  OpenInNew as OpenInNewIcon,
  TravelExplore as TravelExploreIcon,
} from '@mui/icons-material';

import {
  createStop,
  deleteStop,
  listRoutes,
  listStops,
  updateStop,
} from '../api/routes';
import type { BusRoute, BusStop } from '../api/types';
import { MapPicker } from '../components/MapPicker';
import { geocodeStopName } from '../api/geocode';
import { InputAdornment, Snackbar } from '@mui/material';

type FormState = {
  id?: string;
  name: string;
  latitude: number;
  longitude: number;
  order: number;
  demand: number;
};

const EMPTY_FORM: FormState = {
  name: '',
  latitude: 1.5580,
  longitude: 103.6400,
  order: 1,
  demand: 0,
};

const isValidCoord = (lat: number, lng: number) =>
  Number.isFinite(lat) &&
  Number.isFinite(lng) &&
  lat >= -90 &&
  lat <= 90 &&
  lng >= -180 &&
  lng <= 180;

const mapsUrl = (lat: number, lng: number) =>
  `https://www.google.com/maps?q=${lat},${lng}`;

export function StopsPage() {
  const [stops, setStops] = useState<BusStop[] | null>(null);
  const [routes, setRoutes] = useState<BusRoute[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [dialog, setDialog] = useState<{ mode: 'create' | 'edit'; form: FormState } | null>(null);
  const [saving, setSaving] = useState(false);
  const [looking, setLooking] = useState(false);
  const [toast, setToast] = useState<string | null>(null);
  const [lookupMissed, setLookupMissed] = useState<string | null>(null);

  const reload = async () => {
    try {
      const [s, r] = await Promise.all([listStops(), listRoutes()]);
      setStops(s);
      setRoutes(r);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  useEffect(() => {
    reload();
  }, []);

  // Routes a given stop belongs to — used for the "Used by" column.
  const routesByStopId = useMemo(() => {
    const map: Record<string, BusRoute[]> = {};
    for (const r of routes) {
      for (const s of r.stops) {
        (map[s.id] ??= []).push(r);
      }
    }
    return map;
  }, [routes]);

  const openCreate = () => setDialog({ mode: 'create', form: EMPTY_FORM });
  const openEdit = (s: BusStop) =>
    setDialog({
      mode: 'edit',
      form: {
        id: s.id,
        name: s.name,
        latitude: s.latitude,
        longitude: s.longitude,
        order: s.order,
        demand: s.demand ?? 0,
      },
    });

  const submit = async () => {
    if (!dialog) return;
    const f = dialog.form;
    if (!f.name.trim()) {
      setError('Name is required');
      return;
    }
    if (!isValidCoord(f.latitude, f.longitude)) {
      setError('Latitude must be -90…90, longitude -180…180');
      return;
    }
    setSaving(true);
    try {
      const payload: Partial<BusStop> = {
        name: f.name.trim(),
        latitude: f.latitude,
        longitude: f.longitude,
        order: f.order,
        demand: f.demand,
      };
      if (dialog.mode === 'create') {
        await createStop(payload);
      } else if (f.id) {
        await updateStop(f.id, payload);
      }
      setDialog(null);
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  const lookupByName = async () => {
    if (!dialog) return;
    const name = dialog.form.name.trim();
    if (!name) {
      setError('Type a stop name first');
      return;
    }
    setLooking(true);
    setLookupMissed(null);
    try {
      const result = await geocodeStopName(name);
      if (result == null) {
        // OpenStreetMap often doesn't tag UTM-specific buildings.
        // Surface a Google Maps fallback so the admin can find it visually.
        setLookupMissed(name);
        return;
      }
      setDialog({
        ...dialog,
        form: { ...dialog.form, latitude: result.lat, longitude: result.lng },
      });
      setToast('Found a match — verify on map and adjust if needed.');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Lookup failed');
    } finally {
      setLooking(false);
    }
  };

  const googleMapsSearchUrl = (name: string) =>
    `https://www.google.com/maps/search/${encodeURIComponent(
      `${name} Universiti Teknologi Malaysia Skudai`,
    )}`;

  const handleDelete = async (s: BusStop) => {
    const used = routesByStopId[s.id] ?? [];
    const extra =
      used.length > 0
        ? `\n\nUsed by: ${used.map((r) => r.name).join(', ')}. Routes will still reference it but the stop will be unresolved.`
        : '';
    if (!confirm(`Delete stop "${s.name}"?${extra}`)) return;
    try {
      await deleteStop(s.id);
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed');
    }
  };

  return (
    <Stack spacing={2}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Stops
        </Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
          Add Stop
        </Button>
      </Stack>

      <Typography variant="body2" color="text.secondary">
        Edit a stop's name, coordinates, or order. The "Open in Maps" link verifies the
        coordinate on Google Maps in a new tab — easiest way to spot a wrong location.
      </Typography>

      {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}

      {!stops ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : stops.length === 0 ? (
        <Typography color="text.secondary">No stops yet.</Typography>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Coordinates</TableCell>
                <TableCell>Order</TableCell>
                <TableCell>Demand</TableCell>
                <TableCell>Used by</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {stops.map((s) => {
                const used = routesByStopId[s.id] ?? [];
                return (
                  <TableRow key={s.id} hover>
                    <TableCell>
                      <Typography sx={{ fontWeight: 600 }}>{s.name}</Typography>
                    </TableCell>
                    <TableCell>
                      <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                        <Typography variant="caption" sx={{ fontFamily: 'monospace' }}>
                          {s.latitude.toFixed(5)}, {s.longitude.toFixed(5)}
                        </Typography>
                        <Link
                          href={mapsUrl(s.latitude, s.longitude)}
                          target="_blank"
                          rel="noreferrer"
                          sx={{
                            display: 'inline-flex',
                            alignItems: 'center',
                            gap: 0.25,
                            fontSize: 11,
                          }}
                        >
                          Open in Maps
                          <OpenInNewIcon sx={{ fontSize: 12 }} />
                        </Link>
                      </Stack>
                    </TableCell>
                    <TableCell>{s.order}</TableCell>
                    <TableCell>{s.demand ?? 0}</TableCell>
                    <TableCell>
                      {used.length === 0 ? (
                        <Typography variant="caption" color="text.secondary">
                          (unused)
                        </Typography>
                      ) : (
                        <Stack direction="row" spacing={0.5} flexWrap="wrap">
                          {used.map((r) => (
                            <Chip
                              key={r.id}
                              label={r.name}
                              size="small"
                              sx={{
                                bgcolor: r.color,
                                color: 'white',
                                fontWeight: 600,
                              }}
                            />
                          ))}
                        </Stack>
                      )}
                    </TableCell>
                    <TableCell align="right">
                      <IconButton size="small" onClick={() => openEdit(s)}>
                        <EditIcon fontSize="small" />
                      </IconButton>
                      <IconButton size="small" onClick={() => handleDelete(s)}>
                        <DeleteIcon fontSize="small" />
                      </IconButton>
                    </TableCell>
                  </TableRow>
                );
              })}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={!!dialog} onClose={() => setDialog(null)} fullWidth maxWidth="md">
        <DialogTitle>{dialog?.mode === 'create' ? 'Add Stop' : 'Edit Stop'}</DialogTitle>
        <DialogContent>
          {dialog && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Name"
                value={dialog.form.name}
                onChange={(e) => {
                  setLookupMissed(null);
                  setDialog({ ...dialog, form: { ...dialog.form, name: e.target.value } });
                }}
                helperText='e.g. "Kolej Tun Razak". Click "Find on map" to auto-locate.'
                fullWidth
                autoFocus
                slotProps={{
                  input: {
                    endAdornment: (
                      <InputAdornment position="end">
                        <Button
                          size="small"
                          startIcon={<TravelExploreIcon />}
                          onClick={lookupByName}
                          disabled={looking}
                        >
                          {looking ? 'Searching…' : 'Find on map'}
                        </Button>
                      </InputAdornment>
                    ),
                  },
                }}
              />

              {lookupMissed && (
                <Alert
                  severity="info"
                  onClose={() => setLookupMissed(null)}
                  action={
                    <Button
                      color="inherit"
                      size="small"
                      endIcon={<OpenInNewIcon sx={{ fontSize: 14 }} />}
                      component="a"
                      href={googleMapsSearchUrl(lookupMissed)}
                      target="_blank"
                      rel="noreferrer"
                    >
                      Search on Google Maps
                    </Button>
                  }
                >
                  No match in OpenStreetMap for "{lookupMissed}". Find it visually
                  on Google Maps, then click that spot on the map below to place
                  the pin.
                </Alert>
              )}

              <Box sx={{ borderRadius: 3, overflow: 'hidden' }}>
                <MapPicker
                  value={{ lat: dialog.form.latitude, lng: dialog.form.longitude }}
                  onChange={({ lat, lng }) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, latitude: lat, longitude: lng },
                    })
                  }
                />
              </Box>
              <Typography variant="caption" color="text.secondary">
                Click anywhere on the map to drop the pin, or drag the existing pin to fine-tune.
              </Typography>

              <Stack direction="row" spacing={2}>
                <TextField
                  label="Latitude"
                  type="number"
                  value={dialog.form.latitude}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, latitude: Number(e.target.value) },
                    })
                  }
                  fullWidth
                  slotProps={{ htmlInput: { step: 0.0001, min: -90, max: 90 } }}
                />
                <TextField
                  label="Longitude"
                  type="number"
                  value={dialog.form.longitude}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, longitude: Number(e.target.value) },
                    })
                  }
                  fullWidth
                  slotProps={{ htmlInput: { step: 0.0001, min: -180, max: 180 } }}
                />
              </Stack>
              {isValidCoord(dialog.form.latitude, dialog.form.longitude) && (
                <Link
                  href={mapsUrl(dialog.form.latitude, dialog.form.longitude)}
                  target="_blank"
                  rel="noreferrer"
                  sx={{
                    display: 'inline-flex',
                    alignItems: 'center',
                    gap: 0.5,
                    alignSelf: 'flex-start',
                    fontSize: 12,
                  }}
                >
                  Cross-check on Google Maps
                  <OpenInNewIcon sx={{ fontSize: 12 }} />
                </Link>
              )}

              <Stack direction="row" spacing={2}>
                <TextField
                  label="Order"
                  type="number"
                  value={dialog.form.order}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, order: Number(e.target.value) },
                    })
                  }
                  helperText="Position within its route"
                  fullWidth
                  slotProps={{ htmlInput: { step: 1, min: 1 } }}
                />
                <TextField
                  label="Demand"
                  type="number"
                  value={dialog.form.demand}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, demand: Number(e.target.value) },
                    })
                  }
                  helperText="Optional baseline"
                  fullWidth
                  slotProps={{ htmlInput: { step: 1, min: 0 } }}
                />
              </Stack>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialog(null)} disabled={saving}>
            Cancel
          </Button>
          <Button variant="contained" onClick={submit} disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </Button>
        </DialogActions>
      </Dialog>

      <Snackbar
        open={!!toast}
        autoHideDuration={4000}
        onClose={() => setToast(null)}
        anchorOrigin={{ vertical: 'bottom', horizontal: 'center' }}
        message={toast}
      />
    </Stack>
  );
}
