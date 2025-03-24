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

    mapping(address => User) users;
    mapping(address => bool) isAdmin;
    mapping(address => bool) isDoctor;
    mapping(address => bool) isPatient;
    mapping(address => bool) isLabTechnician;
    mapping(address => string) patientRecords;
    mapping(address => mapping(address => bool)) access;
    mapping(address => PatientRecordFiles[]) patientRecordFiles;
    ReportRequest[] reportRequestsArray; 
    event AccessEvent(address indexed userAddress, address patientAddress, bool flag);

    modifier checkUserRegister() {
        require(
            bytes(users[msg.sender].email).length == 0,
            "Already registered"
        );
        _;
    }

    modifier isUserRegistered() {
        require(
            bytes(users[msg.sender].email).length != 0,
            "User not registered"
        );
        _;
    }

    modifier onlyAdmin() {
        require(isAdmin[msg.sender], "User doesn't have ADMIN access");
        _;
    }

    modifier onlyDoctor() {
        require(isDoctor[msg.sender], "User doesn't have DOCTOR access");
        _;
    }

    modifier onlyPatient() {
        require(isPatient[msg.sender], "User doesn't have PATIENT access");
        _;
    }

    modifier onlyLabTechnician() {
        require(
            isLabTechnician[msg.sender],
            "User doesn't have Lab Technician access"
        );
        _;
    }

    event UserLogin(address indexed onwer, string email, bool status);

    function registerPatient(
        string memory _passwordHash,
        string memory _email
    ) public checkUserRegister {
        isPatient[msg.sender] = true;
        register(_passwordHash, _email, Role.PATIENT);
    }

    function registerAdmin(
        string memory _passwordHash,
        string memory _email
    ) public checkUserRegister {
        isAdmin[msg.sender] = true;
        register(_passwordHash, _email, Role.ADMIN);
    }

    function registerDoctor(
        string memory _passwordHash,
        string memory _email
    ) public checkUserRegister {
        isDoctor[msg.sender] = true;
        register(_passwordHash, _email, Role.DOCTOR);
    }

    function registerLabTechnician(
        string memory _passwordHash,
        string memory _email
    ) public checkUserRegister {
        isLabTechnician[msg.sender] = true;
        register(_passwordHash, _email, Role.LAB_TECHNICIAN); 
    }

    function register(
        string memory _passwordHash,
        string memory _email,
        Role role
    ) private {
        users[msg.sender] = User(role, _email, _passwordHash, msg.sender);
    }

    function login(
        string memory _email,
        string memory _passwordHash
    ) public returns (bool) {
        User memory user = users[msg.sender];

        if (
            keccak256(abi.encodePacked(user.email)) ==
            keccak256(abi.encodePacked(_email)) &&
            keccak256(abi.encodePacked(user.passwordHash)) ==
            keccak256(abi.encodePacked(_passwordHash))
        ) {
            emit UserLogin(user.userWalletAddress, user.email, true);
            return true;
        }

        emit UserLogin(user.userWalletAddress, user.email, false);
        return false;
    }

    function hasAccess(
        address _userAddress,
        address _patientAddress
    ) public   {
        bool flag = access[_patientAddress][_userAddress];
        emit AccessEvent(_userAddress, _patientAddress, flag);
    }

    function grantAccess(
        address _userAddress,
        address _patientAddress
    ) public  {
        access[_patientAddress][_userAddress] = true;
    }

    function removeAccess(
        address _userAddress,
        address _patientAddress
    ) public  {
        access[_patientAddress][_userAddress] = false;
    }

    function requestReport(address _patientAddress, string memory _testName) public {
        ReportRequest memory request = ReportRequest({
            patientAddress: _patientAddress,
            completedAt: 0,
            createdAt: block.timestamp,
            testName: _testName,
            status: ReportStatus.REQUESTED,
            labTechnicianAddress: address(0),
            id:requestId
        });

        reportRequestsArray.push(request);
        requestId += 1;
    }

    function accecptReportRequest(uint _requestId, address _labAddress) public {

        reportRequestsArray[_requestId].status = ReportStatus.STARTED;
        reportRequestsArray[_requestId].labTechnicianAddress = _labAddress;
    }
    
    function getAllReportRequest() public view returns(ReportRequest[] memory) {
        return reportRequestsArray;
    }

    function uploadReport(
        uint _requestId,
        string memory _ipfsHash,
        address _labAddress
    ) public {  

        reportRequestsArray[_requestId].status = ReportStatus.COMPLETED;
        reportRequestsArray[_requestId].completedAt = block.timestamp;

        patientRecordFiles[reportRequestsArray[_requestId].patientAddress].push(
            PatientRecordFiles({
                ipfsHash: _ipfsHash,
                appliedAt: reportRequestsArray[_requestId].createdAt,
                testDoneAt: block.timestamp,
                testName: reportRequestsArray[_requestId].testName,
                labTechnicianAddress: _labAddress
            })
        );
    }

    function fetchReports(address _patientAddress)
        public
        view
        returns (PatientRecordFiles[] memory)
    {
        return patientRecordFiles[_patientAddress];
    }
}
