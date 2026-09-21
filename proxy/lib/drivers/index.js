const derbyDriver = require('./derby');
const erewashDriver = require('./erewash');
const ambervalleyDriver = require('./ambervalley');
const highpeakDriver = require('./highpeak');
const derbyshiredalesDriver = require('./derbyshiredales');
const bolsoverDriver = require('./bolsover');
const chesterfieldDriver = require('./chesterfield');
const southderbyshireDriver = require('./southderbyshire');
const northeastderbyshireDriver = require('./northeastderbyshire');

const COUNCILS = [
  derbyDriver, erewashDriver, ambervalleyDriver, highpeakDriver,
  derbyshiredalesDriver, bolsoverDriver, chesterfieldDriver, southderbyshireDriver,
  northeastderbyshireDriver,
];

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
