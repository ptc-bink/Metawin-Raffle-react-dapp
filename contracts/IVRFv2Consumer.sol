// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "./VRFv2Consumer.sol";

interface IVRFv2Consumer {
  function requestRandomWords() external returns (uint256); // call every time, the VRF Consumer will determine whether to formally request the randomWords

  function getRequestStatus(uint256 requestId) external view returns (uint256[] memory); // returns the result of the requestId once the callback has been made.  Returns 0 otherwise (never use the 0 result as a result)
}