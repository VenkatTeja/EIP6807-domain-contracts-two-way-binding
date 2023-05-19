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

    if(registryMap[_domain].dappRegistry != address(0)) {

      if(registryMap[_domain].admin == dappRegistry.owner()) {

        // Use chainlink to the call `{{domain}}/contracts.json`. 
        // Check for each contract listed in contracts.json by calling 
        // dappRegistry.isMyContract(_address)

        _checkForDomain(_domain);

        // If all addresses match, update registryMap
        registryMap[_domain].dappRegistry = _dappRegistry;

      } else {
        recordTransition(_domain, _dappRegistry);
      }

    }else {

    _checkForDomain(_domain);
     
    registryMap[_domain].dappRegistry = _dappRegistry;
    registryMap[_domain].admin = dappRegistry.owner();
    }
  }

  function _checkForDomain(string memory _domain) internal returns (bytes32 requestId) {

    Chainlink.Request memory req = buildChainlinkRequest(
      jobId,
      address(this),
      this.fulfill.selector
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
    
  function fulfill(bytes32 _requestId, string memory _address) public recordChainlinkFulfillment(_requestId) {
    bytes memory _bytes = bytes(_address);
    address _parsedAddress;
    
    assembly {
        _parsedAddress := mload(add(_bytes, 20))
    }
    
    if(!dappRegistry.isMyContract(_parsedAddress)) {
      revert DRC_UnknownContractAddress();
    }
  }

  // In case of a domain transfer, register that there is potential change in registry mapping
  // and a new owner may be attempting to update registry
  // A cool-off period is applied on the domain marking a potential transfer in ownership
  // Cool-off period can be 7 days
  function recordTransition(string memory _domain, address _dappRegistry) internal {
    
    dappRegistry = IDappRegistry(_dappRegistry);
    _checkForDomain(_domain);

    if(recordTransitionMap[_domain].dappRegistry == _dappRegistry) {
      if(block.timestamp > recordTransitionMap[_domain].timestamp + 7 days) {
        registryMap[_domain].dappRegistry = _dappRegistry;
        registryMap[_domain].admin = dappRegistry.owner();
      }
      else {
        revert DRC_CoolOffPeriodNotOver();
      }
    }
    else {
      recordTransitionMap[_domain].dappRegistry = _dappRegistry;
      recordTransitionMap[_domain].timestamp = block.timestamp ;
    }
  }
     
}