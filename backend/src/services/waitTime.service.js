/**
 * EVon Wait Time Estimation Service
 */

/**
 * Estimate wait time for a given station
 * @param {Object} station
 * @param {Number} requestedDuration - hours
 */
const estimateStationWaitTime = (station, requestedDuration = 0.5) => {
  const totalSlots = station.totalSlots || 4;
  const availableSlots = station.availableSlots || 0;
  const occupiedSlots = station.occupiedSlots || Math.max(0, totalSlots - availableSlots);

  // If there are free physical slots, wait time is 0
  if (availableSlots > 0) {
    return {
      estimatedWaitTimeHours: 0,
      estimatedWaitMinutes: 0,
      queueLength: 0,
      congestion: availableSlots <= 1 ? 'Medium' : 'Low',
    };
  }

  // If fully occupied, estimate average remaining time based on power and slots
  // Heuristic: occupied slots will free up uniformly over an average 45 min charge window
  const avgSessionHours = station.chargerPower >= 60 ? 0.5 : 1.0;
  const queueLength = occupiedSlots - totalSlots + 1;
  const waitHours = (Math.max(1, queueLength) * avgSessionHours) / totalSlots;

  return {
    estimatedWaitTimeHours: parseFloat(waitHours.toFixed(2)),
    estimatedWaitMinutes: Math.round(waitHours * 60),
    queueLength: Math.max(1, queueLength),
    congestion: waitHours > 0.5 ? 'High' : 'Medium',
  };
};

module.exports = { estimateStationWaitTime };
