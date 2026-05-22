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
  FormControl,
  InputLabel,
  Link,
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
  ToggleButton,
  ToggleButtonGroup,
  Typography,
} from '@mui/material';
import { Reply as ReplyIcon } from '@mui/icons-material';

import { listAllFeedback, respondToFeedback } from '../api/feedback';
import { listBuses } from '../api/buses';
import type { Bus, Feedback, FeedbackStatus } from '../api/types';

type FilterValue = 'all' | FeedbackStatus;

const STATUS_COLORS: Record<FeedbackStatus, 'warning' | 'info' | 'success'> = {
  new: 'warning',
  in_progress: 'info',
  resolved: 'success',
};

const STATUS_LABEL: Record<FeedbackStatus, string> = {
  new: 'New',
  in_progress: 'In progress',
  resolved: 'Resolved',
};

type DialogState = {
  feedback: Feedback;
  admin_response: string;
  status: FeedbackStatus;
};

export function FeedbackPage() {
  const [items, setItems] = useState<Feedback[] | null>(null);
  const [buses, setBuses] = useState<Bus[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [filter, setFilter] = useState<FilterValue>('all');
  const [dialog, setDialog] = useState<DialogState | null>(null);
  const [saving, setSaving] = useState(false);

  const reload = async () => {
    try {
      const [f, b] = await Promise.all([listAllFeedback(), listBuses()]);
      setItems(f);
      setBuses(b);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Failed to load');
    }
  };

  useEffect(() => {
    reload();
  }, []);

  const busLabel = (busId: string) => {
    const b = buses.find((x) => x.id === busId);
    return b ? `${b.plate_number} · ${b.bus_name}` : busId;
  };

  const filtered = useMemo(() => {
    if (!items) return null;
    if (filter === 'all') return items;
    return items.filter((f) => f.status === filter);
  }, [items, filter]);

  const counts = useMemo(() => {
    const c = { all: 0, new: 0, in_progress: 0, resolved: 0 } as Record<FilterValue, number>;
    for (const f of items ?? []) {
      c.all += 1;
      c[f.status] += 1;
    }
    return c;
  }, [items]);

  const openRespond = (f: Feedback) =>
    setDialog({
      feedback: f,
      admin_response: f.admin_response ?? '',
      status: f.status,
    });

  const submit = async () => {
    if (!dialog) return;
    setSaving(true);
    try {
      await respondToFeedback(dialog.feedback.id, {
        admin_response: dialog.admin_response.trim() || null,
        status: dialog.status,
      });
      setDialog(null);
      await reload();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Save failed');
    } finally {
      setSaving(false);
    }
  };

  return (
    <Stack spacing={2}>
      <Stack direction="row" sx={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <Typography variant="h5" sx={{ fontWeight: 600 }}>
          Feedback
        </Typography>
        <ToggleButtonGroup
          size="small"
          exclusive
          value={filter}
          onChange={(_, v) => v && setFilter(v)}
        >
          <ToggleButton value="all">All ({counts.all})</ToggleButton>
          <ToggleButton value="new">New ({counts.new})</ToggleButton>
          <ToggleButton value="in_progress">In progress ({counts.in_progress})</ToggleButton>
          <ToggleButton value="resolved">Resolved ({counts.resolved})</ToggleButton>
        </ToggleButtonGroup>
      </Stack>

      {error && <Alert severity="error" onClose={() => setError(null)}>{error}</Alert>}

      {!filtered ? (
        <Box sx={{ display: 'flex', justifyContent: 'center', mt: 4 }}>
          <CircularProgress />
        </Box>
      ) : filtered.length === 0 ? (
        <Typography color="text.secondary">No feedback to show.</Typography>
      ) : (
        <TableContainer component={Paper}>
          <Table>
            <TableHead>
              <TableRow>
                <TableCell>When</TableCell>
                <TableCell>Bus</TableCell>
                <TableCell>Description</TableCell>
                <TableCell>Screenshot</TableCell>
                <TableCell>Status</TableCell>
                <TableCell>Admin response</TableCell>
                <TableCell align="right">Actions</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {filtered.map((f) => (
                <TableRow key={f.id} hover>
                  <TableCell>
                    <Typography variant="caption" color="text.secondary">
                      {new Date(f.timestamp).toLocaleString()}
                    </Typography>
                  </TableCell>
                  <TableCell>{busLabel(f.bus_id)}</TableCell>
                  <TableCell sx={{ maxWidth: 320 }}>
                    <Typography variant="body2">{f.description}</Typography>
                    <Typography variant="caption" color="text.secondary" sx={{ fontFamily: 'monospace' }}>
                      {f.student_id}
                    </Typography>
                  </TableCell>
                  <TableCell>
                    {f.screenshot_url ? (
                      <Link href={f.screenshot_url} target="_blank" rel="noreferrer">
                        view
                      </Link>
                    ) : (
                      '—'
                    )}
                  </TableCell>
                  <TableCell>
                    <Chip
                      label={STATUS_LABEL[f.status]}
                      size="small"
                      color={STATUS_COLORS[f.status]}
                    />
                  </TableCell>
                  <TableCell sx={{ maxWidth: 280 }}>
                    {f.admin_response ? (
                      <Typography variant="body2">{f.admin_response}</Typography>
                    ) : (
                      <Typography variant="caption" color="text.secondary">
                        (none)
                      </Typography>
                    )}
                  </TableCell>
                  <TableCell align="right">
                    <Button
                      size="small"
                      variant="outlined"
                      startIcon={<ReplyIcon />}
                      onClick={() => openRespond(f)}
                    >
                      Respond
                    </Button>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </TableContainer>
      )}

      <Dialog open={!!dialog} onClose={() => setDialog(null)} fullWidth maxWidth="sm">
        <DialogTitle>Respond to feedback</DialogTitle>
        <DialogContent>
          {dialog && (
            <Stack spacing={2} sx={{ mt: 1 }}>
              <Typography variant="body2" color="text.secondary">
                Student feedback on {busLabel(dialog.feedback.bus_id)}
              </Typography>
              <Paper variant="outlined" sx={{ p: 1.5 }}>
                <Typography variant="body2">{dialog.feedback.description}</Typography>
              </Paper>
              <FormControl fullWidth>
                <InputLabel>Status</InputLabel>
                <Select
                  label="Status"
                  value={dialog.status}
                  onChange={(e) =>
                    setDialog({ ...dialog, status: e.target.value as FeedbackStatus })
                  }
                >
                  <MenuItem value="new">New</MenuItem>
                  <MenuItem value="in_progress">In progress</MenuItem>
                  <MenuItem value="resolved">Resolved</MenuItem>
                </Select>
              </FormControl>
              <TextField
                label="Response"
                multiline
                rows={4}
                placeholder="Reply to the student…"
                value={dialog.admin_response}
                onChange={(e) =>
                  setDialog({ ...dialog, admin_response: e.target.value })
                }
              />
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
    </Stack>
  );
}
