const { expect } = require("chai");

describe("Project", function() {
  it('works', async () => {
    const Project = await ethers.getContractFactory("Project");
    const ProjectV2 = await ethers.getContractFactory("ProjectV2");

    const instance = await upgrades.deployProxy(Project, [42]);
    const upgraded = await upgrades.upgradeProxy(instance.address, ProjectV2);

    const value = await upgraded.value();
    expect(value.toString()).to.equal('42');
  });
});