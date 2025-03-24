const { buildModule } = require("@nomicfoundation/hardhat-ignition/modules");

module.exports = buildModule("EHRModule", (m) => {

  const ehr = m.contract("EHR", [], { });

  return { ehr };
});