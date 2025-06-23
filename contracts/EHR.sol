// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.28;

contract EHR {
    uint public requestId;

    constructor() {
        requestId = 0;
    }

    enum Role {
        ADMIN,
        PATIENT,
        DOCTOR,
        LAB_TECHNICIAN
    }

    enum ReportStatus {
        STARTED,
        REQUESTED,
        COMPLETED
    }

    struct User {
        Role role;
        string email;
        string passwordHash;
        address userWalletAddress;
    }

    struct ReportRequest {
        address patientAddress;
        uint completedAt;
        uint createdAt;
        string testName;
        ReportStatus status;
        address labTechnicianAddress;
        uint id;
    }

    struct PatientRecordFiles {
        string ipfsHash;
        uint appliedAt;
        uint testDoneAt;
        string testName;
        address labTechnicianAddress;
    }

    mapping(address => User) private users;
    mapping(address => bool) public isAdmin;
    mapping(address => bool) public isDoctor;
    mapping(address => bool) public isPatient;
    mapping(address => bool) public isLabTechnician;

    mapping(address => mapping(address => bool)) public access;
    mapping(address => PatientRecordFiles[]) private patientRecordFiles;

    ReportRequest[] private reportRequestsArray;

    // Events
    event AccessEvent(address indexed userAddress, address patientAddress, bool flag);
    event UserLogin(address indexed owner, string email, bool status);

    // -------------------- MODIFIERS --------------------

    modifier notRegistered() {
        require(bytes(users[msg.sender].email).length == 0, "Already registered");
        _;
    }

    modifier isRegistered() {
        require(bytes(users[msg.sender].email).length != 0, "User not registered");
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "Not an admin");
        _;
    }

    modifier onlyDoctor() {
        require(isDoctor[msg.sender], "Not a doctor");
        _;
    }

    modifier onlyPatient() {
        require(isPatient[msg.sender], "Not a patient");
        _;
    }

    modifier onlyLabTechnician() {
        require(isLabTechnician[msg.sender], "Not a lab technician");
        _;
    }

    // -------------------- REGISTRATION --------------------

    function registerPatient(string memory _passwordHash, string memory _email) public notRegistered {
        isPatient[msg.sender] = true;
        _register(_passwordHash, _email, Role.PATIENT);
    }

    function registerAdmin(string memory _passwordHash, string memory _email) public notRegistered {
        isAdmin[msg.sender] = true;
        _register(_passwordHash, _email, Role.ADMIN);
    }

    function registerDoctor(string memory _passwordHash, string memory _email) public notRegistered {
        isDoctor[msg.sender] = true;
        _register(_passwordHash, _email, Role.DOCTOR);
    }

    function registerLabTechnician(string memory _passwordHash, string memory _email) public notRegistered {
        isLabTechnician[msg.sender] = true;
        _register(_passwordHash, _email, Role.LAB_TECHNICIAN); 
    }

    function _register(string memory _passwordHash, string memory _email, Role role) private {
        users[msg.sender] = User(role, _email, _passwordHash, msg.sender);
    }

    // -------------------- LOGIN --------------------

    function login(string memory _email, string memory _passwordHash) public isRegistered returns (bool) {
        User memory user = users[msg.sender];

        bool isValid = (
            keccak256(abi.encodePacked(user.email)) == keccak256(abi.encodePacked(_email)) &&
            keccak256(abi.encodePacked(user.passwordHash)) == keccak256(abi.encodePacked(_passwordHash))
        );

        emit UserLogin(user.userWalletAddress, user.email, isValid);
        return isValid;
    }

    // -------------------- ACCESS CONTROL --------------------

    function grantAccess(address _userAddress, address _patientAddress) public onlyPatient {
        access[_patientAddress][_userAddress] = true;
        emit AccessEvent(_userAddress, _patientAddress, true);
    }

    function removeAccess(address _userAddress, address _patientAddress) public onlyPatient {
        access[_patientAddress][_userAddress] = false;
        emit AccessEvent(_userAddress, _patientAddress, false);
    }

    function hasAccess(address _userAddress, address _patientAddress) public view returns (bool) {
        return access[_patientAddress][_userAddress];
    }

    // -------------------- REPORT MANAGEMENT --------------------

    function requestReport(address _patientAddress, string memory _testName) public onlyDoctor {
        reportRequestsArray.push(
            ReportRequest({
                patientAddress: _patientAddress,
                completedAt: 0,
                createdAt: block.timestamp,
                testName: _testName,
                status: ReportStatus.REQUESTED,
                labTechnicianAddress: address(0),
                id: requestId
            })
        );
        requestId++;
    }

    function acceptReportRequest(uint _requestId, address _labAddress) public onlyDoctor {
        require(_requestId < reportRequestsArray.length, "Invalid request ID");

        ReportRequest storage request = reportRequestsArray[_requestId];
        require(request.status == ReportStatus.REQUESTED, "Already accepted");

        request.status = ReportStatus.STARTED;
        request.labTechnicianAddress = _labAddress;
    }

    function uploadReport(uint _requestId, string memory _ipfsHash, address _labAddress) public onlyLabTechnician {
        require(_requestId < reportRequestsArray.length, "Invalid request ID");

        ReportRequest storage request = reportRequestsArray[_requestId];
        require(request.status == ReportStatus.STARTED, "Report not accepted");

        request.status = ReportStatus.COMPLETED;
        request.completedAt = block.timestamp;

        patientRecordFiles[request.patientAddress].push(
            PatientRecordFiles({
                ipfsHash: _ipfsHash,
                appliedAt: request.createdAt,
                testDoneAt: block.timestamp,
                testName: request.testName,
                labTechnicianAddress: _labAddress
            })
        );
    }

    function fetchReports(address _patientAddress) public view returns (PatientRecordFiles[] memory) {
        return patientRecordFiles[_patientAddress];
    }

    function getAllReportRequests() public view returns (ReportRequest[] memory) {
        return reportRequestsArray;
    }
}
