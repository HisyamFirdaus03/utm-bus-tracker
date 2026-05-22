import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom';

import { AuthProvider } from './auth/AuthContext';
import { ProtectedRoute } from './auth/ProtectedRoute';
import { AdminLayout } from './layout/AdminLayout';
import { AnalyticsPage } from './pages/AnalyticsPage';
import { BusesPage } from './pages/BusesPage';
import { DashboardPage } from './pages/DashboardPage';
import { FeedbackPage } from './pages/FeedbackPage';
import { LoginPage } from './pages/LoginPage';
import { RoutesPage } from './pages/RoutesPage';
import { SchedulesPage } from './pages/SchedulesPage';

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route
            element={
              <ProtectedRoute>
                <AdminLayout />
              </ProtectedRoute>
            }
          >
            <Route index element={<DashboardPage />} />
            <Route path="routes" element={<RoutesPage />} />
            <Route path="buses" element={<BusesPage />} />
            <Route path="schedules" element={<SchedulesPage />} />
            <Route path="feedback" element={<FeedbackPage />} />
            <Route path="analytics" element={<AnalyticsPage />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  );
}
