const derbyDriver = require('./derby');
const erewashDriver = require('./erewash');

const COUNCILS = [derbyDriver, erewashDriver];

const drivers = {};
const slugMap = {};

for (const driver of COUNCILS) {
  drivers[driver.id] = driver;
  slugMap[driver.id] = driver;
  slugMap[driver.slug] = driver;
  slugMap[driver.name.toLowerCase()] = driver;
}

function getDriver(councilId) {
  if (!councilId) return null;
  return slugMap[councilId.trim().toLowerCase()] || null;
}

function listDrivers() {
  return Object.values(drivers).map(d => ({ id: d.id, name: d.name, slug: d.slug }));
}

module.exports = { getDriver, listDrivers };
