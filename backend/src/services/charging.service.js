/**
 * EVon Charging Calculation Service
 * Computes energy required (kWh), charging duration (hours), and estimated cost.
 */
const calculateCharging = (batteryCapacity, currentSoc, desiredSoc, chargerPowerKw, costPerKwh = 12.0) => {
  const battery = parseFloat(batteryCapacity);
  const cur = parseFloat(currentSoc);
  const des = parseFloat(desiredSoc);
  const power = parseFloat(chargerPowerKw);

  if (isNaN(battery) || isNaN(cur) || isNaN(des) || isNaN(power)) {
    return { error: 'Invalid numeric parameters for charging calculation.' };
  }

  if (cur < 0 || cur > 100 || des < 0 || des > 100) {
    return { error: 'SoC (State of Charge) must be between 0 and 100%.' };
  }

  if (des <= cur) {
    return { error: 'Desired charge level must be greater than current battery level.' };
  }

  const energy = (battery * (des - cur)) / 100.0;
  const duration = power > 0 ? energy / power : 0;
  const cost = energy * costPerKwh;

  return {
    energyRequired: parseFloat(energy.toFixed(2)),
    chargingDuration: parseFloat(duration.toFixed(2)),
    estimatedCost: parseFloat(cost.toFixed(2)),
    error: null,
  };
};

module.exports = { calculateCharging };
