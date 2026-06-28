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
  Delete as DeleteIcon,
  Edit as EditIcon,
} from '@mui/icons-material';

import {
  createDriver,
  deleteDriver,
  listDrivers,
  updateDriver,
  type Driver,
} from '../api/drivers';

type CreateForm = {
  name: string;
  email: string;
  password: string;
  phone_no: string;
};

type EditForm = {
  id: string;
  name: string;
  phone_no: string;
};

const EMPTY_CREATE: CreateForm = { name: '', email: '', password: '', phone_no: '' };

export function DriversPage() {
  const [drivers, setDrivers] = useState<Driver[] | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [createForm, setCreateForm] = useState<CreateForm | null>(null);
  const [editForm, setEditForm] = useState<EditForm | null>(null);
  const [saving, setSaving] = useState(false);

  const reload = async () => {
    try {
      setDrivers(await listDrivers());
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const submitCreate = async () => {
    if (!createForm) return;
    if (!createForm.name || !createForm.email || !createForm.password) {
      setError('Name, email and password are required.');
      return;
    }
    setSaving(true);
    try {
      await createDriver({
        name: createForm.name,
        email: createForm.email,
        password: createForm.password,
        phone_no: createForm.phone_no || undefined,
      });
      setCreateForm(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Create failed');
    } finally {
      setSaving(false);
    }
  };

  const submitEdit = async () => {
    if (!editForm) return;
    setSaving(true);
    try {
      await updateDriver(editForm.id, {
        name: editForm.name,
        phone_no: editForm.phone_no,
      });
      setEditForm(null);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setSaving(false);
    }
  };

  const handleDelete = async (d: Driver) => {
    const warning = d.assigned_bus
      ? `Delete "${d.name}"? This will also unassign them from bus ${d.assigned_bus.plate_number}.`
      : `Delete "${d.name}"?`;
    if (!confirm(warning)) return;
    try {
      await deleteDriver(d.id);
      reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Delete failed');
    }
  };

  return (
    <Stack spacing={2}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Drivers
        </Typography>
        <Button
          variant="contained"
          startIcon={<AddIcon />}
          onClick={() => setCreateForm(EMPTY_CREATE)}
        >
          Add Driver
        </Button>
      </Stack>

      {error && (
        <Alert severity="error" onClose={() => setError(null)}>
          {error}
        </Alert>
      )}

      {!drivers ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : drivers.length === 0 ? (
        <Paper sx={{ p: 4, textAlign: 'center' }}>
          <Typography color="text.secondary">
            No drivers yet. Add one to start assigning them to buses.
          </Typography>
        </Paper>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Phone</TableCell>
                <TableCell>Assigned Bus</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {drivers.map((d) => (
                <TableRow key={d.id}>
                  <TableCell>
                    <Typography sx={{ fontWeight: 600 }}>{d.name}</Typography>
                  </TableCell>
                  <TableCell>{d.email}</TableCell>
                  <TableCell>{d.phone_no || '—'}</TableCell>
                  <TableCell>
                    {d.assigned_bus ? (
                      <Chip
                        size="small"
                        label={`${d.assigned_bus.plate_number} (${d.assigned_bus.bus_name})`}
                        color="primary"
                        variant="outlined"
                      />
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        Unassigned
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell align="right">
                    <IconButton
                      size="small"
                      onClick={() =>
                        setEditForm({
                          id: d.id,
                          name: d.name,
                          phone_no: d.phone_no ?? '',
                        })
                      }
                    >
                      <EditIcon fontSize="small" />
                    </IconButton>
                    <IconButton size="small" onClick={() => handleDelete(d)}>
                      <DeleteIcon fontSize="small" />
                    </IconButton>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={!!createForm} onClose={() => setCreateForm(null)} fullWidth maxWidth="sm">
        <DialogTitle>Add Driver</DialogTitle>
        <DialogContent>
          {createForm && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Full name"
                value={createForm.name}
                onChange={(e) => setCreateForm({ ...createForm, name: e.target.value })}
                autoFocus
              />
              <TextField
                label="Email"
                type="email"
                value={createForm.email}
                onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })}
                helperText="Will be the driver's login email"
              />
              <TextField
                label="Initial password"
                type="password"
                value={createForm.password}
                onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                helperText="Min 6 characters. Share with the driver — they can change it in Firebase Auth flows later."
              />
              <TextField
                label="Phone (optional)"
                value={createForm.phone_no}
                onChange={(e) =>
                  setCreateForm({ ...createForm, phone_no: e.target.value })
                }
              />
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setCreateForm(null)} disabled={saving}>
            Cancel
          </Button>
          <Button variant="contained" onClick={submitCreate} disabled={saving}>
            {saving ? 'Saving…' : 'Create'}
          </Button>
        </DialogActions>
      </Dialog>

      <Dialog open={!!editForm} onClose={() => setEditForm(null)} fullWidth maxWidth="sm">
        <DialogTitle>Edit Driver</DialogTitle>
        <DialogContent>
          {editForm && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <TextField
                label="Full name"
                value={editForm.name}
                onChange={(e) => setEditForm({ ...editForm, name: e.target.value })}
                autoFocus
              />
              <TextField
                label="Phone"
                value={editForm.phone_no}
                onChange={(e) => setEditForm({ ...editForm, phone_no: e.target.value })}
              />
              <Typography variant="caption" color="text.secondary">
                To change email or password, use Firebase Console. To assign a bus,
                go to the Buses page.
              </Typography>
            </Stack>
          )}
        </DialogContent>
        <DialogActions>
          <Button onClick={() => setEditForm(null)} disabled={saving}>
            Cancel
          </Button>
          <Button variant="contained" onClick={submitEdit} disabled={saving}>
            {saving ? 'Saving…' : 'Save'}
          </Button>
        </DialogActions>
      </Dialog>
    </Stack>
  );
}
