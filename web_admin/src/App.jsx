import React, { useState, useEffect, useRef } from 'react';
import { MapContainer, TileLayer, Marker, Popup, Polygon, FeatureGroup, useMap } from 'react-leaflet';
import { EditControl } from 'react-leaflet-draw';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import 'leaflet-draw/dist/leaflet.draw.css';
import * as signalR from '@microsoft/signalr';
import { Shield, Map as MapIcon, Bell, Trash2, Crosshair, Navigation, Activity } from 'lucide-react';

// Fix Default Leaflet Icon Issue
delete L.Icon.Default.prototype._getIconUrl;
L.Icon.Default.mergeOptions({
  iconRetinaUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon-2x.png',
  iconUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-icon.png',
  shadowUrl: 'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.7.1/images/marker-shadow.png',
});

// Auto-center map component
function ChangeView({ center, zoom, forceUpdate }) {
  const map = useMap();
  useEffect(() => {
    if (center && center.length === 2 && center[0] && center[1]) {
      map.setView(center, zoom || map.getZoom());
    }
  }, [center, map, zoom, forceUpdate]);
  return null;
}

function App() {
  const [locations, setLocations] = useState({});
  const [geofences, setGeofences] = useState([]);
  const [events, setEvents] = useState([]);
  const [mapCenter, setMapCenter] = useState([-17.7833, -63.1821]); // Santa Cruz de la Sierra, Bolivia
  const [forceUpdate, setForceUpdate] = useState(0); 
  const connectionRef = useRef(null);

  useEffect(() => {
    // Traducir los botones flotantes de Leaflet Draw
    if (L.drawLocal) {
      L.drawLocal.draw.toolbar.actions.text = '✅ GUARDAR ZONA';
      L.drawLocal.draw.toolbar.actions.title = 'Terminar de dibujar';
      L.drawLocal.draw.toolbar.undo.text = 'Deshacer último punto';
      L.drawLocal.draw.toolbar.undo.title = 'Eliminar el último punto dibujado';
      L.drawLocal.draw.handlers.polygon.tooltip.start = 'Haz clic para empezar a dibujar';
      L.drawLocal.draw.handlers.polygon.tooltip.cont = 'Haz clic para añadir otro punto';
      L.drawLocal.draw.handlers.polygon.tooltip.end = 'Haz clic en el PRIMER punto para cerrar la zona, o en "Guardar Zona"';
      
      L.drawLocal.edit.toolbar.actions.save.title = 'Guardar los cambios';
      L.drawLocal.edit.toolbar.actions.save.text = '✅ GUARDAR CAMBIOS';
      L.drawLocal.edit.toolbar.actions.cancel.title = 'Cancelar edición';
      L.drawLocal.edit.toolbar.actions.cancel.text = 'Cancelar';
      L.drawLocal.edit.handlers.edit.tooltip.text = 'Arrastra los puntos para modificar la zona.';
      L.drawLocal.edit.handlers.edit.tooltip.subtext = 'Haz clic en GUARDAR CAMBIOS abajo cuando termines.';
    }

    fetchGeofences();
    fetchActiveLocations();
    fetchRecentEvents();

    const backendUrl = "https://geofencer-api.onrender.com";
    
    // Connect to WebSockets for live Tracking
    const connection = new signalR.HubConnectionBuilder()
      .withUrl(`${backendUrl}/monitoringHub`)
      .withAutomaticReconnect()
      .build();

    connection.on("ReceiveLocationUpdate", (data) => {
      // Ignorar ubicaciones falsas
      if (data.userId === "admin" || data.userId === "Unknown") return;

      setLocations(prev => {
        // En este nuevo diseño, no lo auto-centramos todo el tiempo para dejar dibujar
        // Sólo guardamos la ubicación
        return { ...prev, [data.userId]: data };
      });

      // Registrar evento si cruzó una frontera
      if (data.event && data.event !== "Ninguno") {
        const newEvent = {
          id: Math.random().toString(36).substr(2, 9),
          type: data.event,
          userId: data.userId,
          geofenceName: data.geofenceName || 'Zona Detectada',
          timestamp: new Date().toISOString()
        };
        setEvents(prev => [newEvent, ...prev].slice(0, 15));
      }
    });

    connection.start().then(() => {
      connection.invoke("JoinMonitoringGroup", "admin");
    }).catch(err => console.log('SignalR Error: ', err));

    connectionRef.current = connection;
    return () => { if (connectionRef.current) connectionRef.current.stop(); };
  }, []);

  const fetchGeofences = () => {
    fetch('https://geofencer-api.onrender.com/api/geofence')
      .then(res => res.json())
      .then(data => setGeofences(data))
      .catch(err => console.error(err));
  };

  const fetchRecentEvents = () => {
    fetch('https://geofencer-api.onrender.com/api/event?limit=15')
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
      .catch(err => console.error(err));
  };

  const fetchActiveLocations = () => {
    fetch('https://geofencer-api.onrender.com/api/location/all')
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          const locs = {};
          data.forEach(item => {
            if (item.userId === "admin" || item.userId === "Unknown") return;
            item.latitude = item.latitude || item.lat;
            item.longitude = item.longitude || item.lon;
            locs[item.userId] = item; 
          });
          setLocations(locs);
          const validLocs = Object.values(locs);
          if (validLocs.length > 0) {
            setMapCenter([validLocs[0].latitude, validLocs[0].longitude]);
          }
        }
      })
      .catch(err => console.error(err));
  };

  const centerOnUser = () => {
    const validLocs = Object.values(locations);
    if (validLocs.length > 0) {
      setMapCenter([validLocs[0].latitude, validLocs[0].longitude]);
      setForceUpdate(prev => prev + 1); // Dispara el render effect de cámara
    }
  };

  const onCreated = async (e) => {
    const { layerType, layer } = e;
    if (layerType === 'polygon') {
      const latlngs = layer.getLatLngs()[0];
      const closed = [...latlngs, latlngs[0]];
      const wkt = `POLYGON((${closed.map(ll => `${ll.lng} ${ll.lat}`).join(', ')}))`;

      const name = prompt("Nombre de esta zona (Ej. Zona Peligrosa, Casa):", "Nueva Zona");
      if (!name) { layer.remove(); return; }

      try {
        const res = await fetch('https://geofencer-api.onrender.com/api/geofence', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ name: name, description: 'Creada en Web', wkt: wkt })
        });
        if (res.ok) {
          fetchGeofences();
        }
        layer.remove();
      } catch (err) { console.error(err); }
    }
  };

  const onEdited = async (e) => {
    const layers = e.layers;
    layers.eachLayer(async (layer) => {
      const id = layer.options.geofenceId || layer.options.id;
      if (!id) return;
      
      const latlngs = layer.getLatLngs()[0];
      const closed = [...latlngs, latlngs[0]];
      const wkt = `POLYGON((` + closed.map(ll => `${ll.lng} ${ll.lat}`).join(', ') + `))`;
      
      try {
        await fetch(`https://geofencer-api.onrender.com/api/geofence/${id}`, {
          method: 'PUT',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ wkt })
        });
      } catch (err) { console.error(err); }
    });
    // Al final refescamos
    setTimeout(fetchGeofences, 1000);
  };

  const deleteGeofence = async (id, name) => {
    if (!window.confirm(`¿Desea borrar la zona "${name}"?`)) return;
    try {
      const res = await fetch(`https://geofencer-api.onrender.com/api/geofence/${id}`, { method: 'DELETE' });
      if (res.ok) fetchGeofences();
    } catch (err) { console.error(err); }
  };

  const getGeofencePositions = (wkt) => {
    if (!wkt) return [];
    try {
      const match = wkt.match(/\(\((.*?)\)\)/);
      if (!match) return [];
      return match[1].split(',').map(c => {
        const parts = c.trim().split(/\s+/);
        return [parseFloat(parts[1]), parseFloat(parts[0])];
      });
    } catch(e) { return []; }
  };

  const focusOnGeofence = (wkt) => {
    const coords = getGeofencePositions(wkt);
    if(coords.length > 0) {
      // Tomamos el primer punto que delimita la zona para enfocar
      setMapCenter([coords[0][0], coords[0][1]]);
      setForceUpdate(prev => prev + 1);
    }
  };

  return (
    <div className="dashboard-layout light-theme">
      {/* MAP BACKGROUND */}
      <div className="map-background">
        <MapContainer center={mapCenter} zoom={16} zoomControl={false} scrollWheelZoom={true}>
          <ChangeView center={mapCenter} zoom={16} forceUpdate={forceUpdate} />
          
          <TileLayer
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
            attribution='&copy; OpenStreetMap'
          />
          
          <FeatureGroup>
            <EditControl
              position='topleft'
              onCreated={onCreated}
              onEdited={onEdited}
              draw={{ circle: false, rectangle: false, circlemarker: false, marker: false, polyline: false }}
            />
            {geofences.map(gf => {
               const positions = getGeofencePositions(gf.wkt);
               if (!positions || positions.length < 3) return null;
               return (
                 <Polygon 
                    key={gf.id} 
                    positions={positions} 
                    pathOptions={{ geofenceId: gf.id, id: gf.id, color: "#0ea5e9", fillColor: "#0ea5e9", fillOpacity: 0.15, weight: 2, dashArray: "5, 10" }}
                 >
                   <Popup><b style={{color: '#0f172a'}}>{gf.name}</b></Popup>
                 </Polygon>
               );
            })}
          </FeatureGroup>

          {Object.values(locations).map((loc, i) => (
            <Marker key={i} position={[loc.latitude, loc.longitude]}>
              <Popup>
                 <div style={{color: '#0f172a', fontWeight: 'bold', fontSize: '14px'}}>
                   🚙 Activo<br/>
                   <span style={{color: '#10b981'}}>{(loc.speed * 3.6 || 0).toFixed(1)} km/h</span>
                 </div>
              </Popup>
            </Marker>
          ))}
        </MapContainer>
      </div>

      {/* OVERLAYS UI */}
      <div className="ui-overlay">
        
        {/* HEADER GLASS */}
        <header className="glass-header">
          <div className="header-brand">
            <div className="brand-icon-wrapper"><Shield className="brand-icon" size={24} /></div>
            <div className="brand-text">
              <h1>GEOFENCER PRO</h1>
              <p>Centro de Control Táctico</p>
            </div>
          </div>
          <button className="glass-btn primary" onClick={centerOnUser}>
            <Crosshair size={18} />
            <span>Ubicar Vehículo</span>
          </button>
        </header>

        {/* CSS GRID BOTTOM/SIDE PANELS */}
        <div className="panels-wrapper">
          
          {/* ZONAS PANEL */}
          <div className="glass-panel">
            <div className="panel-header">
              <div className="panel-title">
                <MapIcon size={18} className="icon-blue" />
                <h2>Zonas Activas</h2>
              </div>
              <span className="badge">{geofences.length}</span>
            </div>
            <div className="glass-scroll-list">
              {geofences.map(gf => (
                <div key={gf.id} className="glass-card">
                  <div className="card-info">
                    <h3>{gf.name}</h3>
                    <p>Monitoreo estricto</p>
                  </div>
                  <div className="card-actions">
                    <button className="action-btn icon-btn" onClick={() => focusOnGeofence(gf.wkt)}>
                      <Navigation size={16} />
                    </button>
                    <button className="action-btn icon-btn danger" onClick={() => deleteGeofence(gf.id, gf.name)}>
                      <Trash2 size={16} />
                    </button>
                  </div>
                </div>
              ))}
              {geofences.length === 0 && <div className="empty-state">No hay zonas definidas. Usa el lápiz verde en el mapa para delimitar un perímetro de seguridad.</div>}
            </div>
          </div>

          {/* ALERTAS PANEL */}
          <div className="glass-panel alerts-panel">
             <div className="panel-header">
              <div className="panel-title">
                <Activity size={18} className="icon-red" />
                <h2>Registro en Tiempo Real</h2>
              </div>
              {events.length > 0 && <span className="pulse-dot"></span>}
            </div>
            <div className="glass-scroll-list">
              {events.map((ev, i) => (
                <div key={i} className={`glass-card alert border-${ev.type === 'Enter' ? 'green' : 'red'}`}>
                  <div className={`alert-icon-circle ${ev.type === 'Enter' ? 'bg-green' : 'bg-red'}`}>
                    <Bell size={14} />
                  </div>
                  <div className="card-info">
                    <h4>{ev.type === 'Enter' ? 'Ingreso Autorizado' : 'SALIDA DE PERÍMETRO'}</h4>
                    <p>{ev.geofenceName}</p>
                  </div>
                  <div className="alert-time">
                    {new Date(ev.timestamp).toLocaleTimeString([], {hour: '2-digit', minute:'2-digit'})}
                  </div>
                </div>
              ))}
              {events.length === 0 && <div className="empty-state">Sistema activo. Monitoreando anomalías e infracciones de perímetro.</div>}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
}

export default App;
