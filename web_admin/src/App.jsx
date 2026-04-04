import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polygon, FeatureGroup, useMap } from 'react-leaflet';
import { EditControl } from 'react-leaflet-draw';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet-draw/dist/leaflet.draw.css';
import { 
  Shield, Map as MapIcon, Settings, Bell, BarChart3, User, 
  Navigation, AlertTriangle, Trash2, Crosshair, Zap, Activity
} from 'lucide-react';
import * as signalR from '@microsoft/signalr';

// Fix Default Leaflet Icon Issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Component to handle map center changes
function ChangeView({ center, zoom }) {
  const map = useMap();
  if (center) map.setView(center, zoom || map.getZoom());
  return null;
}

function App() {
  const [locations, setLocations] = useState({});
  const [geofences, setGeofences] = useState([]);
  const [events, setEvents] = useState([]);
  const [mapCenter, setMapCenter] = useState([4.711, -74.072]);
  const [connectionStatus, setConnectionStatus] = useState('Disconnected');
  const [activeTab, setActiveTab] = useState('live');
  const [isSimulating, setIsSimulating] = useState(false);

  const connectionRef = useRef(null);
  const simulationRef = useRef(null);
  const simPosRef = useRef({ lat: 4.711, lon: -74.072 });

  const toggleSimulation = () => {
    if (isSimulating) {
      clearInterval(simulationRef.current);
      setIsSimulating(false);
    } else {
      setIsSimulating(true);
      // Actualizamos la posición inicial al centro seleccionado para probar mejor
      simPosRef.current = { lat: mapCenter[0], lon: mapCenter[1] };
      
      simulationRef.current = setInterval(async () => {
        // Mover el punto un poco hacia el noreste
        simPosRef.current = {
          lat: simPosRef.current.lat + 0.0005,
          lon: simPosRef.current.lon + 0.0002
        };
        try {
          await fetch('https://geofencer-api.onrender.com/api/location/ping', {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify({
              deviceId: 'HONORANY-SIM',
              latitude: simPosRef.current.lat,
              longitude: simPosRef.current.lon,
              speed: 12.5,
              accuracy: 5
            })
          });
        } catch(e) {}
      }, 3000); // Enviar 'ping' cada 3 segundos
    }
  };

  useEffect(() => {
    // 1. Initial Load
    fetchGeofences();
    fetchRecentEvents();

    const backendUrl = "https://geofencer-api.onrender.com";
    
    // 2. SignalR Setup
    const connection = new signalR.HubConnectionBuilder()
      .withUrl(`${backendUrl}/monitoringHub`)
      .withAutomaticReconnect()
      .build();

    connection.on("ReceiveLocationUpdate", (data) => {
      setLocations(prev => ({ ...prev, [data.userId]: data }));
      
      // If there's an event tied to this location update, add it to events
      if (data.event) {
        const newEvent = {
          id: Math.random().toString(36).substr(2, 9),
          type: data.event,
          userId: data.userId,
          geofenceName: data.geofenceName || 'Zona Detectada',
          timestamp: new Date().toISOString()
        };
        setEvents(prev => [newEvent, ...prev].slice(0, 50));
      }
    });

    connection.start()
      .then(() => {
        setConnectionStatus('Connected');
        console.log('SignalR Connected');
        connection.invoke("JoinMonitoringGroup", "admin");
      })
      .catch(err => {
        setConnectionStatus('Error');
        console.log('SignalR Error: ', err);
      });

    connectionRef.current = connection;

    return () => {
      if (connectionRef.current) connectionRef.current.stop();
    };
  }, []);

  const fetchGeofences = () => {
    fetch('https://geofencer-api.onrender.com/api/geofence')
      .then(res => res.json())
      .then(data => setGeofences(data))
      .catch(err => {
        console.error("Error loading geofences", err);
        setConnectionStatus('Backend Error');
      });
  };

  const fetchRecentEvents = () => {
    fetch('https://geofencer-api.onrender.com/api/event?limit=20')
      .then(res => res.json())
      .then(data => {
        const eventTypes = ["Enter", "Exit", "OutsideTooLong", "SuspiciousMovement"];
        const formattedData = data.map(ev => ({
            ...ev,
            type: typeof ev.type === 'number' ? eventTypes[ev.type] : ev.type,
            geofenceName: ev.geofence?.name || 'Zona Detectada'
        }));
        setEvents(formattedData);
      })
      .catch(err => console.error("Error loading events", err));
  };

  const onCreated = async (e) => {
    const { layerType, layer } = e;
    if (layerType === 'polygon') {
      const latlngs = layer.getLatLngs()[0];
      const closed = [...latlngs, latlngs[0]];
      const wkt = `POLYGON((${closed.map(ll => `${ll.lng} ${ll.lat}`).join(', ')}))`;

      try {
        const name = prompt("Nombre de la Geocerca:", `Zona ${geofences.length + 1}`);
        if (!name) { layer.remove(); return; }

        const res = await fetch('https://geofencer-api.onrender.com/api/geofence', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: name, description: 'Creada desde Dashboard', wkt: wkt })
        });
        if (res.ok) {
          fetchGeofences();
          layer.remove();
        }
      } catch (err) {
        console.error(err);
      }
    }
  };

  const deleteGeofence = async (id) => {
    if (!window.confirm("¿Eliminar esta geocerca?")) return;
    try {
      const res = await fetch(`https://geofencer-api.onrender.com/api/geofence/${id}`, { method: 'DELETE' });
      if (res.ok) fetchGeofences();
    } catch (err) {
      console.error(err);
    }
  };

  const getGeofencePositions = (wkt) => {
    if (!wkt) return [];
    try {
      // Usar regex para extraer todo lo que esté entre los paréntesis dobles
      const match = wkt.match(/\(\((.*?)\)\)/);
      if (!match) return [];
      
      const coords = match[1].split(',');
      return coords.map(c => {
        const parts = c.trim().split(/\s+/);
        const lng = parseFloat(parts[0]);
        const lat = parseFloat(parts[1]);
        if (isNaN(lat) || isNaN(lng)) throw new Error("Invalid coordinate");
        return [lat, lng];
      });
    } catch(e) {
      console.error("WKT Parse error:", e);
      return [];
    }
  };

  const focusOnGeofence = (wkt) => {
    const positions = getGeofencePositions(wkt);
    if (positions.length > 0) {
      setMapCenter(positions[0]);
    }
  };

  return (
    <div className="dashboard">
      <aside className="sidebar">
        <div className="logo">
          <Shield size={32} />
          <span>GEOFENCER</span>
        </div>
        
        <nav style={{ flex: 1 }}>
          <div 
            className={`nav-item ${activeTab === 'live' ? 'active' : ''}`}
            onClick={() => setActiveTab('live')}
          >
            <MapIcon size={20} /> Mapa en Vivo
          </div>
          <div 
            className={`nav-item ${activeTab === 'zones' ? 'active' : ''}`}
            onClick={() => setActiveTab('zones')}
          >
            <Shield size={20} /> Admin Zonas
          </div>
          <div className="nav-item"><AlertTriangle size={20} /> Alertas Críticas</div>
          <div className="nav-item"><BarChart3 size={20} /> Analíticas</div>
          <div className="nav-item"><Settings size={20} /> Configuración</div>
        </nav>

        <div className="glass-card" style={{ padding: '1rem', marginTop: 'auto' }}>
          <div className="status-indicator">
            <div className={`pulse ${connectionStatus === 'Connected' ? '' : 'error'}`} 
                 style={{backgroundColor: connectionStatus === 'Connected' ? 'var(--success)' : 'var(--error)'}}></div>
            <span>Sistema: {connectionStatus}</span>
          </div>
        </div>
      </aside>

      <main className="main-content">
        <header className="top-bar">
          <div>
            <h2>Panel de Control Geoespacial</h2>
            <p style={{fontSize: '0.8rem', color: 'var(--text-muted)'}}>Monitoreo de activos en tiempo real</p>
          </div>
          
          <div style={{ display: 'flex', gap: '1.5rem', alignItems: 'center' }}>
            
            <button 
              onClick={toggleSimulation}
              style={{
                background: isSimulating ? 'var(--error)' : 'var(--success)',
                color: 'white',
                border: 'none',
                padding: '0.6rem 1.2rem',
                borderRadius: '8px',
                fontWeight: 'bold',
                cursor: 'pointer',
                display: 'flex',
                alignItems: 'center',
                gap: '0.5rem',
                boxShadow: `0 0 15px ${isSimulating ? 'rgba(239, 68, 68, 0.4)' : 'rgba(34, 197, 94, 0.4)'}`
              }}
            >
              {isSimulating ? 'Detener Simulación' : 'Simular HONORANY'}
            </button>

            <div style={{ textAlign: 'right' }}>
              <div style={{ fontSize: '0.9rem', fontWeight: 'bold' }}>Admin Principal</div>
              <div style={{ fontSize: '0.7rem', color: 'var(--success)' }}>ONLINE</div>
            </div>
            <div style={{ width: 45, height: 45, background: 'linear-gradient(45deg, #333, #555)', borderRadius: '14px', border: '1px solid var(--border)' }}></div>
          </div>
        </header>

        <div className="map-container">
          <MapContainer center={mapCenter} zoom={15} zoomControl={false}>
            <ChangeView center={mapCenter} />
            <TileLayer
              url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
              attribution='&copy; OpenStreetMap contributors'
            />
            
            <FeatureGroup>
              <EditControl
                position='topleft'
                onCreated={onCreated}
                draw={{ circle: false, rectangle: false, circlemarker: false, marker: false, polyline: false }}
              />
              {geofences.map(gf => {
                 const positions = getGeofencePositions(gf.wkt);
                 if (!positions || positions.length < 3) return null;
                 
                 return (
                   <Polygon 
                      key={gf.id} 
                      positions={positions} 
                      pathOptions={{ color: "#6366f1", fillColor: "#6366f1", fillOpacity: 0.15, weight: 2 }}
                   >
                     <Popup>
                       <strong>{gf.name}</strong><br/>
                       {gf.description}
                     </Popup>
                   </Polygon>
                 );
              })}
            </FeatureGroup>

            {Object.values(locations).map((loc, i) => (
              <Marker key={i} position={[loc.latitude, loc.longitude]}>
                <Popup>
                  <div style={{color: '#000'}}>
                    <strong>{loc.userId}</strong><br/>
                    Velocidad: {(loc.speed * 3.6 || 0).toFixed(1)} km/h<br/>
                    <small>{new Date(loc.timestamp).toLocaleTimeString()}</small>
                  </div>
                </Popup>
              </Marker>
            ))}
          </MapContainer>

          <div className="right-panel">
            {/* Geofence List */}
            <div className="glass-card geofence-list-panel">
              <div className="panel-header">
                <h3><Shield size={18} color="var(--accent)" /> Geocercas Activas</h3>
                <span className="badge badge-accent">{geofences.length}</span>
              </div>
              <div className="scroll-area">
                {geofences.length === 0 && <p style={{color: 'var(--text-muted)', fontSize: '0.8rem'}}>No hay zonas definidas.</p>}
                {geofences.map(gf => (
                  <div key={gf.id} className="list-item" onClick={() => focusOnGeofence(gf.wkt)}>
                    <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'center'}}>
                      <div>
                        <div style={{fontWeight: 'bold', fontSize: '0.9rem'}}>{gf.name}</div>
                        <div style={{fontSize: '0.7rem', color: 'var(--text-muted)'}}>Polígono Activado</div>
                      </div>
                      <div style={{display: 'flex', gap: '0.5rem'}}>
                        <Crosshair size={16} color="var(--text-muted)" onClick={(e) => { e.stopPropagation(); focusOnGeofence(gf.wkt); }} />
                        <Trash2 size={16} color="var(--error)" onClick={(e) => { e.stopPropagation(); deleteGeofence(gf.id); }} />
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>

            {/* Event Log */}
            <div className="glass-card event-panel">
              <div className="panel-header">
                <h3><Activity size={18} color="var(--warning)" /> Registro de Eventos</h3>
                <Zap size={16} color="var(--warning)" />
              </div>
              <div className="scroll-area">
                {events.length === 0 && <p style={{color: 'var(--text-muted)', fontSize: '0.8rem'}}>Esperando telemetría...</p>}
                {events.map((ev, i) => (
                  <div key={i} className={`list-item event-item ${ev.type?.toLowerCase()}`}>
                    <div style={{display: 'flex', justifyContent: 'space-between', alignItems: 'start'}}>
                      <div>
                        <span className={`badge ${ev.type === 'Enter' ? 'badge-success' : 'badge-error'}`}>
                          {ev.type === 'Enter' ? 'ENTRADA' : 'SALIDA'}
                        </span>
                        <div style={{fontWeight: 'bold', fontSize: '0.9rem', marginTop: '0.4rem'}}>{ev.userId}</div>
                        <div style={{fontSize: '0.75rem', color: 'var(--text-main)'}}>{ev.geofenceName}</div>
                      </div>
                      <div style={{fontSize: '0.7rem', color: 'var(--text-muted)'}}>
                        {new Date(ev.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                      </div>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
}

export default App;
