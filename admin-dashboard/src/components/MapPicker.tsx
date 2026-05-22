import 'leaflet/dist/leaflet.css';

import L from 'leaflet';
import { useEffect, useRef } from 'react';
import {
  MapContainer,
  Marker,
  TileLayer,
  useMap,
  useMapEvents,
} from 'react-leaflet';

// Vite-friendly fix for Leaflet's default marker icon (the bundler can't
// resolve the PNGs imported from inside the package). Point at the official
// CDN copies so markers render reliably.
type LeafletIconPrototype = { _getIconUrl?: unknown };
delete (L.Icon.Default.prototype as LeafletIconPrototype)._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png',
  iconUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png',
  shadowUrl: 'https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png',
});

export type LatLng = { lat: number; lng: number };

type Props = {
  value: LatLng;
  onChange: (next: LatLng) => void;
  height?: number;
};

function ClickHandler({ onChange }: { onChange: Props['onChange'] }) {
  useMapEvents({
    click(e) {
      onChange({ lat: e.latlng.lat, lng: e.latlng.lng });
    },
  });
  return null;
}

// Re-centers when the external lat/lng changes (e.g., after a name lookup).
function Recenter({ value }: { value: LatLng }) {
  const map = useMap();
  const last = useRef(value);
  useEffect(() => {
    if (last.current.lat !== value.lat || last.current.lng !== value.lng) {
      map.setView([value.lat, value.lng], map.getZoom());
      last.current = value;
    }
  }, [value, map]);
  return null;
}

export function MapPicker({ value, onChange, height = 320 }: Props) {
  return (
    <MapContainer
      center={[value.lat, value.lng]}
      zoom={16}
      style={{ height, width: '100%', borderRadius: 12 }}
      scrollWheelZoom
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker
        position={[value.lat, value.lng]}
        draggable
        eventHandlers={{
          dragend(e) {
            const { lat, lng } = (e.target as L.Marker).getLatLng();
            onChange({ lat, lng });
          },
        }}
      />
      <ClickHandler onChange={onChange} />
      <Recenter value={value} />
    </MapContainer>
  );
}

