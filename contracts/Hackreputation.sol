// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./PhatRollupAnchor.sol";

contract Hackreputation is PhatRollupAnchor, Ownable {
    event ResponseReceived(uint reqId, string pair, uint256 value);
    event ErrorReceived(uint reqId, string pair, uint256 errno);

    uint constant TYPE_RESPONSE = 0;
    uint constant TYPE_ERROR = 2;

    mapping(uint => string) requests;
    uint nextRequest = 1;

    struct HackathonData {
        uint numberOfParticipations; // 10
        uint numberOfWins; // 6
        uint numberOfLosses; // 4
    }

    mapping(string => HackathonData) public hackathons; // Mapping from profileID to HackathonData

    constructor(address phatAttestor) {
        _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
    }

    function increaseParticipations(string calldata profileId) external onlyOwner {
        hackathons[profileId].numberOfParticipations++;
    }

    function increaseWins(string calldata profileId) external onlyOwner {
        hackathons[profileId].numberOfWins++;
    }

    function increaseLosses(string calldata profileId) external onlyOwner {
        hackathons[profileId].numberOfLosses++;
    }

    // Function to get the hackathon data for a user
    function getHackathonData(string calldata profileId) external view returns (uint, uint, uint) {
        HackathonData storage userData = hackathons[profileId];
        return (userData.numberOfParticipations, userData.numberOfWins, userData.numberOfLosses);
    }

// hackreputation
    function calculateReputation(string calldata profileId) public view returns (uint) {
        HackathonData storage userData = hackathons[profileId];

        uint reputation = userData.numberOfWins * 2 - userData.numberOfLosses * 4 + userData.numberOfParticipations;
        return reputation;
    }

    function setAttestor(address phatAttestor) public {
        _grantRole(PhatRollupAnchor.ATTESTOR_ROLE, phatAttestor);
    }

    function request(string calldata profileId) public {
        // assemble the request
        uint id = nextRequest;
        requests[id] = profileId;
        _pushMessage(abi.encode(id, profileId));
        nextRequest += 1;
    }

    function malformedRequest(bytes calldata malformedData) public {
        uint id = nextRequest;
        requests[id] = "malformed_req";
        _pushMessage(malformedData);
        nextRequest += 1;
    }

    function _onMessageReceived(bytes calldata action) internal override {
        require(action.length == 32 * 3, "cannot parse action");
        (uint respType, uint id, uint256 data) = abi.decode(
            action,
            (uint, uint, uint256)
        );
        // data -> lens data
        if (respType == TYPE_RESPONSE) {
            uint reputation = this.calculateReputation(requests[id]);
            // Calculate overall hackreputation value by adding data value
            uint overallReputation = reputation + data;
            emit ResponseReceived(id, requests[id], overallReputation);
        } else if (respType == TYPE_ERROR) {
            delete requests[id];
        }
    }
}
