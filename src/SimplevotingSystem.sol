// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    AccessControl
} from "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract SimpleVotingSystem is Ownable, AccessControl {
    struct Candidate {
        uint id;
        string name;
        uint voteCount;
    }

    // Roles ADMIN
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    // Role FOUNDER
    bytes32 public constant FOUNDER_ROLE = keccak256("FOUNDER_ROLE");

    // Workflow statuses
    enum WorkflowStatus {
        REGISTER_CANDIDATES,
        FOUND_CANDIDATES,
        VOTE,
        COMPLETED
    }

    WorkflowStatus public workflowStatus;

    // Mappings et variables de stockage
    mapping(uint => Candidate) public candidates;
    mapping(address => bool) public voters;
    uint[] private candidateIds;

    // Fonds associés à chaque candidat
    mapping(uint => uint) public candidateFunds;

    // Constructeur
    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);

        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;
    }

    modifier onlyDuring(WorkflowStatus _status) {
        require(
            workflowStatus == _status,
            "Function cannot be called at this time"
        );
        _;
    }

    // Gestion du workflow
    function setWorkflowStatus(
        WorkflowStatus _newStatus
    ) external onlyRole(ADMIN_ROLE) {
        workflowStatus = _newStatus;
    }

    // Fonctions pour gérer les candidats et les votes
    function addCandidate(
        string memory _name
    )
        public
        onlyRole(ADMIN_ROLE)
        onlyDuring(WorkflowStatus.REGISTER_CANDIDATES)
    {
        require(bytes(_name).length > 0, "Candidate name cannot be empty");

        uint candidateId = candidateIds.length + 1;
        candidates[candidateId] = Candidate(candidateId, _name, 0);
        candidateIds.push(candidateId);
    }

    // Fonction pour voter pour un candidat
    function vote(uint _candidateId) public onlyDuring(WorkflowStatus.VOTE) {
        require(!voters[msg.sender], "You have already voted");
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;
    }

    // Fonction pour envoyer des fonds à un candidat (seulement les founders)
    function fundCandidate(
        uint _candidateId
    ) external payable onlyRole(FOUNDER_ROLE) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        require(msg.value > 0, "No funds sent");

        candidateFunds[_candidateId] += msg.value;
    }

    // Fonctions pour obtenir les résultats
    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId].voteCount;
    }

    // Fonction pour obtenir le nombre total de candidats
    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

    // Fonction pour obtenir les détails d'un candidat
    function getCandidate(
        uint _candidateId
    ) public view returns (Candidate memory) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId];
    }

    function transferOwnership(address newOwner) public override onlyOwner {
        address oldOwner = owner();

        super.transferOwnership(newOwner);

        _revokeRole(ADMIN_ROLE, oldOwner);
        _revokeRole(FOUNDER_ROLE, oldOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);

        _grantRole(ADMIN_ROLE, newOwner);
        _grantRole(FOUNDER_ROLE, newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }
}
