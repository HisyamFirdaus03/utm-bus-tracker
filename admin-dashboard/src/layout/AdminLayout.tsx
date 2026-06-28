import {
  AppBar,
  Box,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Typography,
} from '@mui/material';
import {
  AltRoute as RouteIcon,
  DirectionsBus as BusIcon,
  Schedule as ScheduleIcon,
  Dashboard as DashboardIcon,
  Feedback as FeedbackIcon,
  Insights as InsightsIcon,
  Logout as LogoutIcon,
  People as DriversIcon,
  Place as StopIcon,
} from '@mui/icons-material';
import { NavLink, Outlet, useNavigate } from 'react-router-dom';

import { useAuth } from '../auth/AuthContext';

const DRAWER_WIDTH = 220;

const NAV = [
  { label: 'Dashboard', to: '/', icon: <DashboardIcon /> },
  { label: 'Routes', to: '/routes', icon: <RouteIcon /> },
  { label: 'Stops', to: '/stops', icon: <StopIcon /> },
  { label: 'Buses', to: '/buses', icon: <BusIcon /> },
  { label: 'Drivers', to: '/drivers', icon: <DriversIcon /> },
  { label: 'Schedules', to: '/schedules', icon: <ScheduleIcon /> },
  { label: 'Feedback', to: '/feedback', icon: <FeedbackIcon /> },
  { label: 'Analytics', to: '/analytics', icon: <InsightsIcon /> },
];

export function AdminLayout() {
  const { user, signOutUser } = useAuth();
  const navigate = useNavigate();

  const handleLogout = async () => {
    await signOutUser();
    navigate('/login', { replace: true });
  };

  return (
    <Box sx={{ display: 'flex' }}>
      <AppBar
        position="fixed"
        sx={{ width: `calc(100% - ${DRAWER_WIDTH}px)`, ml: `${DRAWER_WIDTH}px` }}
      >
        <Toolbar>
          <Box
            sx={{
              px: 1,
              py: 0.25,
              mr: 1,
              bgcolor: 'primary.main',
              color: 'white',
              borderRadius: 0.5,
              fontWeight: 700,
              fontSize: 12,
            }}
          >
            UTM
          </Box>
          <Typography variant="h6" color="primary" sx={{ flexGrow: 1 }}>
            BusTracker Admin
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mr: 1 }}>
            {user?.email}
          </Typography>
          <IconButton onClick={handleLogout} aria-label="Logout">
            <LogoutIcon />
          </IconButton>
        </Toolbar>
      </AppBar>

      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            width: DRAWER_WIDTH,
            boxSizing: 'border-box',
          },
        }}
      >
        <Toolbar sx={{ borderBottom: '1px solid #E0E0E0' }}>
          <Typography variant="subtitle1" color="primary" sx={{ fontWeight: 700 }}>
            UTM BusTracker
          </Typography>
        </Toolbar>
        <List>
          {NAV.map((item) => (
            <ListItemButton
              key={item.to}
              component={NavLink}
              to={item.to}
              end={item.to === '/'}
              sx={{
                '&.active': {
                  bgcolor: 'primary.main',
                  color: 'white',
                  '& .MuiListItemIcon-root': { color: 'white' },
                },
              }}
            >
              <ListItemIcon>{item.icon}</ListItemIcon>
              <ListItemText primary={item.label} />
            </ListItemButton>
          ))}
        </List>
      </Drawer>

      <Box component="main" sx={{ flexGrow: 1, p: 3, mt: 8 }}>
        <Outlet />
      </Box>
    </Box>
  );
}
