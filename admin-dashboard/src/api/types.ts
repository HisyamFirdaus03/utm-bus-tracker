export type BusStop = {
  id: string;
  name: string;
  latitude: number;
  longitude: number;
  order: number;
  demand?: number;
};

export type RouteSchedule = {
  departure_time: string;
  arrival_time: string;
  frequencies: number;
};

export type BusRoute = {
  id: string;
  name: string;
  description: string;
  color: string;
  is_active: boolean;
  stops: BusStop[];
  schedule?: RouteSchedule | null;
};

export type Bus = {
  id: string;
  bus_name: string;
  plate_number: string;
  route_id: string;
  status: 'active' | 'inactive' | 'maintenance';
  capacity: number;
  driver_id?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  speed?: number | null;
  last_updated?: string | null;
};
