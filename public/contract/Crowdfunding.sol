// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Crowdfunding {
    address public platformOwner;
    uint public projectCount;

    struct Project {
        address owner;
        string title;
        string description;
        uint goal;
        uint deadline;
        uint fundsRaised;
        bool isCompleted;
    }

    mapping(uint => Project) public projects;
    mapping(uint => mapping(address => uint)) public contributions;

    constructor() {
        platformOwner = msg.sender;
    }

    // Events
    event ProjectCreated(uint projectId, string title, uint goal, uint deadline);
    event ContributionReceived(uint projectId, address contributor, uint amount);
    event ProjectCompleted(uint projectId);
    event RefundIssued(uint projectId, address contributor, uint amount);

    // Modifier to ensure the project is active
    modifier activeProject(uint projectId) {
        require(block.timestamp < projects[projectId].deadline, "Project has ended");
        require(!projects[projectId].isCompleted, "Project already completed");
        _;
    }

    // Create a new project
    function createProject(
        string memory _title,
        string memory _description,
        uint _goal,
        uint _durationInDays
    ) public returns (uint) {
        require(_goal > 0, "Goal must be greater than zero");
        require(_durationInDays > 0, "Duration must be greater than zero");

        projectCount++;
        projects[projectCount] = Project(
            msg.sender,
            _title,
            _description,
            _goal,
            block.timestamp + (_durationInDays * 1 days),
            0,
            false
        );

        emit ProjectCreated(projectCount, _title, _goal, projects[projectCount].deadline);
        return projectCount;
    }

    // Contribute to a project
    function contribute(uint _projectId) public payable activeProject(_projectId) {
        require(msg.value > 0, "Contribution must be greater than zero");

        Project storage project = projects[_projectId];
        require(project.fundsRaised < project.goal, "Funding goal already met");

        project.fundsRaised += msg.value;
        contributions[_projectId][msg.sender] += msg.value;

        emit ContributionReceived(_projectId, msg.sender, msg.value);

        if (project.fundsRaised >= project.goal) {
            project.isCompleted = true;
            emit ProjectCompleted(_projectId);
        }
    }

    // Withdraw funds if the project is completed
    function withdrawFunds(uint _projectId) public {
        Project storage project = projects[_projectId];
        require(msg.sender == project.owner, "Only project owner can withdraw");
        require(project.isCompleted, "Project funding goal not met yet");

        uint amount = project.fundsRaised;
        project.fundsRaised = 0;

        // Transfer funds to the project owner
        (bool success, ) = project.owner.call{value: amount}("");
        require(success, "Transfer failed");

        // By setting project.fundsRaised to 0 before transferring funds, we minimize the risk of reentrancy.
    }

    // Refund contributions if the project is not completed
    function refund(uint _projectId) public {
        Project storage project = projects[_projectId];
        require(block.timestamp > project.deadline, "Project is still active");
        require(!project.isCompleted, "Project funding goal met");

        uint amount = contributions[_projectId][msg.sender];
        require(amount > 0, "No contributions to refund");

        contributions[_projectId][msg.sender] = 0;

        // Transfer funds back to the contributor
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "Refund failed");

        // By setting contributions[_projectId][msg.sender] to 0 before transferring funds, we minimize the risk of reentrancy.
        emit RefundIssued(_projectId, msg.sender, amount);
    }

    // Get details of a project
    function getProject(uint _projectId) public view returns (
        address, string memory, string memory, uint, uint, uint, bool
    ) {
        Project storage project = projects[_projectId];
        return (
            project.owner,
            project.title,
            project.description,
            project.goal,
            project.deadline,
            project.fundsRaised,
            project.isCompleted
        );
    }

    // Get all active projects
    function getActiveProjects() public view returns (uint[] memory) {
        uint[] memory activeProjects = new uint[](projectCount);
        uint counter = 0;

        for (uint i = 1; i <= projectCount; i++) {
            if (!projects[i].isCompleted && block.timestamp < projects[i].deadline) {
                activeProjects[counter] = i;
                counter++;
            }
        }

        return activeProjects;
    }
}