// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "./interfaces/ITuringHelper.sol";
import "@openzeppelin/contracts/metatx/ERC2771Context.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract AuthenticatedFaucet is ERC2771Context {
    string public apiUrl;
    ITuringHelper public turingHelper;
    mapping(uint256 => uint256) twitterUserLastClaim;
    uint256 lastEpochStart;
    uint256 amountClaimsInLastEpoch;
    uint256 maxClaimsPerEpoch;
    uint256 testnetETHPerClaim;

    event GasClaimed(uint256 authorId);

    constructor(address trustedForwarder, string memory apiUrl_, address turingHelper_, uint256 maxClaimsPerEpoch_, uint256 testnetETHPerClaim_)
            ERC2771Context(trustedForwarder) {
        apiUrl = apiUrl_;
        turingHelper = ITuringHelper(turingHelper_);
        lastEpochStart = block.timestamp;
        amountClaimsInLastEpoch = 0;
        maxClaimsPerEpoch = maxClaimsPerEpoch_;
        testnetETHPerClaim = testnetETHPerClaim_;
    }

    /// @dev Send funds to authenticated user. OnlyOwner as sent via Signature.
    /// @param twitterPostID_: Tweet ID with the assigned ID.
    function sendFunds(string calldata twitterPostID_) external {
        require(address(this).balance >= testnetETHPerClaim, "No testnet funds");
        if (block.timestamp >= (lastEpochStart + 1 hours)) {
            lastEpochStart = block.timestamp;
            amountClaimsInLastEpoch = 1;
        } else {
            amountClaimsInLastEpoch++;
        }

        require(amountClaimsInLastEpoch < maxClaimsPerEpoch, "Rate limit reached");

        bytes memory encRequest = abi.encode(_msgSender(), twitterPostID_);

        (uint256 resp, uint256 authorId, uint256 errorMsgVal) = abi.decode(turingHelper.TuringTx(apiUrl, encRequest), (uint256, uint256, uint256));
        // 0 = false, 1 = true
        bool isAllowedToClaim = resp != 0;

        require(isAllowedToClaim, string(abi.encodePacked("Invalid request:", Strings.toString(errorMsgVal))));
        require((block.timestamp - twitterUserLastClaim[authorId]) > 1 days, "Cooldown");
        twitterUserLastClaim[authorId] = block.timestamp;

        payable(_msgSender()).transfer(testnetETHPerClaim);
        emit GasClaimed(authorId);
    }

    receive() external payable {}
}