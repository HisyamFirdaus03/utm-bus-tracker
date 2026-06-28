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
  FormControl,
  IconButton,
  InputLabel,
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

import { createBus, deleteBus, listBuses, updateBus } from '../api/buses';
import { listDrivers, type Driver } from '../api/drivers';
import { listRoutes } from '../api/routes';
import type { Bus, BusRoute } from '../api/types';

type FormState = {
  id?: string;
  bus_name: string;
  plate_number: string;
  route_id: string;
  status: Bus['status'];
  capacity: number;
  driver_id: string;
};

const EMPTY_FORM: FormState = {
  bus_name: '',
  plate_number: '',
  route_id: '',
  status: 'inactive',
  capacity: 40,
  driver_id: '',
};

const STATUS_COLORS: Record<Bus['status'], 'success' | 'default' | 'warning'> = {
  active: 'success',
  inactive: 'default',
  maintenance: 'warning',
};

export function BusesPage() {
  const [buses, setBuses] = useState<Bus[] | null>(null);
  const [routes, setRoutes] = useState<BusRoute[]>([]);
  const [drivers, setDrivers] = useState<Driver[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [dialog, setDialog] = useState<{ mode: 'create' | 'edit'; form: FormState } | null>(null);

  const reload = async () => {
    try {
      const [b, r, d] = await Promise.all([listBuses(), listRoutes(), listDrivers()]);
      setBuses(b);
      setRoutes(r);
      setDrivers(d);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  const driverLabel = (uid: string | null | undefined) => {
    if (!uid) return null;
    const d = drivers.find((x) => x.id === uid);
    return d ? `${d.name} (${d.email})` : uid;
  };

  useEffect(() => {
    reload();
  }, []);

  const openCreate = () => setDialog({ mode: 'create', form: EMPTY_FORM });
  const openEdit = (b: Bus) =>
    setDialog({
      mode: 'edit',
      form: {
        id: b.id,
        bus_name: b.bus_name,
        plate_number: b.plate_number,
        route_id: b.route_id,
        status: b.status,
        capacity: b.capacity,
        driver_id: b.driver_id ?? '',
      },
    });

  const submit = async () => {
    if (!dialog) return;
    const f = dialog.form;
    const payload: Partial<Bus> = {
      bus_name: f.bus_name,
      plate_number: f.plate_number,
      route_id: f.route_id,
      status: f.status,
      capacity: f.capacity,
      driver_id: f.driver_id || null,
    };
    try {
      if (dialog.mode === 'create') {
        await createBus(payload);
      } else if (f.id) {
        await updateBus(f.id, payload);
      }
      setDialog(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    }
  };

  const handleDelete = async (b: Bus) => {
    if (!confirm(`Delete bus "${b.plate_number}"?`)) return;
    try {
      await deleteBus(b.id);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed');
    }
  };

  return (
    <Stack spacing={2}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Buses
        </Typography>
        <Button variant="contained" startIcon={<AddIcon />} onClick={openCreate}>
          Add Bus
        </Button>
      </Stack>

      {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}

      {!buses ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Plate</TableCell>
                <TableCell>Name</TableCell>
                <TableCell>Route</TableCell>
                <TableCell>Capacity</TableCell>
                <TableCell>Driver</TableCell>
                <TableCell>Status</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {buses.map((b) => (
                <TableRow key={b.id}>
                  <TableCell>
                    <Typography sx={{ fontWeight: 600 }}>{b.plate_number}</Typography>
                  </TableCell>
                  <TableCell>{b.bus_name}</TableCell>
                  <TableCell>
                    {routes.find((r) => r.id === b.route_id)?.name ?? b.route_id}
                  </TableCell>
                  <TableCell>{b.capacity}</TableCell>
                  <TableCell>
                    {b.driver_id ? (
                      <Typography variant="body2">
                        {driverLabel(b.driver_id)}
                      </Typography>
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        Unassigned
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell>
                    <Chip label={b.status} size="small" color={STATUS_COLORS[b.status]} />
                  </TableCell>
                  <TableCell align="right">
                    <IconButton size="small" onClick={() => openEdit(b)}>
                      <EditIcon fontSize="small" />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleDelete(b)}>
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
        <DialogTitle>{dialog?.mode === 'create' ? 'Add Bus' : 'Edit Bus'}</DialogTitle>
        <DialogContent>
          {dialog && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Plate number"
                value={dialog.form.plate_number}
                onChange={(e) =>
                  setDialog({
                    ...dialog,
                    form: { ...dialog.form, plate_number: e.target.value },
                  })
                }
              />
              <TextField
                label="Bus name"
                value={dialog.form.bus_name}
                onChange={(e) =>
                  setDialog({
                    ...dialog,
                    form: { ...dialog.form, bus_name: e.target.value },
                  })
                }
              />
              <FormControl fullWidth>
                <InputLabel>Route</InputLabel>
                <Select
                  label="Route"
                  value={dialog.form.route_id}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, route_id: e.target.value },
                    })
                  }
                >
                  {routes.map((r) => (
                    <MenuItem key={r.id} value={r.id}>
                      {r.name}
                    </MenuItem>
                  ))}
                </Select>
              </FormControl>
              <Stack direction="row" spacing={2}>
                <FormControl fullWidth>
                  <InputLabel>Status</InputLabel>
                  <Select
                    label="Status"
                    value={dialog.form.status}
                    onChange={(e) =>
                      setDialog({
                        ...dialog,
                        form: { ...dialog.form, status: e.target.value as Bus['status'] },
                      })
                    }
                  >
                    <MenuItem value="active">active</MenuItem>
                    <MenuItem value="inactive">inactive</MenuItem>
                    <MenuItem value="maintenance">maintenance</MenuItem>
                  </Select>
                </FormControl>
                <TextField
                  label="Capacity"
                  type="number"
                  value={dialog.form.capacity}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, capacity: Number(e.target.value) },
                    })
                  }
                />
              </Stack>
              <FormControl fullWidth>
                <InputLabel>Driver</InputLabel>
                <Select
                  label="Driver"
                  value={dialog.form.driver_id}
                  onChange={(e) =>
                    setDialog({
                      ...dialog,
                      form: { ...dialog.form, driver_id: e.target.value as string },
                    })
                  }
                >
                  <MenuItem value="">
                    <em>Unassigned</em>
                  </MenuItem>
                  {drivers.map((d) => {
                    const assignedElsewhere =
                      d.assigned_bus_id && d.assigned_bus_id !== dialog.form.id;
                    return (
                      <MenuItem key={d.id} value={d.id} disabled={!!assignedElsewhere}>
                        {d.name} ({d.email})
                        {assignedElsewhere && d.assigned_bus
                          ? ` — already on ${d.assigned_bus.plate_number}`
                          : ''}
                      </MenuItem>
                    );
                  })}
                </Select>
              </FormControl>
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
