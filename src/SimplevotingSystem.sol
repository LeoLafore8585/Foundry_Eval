// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {
    AccessControl
} from "openzeppelin-contracts/contracts/access/AccessControl.sol";
import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";

// NFT de vote, un NFT par votant
contract VotingNFT is ERC721, Ownable {
    uint256 private _nextTokenId;

    constructor() ERC721("VotingNFT", "VOTE") Ownable(msg.sender) {}

    function safeMint(address to) external onlyOwner {
        uint256 tokenId = ++_nextTokenId;
        _safeMint(to, tokenId);
    }
}

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
    // Role WITHDRAWER
    bytes32 public constant WITHDRAWER_ROLE = keccak256("WITHDRAWER_ROLE");

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
    mapping(uint => uint) public candidateFunds;
    uint[] private candidateIds;

    // Timestamp de début de la phase VOTE
    uint public voteStartTime;

    // Contrat NFT de vote
    VotingNFT public votingNFT;

    // Constructeur
    constructor() Ownable(msg.sender) {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(FOUNDER_ROLE, msg.sender);
        _grantRole(WITHDRAWER_ROLE, msg.sender);

        workflowStatus = WorkflowStatus.REGISTER_CANDIDATES;

        // Déploiement du NFT de vote
        votingNFT = new VotingNFT();
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

        if (_newStatus == WorkflowStatus.VOTE) {
            voteStartTime = block.timestamp;
        }
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
        require(
            block.timestamp >= voteStartTime + 1 hours,
            "Voting not allowed yet"
        );
        require(
            votingNFT.balanceOf(msg.sender) == 0,
            "Already owns voting NFT"
        );

        voters[msg.sender] = true;
        candidates[_candidateId].voteCount += 1;

        // Donne un NFT de vote au votant
        votingNFT.safeMint(msg.sender);
    }

    // Funding des candidats
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

    // Fonction de retrait des fonds du contrat (seulement quand le workflow est terminé)
    function withdraw(
        address payable to,
        uint amount
    ) external onlyRole(WITHDRAWER_ROLE) {
        require(
            workflowStatus == WorkflowStatus.COMPLETED,
            "Workflow not completed"
        );
        require(to != address(0), "Invalid recipient");
        require(amount > 0, "Amount must be greater than zero");
        require(address(this).balance >= amount, "Insufficient balance");

        (bool success, ) = to.call{value: amount}("");
        require(success, "Withdraw failed");
    }

    // Fonctions pour obtenir les résultats
    function getTotalVotes(uint _candidateId) public view returns (uint) {
        require(
            _candidateId > 0 && _candidateId <= candidateIds.length,
            "Invalid candidate ID"
        );
        return candidates[_candidateId].voteCount;
    }

    function getCandidatesCount() public view returns (uint) {
        return candidateIds.length;
    }

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
        _revokeRole(WITHDRAWER_ROLE, oldOwner);
        _revokeRole(DEFAULT_ADMIN_ROLE, oldOwner);

        _grantRole(ADMIN_ROLE, newOwner);
        _grantRole(FOUNDER_ROLE, newOwner);
        _grantRole(WITHDRAWER_ROLE, newOwner);
        _grantRole(DEFAULT_ADMIN_ROLE, newOwner);
    }

    // Désigne le candidat vainqueur lorsque le workflow est terminé
    function getWinningCandidateId() public view returns (uint) {
        require(
            workflowStatus == WorkflowStatus.COMPLETED,
            "Workflow not completed"
        );
        require(candidateIds.length > 0, "No candidates");

        uint winningId = candidateIds[0];
        uint highestVotes = candidates[winningId].voteCount;

        for (uint i = 1; i < candidateIds.length; i++) {
            uint candidateId = candidateIds[i];
            uint votes = candidates[candidateId].voteCount;
            if (votes > highestVotes) {
                highestVotes = votes;
                winningId = candidateId;
            }
        }

        return winningId;
    }
}
