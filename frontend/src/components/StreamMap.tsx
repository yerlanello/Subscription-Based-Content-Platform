"use client";

import { useEffect } from "react";
import { MapContainer, TileLayer, Marker, Popup, useMap } from "react-leaflet";
import L from "leaflet";
import Link from "next/link";
import "leaflet/dist/leaflet.css";

// Fix default marker icons in Next.js
const defaultIcon = L.icon({
  iconUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon.png",
  iconRetinaUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-icon-2x.png",
  shadowUrl: "https://unpkg.com/leaflet@1.9.4/dist/images/marker-shadow.png",
  iconSize: [25, 41],
  iconAnchor: [12, 41],
  popupAnchor: [1, -34],
});

const liveIcon = L.divIcon({
  className: "",
  html: `<div class="relative flex items-center justify-center">
    <div class="w-5 h-5 rounded-full bg-red-500 border-2 border-white shadow-lg"></div>
    <div class="absolute w-5 h-5 rounded-full bg-red-500 animate-ping opacity-75"></div>
  </div>`,
  iconSize: [20, 20],
  iconAnchor: [10, 10],
  popupAnchor: [0, -14],
});

function FitBounds({ streams }: { streams: StreamInfo[] }) {
  const map = useMap();
  useEffect(() => {
    const withCoords = streams.filter((s) => s.latitude != null && s.longitude != null);
    if (withCoords.length === 0) return;
    const bounds = L.latLngBounds(
      withCoords.map((s) => [s.latitude!, s.longitude!])
    );
    // Defer until the map container has its CSS transform applied
    const t = setTimeout(() => {
      try {
        map.fitBounds(bounds, { padding: [40, 40], maxZoom: 12 });
      } catch {
        // map unmounted before timeout fired
      }
    }, 150);
    return () => clearTimeout(t);
  }, [streams, map]);
  return null;
}

export interface StreamInfo {
  id: string;
  title: string;
  username: string;
  display_name: string;
  avatar_url?: string;
  latitude?: number;
  longitude?: number;
  viewer_count: number;
  started_at: string;
}

interface Props {
  streams: StreamInfo[];
}

export default function StreamMap({ streams }: Props) {
  const withCoords = streams.filter((s) => s.latitude != null && s.longitude != null);

  return (
    <MapContainer
      center={[48, 15]}
      zoom={3}
      style={{ height: "100%", width: "100%" }}
      className="rounded-xl z-0"
    >
      <TileLayer
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      {withCoords.map((stream) => (
        <Marker
          key={stream.id}
          position={[stream.latitude!, stream.longitude!]}
          icon={liveIcon}
        >
          <Popup>
            <div className="min-w-[180px]">
              <p className="font-semibold text-sm">{stream.title}</p>
              <p className="text-xs text-gray-500 mb-2">{stream.display_name}</p>
              <Link
                href={`/streams/${stream.id}`}
                className="block text-center bg-red-500 text-white text-xs font-semibold px-3 py-1.5 rounded-lg hover:bg-red-600"
              >
                Смотреть
              </Link>
            </div>
          </Popup>
        </Marker>
      ))}
      {withCoords.length > 0 && <FitBounds streams={streams} />}
    </MapContainer>
  );
}
