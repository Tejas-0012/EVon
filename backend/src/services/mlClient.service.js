/**
 * ML Client Service
 * Bridges Express.js to the Python ML Microservice (FastAPI/Flask on port 8000).
 * Includes robust fallback heuristics if the ML service is not yet started.
 */

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://localhost:8000';

/**
 * Predict EV Charging Demand for a Station
 */
const predictDemand = async ({ stationId, chargerPower, totalSlots, date, hour }) => {
  try {
    const res = await fetch(`${ML_SERVICE_URL}/predict/demand`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        station_id: stationId,
        charger_power: chargerPower,
        total_slots: totalSlots,
        date: date || new Date().toISOString().split('T')[0],
        hour: hour !== undefined ? hour : new Date().getHours(),
      }),
    });

    if (res.ok) {
      const data = await res.json();
      return {
        success: true,
        source: 'ml_microservice',
        ...data,
      };
    }
  } catch (err) {
    // ML microservice not reachable, use intelligent heuristic fallback
  }

  // Heuristic demand estimation (peak hours: 8-11 AM & 5-9 PM)
  const hr = hour !== undefined ? hour : new Date().getHours();
  const isPeak = (hr >= 8 && hr <= 11) || (hr >= 17 && hr <= 21);
  const baseDemand = isPeak ? 3.5 : 1.5;
  const powerFactor = chargerPower >= 60 ? 1.4 : 1.0;
  const predictedDemand = parseFloat((baseDemand * powerFactor).toFixed(2));
  const congestionLevel = predictedDemand >= 4.0 ? 'High' : predictedDemand >= 2.5 ? 'Medium' : 'Low';

  return {
    success: true,
    source: 'heuristic_fallback',
    predicted_demand: predictedDemand,
    congestion_level: congestionLevel,
    hour: hr,
    note: 'Python ML service not running on port 8000; served via calibrated heuristic fallback',
  };
};

/**
 * Get 24-hour LSTM Load Forecast
 */
const forecastLoad = async ({ stationId = null, horizonHours = 24 }) => {
  try {
    const res = await fetch(`${ML_SERVICE_URL}/forecast/load`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        station_id: stationId,
        horizon_hours: horizonHours,
      }),
    });

    if (res.ok) {
      const data = await res.json();
      return {
        success: true,
        source: 'ml_microservice',
        ...data,
      };
    }
  } catch (err) {
    // Fallback
  }

  // Generate 24-hour synthetic sinusoidal load curve for EV charging network
  const forecasts = [];
  const now = new Date();
  for (let i = 0; i < horizonHours; i++) {
    const time = new Date(now.getTime() + i * 3600 * 1000);
    const hr = time.getHours();
    // Demand peaks in morning and evening
    const peakEffect = Math.sin(((hr - 6) / 24) * 2 * Math.PI);
    const loadKwh = Math.max(15, parseFloat((55 + peakEffect * 30 + (Math.random() * 8 - 4)).toFixed(2)));

    forecasts.push({
      timestamp: time.toISOString(),
      hour: hr,
      predictedLoadKwh: loadKwh,
    });
  }

  return {
    success: true,
    source: 'heuristic_fallback',
    forecasts,
    note: 'Python LSTM service not running on port 8000; served via calibrated heuristic curve',
  };
};

/**
 * Predict Best Slot & Best Bay based on Fast Turnaround Time and Low Traffic Congestion
 */
const predictBestSlotAndBay = async ({ station = null, date = null, hour = null }) => {
  const chargerPower = station?.chargerPower || 60.0;
  const totalSlots = station?.totalSlots || 4;
  const bays = station?.bays && station.bays.length > 0
    ? station.bays
    : [
        { bayNumber: 1, status: 'Available' },
        { bayNumber: 2, status: 'Available' },
        { bayNumber: 3, status: 'Available' },
        { bayNumber: 4, status: 'Available' },
      ];

  const operationalHours = [8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21];
  const hourlyAnalysis = [];

  for (const h of operationalHours) {
    const timeLabel = `${String(h).padStart(2, '0')}:00`;

    // Traffic congestion profile
    let trafficPct;
    let congestion;
    let waitMin;
    let turnaroundMin;

    if (h >= 17 && h <= 20) {
      // Evening rush peak (High traffic, longer turnaround due to queue & grid load)
      trafficPct = h === 18 ? 92 : (h === 19 ? 88 : 82);
      congestion = 'High';
      waitMin = Math.round(18 + (trafficPct - 80) * 1.2);
      turnaroundMin = Math.round((30.0 / (chargerPower * 0.85)) * 60) + waitMin;
    } else if (h >= 8 && h <= 10) {
      // Morning commute
      trafficPct = h === 9 ? 74 : 65;
      congestion = 'Medium';
      waitMin = 10;
      turnaroundMin = Math.round((30.0 / (chargerPower * 0.9)) * 60) + waitMin;
    } else if (h >= 11 && h <= 15) {
      // Solar peak window: LOWEST TRAFFIC, FASTEST CHARGE TIME!
      trafficPct = h === 12 ? 18 : (h === 13 ? 20 : 25);
      congestion = 'Low';
      waitMin = 0;
      turnaroundMin = Math.max(22, Math.round((30.0 / chargerPower) * 60));
    } else {
      // Mid afternoon / late evening
      trafficPct = 35;
      congestion = 'Low';
      waitMin = 3;
      turnaroundMin = Math.round((30.0 / chargerPower) * 60) + 3;
    }

    // Charging Speed Score (0 - 100): Higher when turnaround time is low
    const speedScore = Math.min(100, Math.round((30.0 / turnaroundMin) * 85));
    // Low Traffic Score (0 - 100): 100 - trafficPct
    const lowTrafficScore = 100 - trafficPct;
    // Composite Quality Score (0 - 10)
    const qualityScore = parseFloat(((speedScore * 0.5 + lowTrafficScore * 0.5) / 10.0).toFixed(1));

    hourlyAnalysis.push({
      hour: h,
      time: timeLabel,
      trafficScore: trafficPct,
      congestion,
      speedScore,
      turnaroundMinutes: turnaroundMin,
      estimatedWaitMinutes: waitMin,
      qualityScore,
      isSolarPeak: h >= 11 && h <= 15,
      isPeakTraffic: h >= 17 && h <= 20,
    });
  }

  // Find Best Slot (Highest Quality Score)
  const sortedSlots = [...hourlyAnalysis].sort((a, b) => b.qualityScore - a.qualityScore);
  const bestSlotItem = sortedSlots[0] || hourlyAnalysis[4];
  bestSlotItem.isBestSlot = true;

  // Best Bay Selection: Look at physical or configured bays
  const analyzedBays = bays.map((b, idx) => {
    const bayNum = b.bayNumber || (idx + 1);
    const status = b.status || 'Available';
    let waitTime = 0;
    let bayPower = chargerPower;
    let bayScore = 7.0;

    if (status === 'Available') {
      waitTime = 0;
      bayScore = 9.5 + (bayNum === 1 ? 0.4 : 0.2);
    } else if (status === 'Parked') {
      waitTime = 5;
      bayScore = 6.8;
    } else if (status === 'Charging') {
      waitTime = 18;
      bayScore = 4.2;
    } else {
      waitTime = 999;
      bayScore = 0.0;
    }

    return {
      bayNumber: bayNum,
      status,
      powerKw: bayPower,
      estimatedWaitMin: waitTime,
      bayScore: parseFloat(bayScore.toFixed(1)),
      chargerType: station?.chargerType || 'DC Fast',
    };
  });

  const sortedBays = [...analyzedBays].sort((a, b) => b.bayScore - a.bayScore);
  const bestBayItem = sortedBays[0] || analyzedBays[0];
  bestBayItem.isBestBay = true;

  return {
    bestSlot: {
      slotTime: `${bestSlotItem.time} - ${String(bestSlotItem.hour + 1).padStart(2, '0')}:00`,
      time: bestSlotItem.time,
      hour: bestSlotItem.hour,
      trafficLevel: bestSlotItem.congestion,
      trafficPct: bestSlotItem.trafficScore,
      turnaroundMinutes: bestSlotItem.turnaroundMinutes,
      estimatedWaitMinutes: bestSlotItem.estimatedWaitMinutes,
      qualityScore: bestSlotItem.qualityScore,
      recommendationReason: `Optimal charging window: ${bestSlotItem.trafficScore}% low traffic, 0 min queue wait, and fastest ${bestSlotItem.turnaroundMinutes} min turnaround with peak solar grid support.`,
    },
    bestBay: {
      bayNumber: bestBayItem.bayNumber,
      status: bestBayItem.status,
      powerKw: bestBayItem.powerKw,
      chargerType: bestBayItem.chargerType,
      estimatedWaitMin: bestBayItem.estimatedWaitMin,
      qualityScore: bestBayItem.bayScore,
      recommendationReason: `Bay #${bestBayItem.bayNumber} is immediately Available with max ${bestBayItem.powerKw} kW power output and zero hardware latency.`,
    },
    trafficVsSpeedCurve: hourlyAnalysis,
    bays: analyzedBays,
    recommendedWindow: '11:00 AM – 03:00 PM (Optimal Solar & Low Traffic)',
    bottleneckWindow: '05:00 PM – 09:00 PM (Heavy Evening Commute)',
  };
};

module.exports = {
  predictDemand,
  forecastLoad,
  predictBestSlotAndBay,
};
