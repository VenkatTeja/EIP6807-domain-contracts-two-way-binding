// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";

interface IDappRegistry {    
  function isMyContract(address _address) external view returns (bool);
  function owner() external view returns (address);
}

error DRC_UnknownContractAddress();
error DRC_CoolOffPeriodNotOver();

contract DomainContractRegistry is ChainlinkClient{
  using Chainlink for Chainlink.Request;
  
  struct RegistryInfo {
    address dappRegistry;
    address admin;
  }

  struct RecordTransition {
    address dappRegistry;
    uint256 timestamp;
  }
  
  bytes32 private jobId;
  uint256 private fee;
  string private domain;
  IDappRegistry private dappRegistry;
  mapping(string => RegistryInfo) public registryMap;
  mapping(string => RecordTransition) public recordTransitionMap;

  constructor() {
    setChainlinkToken(0x779877A7B0D9E8603169DdbD7836e478b4624789);
    setChainlinkOracle(0x6090149792dAAeE9D1D568c9f9a6F6B46AA29eFD);
    jobId = "7d80a6386ef543a3abb52817f6707e3b";
    fee = (1 * LINK_DIVISIBILITY) / 10;
  }

  function setDappRegistry(string memory _domain, address _dappRegistry) external {
    // check if a domain already has a dapp registry mapped
    // if yes, check if owner is same. if so, allow the change
    // if no, recordTransition(_domain, _dappRegistry);
      
    dappRegistry = IDappRegistry(_dappRegistry);
    domain = _domain;

    if(registryMap[_domain].dappRegistry != address(0)) {

      if(registryMap[_domain].admin == dappRegistry.owner()) {

        // Use chainlink to the call `{{domain}}/contracts.json`. 
        // Check for each contract listed in contracts.json by calling 
        // dappRegistry.isMyContract(_address)

        _checkForDomain(_domain, this.fulfill1.selector);

      } else {
        recordTransition(_domain, _dappRegistry);
      }

    }else {

    _checkForDomain(_domain, this.fulfill2.selector);
    }
  }

  function _checkForDomain(string memory _domain, bytes4 selector) internal returns (bytes32 requestId) {
    Chainlink.Request memory req = buildChainlinkRequest(
      jobId,
      address(this),
      selector
    );

    req.add(
      "get",
      string(
        abi.encodePacked(
          "https://",
          _domain,
          "/contracts.json"
        )
      )
    );

    req.add("path", "0,contractAddress");

    return sendChainlinkRequest(req, fee);
  }
    

  function fulfill1(bytes32 _requestId, string memory _address) public recordChainlinkFulfillment(_requestId) {
    address _parsedAddress;
    _parsedAddress = parseAddr(_address);

    if(!dappRegistry.isMyContract(_parsedAddress)) {
      revert DRC_UnknownContractAddress();
    }
    registryMap[domain].dappRegistry = address(dappRegistry);
  }
  

  function fulfill2(bytes32 _requestId, string memory _address) public recordChainlinkFulfillment(_requestId) {
    address _parsedAddress;
    _parsedAddress = parseAddr(_address);

    if(!dappRegistry.isMyContract(_parsedAddress)) {
      revert DRC_UnknownContractAddress();
    }
    registryMap[domain].dappRegistry = address(dappRegistry);
    registryMap[domain].admin = dappRegistry.owner();
  }


  function fulfill3(bytes32 _requestId, string memory _address) public recordChainlinkFulfillment(_requestId) {
    address _parsedAddress;
    _parsedAddress = parseAddr(_address);

    if(!dappRegistry.isMyContract(_parsedAddress)) {
      revert DRC_UnknownContractAddress();
    }

    if(recordTransitionMap[domain].dappRegistry == address(dappRegistry)) {
      if(block.timestamp > recordTransitionMap[domain].timestamp + 7 days) {
        registryMap[domain].dappRegistry = address(dappRegistry);
        registryMap[domain].admin = dappRegistry.owner();
      }
      else {
        revert DRC_CoolOffPeriodNotOver();
      }
    }
    else {
      recordTransitionMap[domain].dappRegistry = address(dappRegistry);
      recordTransitionMap[domain].timestamp = block.timestamp ;
    }
  }

  // In case of a domain transfer, register that there is potential change in registry mapping
  // and a new owner may be attempting to update registry
  // A cool-off period is applied on the domain marking a potential transfer in ownership
  // Cool-off period can be 7 days
  function recordTransition(string memory _domain, address _dappRegistry) internal {
    
    dappRegistry = IDappRegistry(_dappRegistry);
    _checkForDomain(_domain, this.fulfill3.selector);
  }

  function parseAddr(string memory _a) internal pure returns (address _parsedAddress) {
    bytes memory tmp = bytes(_a);
    uint160 iaddr = 0;
    uint160 b1;
    uint160 b2;
    for (uint i = 2; i < 2 + 2 * 20; i += 2) {
        iaddr *= 256;
        b1 = uint160(uint8(tmp[i]));
        b2 = uint160(uint8(tmp[i + 1]));
        if ((b1 >= 97) && (b1 <= 102)) {
            b1 -= 87;
        } else if ((b1 >= 65) && (b1 <= 70)) {
            b1 -= 55;
        } else if ((b1 >= 48) && (b1 <= 57)) {
            b1 -= 48;
        }
        if ((b2 >= 97) && (b2 <= 102)) {
            b2 -= 87;
        } else if ((b2 >= 65) && (b2 <= 70)) {
            b2 -= 55;
        } else if ((b2 >= 48) && (b2 <= 57)) {
            b2 -= 48;
        }
        iaddr += (b1 * 16 + b2);
    }
    return address(iaddr);
}
     
}