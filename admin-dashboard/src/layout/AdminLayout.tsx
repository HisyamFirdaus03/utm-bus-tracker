import {
  AppBar,
  Avatar,
  Box,
  Drawer,
  IconButton,
  List,
  ListItemButton,
  ListItemIcon,
  ListItemText,
  Toolbar,
  Tooltip,
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
import { UtmLogo } from '../components/UtmLogo';
import { tokens } from '../theme';

const DRAWER_WIDTH = 244;

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
    <Box sx={{ display: 'flex', minHeight: '100vh', bgcolor: 'background.default' }}>
      <AppBar
        position="fixed"
        sx={{ width: `calc(100% - ${DRAWER_WIDTH}px)`, ml: `${DRAWER_WIDTH}px`, zIndex: 1201 }}
      >
        <Toolbar sx={{ gap: 1.5 }}>
          <Typography variant="h6" sx={{ flexGrow: 1, fontSize: 18 }}>
            UTM BusTracker Admin Dashboard
          </Typography>
          <Box sx={{ textAlign: 'right', mr: 0.5, display: { xs: 'none', sm: 'block' } }}>
            <Typography variant="body2" sx={{ fontWeight: 600, color: 'text.primary', lineHeight: 1.2 }}>
              {user?.email?.split('@')[0] ?? 'Admin'}
            </Typography>
            <Typography variant="caption" sx={{ color: 'text.secondary' }}>
              Administrator
            </Typography>
          </Box>
          <Avatar sx={{ width: 36, height: 36, bgcolor: tokens.crimsonSoft, color: 'primary.main', fontWeight: 700 }}>
            {(user?.email?.[0] ?? 'A').toUpperCase()}
          </Avatar>
          <Tooltip title="Log out">
            <IconButton onClick={handleLogout} aria-label="Logout" sx={{ color: 'text.secondary' }}>
              <LogoutIcon />
            </IconButton>
          </Tooltip>
        </Toolbar>
      </AppBar>

      <Drawer
        variant="permanent"
        sx={{
          width: DRAWER_WIDTH,
          flexShrink: 0,
          '& .MuiDrawer-paper': { width: DRAWER_WIDTH, boxSizing: 'border-box' },
        }}
      >
        <Toolbar sx={{ px: 2.5, justifyContent: 'center' }}>
          <UtmLogo height={42} />
        </Toolbar>

        <List sx={{ px: 1.5, py: 1 }}>
          {NAV.map((item) => (
            <ListItemButton
              key={item.to}
              component={NavLink}
              to={item.to}
              end={item.to === '/'}
              sx={{
                borderRadius: 2.5,
                mb: 0.5,
                px: 1.5,
                py: 1.1,
                color: 'text.secondary',
                '& .MuiListItemIcon-root': { color: 'text.secondary', minWidth: 38 },
                '& .MuiListItemText-primary': { fontWeight: 600, fontSize: 14.5 },
                '&:hover': { bgcolor: tokens.crimsonSoft, color: 'primary.main' },
                '&:hover .MuiListItemIcon-root': { color: 'primary.main' },
                '&.active': {
                  bgcolor: 'primary.main',
                  color: 'white',
                  boxShadow: '0 6px 16px rgba(139, 26, 43, 0.24)',
                  '& .MuiListItemIcon-root': { color: 'white' },
                  '&:hover': { bgcolor: 'primary.dark', color: 'white' },
                  '&:hover .MuiListItemIcon-root': { color: 'white' },
                },
              }}
            >
              <ListItemIcon>{item.icon}</ListItemIcon>
              <ListItemText primary={item.label} />
            </ListItemButton>
          ))}
        </List>
      </Drawer>

      <Box component="main" sx={{ flexGrow: 1, p: 3.5, mt: 8 }}>
        <Outlet />
      </Box>
    </Box>
  );
}
