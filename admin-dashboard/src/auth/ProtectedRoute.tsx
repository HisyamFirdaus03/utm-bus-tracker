import { Navigate } from 'react-router-dom';
import { Box, CircularProgress, Typography } from '@mui/material';

import { useAuth } from './AuthContext';

export function ProtectedRoute({ children }: { children: React.ReactNode }) {
  const { user, role, loading } = useAuth();

  if (loading) {
    return (
      <Box sx={{ display: 'flex', alignItems: 'center', justifyContent: 'center', height: '100vh' }}>
        <CircularProgress />
      </Box>
    );
  }

  if (!user) return <Navigate to="/login" replace />;

  if (role !== 'admin') {
    return (
      <Box
        sx={{
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          height: '100vh',
          p: 4,
        }}
      >
        <Typography variant="h6" color="error">Admin access required</Typography>
        <Typography color="text.secondary" sx={{ mt: 1 }}>
          This account does not have the admin role. Ask the project owner to grant access.
        </Typography>
      </Box>
    );
  }

  return <>{children}</>;
}
