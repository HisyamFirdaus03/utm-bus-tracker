import { useEffect, useState } from 'react';
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
  MenuItem,
  Paper,
  Select,
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
} from '@mui/icons-material';

import {
  createRoute,
  deleteRoute,
  listRoutes,
  listStops,
  updateRoute,
} from '../api/routes';
import type { BusRoute, BusStop } from '../api/types';

type FormState = {
  id?: string;
  name: string;
  description: string;
  color: string;
  is_active: boolean;
  stop_ids: string[];
  departure_time: string;
  arrival_time: string;
  frequencies: number;
};

const EMPTY_FORM: FormState = {
  name: '',
  description: '',
  color: '#D42A2A',
  is_active: true,
  stop_ids: [],
  departure_time: '07:00',
  arrival_time: '22:00',
  frequencies: 15,
};

export function RoutesPage() {
  const [routes, setRoutes] = useState<BusRoute[] | null>(null);
  const [stops, setStops] = useState<BusStop[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [dialog, setDialog] = useState<{ mode: 'create' | 'edit'; form: FormState } | null>(null);

  const reload = async () => {
    try {
      const [r, s] = await Promise.all([listRoutes(), listStops()]);
      setRoutes(r);
      setStops(s);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const openCreate = () => setDialog({ mode: 'create', form: EMPTY_FORM });
  const openEdit = (r: BusRoute) =>
    setDialog({
      mode: 'edit',
      form: {
        id: r.id,
        name: r.name,
        description: r.description,
        color: r.color,
        is_active: r.is_active,
        stop_ids: r.stops.map((s) => s.id),
        departure_time: r.schedule?.departure_time ?? '07:00',
        arrival_time: r.schedule?.arrival_time ?? '22:00',
        frequencies: r.schedule?.frequencies ?? 15,
      },
    });

  const submit = async () => {
    if (!dialog) return;
    const f = dialog.form;
    const payload = {
      name: f.name,
      description: f.description,
      color: f.color,
      is_active: f.is_active,
      stop_ids: f.stop_ids,
      schedule: {
        departure_time: f.departure_time,
        arrival_time: f.arrival_time,
        frequencies: f.frequencies,
      },
    };
    try {
      if (dialog.mode === 'create') {
        await createRoute(payload);
      } else if (f.id) {
        await updateRoute(f.id, payload);
      }
      setDialog(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    }
  };

  const handleDelete = async (r: BusRoute) => {
    if (!confirm(`Delete route "${r.name}"?`)) return;
    try {
      await deleteRoute(r.id);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed');
    }
  };

  return (
    <Stack spacing={2}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Routes
        </Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
          Add Route
        </Button>
      </Stack>

      {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}

      {!routes ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Stops</TableCell>
                <TableCell>Schedule</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {routes.map((r) => (
                <TableRow key={r.id}>
                  <TableCell>
                    <Stack direction="row" spacing={1} sx={{ alignItems: 'center' }}>
                      <Box
                        sx={{
                          width: 12,
                          height: 12,
                          borderRadius: 0.5,
                          bgcolor: r.color,
                        }}
                      />
                      <Typography sx={{ fontWeight: 600 }}>{r.name}</Typography>
                    </Stack>
                  </TableCell>
                  <TableCell>{r.description}</TableCell>
                  <TableCell>{r.stops.length}</TableCell>
                  <TableCell>
                    {r.schedule
                      ? `${r.schedule.departure_time}–${r.schedule.arrival_time}, every ${r.schedule.frequencies} min`
                      : '—'}
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={r.is_active ? 'Active' : 'Inactive'}
                      size="small"
                      color={r.is_active ? 'success' : 'default'}
                    />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openEdit(r)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleDelete(r)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={!!dialog} onClose={() => setDialog(null)} fullWidth maxWidth="sm">
        <DialogTitle>{dialog?.mode === 'create' ? 'Add Route' : 'Edit Route'}</DialogTitle>
        <DialogContent>
          {dialog && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Name"
                value={dialog.form.name}
                onChange={(e) =>
                  setDialog({ ...dialog, form: { ...dialog.form, name: e.target.value } })
                }
              />
              <TextField
                label="Description"
                multiline
                rows={2}
                value={dialog.form.description}
                onChange={(e) =>
                  setDialog({
                    ...dialog,
                    form: { ...dialog.form, description: e.target.value },
                  })
                }
              />
              <TextField
                label="Color (hex)"
                value={dialog.form.color}
                onChange={(e) =>
                  setDialog({ ...dialog, form: { ...dialog.form, color: e.target.value } })
                }
              />
              <Box>
                <Typography variant="body2" color="text.secondary" sx={{ mb: 1 }}>
                  Stops (in order)
                </Typography>
                <Select
                  multiple
                  fullWidth
                  value={dialog.form.stop_ids}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: {
                        ...dialog.form,
                        stop_ids:
                          typeof e.target.value === 'string'
                            ? e.target.value.split(',')
                            : (e.target.value as string[]),
                      },
                    })
                  }
                  renderValue={(selected) =>
                    selected
                      .map((id) => stops.find((s) => s.id === id)?.name ?? id)
                      .join(', ')
                  }
                >
                  {stops.map((s) => (
                    <MenuItem key={s.id} value={s.id}>
                      {s.name}
                    </MenuItem>
                  ))}
                </Select>
              </Box>
              <Stack direction="row" spacing={2}>
                <TextField
                  label="Departure"
                  value={dialog.form.departure_time}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, departure_time: e.target.value },
                    })
                  }
                />
                <TextField
                  label="Arrival"
                  value={dialog.form.arrival_time}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, arrival_time: e.target.value },
                    })
                  }
                />
                <TextField
                  label="Every N min"
                  type="number"
                  value={dialog.form.frequencies}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, frequencies: Number(e.target.value) },
                    })
                  }
                />
              </Stack>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setDialog(null)}>Cancel</Button>
          <Button variant="contained" onClick={submit}>
            Save
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
