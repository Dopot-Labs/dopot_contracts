// Load dependencies
const { expect } = require('chai');
 
let Project;
let project;
 
// Start test block
describe('Project', function () {
  beforeEach(async function () {
    Project = await ethers.getContractFactory("Project");
    project = await Project.deploy();
    await project.deployed();
  });
 
  // Test case
  it('retrieve returns a value previously stored', async function () {
    // Store a value
    await project.store(42);
 
    // Test if the returned value is the same one
    // Note that we need to use strings to compare the 256 bit integers
    expect((await project.retrieve()).toString()).to.equal('42');
  });
});