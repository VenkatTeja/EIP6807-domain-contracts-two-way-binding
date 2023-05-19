// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;
 
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDappRegistry {
    function isMyContract(address _address) external view returns (bool);
}

contract DRC is IDappRegistry,Ownable{

    mapping(address => bool) private _contractAddress;

    function addAddress(address _address) external onlyOwner {
        _contractAddress[_address] = true;
    }

    function removeAddress(address _address) external onlyOwner {
        _contractAddress[_address] = false;
    }

    function isMyContract(address _address) external view override returns (bool) {
        return _contractAddress[_address];
    }

}